import {
  ExploreLoadedPayload,
  ExplorePayload,
  ExplorePreview,
  ExploreRecommendation,
  ExploreSource,
  ExploreStoredSnapshot
} from './ExploreContracts';

/**
 * HTML source classification owned by Explore's data boundary.
 *
 * The feature deliberately does not expose Catalog's cache/result classes in
 * its public API.  A product can adapt any HTML gateway (the catalog graph is
 * the default one) to this small serializable contract.
 */
export enum ExploreHtmlSource {
  NETWORK = 'network',
  FRESH_CACHE = 'fresh_cache',
  STALE_CACHE = 'stale_cache'
}

export class ExploreHtmlLoadResult {
  readonly html: string;
  readonly source: ExploreHtmlSource;
  readonly fetchedAt: number;

  constructor(html: string, source: ExploreHtmlSource, fetchedAt: number) {
    this.html = html;
    this.source = source;
    this.fetchedAt = fetchedAt;
  }
}

/** Raw HTML gateway used by Explore list and recommendation adapters. */
export interface ExploreHtmlRepository {
  loadHtml(sourceUrl: string, forceNetwork?: boolean): Promise<ExploreHtmlLoadResult>;
  /** Invalidate a semantically invalid cached page before retrying the source. */
  discard(sourceUrl: string): Promise<void>;
}

/** Network/page seam for random recommendations; no RCP object crosses it. */
export class ExploreFetchedPage {
  readonly html: string;
  readonly fetchedAt: number;

  constructor(html: string, fetchedAt: number) {
    this.html = html;
    this.fetchedAt = fetchedAt;
  }
}

export interface ExploreRecommendationPageGateway {
  fetchPage(sourceUrl: string): Promise<ExploreFetchedPage>;
}

/** Resolve a human-readable title when a recommendation page only exposes its
 * page slug (the common case for SCP pages). */
export type ExploreTitleResolver = (itemId: string) => Promise<string>;

/** 探索索引端口；具体 RDB/RCP/HTML 实现只能位于 data。 */
export interface ExploreListRepository {
  read(source: ExploreSource): Promise<ExploreStoredSnapshot | undefined>;
  isFresh(snapshot: ExploreStoredSnapshot, now?: number): boolean;
  load(source: ExploreSource, forceNetwork?: boolean): Promise<ExploreLoadedPayload>;
  put(source: ExploreSource, payload: ExplorePayload, fetchedAt?: number): Promise<void>;
}

/** 推荐候选端口；dayKey 作为测试和未来离线实现的显式输入。 */
export interface RecommendationRepository {
  loadDaily(batchIndex: number, dayKey?: string): Promise<ExploreRecommendation[]>;
}

/** 卡片预览端口；不向上层暴露图片缓存或 ArkUI 类型。 */
export interface PreviewRepository {
  getPreview(itemId: string): Promise<ExplorePreview>;
  resolveFetchedHtml(itemId: string, html: string, fetchedAt?: number): Promise<ExplorePreview>;
}
