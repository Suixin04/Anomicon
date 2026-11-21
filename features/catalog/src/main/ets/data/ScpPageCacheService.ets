import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { ArkTSUtils } from '@kit.ArkTS';
import { ANOMICON_DATABASE_NAME, AtomicTextCacheFileStore } from 'anomiconbasic';

const TABLE_NAME: string = 'scp_page_cache';
const PAGE_TEXT_CACHE_DIRECTORY: string = 'scp_page_text_cache';
const CREATE_CACHE_TABLE: string =
  'CREATE TABLE IF NOT EXISTS scp_page_cache (' +
  'source_url TEXT PRIMARY KEY, html TEXT NOT NULL DEFAULT \'\', html_path TEXT NOT NULL DEFAULT \'\', ' +
  'fetched_at INTEGER NOT NULL, etag TEXT NOT NULL DEFAULT \'\', ' +
  'last_modified TEXT NOT NULL DEFAULT \'\')';
const ADD_HTML_PATH_COLUMN: string =
  'ALTER TABLE scp_page_cache ADD COLUMN html_path TEXT NOT NULL DEFAULT \'\'';

export class ScpCachedPage {
  readonly sourceUrl: string;
  readonly html: string;
  readonly fetchedAt: number;
  readonly etag: string;
  readonly lastModified: string;

  constructor(
    sourceUrl: string,
    html: string,
    fetchedAt: number,
    etag: string = '',
    lastModified: string = ''
  ) {
    this.sourceUrl = sourceUrl;
    this.html = html;
    this.fetchedAt = fetchedAt;
    this.etag = etag;
    this.lastModified = lastModified;
  }
}

/** 原始网页快照缓存。数据库对象只在主线程使用，不传入 TaskPool。 */
export class ScpPageCacheService {
  private store: relationalStore.RdbStore | undefined = undefined;
  private textFiles: AtomicTextCacheFileStore | undefined = undefined;
  private initialization: Promise<void> | undefined = undefined;
  private context: common.UIAbilityContext | undefined = undefined;
  private readonly operationLock: ArkTSUtils.locks.AsyncLock =
    new ArkTSUtils.locks.AsyncLock();
  // Request generations are supplied by CachedArticleRepo.  Fetched-at is
  // retained as a second guard so a restarted service can still reject an
  // older response using the persisted row metadata.
  private readonly latestGenerations: Map<string, number> = new Map<string, number>();
  private readonly latestFetchedAts: Map<string, number> = new Map<string, number>();

  initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.store !== undefined && this.textFiles !== undefined) {
      return Promise.resolve();
    }
    if (this.initialization !== undefined) {
      return this.initialization;
    }
    this.initialization = this.open(context);
    return this.initialization;
  }

  /** Records a request generation before its asynchronous network work starts. */
  registerGeneration(sourceUrl: string, requestedGeneration: number): number {
    const current = this.latestGenerations.get(sourceUrl);
    const generation = current === undefined || requestedGeneration > current ?
      requestedGeneration : current + 1;
    this.latestGenerations.set(sourceUrl, generation);
    return generation;
  }

  async get(sourceUrl: string): Promise<ScpCachedPage | undefined> {
    let cached: ScpCachedPage | undefined = undefined;
    await this.enqueueOperation(async (): Promise<void> => {
      cached = await this.getNow(sourceUrl);
      if (cached !== undefined) {
        this.recordFetchedAt(sourceUrl, cached.fetchedAt);
      }
    });
    return cached;
  }

  private async getNow(sourceUrl: string): Promise<ScpCachedPage | undefined> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('source_url', sourceUrl);
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    let storedSourceUrl: string = '';
    let currentHtml: string = '';
    let htmlPath: string = '';
    let fetchedAt: number = 0;
    let etag: string = '';
    let lastModified: string = '';
    try {
      resultSet = await store.query(predicates, [
        'source_url', 'html', 'html_path', 'fetched_at', 'etag', 'last_modified'
      ]);
      if (!resultSet.goToFirstRow()) {
        return undefined;
      }
      storedSourceUrl = resultSet.getString(resultSet.getColumnIndex('source_url'));
      currentHtml = resultSet.getString(resultSet.getColumnIndex('html'));
      htmlPath = resultSet.getString(resultSet.getColumnIndex('html_path'));
      fetchedAt = resultSet.getLong(resultSet.getColumnIndex('fetched_at'));
      etag = resultSet.getString(resultSet.getColumnIndex('etag'));
      lastModified = resultSet.getString(resultSet.getColumnIndex('last_modified'));
    } catch (error) {
      throw this.cacheError('读取', error);
    } finally {
      this.closeResultSet(resultSet, 'page');
    }

    let html = currentHtml;
    if (htmlPath.length > 0) {
      // Rows written before the file-backed migration may still contain a
      // usable RDB copy.  If the sidecar file is temporarily unavailable (or
      // was lost during an interrupted migration), keep that copy as the
      // fallback instead of turning a valid page cache into a miss.
      const fileHtml = await this.requireTextFiles().read(htmlPath);
      if (fileHtml !== undefined) {
        html = fileHtml;
      }
    }
    if (html.trim().length === 0) {
      // AtomicTextCacheFileStore already removes files it can prove damaged.
      // An undefined read also represents a transient I/O/open failure, so do
      // not delete the path here or a recoverable cache would be lost.
      return undefined;
    }
    return new ScpCachedPage(storedSourceUrl, html, fetchedAt, etag, lastModified);
  }

  async put(page: ScpCachedPage, generation?: number): Promise<void> {
    await this.enqueueOperation(async (): Promise<void> => {
      const committed = await this.putNow(page, generation);
      if (committed) {
        this.recordCommittedWrite(page.sourceUrl, page.fetchedAt, generation);
      }
    });
  }

  private async putNow(page: ScpCachedPage, generation?: number): Promise<boolean> {
    const store = await this.requireStore();
    const textFiles = this.requireTextFiles();
    const previousPath = await this.findHtmlPathNow(page.sourceUrl);
    const storedFetchedAt = await this.readFetchedAtNow(page.sourceUrl);
    if (!this.shouldAcceptWrite(page.sourceUrl, page.fetchedAt, generation, storedFetchedAt)) {
      return false;
    }
    let nextPath: string = '';
    let committed: boolean = false;
    try {
      nextPath = await textFiles.write(page.html);
      // A newer request may register while the sidecar write is suspended.
      // Re-read the durable timestamp and re-check before replacing metadata.
      const latestStoredFetchedAt = await this.readFetchedAtNow(page.sourceUrl);
      if (!this.shouldAcceptWrite(
        page.sourceUrl, page.fetchedAt, generation, latestStoredFetchedAt)) {
        await this.removeFileQuietly(nextPath, 'obsolete page');
        nextPath = '';
        return false;
      }
      const values: relationalStore.ValuesBucket = {
        'source_url': page.sourceUrl,
        // 旧字段保留为空值只为兼容既有 NOT NULL 表结构；正文不再进入 RDB。
        'html': '',
        'html_path': nextPath,
        'fetched_at': page.fetchedAt,
        'etag': page.etag,
        'last_modified': page.lastModified
      };
      const rowId = await store.insert(
        TABLE_NAME,
        values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
      if (rowId < 0) {
        throw new Error(`写入网页缓存元数据失败：${page.sourceUrl}`);
      }
      committed = true;
      if (previousPath.length > 0 && previousPath !== nextPath) {
        await this.removeFileQuietly(previousPath, 'replaced page');
      }
      return true;
    } catch (error) {
      if (!committed && nextPath.length > 0) {
        await this.removeFileQuietly(nextPath, 'uncommitted page');
      }
      throw this.cacheError('写入', error);
    }
  }

  /** 服务器以 304 确认副本未变时只续期时间戳，不重写正文。 */
  async updateFetchedAt(sourceUrl: string, fetchedAt: number, generation?: number): Promise<boolean> {
    let renewed = false;
    await this.enqueueOperation(async (): Promise<void> => {
      const storedFetchedAt = await this.readFetchedAtNow(sourceUrl);
      if (storedFetchedAt === undefined ||
        !this.shouldAcceptWrite(sourceUrl, fetchedAt, generation, storedFetchedAt)) {
        return;
      }
      const store = await this.requireStore();
      const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
      predicates.equalTo('source_url', sourceUrl);
      const values: relationalStore.ValuesBucket = { 'fetched_at': fetchedAt };
      try {
        // Keep the generation check adjacent to the actual update.  Request
        // registration can happen while the metadata query above is pending.
        const latestStoredFetchedAt = await this.readFetchedAtNow(sourceUrl);
        if (!this.shouldAcceptWrite(sourceUrl, fetchedAt, generation, latestStoredFetchedAt)) {
          return;
        }
        const updated = await store.update(values, predicates);
        if (updated <= 0) {
          throw new Error(`续期网页缓存失败：${sourceUrl}`);
        }
        this.recordCommittedWrite(sourceUrl, fetchedAt, generation);
        renewed = true;
      } catch (error) {
        throw this.cacheError('续期', error);
      }
    });
    return renewed;
  }

  /** 仅删除指定 URL 的原始网页快照，不影响其他文章缓存。 */
  async remove(sourceUrl: string, rejectedHtml?: string): Promise<void> {
    await this.enqueueOperation(async (): Promise<void> => {
      if (rejectedHtml !== undefined) {
        const current = await this.getNow(sourceUrl);
        if (current === undefined || current.html !== rejectedHtml) {
          return;
        }
        // This rejection concerns one payload, not any pending refresh for the URL.
      } else {
        // Explicit URL invalidation also rejects older in-flight writes.
        this.advanceGeneration(sourceUrl);
      }
      const store = await this.requireStore();
      const previousPath = await this.findHtmlPathNow(sourceUrl);
      const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
      predicates.equalTo('source_url', sourceUrl);
      try {
        const deleted = await store.delete(predicates);
        if (deleted < 0) {
          throw new Error(`删除网页缓存元数据失败：${sourceUrl}`);
        }
      } catch (error) {
        throw this.cacheError('删除', error);
      }
      if (previousPath.length > 0) {
        await this.removeFileQuietly(previousPath, 'removed page');
      }
    });
  }

  private async open(context: common.UIAbilityContext): Promise<void> {
    try {
      const textFiles = new AtomicTextCacheFileStore(context.cacheDir, PAGE_TEXT_CACHE_DIRECTORY);
      await textFiles.initialize();
      const store = await relationalStore.getRdbStore(context, {
        name: ANOMICON_DATABASE_NAME,
        securityLevel: relationalStore.SecurityLevel.S1,
        encrypt: false
      });
      await store.executeSql(CREATE_CACHE_TABLE);
      await this.ensureHtmlPathColumn(store);
      this.textFiles = textFiles;
      this.store = store;
    } catch (error) {
      this.initialization = undefined;
      throw this.cacheError('初始化', error);
    }
  }

  private async requireStore(): Promise<relationalStore.RdbStore> {
    if (this.initialization !== undefined) {
      await this.initialization;
    }
    if ((this.store === undefined || this.textFiles === undefined) && this.context !== undefined) {
      // A failed database/file-cache open clears initialization.  Retry on
      // demand so one transient startup error cannot poison the graph.
      await this.initialize(this.context);
    }
    if (this.store === undefined) {
      throw new Error('图鉴缓存尚未初始化');
    }
    return this.store;
  }

  private requireTextFiles(): AtomicTextCacheFileStore {
    if (this.textFiles === undefined) {
      throw new Error('网页文本缓存目录尚未初始化');
    }
    return this.textFiles;
  }

  private async ensureHtmlPathColumn(store: relationalStore.RdbStore): Promise<void> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    let hasPath: boolean = false;
    try {
      resultSet = await store.querySql(`PRAGMA table_info(${TABLE_NAME})`);
      while (resultSet.goToNextRow()) {
        if (resultSet.getString(resultSet.getColumnIndex('name')) === 'html_path') {
          hasPath = true;
          break;
        }
      }
    } catch (error) {
      throw this.cacheError('检查表结构', error);
    } finally {
      this.closeResultSet(resultSet, 'page schema');
    }
    if (!hasPath) {
      try {
        await store.executeSql(ADD_HTML_PATH_COLUMN);
      } catch (error) {
        throw this.cacheError('升级表结构', error);
      }
    }
  }

  private async readFetchedAtNow(sourceUrl: string): Promise<number | undefined> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('source_url', sourceUrl);
    predicates.limitAs(1);
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await store.query(predicates, ['fetched_at']);
      if (!resultSet.goToFirstRow()) {
        return undefined;
      }
      return resultSet.getLong(resultSet.getColumnIndex('fetched_at'));
    } catch (error) {
      throw this.cacheError('查询更新时间', error);
    } finally {
      this.closeResultSet(resultSet, 'page fetched-at');
    }
  }

  private shouldAcceptWrite(
    sourceUrl: string,
    fetchedAt: number,
    generation: number | undefined,
    storedFetchedAt: number | undefined
  ): boolean {
    const knownFetchedAt = Math.max(
      this.latestFetchedAts.get(sourceUrl) ?? 0,
      storedFetchedAt ?? 0
    );
    if (knownFetchedAt > fetchedAt) {
      return false;
    }
    const latestGeneration = this.latestGenerations.get(sourceUrl);
    if (latestGeneration !== undefined && generation !== undefined && generation < latestGeneration) {
      return false;
    }
    return true;
  }

  private recordFetchedAt(sourceUrl: string, fetchedAt: number): void {
    const current = this.latestFetchedAts.get(sourceUrl);
    if (current === undefined || fetchedAt > current) {
      this.latestFetchedAts.set(sourceUrl, fetchedAt);
    }
  }

  private recordCommittedWrite(sourceUrl: string, fetchedAt: number, generation: number | undefined): void {
    this.recordFetchedAt(sourceUrl, fetchedAt);
    if (generation !== undefined) {
      const current = this.latestGenerations.get(sourceUrl);
      if (current === undefined || generation > current) {
        this.latestGenerations.set(sourceUrl, generation);
      }
    }
  }

  private advanceGeneration(sourceUrl: string): void {
    const current = this.latestGenerations.get(sourceUrl) ?? 0;
    this.latestGenerations.set(sourceUrl, current + 1);
  }

  private async findHtmlPathNow(sourceUrl: string): Promise<string> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('source_url', sourceUrl);
    predicates.limitAs(1);
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await store.query(predicates, ['html_path']);
      return resultSet.goToFirstRow() ?
        resultSet.getString(resultSet.getColumnIndex('html_path')) : '';
    } catch (error) {
      throw this.cacheError('查询文件路径', error);
    } finally {
      this.closeResultSet(resultSet, 'page path');
    }
  }

  private enqueueOperation(operation: () => Promise<void>): Promise<void> {
    try {
      return this.operationLock.lockAsync<void>(
        operation,
        ArkTSUtils.locks.AsyncLockMode.EXCLUSIVE
      );
    } catch (error) {
      return Promise.reject(error);
    }
  }

  private async removeFileQuietly(path: string, reason: string): Promise<void> {
    try {
      await this.requireTextFiles().remove(path);
    } catch (error) {
      console.warn(
        `Clean ${reason} file failed: ${error instanceof Error ? error.message : 'unknown error'}`
      );
    }
  }

  private closeResultSet(resultSet: relationalStore.ResultSet | undefined, operation: string): void {
    try {
      resultSet?.close();
    } catch (error) {
      console.warn(
        `Close ${operation} result set failed: ${error instanceof Error ? error.message : 'unknown error'}`
      );
    }
  }

  private cacheError(operation: string, error: Object): Error {
    const message = error instanceof Error ? error.message : '未知数据库错误';
    return new Error(`图鉴缓存${operation}失败：${message}`);
  }
}
