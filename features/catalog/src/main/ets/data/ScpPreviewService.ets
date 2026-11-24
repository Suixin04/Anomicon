import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { ArkTSUtils } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { ANOMICON_DATABASE_NAME } from 'anomiconbasic';
import { articleUrlOf } from '../domain/ScpSeriesItem';
import {
  extractPreviewDescriptionOffThread,
  extractPreviewOffThread
} from './ScpPreviewExtractTask';
import {
  CachedArticleRepo
} from './CachedArticleRepo';
import {
  ScpHtmlLoadResult,
  ScpHtmlRequestPriority,
  ScpHtmlSource
} from '../domain/ArticleHtmlRepository';
import { ScpCachePolicy } from '../domain/ScpCachePolicy';
import { ScpImageCacheService } from './ScpImageCacheService';
import {
  ScpImagePrefetchPriority,
  ScpImagePrefetchService
} from './ScpImagePrefetchService';

// v2 修正了作者头像被误识别为正文首图的历史数据，换表使旧结果立即失效。
const TABLE_NAME: string = 'scp_preview_cache_v2';
const CREATE_PREVIEW_TABLE: string =
  'CREATE TABLE IF NOT EXISTS scp_preview_cache_v2 (' +
  'item_id TEXT PRIMARY KEY, image_url TEXT NOT NULL, local_path TEXT NOT NULL, ' +
  'aspect REAL NOT NULL DEFAULT 0, description TEXT NOT NULL DEFAULT "", ' +
  'updated_at INTEGER NOT NULL)';
const LEGACY_TABLE_NAME: string = 'scp_preview_cache';
const ADD_ASPECT_COLUMN: string =
  'ALTER TABLE scp_preview_cache_v2 ADD COLUMN aspect REAL NOT NULL DEFAULT 0';
const ADD_DESCRIPTION_COLUMN: string =
  'ALTER TABLE scp_preview_cache_v2 ADD COLUMN description TEXT NOT NULL DEFAULT \'\'';
const DELETE_DECORATIVE_PREVIEWS: string =
  `DELETE FROM ${TABLE_NAME} WHERE lower(image_url) LIKE '%component:%' ` +
  `OR lower(image_url) LIKE '%component%3a%' ` +
  `OR lower(image_url) LIKE '%classified-bar%' ` +
  `OR lower(image_url) LIKE '%classified-decoration%' ` +
  `OR lower(image_url) LIKE '%local--files/theme:%' ` +
  `OR lower(image_url) LIKE '%local--files/theme%3a%'`;
const MAX_HTML_CONCURRENCY: number = 4;
const MAX_LOW_PRIORITY_HTML_LOADS: number = 3;
const PREVIEW_CANCELLED_MESSAGE: string = '__anomicon_preview_cancelled__';

class ScpPreviewHtmlWaiter {
  readonly sourceUrl: string;
  priority: ScpHtmlRequestPriority;
  readonly sequence: number;
  readonly resolve: (priority: ScpHtmlRequestPriority) => void;
  readonly reject: (error: Error) => void;

  constructor(
    sourceUrl: string,
    priority: ScpHtmlRequestPriority,
    sequence: number,
    resolve: (priority: ScpHtmlRequestPriority) => void,
    reject: (error: Error) => void
  ) {
    this.sourceUrl = sourceUrl;
    this.priority = priority;
    this.sequence = sequence;
    this.resolve = resolve;
    this.reject = reject;
  }
}

/** 卡片预览结果：本地路径/远程地址、宽高比（width/height）、正文首段描述。 */
export class ScpPreviewInfo {
  readonly path: string;
  readonly aspect: number;
  readonly description: string;
  readonly url: string;
  /** Timestamp of the source HTML/cache row; never the parser completion time. */
  readonly fetchedAt: number;
  readonly stale: boolean;
  /** Non-empty only for a failed HTML/network resolution. Empty image is valid. */
  readonly error: string;
  readonly failed: boolean;

  constructor(
    path: string,
    aspect: number,
    description: string = '',
    url: string = '',
    fetchedAt: number = 0,
    stale: boolean = false,
    error: string = ''
  ) {
    this.path = path;
    this.aspect = aspect;
    this.description = description;
    this.url = url;
    this.fetchedAt = fetchedAt;
    this.stale = stale;
    this.error = error;
    this.failed = error.trim().length > 0;
  }
}

class ScpPreviewRow {
  readonly itemId: string;
  readonly imageUrl: string;
  readonly localPath: string;
  readonly aspect: number;
  readonly description: string;
  readonly updatedAt: number;

  constructor(
    itemId: string,
    imageUrl: string,
    localPath: string,
    aspect: number,
    description: string,
    updatedAt: number
  ) {
    this.itemId = itemId;
    this.imageUrl = imageUrl;
    this.localPath = localPath;
    this.aspect = aspect;
    this.description = description;
    this.updatedAt = updatedAt;
  }
}

/**
 * 图鉴卡片预览图管线（懒加载）：
 * 1. 本地文件已缓存 → 直接返回路径（宽高比未知时现场解码补全）；
 * 2. 已知远程图地址 → 立即交给 ArkUI Image 的原生异步图片管线；
 * 3. 都没有 → 拉取文章页原始 HTML（6h 缓存 + 条件请求），静态提取正文首图，
 *    缓存图地址与描述；无图返回空结果，图片缓存失败则保留远程地址让 Image 兜底。
 * 探索页的固定尺寸推荐图另行使用 ScpImageCacheService 落盘。
 */
export class ScpPreviewService {
  private store: relationalStore.RdbStore | undefined = undefined;
  private initialization: Promise<void> | undefined = undefined;
  private context: common.UIAbilityContext | undefined = undefined;
  private readonly repository: CachedArticleRepo;
  private readonly imageCache: ScpImageCacheService;
  private readonly imagePrefetch: ScpImagePrefetchService | undefined;
  private readonly inflight: Map<string, Promise<ScpPreviewInfo>> = new Map();
  private readonly inflightPriorities: Map<string, ScpHtmlRequestPriority> = new Map();
  /** Explicit card retries own a separate request even when a stale refresh is running. */
  private readonly forcedInflight: Set<string> = new Set<string>();
  private readonly refreshing: Map<string, Promise<ScpPreviewInfo | undefined>> = new Map();
  private readonly refreshListeners: Map<string, Array<(info: ScpPreviewInfo) => void>> = new Map();
  /**
   * Durable preview rows are shared by normal loads, background revalidation,
   * and explicit retries.  Keep a monotonic owner per item so a late old task
   * cannot replace a newer result after its Promise identity has gone stale.
   */
  private readonly previewWriteGenerations: Map<string, number> = new Map();
  private readonly previewWriteLock: ArkTSUtils.locks.AsyncLock =
    new ArkTSUtils.locks.AsyncLock();
  private activeHtmlLoads: number = 0;
  private activeLowPriorityHtmlLoads: number = 0;
  private nextHtmlSequence: number = 0;
  private readonly htmlWaiters: ScpPreviewHtmlWaiter[] = [];

  constructor(
    repository: CachedArticleRepo,
    imageCache: ScpImageCacheService,
    imagePrefetch?: ScpImagePrefetchService
  ) {
    this.repository = repository;
    this.imageCache = imageCache;
    this.imagePrefetch = imagePrefetch;
  }

  initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.store !== undefined) {
      return Promise.resolve();
    }
    if (this.initialization !== undefined) {
      return this.initialization;
    }
    this.initialization = this.open(context);
    return this.initialization;
  }

  /** 返回本地/远程图片信息；同一条目的低优先级任务可在进入视口时原地晋升。 */
  getPreview(
    itemId: string,
    onRefreshed?: (info: ScpPreviewInfo) => void,
    priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.VISIBLE,
    forceRefresh: boolean = false
  ): Promise<ScpPreviewInfo> {
    if (onRefreshed !== undefined) {
      const listeners = this.refreshListeners.get(itemId) ?? [];
      // A card can issue the same request more than once while a stale row is
      // revalidating.  Keep one callback per identity so one refresh does not
      // notify the same view repeatedly.
      if (listeners.indexOf(onRefreshed) < 0) {
        listeners.push(onRefreshed);
      }
      this.refreshListeners.set(itemId, listeners);
    }
    const existing = this.inflight.get(itemId);
    if (existing !== undefined && (!forceRefresh || this.forcedInflight.has(itemId))) {
      this.promotePreview(itemId, priority);
      return existing;
    }
    const writeGeneration = this.beginPreviewWrite(itemId);
    this.inflightPriorities.set(itemId, priority);
    const task = forceRefresh ?
      this.resolveForced(itemId, priority, writeGeneration) :
      this.resolve(itemId, writeGeneration);
    if (forceRefresh) {
      this.forcedInflight.add(itemId);
    }
    this.inflight.set(itemId, task);
    task.then(() => {
      this.finishInflight(itemId, task);
    }).catch(() => {
      this.finishInflight(itemId, task);
    });
    return task;
  }

  private finishInflight(itemId: string, task: Promise<ScpPreviewInfo>): void {
    if (this.inflight.get(itemId) !== task) {
      return;
    }
    this.inflight.delete(itemId);
    this.inflightPriorities.delete(itemId);
    this.forcedInflight.delete(itemId);
    if (!this.refreshing.has(itemId)) {
      this.refreshListeners.delete(itemId);
    }
  }

  /** 预取一批条目的预览（瀑布流可见窗口外的预加载）；失败静默，命中缓存零成本。 */
  prefetch(itemIds: string[]): void {
    for (let index: number = 0; index < itemIds.length; index++) {
      this.getPreview(itemIds[index], undefined, ScpHtmlRequestPriority.PREFETCH).catch(() => {
        // 预取失败忽略：卡片进入视口时会按需重试。
      });
    }
  }

  /** 移除尚未开始且仍是低优先级的预取；可见任务和活动网络请求不受影响。 */
  cancelQueuedPrefetch(itemIds: string[]): void {
    const itemByUrl: Map<string, string> = new Map<string, string>();
    for (let index: number = 0; index < itemIds.length; index++) {
      const itemId = itemIds[index];
      itemByUrl.set(articleUrlOf(itemId), itemId);
      const priority = this.inflightPriorities.get(itemId);
      if (priority === undefined || priority >= ScpHtmlRequestPriority.PREFETCH) {
        this.imagePrefetch?.cancelOwner(`catalog:${itemId}`);
      }
    }
    for (let index: number = this.htmlWaiters.length - 1; index >= 0; index--) {
      const waiter = this.htmlWaiters[index];
      const itemId = itemByUrl.get(waiter.sourceUrl);
      if (itemId !== undefined && waiter.priority >= ScpHtmlRequestPriority.PREFETCH) {
        this.htmlWaiters.splice(index, 1);
        if ((this.inflightPriorities.get(itemId) ?? ScpHtmlRequestPriority.VISIBLE) >=
          ScpHtmlRequestPriority.PREFETCH) {
          this.inflight.delete(itemId);
          this.inflightPriorities.delete(itemId);
          this.refreshListeners.delete(itemId);
        }
        waiter.reject(new Error(PREVIEW_CANCELLED_MESSAGE));
      }
    }
  }

  private promotePreview(itemId: string, priority: ScpHtmlRequestPriority): void {
    const current = this.inflightPriorities.get(itemId);
    if (current !== undefined && priority < current) {
      this.inflightPriorities.set(itemId, priority);
    }
    const sourceUrl = articleUrlOf(itemId);
    for (let index: number = 0; index < this.htmlWaiters.length; index++) {
      const waiter = this.htmlWaiters[index];
      if (waiter.sourceUrl === sourceUrl && priority < waiter.priority) {
        waiter.priority = priority;
      }
    }
    this.repository.promote(sourceUrl, priority);
    this.drainHtmlWaiters();
  }

  private previewPriority(itemId: string): ScpHtmlRequestPriority {
    return this.inflightPriorities.get(itemId) ?? ScpHtmlRequestPriority.VISIBLE;
  }

  private async resolve(itemId: string, writeGeneration: number): Promise<ScpPreviewInfo> {
    let row: ScpPreviewRow | undefined = undefined;
    try {
      row = await this.readRow(itemId);
    } catch (error) {
      // 预览数据库只是派生缓存；不可用时继续走原始文章与图片管线。
      console.warn(`Read preview cache failed: ${error instanceof Error ? error.message : 'unknown error'}`);
    }
    if (row !== undefined) {
      if (!ScpCachePolicy.isFresh(row.updatedAt)) {
        // stale-while-revalidate：只读本地结果立即返回，来源更新在后台完成。
        const cached = await this.resolveCachedRow(row);
        // A force retry may have superseded this stale read while the local
        // file was being checked.  Do not start a third background task that
        // could otherwise become the newest durable-write owner.
        if (this.isCurrentPreviewWrite(itemId, writeGeneration)) {
          this.startRevalidation(itemId, row);
        }
        return cached;
      }
      return this.resolveFromRow(itemId, row, writeGeneration);
    }
    return this.resolveCatalogFromSource(itemId, writeGeneration);
  }

  /** Explicit card retry: bypass both the derived row and any stale refresh. */
  private async resolveForced(
    itemId: string,
    priority: ScpHtmlRequestPriority,
    writeGeneration: number
  ): Promise<ScpPreviewInfo> {
    let row: ScpPreviewRow | undefined = undefined;
    try {
      row = await this.readRow(itemId);
    } catch (error) {
      // The preview row is optional; a forced retry can still rebuild it from
      // the source page when the derived database is unavailable.
      console.warn(`Read preview row for retry failed: ${error instanceof Error ? error.message : 'unknown error'}`);
    }
    const result = await this.startRevalidation(
      itemId, row, true, priority, writeGeneration);
    return result ?? this.failedPreview(
      '预览更新失败，请稍后重试', row?.updatedAt ?? 0, row !== undefined);
  }

  /** 过期行的立即结果：不等待网络，也不使用旧远程地址重新下载。 */
  private async resolveCachedRow(row: ScpPreviewRow): Promise<ScpPreviewInfo> {
    const description = this.validDescription(row.description) ? row.description : '';
    if (await this.isReusableLocalPath(row.localPath)) {
      const aspect = row.aspect > 0.05 ?
        row.aspect : await ScpPreviewService.readAspect(row.localPath);
      return new ScpPreviewInfo(row.localPath, aspect, description, '', row.updatedAt, true);
    }
    return new ScpPreviewInfo('', row.aspect, description, row.imageUrl, row.updatedAt, true);
  }

  private startRevalidation(
    itemId: string,
    row: ScpPreviewRow | undefined,
    forceNetwork: boolean = false,
    priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.BACKGROUND,
    writeGeneration?: number
  ): Promise<ScpPreviewInfo | undefined> {
    const existing = this.refreshing.get(itemId);
    if (existing !== undefined && !forceNetwork) {
      return existing;
    }
    const generation = writeGeneration ?? this.beginPreviewWrite(itemId);
    const task: Promise<ScpPreviewInfo | undefined> = forceNetwork ?
      this.revalidateForced(itemId, row, priority, generation) :
      (row === undefined ? Promise.resolve(undefined) : this.revalidate(itemId, row, generation));
    this.refreshing.set(itemId, task);
    task.then((info: ScpPreviewInfo | undefined) => {
      // A forced retry can supersede an older stale-while-revalidate task.
      // An obsolete task may still finish and write its own cache row, but it
      // must never clear or notify the newer task's listeners.
      if (this.refreshing.get(itemId) !== task) {
        return;
      }
      this.refreshing.delete(itemId);
      if (info !== undefined) {
        const listeners = this.refreshListeners.get(itemId) ?? [];
        for (let index: number = 0; index < listeners.length; index++) {
          try {
            listeners[index](info);
          } catch (error) {
            console.warn(`Notify preview refresh failed: ${error instanceof Error ? error.message : 'unknown error'}`);
          }
        }
      }
      this.refreshListeners.delete(itemId);
    }).catch((error: Error) => {
      if (this.refreshing.get(itemId) !== task) {
        return;
      }
      this.refreshing.delete(itemId);
      this.refreshListeners.delete(itemId);
      console.warn(`Refresh preview failed: ${error.message}`);
    });
    return task;
  }

  private async revalidate(
    itemId: string,
    row: ScpPreviewRow,
    writeGeneration: number
  ): Promise<ScpPreviewInfo | undefined> {
    try {
      const result = await this.loadHtmlLimited(
        articleUrlOf(itemId), ScpHtmlRequestPriority.BACKGROUND);
      if (result.source === ScpHtmlSource.STALE_CACHE) {
        return undefined;
      }
      return await this.resolveCatalogHtml(itemId, result, row, writeGeneration);
    } catch (error) {
      // 保留过期行；下一次进入视口继续重验。
      return undefined;
    }
  }

  private async revalidateForced(
    itemId: string,
    row: ScpPreviewRow | undefined,
    priority: ScpHtmlRequestPriority,
    writeGeneration: number
  ): Promise<ScpPreviewInfo> {
    try {
      const result = await this.loadHtmlLimited(
        articleUrlOf(itemId), priority, true);
      if (result.source === ScpHtmlSource.STALE_CACHE) {
        // Cached HTML is not a successful explicit retry.  Keep the result
        // visibly retryable instead of parsing old content as a fresh image.
        return this.failedPreview(
          '预览更新失败，正在显示缓存内容', row?.updatedAt ?? 0, row !== undefined);
      }
      return await this.resolveCatalogHtml(itemId, result, row, writeGeneration);
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知网络错误';
      return this.failedPreview(
        `预览加载失败：${message}`, row?.updatedAt ?? 0, row !== undefined);
    }
  }

  private async resolveCatalogFromSource(
    itemId: string,
    writeGeneration: number
  ): Promise<ScpPreviewInfo> {
    try {
      const result = await this.loadHtmlLimited(articleUrlOf(itemId), this.previewPriority(itemId));
      return this.resolveCatalogHtml(itemId, result, undefined, writeGeneration);
    } catch (error) {
      if (error instanceof Error && error.message === PREVIEW_CANCELLED_MESSAGE) {
        throw error;
      }
      // 网络失败不落库，下次进入视口自动重试。
      const message = error instanceof Error ? error.message : '无法加载文章页面';
      return this.failedPreview(`预览加载失败：${message}`);
    }
  }

  /**
   * 目录卡片优先返回远程图源：ArkUI Image 可立即进入原生网络图片管线，
   * 不串行等待“完整下载 → 校验解码 → 原子落盘 → 再解码渲染”。
   */
  private async resolveCatalogHtml(
    itemId: string,
    result: ScpHtmlLoadResult,
    previous: ScpPreviewRow | undefined,
    writeGeneration: number,
    warmImage: boolean = true
  ): Promise<ScpPreviewInfo> {
    const highPriority = this.previewPriority(itemId) < ScpHtmlRequestPriority.PREFETCH;
    const extracted = await extractPreviewOffThread(result.html, highPriority);
    if (extracted.error.length > 0) {
      return this.failedPreview(
        extracted.error,
        result.fetchedAt,
        result.source === ScpHtmlSource.STALE_CACHE
      );
    }
    const imageUrl = extracted.imageUrl;
    const description = extracted.description;
    if (imageUrl.length === 0) {
      await this.safePutRow(itemId, '', '', 0, description, result.fetchedAt, writeGeneration);
      return new ScpPreviewInfo('', 0, description, '', result.fetchedAt,
        result.source === ScpHtmlSource.STALE_CACHE);
    }
    if (previous !== undefined && previous.imageUrl === imageUrl &&
      await this.isReusableLocalPath(previous.localPath)) {
      const aspect = previous.aspect > 0.05 ?
        previous.aspect : await ScpPreviewService.readAspect(previous.localPath);
      await this.safePutRow(
        itemId, imageUrl, previous.localPath, aspect, description,
        result.fetchedAt, writeGeneration
      );
      return new ScpPreviewInfo(previous.localPath, aspect, description, '', result.fetchedAt,
        result.source === ScpHtmlSource.STALE_CACHE);
    }
    const aspect = extracted.aspect > 0.05 ? extracted.aspect :
      (previous !== undefined && previous.imageUrl === imageUrl ? previous.aspect : 0);
    await this.safePutRow(itemId, imageUrl, '', aspect, description,
      result.fetchedAt, writeGeneration);
    if (warmImage) {
      this.warmCatalogImageIfCurrent(itemId, imageUrl, writeGeneration);
    }
    return new ScpPreviewInfo('', aspect, description, imageUrl, result.fetchedAt,
      result.source === ScpHtmlSource.STALE_CACHE);
  }

  /**
   * 复用调用方已经取得的官网 HTML 构建预览，避免为了首图再次请求同一文章。
   * 每日推荐的随机编号校验与预览提取因此共享同一份服务器响应。
   */
  async resolveFetchedHtml(
    itemId: string,
    html: string,
    fetchedAt: number = Date.now()
  ): Promise<ScpPreviewInfo> {
    const writeGeneration = this.beginPreviewWrite(itemId);
    // 和目录一样优先复用本地图；否则交给原生 Image 加载，不卡住推荐卡出牌。
    const previous = await this.readRowNow(itemId).catch((): ScpPreviewRow | undefined => undefined);
    return this.resolveCatalogHtml(
      itemId,
      new ScpHtmlLoadResult(html, ScpHtmlSource.NETWORK, fetchedAt),
      previous,
      writeGeneration,
      false // The rendered deck window loads its own images; do not download off-window cards.
    );
  }

  /** 已有缓存行：本地文件直接返回；缺宽高比/描述时用（6h 缓存的）文章 HTML 补全。 */
  private async resolveFromRow(
    itemId: string,
    row: ScpPreviewRow,
    writeGeneration: number
  ): Promise<ScpPreviewInfo> {
    if (await this.isReusableLocalPath(row.localPath)) {
      const aspect = row.aspect > 0.05 ?
        row.aspect : await ScpPreviewService.readAspect(row.localPath);
      let description = row.description;
      if (!this.validDescription(description) && row.imageUrl.length > 0) {
        description = await this.loadDescription(itemId);
        await this.safePutRow(
          itemId, row.imageUrl, row.localPath, aspect, description,
          row.updatedAt, writeGeneration
        );
      }
      return new ScpPreviewInfo(row.localPath, aspect, description, '', row.updatedAt, false);
    }
    if (row.imageUrl.length > 0) {
      let description = row.description;
      if (!this.validDescription(description)) {
        description = await this.loadDescription(itemId);
        await this.safePutRow(
          itemId, row.imageUrl, '', row.aspect, description,
          row.updatedAt, writeGeneration
        );
      }
      this.warmCatalogImageIfCurrent(itemId, row.imageUrl, writeGeneration);
      return new ScpPreviewInfo('', row.aspect, description, row.imageUrl, row.updatedAt, false);
    }
    // 已确认无图
    if (this.validDescription(row.description)) {
      return new ScpPreviewInfo('', 1, row.description, '', row.updatedAt, false);
    }
    const description = await this.loadDescription(itemId);
    if (description.length > 0) {
      await this.safePutRow(itemId, '', '', 0, description, row.updatedAt, writeGeneration);
    }
    return new ScpPreviewInfo('', 1, description, '', row.updatedAt, false);
  }

  /** 旧版本提取的描述可能带 "id=" 前缀等垃圾，视为无效。 */
  private validDescription(description: string): boolean {
    return description.length > 0 && !description.startsWith('id=');
  }

  private warmCatalogImage(itemId: string, imageUrl: string): void {
    if (this.imagePrefetch === undefined || imageUrl.length === 0) {
      return;
    }
    const warmPriority = this.previewPriority(itemId) >= ScpHtmlRequestPriority.PREFETCH ?
      ScpImagePrefetchPriority.NEAR_VIEWPORT : ScpImagePrefetchPriority.VISIBLE;
    // Warming is only an optimization.  Never hold up the preview result on
    // cache-download capability, queueing, or network latency.
    this.imagePrefetch.warm(
      imageUrl, warmPriority, `catalog:${itemId}`
    ).catch((): void => {
      // 失败时仍把远程 URL 交给组件自身的 Image 管线兜底。
    });
  }

  private warmCatalogImageIfCurrent(
    itemId: string,
    imageUrl: string,
    writeGeneration: number
  ): void {
    if (writeGeneration === 0 || this.isCurrentPreviewWrite(itemId, writeGeneration)) {
      this.warmCatalogImage(itemId, imageUrl);
    }
  }

  /** 从文章页提取首段描述；HTML 有 6h 缓存，成本极低。 */
  private async loadDescription(itemId: string): Promise<string> {
    try {
      const priority = this.previewPriority(itemId);
      const result = await this.loadHtmlLimited(articleUrlOf(itemId), priority);
      return await extractPreviewDescriptionOffThread(
        result.html,
        priority < ScpHtmlRequestPriority.PREFETCH
      );
    } catch (error) {
      return '';
    }
  }

  private failedPreview(
    message: string,
    fetchedAt: number = 0,
    stale: boolean = false
  ): ScpPreviewInfo {
    const normalized = message.trim().length > 0 ? message : '预览解析失败';
    return new ScpPreviewInfo('', 1, '', '', fetchedAt, stale, normalized);
  }

  /**
   * 预览 HTML 的优先级闸门。缓存读取/字符串提取最多四份并行，低优先级最多三份，
   * 始终为刚进入视口的卡片保留一个处理槽。
   */
  private async loadHtmlLimited(
    sourceUrl: string,
    priority: ScpHtmlRequestPriority,
    forceNetwork: boolean = false
  ): Promise<ScpHtmlLoadResult> {
    const grantedPriority = await this.acquireHtmlSlot(sourceUrl, priority);
    try {
      return await this.repository.loadHtml(sourceUrl, forceNetwork, grantedPriority);
    } finally {
      this.releaseHtmlSlot(grantedPriority);
    }
  }

  private acquireHtmlSlot(
    sourceUrl: string,
    priority: ScpHtmlRequestPriority
  ): Promise<ScpHtmlRequestPriority> {
    if (this.canStartHtml(priority) && this.htmlWaiters.length === 0) {
      this.markHtmlStarted(priority);
      return Promise.resolve(priority);
    }
    return new Promise<ScpHtmlRequestPriority>(
      (
        resolve: (grantedPriority: ScpHtmlRequestPriority) => void,
        reject: (error: Error) => void
      ): void => {
        this.htmlWaiters.push(new ScpPreviewHtmlWaiter(
          sourceUrl, priority, this.nextHtmlSequence++, resolve, reject));
        this.drainHtmlWaiters();
      }
    );
  }

  private releaseHtmlSlot(priority: ScpHtmlRequestPriority): void {
    this.activeHtmlLoads = Math.max(0, this.activeHtmlLoads - 1);
    if (this.isLowHtmlPriority(priority)) {
      this.activeLowPriorityHtmlLoads = Math.max(0, this.activeLowPriorityHtmlLoads - 1);
    }
    this.drainHtmlWaiters();
  }

  private drainHtmlWaiters(): void {
    while (this.activeHtmlLoads < MAX_HTML_CONCURRENCY) {
      const index = this.nextHtmlWaiterIndex();
      if (index < 0) {
        return;
      }
      const waiter = this.htmlWaiters.splice(index, 1)[0];
      this.markHtmlStarted(waiter.priority);
      waiter.resolve(waiter.priority);
    }
  }

  private nextHtmlWaiterIndex(): number {
    let selected: number = -1;
    for (let index: number = 0; index < this.htmlWaiters.length; index++) {
      const candidate = this.htmlWaiters[index];
      if (!this.canStartHtml(candidate.priority)) {
        continue;
      }
      if (selected < 0 || candidate.priority < this.htmlWaiters[selected].priority ||
        (candidate.priority === this.htmlWaiters[selected].priority &&
          candidate.sequence < this.htmlWaiters[selected].sequence)) {
        selected = index;
      }
    }
    return selected;
  }

  private canStartHtml(priority: ScpHtmlRequestPriority): boolean {
    if (this.activeHtmlLoads >= MAX_HTML_CONCURRENCY) {
      return false;
    }
    return !this.isLowHtmlPriority(priority) ||
      this.activeLowPriorityHtmlLoads < MAX_LOW_PRIORITY_HTML_LOADS;
  }

  private markHtmlStarted(priority: ScpHtmlRequestPriority): void {
    this.activeHtmlLoads++;
    if (this.isLowHtmlPriority(priority)) {
      this.activeLowPriorityHtmlLoads++;
    }
  }

  private isLowHtmlPriority(priority: ScpHtmlRequestPriority): boolean {
    return priority >= ScpHtmlRequestPriority.PREFETCH;
  }

  /** 本地文件解码宽高比（width/height），失败返回 1（正方形兜底）。 */
  private static async readAspect(path: string): Promise<number> {
    let source: image.ImageSource | undefined = undefined;
    try {
      source = image.createImageSource(path);
      const info = await source.getImageInfo();
      if (info.size.width > 0 && info.size.height > 0) {
        return info.size.width / info.size.height;
      }
    } catch (error) {
      console.warn(`Read image aspect failed: ${error instanceof Error ? error.message : 'unknown error'}`);
    } finally {
      if (source !== undefined) {
        try {
          await source.release();
        } catch (error) {
          console.warn(`Release image source failed: ${error instanceof Error ? error.message : 'unknown error'}`);
        }
      }
    }
    return 1;
  }

  /** DB 中的历史路径只有归属正确且经 ImageKit 实际解码校验后才允许展示。 */
  private isReusableLocalPath(path: string): Promise<boolean> {
    return this.imageCache.isReusableManagedCachePath(path);
  }

  private beginPreviewWrite(itemId: string): number {
    const nextGeneration = (this.previewWriteGenerations.get(itemId) ?? 0) + 1;
    this.previewWriteGenerations.set(itemId, nextGeneration);
    return nextGeneration;
  }

  private isCurrentPreviewWrite(itemId: string, writeGeneration: number): boolean {
    return writeGeneration <= 0 ||
      this.previewWriteGenerations.get(itemId) === writeGeneration;
  }

  private async readRow(itemId: string): Promise<ScpPreviewRow | undefined> {
    let row: ScpPreviewRow | undefined = undefined;
    await this.enqueuePreviewWrite(async (): Promise<void> => {
      row = await this.readRowNow(itemId);
    });
    return row;
  }

  private async readRowNow(itemId: string): Promise<ScpPreviewRow | undefined> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('item_id', itemId);
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await store.query(
        predicates, ['item_id', 'image_url', 'local_path', 'aspect', 'description', 'updated_at']);
      if (!resultSet.goToFirstRow()) {
        return undefined;
      }
      return new ScpPreviewRow(
        resultSet.getString(resultSet.getColumnIndex('item_id')),
        resultSet.getString(resultSet.getColumnIndex('image_url')),
        resultSet.getString(resultSet.getColumnIndex('local_path')),
        resultSet.getDouble(resultSet.getColumnIndex('aspect')),
        resultSet.getString(resultSet.getColumnIndex('description')),
        resultSet.getLong(resultSet.getColumnIndex('updated_at'))
      );
    } catch (error) {
      console.warn(`Read preview row failed: ${error instanceof Error ? error.message : 'unknown error'}`);
      return undefined;
    } finally {
      try {
        resultSet?.close();
      } catch (error) {
        console.warn(`Close preview result set failed: ${error instanceof Error ? error.message : 'unknown error'}`);
      }
    }
  }

  private async putRow(
    itemId: string,
    imageUrl: string,
    localPath: string,
    aspect: number,
    description: string,
    updatedAt: number = Date.now(),
    writeGeneration: number = 0
  ): Promise<boolean> {
    let accepted: boolean = false;
    try {
      await this.enqueuePreviewWrite(async (): Promise<void> => {
        if (!this.isCurrentPreviewWrite(itemId, writeGeneration)) {
          return;
        }
        const previous = await this.readRowNow(itemId);
        // fetchedAt is the source snapshot timestamp.  This second guard also
        // protects rows restored after process restart, where the in-memory
        // request generation is no longer available.
        if (previous !== undefined && previous.updatedAt > updatedAt) {
          return;
        }
        // A newer request may have started while the previous row was read.
        if (!this.isCurrentPreviewWrite(itemId, writeGeneration)) {
          return;
        }
        const store = await this.requireStore();
        const values: relationalStore.ValuesBucket = {
          'item_id': itemId,
          'image_url': imageUrl,
          'local_path': localPath,
          'aspect': aspect,
          'description': description,
          'updated_at': updatedAt
        };
        const rowId = await store.insert(
          TABLE_NAME,
          values,
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
        );
        if (rowId < 0) {
          throw new Error(`预览缓存写入返回无效行号：${itemId}`);
        }
        accepted = true;
      });
    } catch (error) {
      console.warn(`Write preview row failed: ${error instanceof Error ? error.message : 'unknown error'}`);
    }
    return accepted;
  }

  private async safePutRow(
    itemId: string,
    imageUrl: string,
    localPath: string,
    aspect: number,
    description: string,
    updatedAt: number,
    writeGeneration: number = 0
  ): Promise<boolean> {
    try {
      return await this.putRow(
        itemId, imageUrl, localPath, aspect, description, updatedAt, writeGeneration
      );
    } catch (error) {
      console.warn(`Preview cache unavailable: ${error instanceof Error ? error.message : 'unknown error'}`);
      return false;
    }
  }

  /** 清空全部派生预览缓存行，保留系列目录等独立表。 */
  async clearAll(): Promise<void> {
    await this.enqueuePreviewWrite(async (): Promise<void> => {
      const activeKeys = Array.from(this.previewWriteGenerations.keys());
      for (let index = 0; index < activeKeys.length; index++) {
        this.beginPreviewWrite(activeKeys[index]);
      }
      const store = await this.requireStore();
      const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
      const deleted = await store.delete(predicates);
      if (deleted < 0) {
        throw new Error('清空预览缓存失败');
      }
    });
  }

  private enqueuePreviewWrite(operation: () => Promise<void>): Promise<void> {
    try {
      return this.previewWriteLock.lockAsync<void>(
        operation,
        ArkTSUtils.locks.AsyncLockMode.EXCLUSIVE
      );
    } catch (error) {
      return Promise.reject(error);
    }
  }

  private async open(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await relationalStore.getRdbStore(context, {
        name: ANOMICON_DATABASE_NAME,
        securityLevel: relationalStore.SecurityLevel.S1,
        encrypt: false
      });
      await store.executeSql(CREATE_PREVIEW_TABLE);
      await this.ensurePreviewColumns(store);
      // 清除已知主题装饰图的历史派生行，使覆盖升级立即采用收紧后的首图规则。
      await store.executeSql(DELETE_DECORATIVE_PREVIEWS);
      // v1 的首图提取语义会把作者头像当正文图；它是可重建派生缓存，安全失效。
      await store.executeSql(`DROP TABLE IF EXISTS ${LEGACY_TABLE_NAME}`);
      this.store = store;
    } catch (error) {
      this.initialization = undefined;
      const message = error instanceof Error ? error.message : '未知数据库错误';
      throw new Error(`预览缓存初始化失败：${message}`);
    }
  }

  private async ensurePreviewColumns(store: relationalStore.RdbStore): Promise<void> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    let hasAspect: boolean = false;
    let hasDescription: boolean = false;
    try {
      resultSet = await store.querySql(`PRAGMA table_info(${TABLE_NAME})`);
      while (resultSet.goToNextRow()) {
        const name = resultSet.getString(resultSet.getColumnIndex('name'));
        if (name === 'aspect') {
          hasAspect = true;
        } else if (name === 'description') {
          hasDescription = true;
        }
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知数据库错误';
      throw new Error(`检查预览缓存表结构失败：${message}`);
    } finally {
      try {
        resultSet?.close();
      } catch (error) {
        console.warn(`Close preview schema result failed: ${error instanceof Error ? error.message : 'unknown error'}`);
      }
    }
    try {
      if (!hasAspect) {
        await store.executeSql(ADD_ASPECT_COLUMN);
      }
      if (!hasDescription) {
        await store.executeSql(ADD_DESCRIPTION_COLUMN);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知数据库错误';
      throw new Error(`升级预览缓存表结构失败：${message}`);
    }
  }

  private async requireStore(): Promise<relationalStore.RdbStore> {
    if (this.initialization !== undefined) {
      await this.initialization;
    }
    if (this.store === undefined && this.context !== undefined) {
      // Preview rows are derived data; retry a transient RDB open failure when
      // the next card asks for a preview.
      await this.initialize(this.context);
    }
    if (this.store === undefined) {
      throw new Error('预览缓存尚未初始化');
    }
    return this.store;
  }
}
