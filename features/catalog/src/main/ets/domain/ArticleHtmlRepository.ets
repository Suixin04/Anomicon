export enum ScpHtmlSource {
  NETWORK = 'network',
  FRESH_CACHE = 'fresh_cache',
  STALE_CACHE = 'stale_cache'
}

/**
 * 页面请求优先级。数值越小越优先；预取与后台刷新会主动为用户操作保留网络槽。
 */
export enum ScpHtmlRequestPriority {
  USER_INITIATED = 0,
  VISIBLE = 1,
  PREFETCH = 2,
  BACKGROUND = 3
}

export class ScpHtmlLoadResult {
  readonly html: string;
  readonly source: ScpHtmlSource;
  readonly fetchedAt: number;

  constructor(html: string, source: ScpHtmlSource, fetchedAt: number) {
    this.html = html;
    this.source = source;
    this.fetchedAt = fetchedAt;
  }
}

/** 原始文章 HTML 端口；调用方不感知 NetworkKit 与缓存数据库。 */
export interface ArticleHtmlRepository {
  loadHtml(
    sourceUrl: string,
    forceNetwork?: boolean,
    priority?: ScpHtmlRequestPriority
  ): Promise<ScpHtmlLoadResult>;

  /**
   * Drop a source snapshot that failed semantic validation.  This is kept as
   * a port operation (rather than exposing the page-cache adapter) so
   * consumers such as Explore can retry a poisoned HTML response without
   * depending on Catalog's RDB implementation.  A supplied snapshot limits
   * invalidation to the same response body, including after a 304 renewal.
   */
  discard(sourceUrl: string, rejected?: ScpHtmlLoadResult): Promise<void>;
}
