import { ScpCachedPage, ScpPageCacheService } from './ScpPageCacheService';
import { ScpPageFetchService } from './ScpPageFetchService';
import { ScpCachePolicy } from '../domain/ScpCachePolicy';
import {
  ArticleHtmlRepository,
  ScpHtmlLoadResult,
  ScpHtmlRequestPriority,
  ScpHtmlSource
} from '../domain/ArticleHtmlRepository';
import { ScpWikiUrlPolicy } from './ScpWikiUrlPolicy';
import { ScpRequestScheduler } from './ScpRequestScheduler';

/**
 * 图鉴正文的原始 HTML 读取入口。新鲜度窗口内直接返回缓存；
 * 过期后走条件请求（ETag/Last-Modified），304 只续期；网络失败回退旧缓存。
 * 解析与渲染由上层（ArkWeb 提取 + 文档缓存）负责。
 */
export class CachedArticleRepo implements ArticleHtmlRepository {
  private readonly inflight: Map<string, Promise<ScpHtmlLoadResult>> =
    new Map<string, Promise<ScpHtmlLoadResult>>();
  private readonly inflightPriorities: Map<string, ScpHtmlRequestPriority> =
    new Map<string, ScpHtmlRequestPriority>();
  // A force refresh and a normal refresh use different inflight keys, so keep
  // one monotonic generation per normalized URL for cache-write ordering.
  private nextRequestGeneration: number = 0;
  private readonly requestGenerations: Map<string, number> = new Map<string, number>();
  private readonly fetchService: ScpPageFetchService;
  private readonly cacheService: ScpPageCacheService;
  private readonly scheduler: ScpRequestScheduler;

  constructor(
    fetchService: ScpPageFetchService,
    cacheService: ScpPageCacheService,
    scheduler: ScpRequestScheduler
  ) {
    this.fetchService = fetchService;
    this.cacheService = cacheService;
    this.scheduler = scheduler;
  }

  promote(sourceUrl: string, priority: ScpHtmlRequestPriority): void {
    const normalizedUrl = ScpWikiUrlPolicy.normalizePageUrl(sourceUrl);
    const normalKey = `normal:${normalizedUrl}`;
    const forceKey = `force:${normalizedUrl}`;
    this.promoteRequestKey(normalKey, priority);
    this.promoteRequestKey(forceKey, priority);
    this.scheduler.promote(normalizedUrl, priority);
  }

  async loadHtml(
    sourceUrl: string,
    forceNetwork: boolean = false,
    priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.USER_INITIATED
  ): Promise<ScpHtmlLoadResult> {
    const normalizedUrl = ScpWikiUrlPolicy.normalizePageUrl(sourceUrl);
    const requestKey = `${forceNetwork ? 'force' : 'normal'}:${normalizedUrl}`;
    const existing = this.inflight.get(requestKey);
    if (existing !== undefined) {
      this.promoteRequestKey(requestKey, priority);
      // 同一页面的预取已经排队时，正文或可见卡请求直接晋升其全局网络优先级。
      this.scheduler.promote(normalizedUrl, priority);
      return existing;
    }
    const requestedGeneration = this.registerRequestGeneration(normalizedUrl);
    // The cache service may have advanced a tombstone while a previous
    // discard was in flight.  Use its resolved value so the next request can
    // write again without being mistaken for the invalidated generation.
    const generation = this.cacheService.registerGeneration(normalizedUrl, requestedGeneration);
    this.nextRequestGeneration = Math.max(this.nextRequestGeneration, generation);
    this.requestGenerations.set(normalizedUrl, generation);
    this.inflightPriorities.set(requestKey, priority);
    const task = this.loadHtmlNow(normalizedUrl, forceNetwork, requestKey, generation);
    this.inflight.set(requestKey, task);
    task.then((): void => {
      this.inflight.delete(requestKey);
      this.inflightPriorities.delete(requestKey);
    }).catch((): void => {
      this.inflight.delete(requestKey);
      this.inflightPriorities.delete(requestKey);
    });
    return task;
  }

  private async loadHtmlNow(
    sourceUrl: string,
    forceNetwork: boolean,
    requestKey: string,
    generation: number
  ): Promise<ScpHtmlLoadResult> {
    let cached: ScpCachedPage | undefined = undefined;
    try {
      cached = await this.cacheService.get(sourceUrl);
    } catch (error) {
      console.warn(`Read catalog cache failed: ${error instanceof Error ? error.message : 'unknown error'}`);
    }

    if (!forceNetwork && cached !== undefined && ScpCachePolicy.isFresh(cached.fetchedAt)) {
      return new ScpHtmlLoadResult(cached.html, ScpHtmlSource.FRESH_CACHE, cached.fetchedAt);
    }

    try {
      const priority = this.inflightPriorities.get(requestKey) ??
        ScpHtmlRequestPriority.USER_INITIATED;
      let fetched = await this.fetchService.fetchPage(
        sourceUrl,
        cached?.etag ?? '',
        cached?.lastModified ?? '',
        priority
      );
      let fetchedAt = Date.now();
      if (fetched.notModified && cached !== undefined) {
        // 304 only renews an existing row for the still-current request generation.
        if (await this.cacheService.updateFetchedAt(sourceUrl, fetchedAt, generation)) {
          return new ScpHtmlLoadResult(cached.html, ScpHtmlSource.FRESH_CACHE, fetchedAt);
        }
        // If the body was discarded while the conditional request was in flight,
        // do not publish it as fresh. Re-read a concurrent write or retry unconditionally.
        cached = undefined;
        const current = await this.cacheService.get(sourceUrl);
        if (current !== undefined) {
          const source = ScpCachePolicy.isFresh(current.fetchedAt) ?
            ScpHtmlSource.FRESH_CACHE : ScpHtmlSource.STALE_CACHE;
          return new ScpHtmlLoadResult(current.html, source, current.fetchedAt);
        }
        fetched = await this.fetchService.fetchPage(sourceUrl, '', '', priority);
        fetchedAt = Date.now();
      }
      if (fetched.notModified) {
        throw new Error('服务器返回 304，但本地没有可用正文');
      }
      // Queue persistence before returning so later reads and conditional
      // invalidation still run after this write, without delaying HTML parsing.
      this.cacheService.put(
        new ScpCachedPage(sourceUrl, fetched.html, fetchedAt, fetched.etag, fetched.lastModified),
        generation
      ).catch((error: Error): void => {
        console.warn(`Write catalog cache failed: ${error.message}`);
      });
      return new ScpHtmlLoadResult(fetched.html, ScpHtmlSource.NETWORK, fetchedAt);
    } catch (networkError) {
      if (cached !== undefined) {
        return new ScpHtmlLoadResult(cached.html, ScpHtmlSource.STALE_CACHE, cached.fetchedAt);
      }
      const message = networkError instanceof Error ? networkError.message : '未知网络错误';
      throw new Error(message);
    }
  }

  private registerRequestGeneration(sourceUrl: string): number {
    const previousForUrl = this.requestGenerations.get(sourceUrl) ?? 0;
    const generation = Math.max(this.nextRequestGeneration + 1, previousForUrl + 1);
    this.nextRequestGeneration = generation;
    this.requestGenerations.set(sourceUrl, generation);
    return generation;
  }

  private promoteRequestKey(requestKey: string, priority: ScpHtmlRequestPriority): void {
    const currentPriority = this.inflightPriorities.get(requestKey);
    if (currentPriority !== undefined && priority < currentPriority) {
      this.inflightPriorities.set(requestKey, priority);
    }
  }

  /** 由了解页面语义的上层定向丢弃无效快照。 */
  async discard(sourceUrl: string, rejected?: ScpHtmlLoadResult): Promise<void> {
    try {
      await this.cacheService.remove(ScpWikiUrlPolicy.normalizePageUrl(sourceUrl), rejected?.html);
    } catch (error) {
      console.warn(`Discard invalid page cache failed: ${error instanceof Error ? error.message : 'unknown error'}`);
    }
  }
}
