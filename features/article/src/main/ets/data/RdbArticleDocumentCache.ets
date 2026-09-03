import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { ArkTSUtils } from '@kit.ArkTS';
import { ANOMICON_DATABASE_NAME, AtomicTextCacheFileStore } from 'anomiconbasic';
import {
  ArticleDocumentCachePort,
  ArticleDocumentCacheRecord
} from '../domain/ArticleContracts';
import { ArticleCachePolicy } from '../domain/ArticleCachePolicy';

const TABLE_NAME: string = 'scp_article_document';
const DOCUMENT_TEXT_CACHE_DIRECTORY: string = 'scp_document_text_cache';
const CREATE_DOC_TABLE: string =
  'CREATE TABLE IF NOT EXISTS scp_article_document (' +
  'item_id TEXT PRIMARY KEY, json TEXT NOT NULL DEFAULT \'\', json_path TEXT NOT NULL DEFAULT \'\', ' +
  'schema_version INTEGER NOT NULL, parsed_at INTEGER NOT NULL)';
const ADD_JSON_PATH_COLUMN: string =
  'ALTER TABLE scp_article_document ADD COLUMN json_path TEXT NOT NULL DEFAULT \'\'';

/** 解析结果的持久化缓存：新鲜期内零 HTML 解析开销，过期后由页面后台重验。 */
export class RdbArticleDocumentCache implements ArticleDocumentCachePort {
  private readonly context: common.UIAbilityContext;
  private store: relationalStore.RdbStore | undefined = undefined;
  private textFiles: AtomicTextCacheFileStore | undefined = undefined;
  private initialization: Promise<void> | undefined = undefined;
  private readonly operationLock: ArkTSUtils.locks.AsyncLock =
    new ArkTSUtils.locks.AsyncLock();

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  isFresh(document: ArticleDocumentCacheRecord): boolean {
    return ArticleCachePolicy.isFresh(document.parsedAt);
  }

  initialize(): Promise<void> {
    if (this.initialization !== undefined) {
      return this.initialization;
    }
    this.initialization = this.open();
    return this.initialization;
  }

  async get(itemId: string): Promise<ArticleDocumentCacheRecord | undefined> {
    let stored: ArticleDocumentCacheRecord | undefined = undefined;
    await this.enqueueOperation(async (): Promise<void> => {
      stored = await this.getNow(itemId);
    });
    return stored;
  }

  private async getNow(itemId: string): Promise<ArticleDocumentCacheRecord | undefined> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('item_id', itemId);
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    let storedItemId: string = '';
    let currentJson: string = '';
    let jsonPath: string = '';
    let schemaVersion: number = 0;
    let parsedAt: number = 0;
    try {
      resultSet = await store.query(predicates, [
        'item_id', 'json', 'json_path', 'schema_version', 'parsed_at'
      ]);
      if (!resultSet.goToFirstRow()) {
        return undefined;
      }
      storedItemId = resultSet.getString(resultSet.getColumnIndex('item_id'));
      currentJson = resultSet.getString(resultSet.getColumnIndex('json'));
      jsonPath = resultSet.getString(resultSet.getColumnIndex('json_path'));
      schemaVersion = resultSet.getLong(resultSet.getColumnIndex('schema_version'));
      parsedAt = resultSet.getLong(resultSet.getColumnIndex('parsed_at'));
    } catch (error) {
      throw this.documentError('读取', error);
    } finally {
      this.closeResultSet(resultSet, 'document');
    }

    let json = currentJson;
    if (jsonPath.length > 0) {
      // The file column is the new source of truth, but older rows still keep
      // a usable JSON copy in `json`.  A missing/temporarily unreadable file
      // must therefore fall back to that legacy copy instead of turning a
      // valid cache row into a miss.  Ignore whitespace or malformed files so
      // they cannot hide a valid legacy value.
      const fileJson = await this.requireTextFiles().read(jsonPath);
      if (fileJson !== undefined && this.isValidJson(fileJson)) {
        json = fileJson;
      }
    }
    if (!this.isValidJson(json)) {
      // AtomicTextCacheFileStore removes only files it can prove damaged.
      // An undefined read may be a transient I/O failure; never turn that
      // cache miss into destructive cleanup at this layer.
      return undefined;
    }
    return {
      itemId: storedItemId,
      json,
      schemaVersion,
      parsedAt
    };
  }

  async put(document: ArticleDocumentCacheRecord): Promise<void> {
    await this.enqueueOperation(async (): Promise<void> => {
      await this.putNow(document);
    });
  }

  private async putNow(document: ArticleDocumentCacheRecord): Promise<void> {
    const store = await this.requireStore();
    const textFiles = this.requireTextFiles();
    const previousPath = await this.findJsonPathNow(document.itemId);
    let nextPath: string = '';
    let committed: boolean = false;
    try {
      nextPath = await textFiles.write(document.json);
      const values: relationalStore.ValuesBucket = {
        'item_id': document.itemId,
        // 旧字段保留为空值只为兼容既有 NOT NULL 表结构；文档正文不再进入 RDB。
        'json': '',
        'json_path': nextPath,
        'schema_version': document.schemaVersion,
        'parsed_at': document.parsedAt
      };
      const rowId = await store.insert(
        TABLE_NAME,
        values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
      if (rowId < 0) {
        throw new Error(`写入文档缓存元数据失败：${document.itemId}`);
      }
      committed = true;
      if (previousPath.length > 0 && previousPath !== nextPath) {
        await this.removeFileQuietly(previousPath, 'replaced document');
      }
    } catch (error) {
      if (!committed && nextPath.length > 0) {
        await this.removeFileQuietly(nextPath, 'uncommitted document');
      }
      throw this.documentError('写入', error);
    }
  }

  /** 删除指定文档缓存；用于失效策略扩展时同步清理文件正文。 */
  async remove(itemId: string): Promise<void> {
    await this.enqueueOperation(async (): Promise<void> => {
      const store = await this.requireStore();
      const previousPath = await this.findJsonPathNow(itemId);
      const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
      predicates.equalTo('item_id', itemId);
      try {
        const deleted = await store.delete(predicates);
        if (deleted < 0) {
          throw new Error(`删除文档缓存元数据失败：${itemId}`);
        }
      } catch (error) {
        throw this.documentError('删除', error);
      }
      if (previousPath.length > 0) {
        await this.removeFileQuietly(previousPath, 'removed document');
      }
    });
  }

  private async open(): Promise<void> {
    try {
      const textFiles = new AtomicTextCacheFileStore(
        this.context.cacheDir,
        DOCUMENT_TEXT_CACHE_DIRECTORY
      );
      await textFiles.initialize();
      const store = await relationalStore.getRdbStore(this.context, {
        name: ANOMICON_DATABASE_NAME,
        securityLevel: relationalStore.SecurityLevel.S1,
        encrypt: false
      });
      await store.executeSql(CREATE_DOC_TABLE);
      await this.ensureJsonPathColumn(store);
      this.textFiles = textFiles;
      this.store = store;
    } catch (error) {
      this.initialization = undefined;
      throw this.documentError('初始化', error);
    }
  }

  private async requireStore(): Promise<relationalStore.RdbStore> {
    if (this.initialization !== undefined) {
      await this.initialization;
    }
    if (this.store === undefined) {
      throw new Error('正文文档缓存尚未初始化');
    }
    return this.store;
  }

  private requireTextFiles(): AtomicTextCacheFileStore {
    if (this.textFiles === undefined) {
      throw new Error('文档文本缓存目录尚未初始化');
    }
    return this.textFiles;
  }

  private async ensureJsonPathColumn(store: relationalStore.RdbStore): Promise<void> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    let hasPath: boolean = false;
    try {
      resultSet = await store.querySql(`PRAGMA table_info(${TABLE_NAME})`);
      while (resultSet.goToNextRow()) {
        if (resultSet.getString(resultSet.getColumnIndex('name')) === 'json_path') {
          hasPath = true;
          break;
        }
      }
    } catch (error) {
      throw this.documentError('检查表结构', error);
    } finally {
      this.closeResultSet(resultSet, 'document schema');
    }
    if (!hasPath) {
      try {
        await store.executeSql(ADD_JSON_PATH_COLUMN);
      } catch (error) {
        throw this.documentError('升级表结构', error);
      }
    }
  }

  private async findJsonPathNow(itemId: string): Promise<string> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('item_id', itemId);
    predicates.limitAs(1);
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await store.query(predicates, ['json_path']);
      return resultSet.goToFirstRow() ?
        resultSet.getString(resultSet.getColumnIndex('json_path')) : '';
    } catch (error) {
      throw this.documentError('查询文件路径', error);
    } finally {
      this.closeResultSet(resultSet, 'document path');
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

  private isValidJson(json: string): boolean {
    if (json.trim().length === 0) {
      return false;
    }
    try {
      JSON.parse(json);
      return true;
    } catch (error) {
      return false;
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

  private documentError(operation: string, error: Object): Error {
    const message = error instanceof Error ? error.message : '未知数据库错误';
    return new Error(`正文文档缓存${operation}失败：${message}`);
  }
}
