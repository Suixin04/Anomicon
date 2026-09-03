import { LibraryContentRef } from 'library';
import { ScpArticleDocument } from './ScpDocument';

/** Source semantics of the raw HTML supplied by a product adapter. */
export enum ArticleHtmlSource {
  NETWORK = 'network',
  FRESH_CACHE = 'fresh_cache',
  STALE_CACHE = 'stale_cache'
}

/** Serializable HTML receipt; Catalog cache types never cross this port. */
export class ArticleHtmlSnapshot {
  readonly html: string;
  readonly source: ArticleHtmlSource;
  readonly fetchedAt: number;

  constructor(html: string, source: ArticleHtmlSource, fetchedAt: number) {
    this.html = html;
    this.source = source;
    this.fetchedAt = fetchedAt;
  }
}

/**
 * Article-side raw HTML port.  A product may adapt Catalog's shared fetch
 * pipeline, but Article never imports Catalog's model or repository types.
 */
export interface ArticleHtmlPort {
  load(sourceUrl: string, forceNetwork?: boolean): Promise<ArticleHtmlSnapshot>;
}

/** Source semantics are kept explicit so parsing time cannot fake freshness. */
export enum ArticleContentSource {
  DOCUMENT_CACHE = 'document_cache',
  FRESH_HTML_CACHE = 'fresh_html_cache',
  NETWORK = 'network',
  STALE_HTML_CACHE = 'stale_html_cache'
}

/** HTML handed to the compatibility extractor only when native parsing declines it. */
export class PendingExtraction {
  readonly requestId: number;
  readonly contentKey: string;
  readonly itemId: string;
  readonly sourceUrl: string;
  readonly html: string;
  readonly fetchedAt: number;
  readonly stale: boolean;

  constructor(
    requestId: number,
    contentKey: string,
    itemId: string,
    sourceUrl: string,
    html: string,
    fetchedAt: number,
    stale: boolean = false
  ) {
    this.requestId = requestId;
    this.contentKey = contentKey;
    this.itemId = itemId;
    this.sourceUrl = sourceUrl;
    this.html = html;
    this.fetchedAt = fetchedAt;
    this.stale = stale;
  }
}

/** UI hand-off for ArkWeb extraction; the WebView instance never crosses it. */
export interface ArticleExtractionRequest {
  readonly requestId: number;
  readonly html: string;
  readonly sourceUrl: string;
  readonly stale: boolean;
}

export class ArticleLoadResult {
  readonly document: ScpArticleDocument | undefined;
  readonly pendingExtraction: PendingExtraction | undefined;
  readonly source: ArticleContentSource;
  readonly fetchedAt: number;
  readonly stale: boolean;
  readonly error: string;

  constructor(
    document: ScpArticleDocument | undefined = undefined,
    pendingExtraction: PendingExtraction | undefined = undefined,
    source: ArticleContentSource = ArticleContentSource.NETWORK,
    fetchedAt: number = 0,
    stale: boolean = false,
    error: string = ''
  ) {
    this.document = document;
    this.pendingExtraction = pendingExtraction;
    this.source = source;
    this.fetchedAt = fetchedAt;
    this.stale = stale;
    this.error = error;
  }
}

/**
 * Article 文档缓存的窄化端口。
 *
 * 记录只包含可序列化元数据和正文 JSON，不把 RDB、ResultSet 或文件句柄
 * 暴露给 application/VM。具体 schema 迁移与原子文件写入由组合根注入的
 * data adapter 负责。
 */
export interface ArticleDocumentCacheRecord {
  readonly itemId: string;
  readonly json: string;
  readonly schemaVersion: number;
  readonly parsedAt: number;
}

export interface ArticleDocumentCachePort {
  get(itemId: string): Promise<ArticleDocumentCacheRecord | undefined>;
  put(record: ArticleDocumentCacheRecord): Promise<void>;
  isFresh(record: ArticleDocumentCacheRecord): boolean;
}

/** Parser boundary used by the Article gateway; no HTML/WebView object escapes. */
export interface ArticleDocumentParserPort {
  parse(
    payloadText: string,
    sourceUrl: string,
    fetchedAt: number
  ): ScpArticleDocument;
  /** Serialize native HTML extraction for the same derived-document cache. */
  parseHtmlPayload?(html: string): Promise<string>;
  currentSchemaVersion(): number;
}

/**
 * Related-content metadata needed by the reader chrome.
 *
 * The reader does not need to know where a title or the small related-tale
 * list came from (catalog cache, network, or another product).  Keeping this
 * as a serializable port lets the Article ViewModel own the request token and
 * lifecycle rules while the product composition root supplies the adapter.
 */
export interface ArticleRelatedTale {
  readonly id: string;
  readonly title: string;
}

export interface ArticleMetadataPort {
  resolveTitle(content: LibraryContentRef): Promise<string>;
  listRelatedTales(content: LibraryContentRef, limit: number): Promise<ArticleRelatedTale[]>;
}

/**
 * 最小阅读历史快照。
 *
 * Article 只需要恢复滚动位置；最近阅读列表、排序和数据库字段仍归
 * Library feature 所有。使用独立快照避免把 ReadingHistoryEntry（以及
 * Library presentation 类型）反向带入正文 feature。
 */
export interface ArticleHistorySnapshot {
  readonly scrollOffset: number;
  readonly completed?: boolean;
}

/**
 * 正文使用的阅读历史端口。
 *
 * 这是 Article application/presentation 能看到的唯一历史协议。实现可以
 * 是共享 Library ViewModel 的 adapter，也可以是测试替身或未来独立仓储；
 * Article 不依赖 RDB、AppStorageV2 或具体 Library ViewModel。
 */
export interface ArticleHistoryPort {
  recordOpened(content: LibraryContentRef): Promise<void>;
  find(contentKey: string): Promise<ArticleHistorySnapshot | undefined>;
  updateProgress(content: LibraryContentRef, offset: number): Promise<void>;
  updateMetadata(content: LibraryContentRef): Promise<void>;
  /** Persist an explicit user annotation independent of scroll progress. */
  setCompleted?(content: LibraryContentRef, completed: boolean): Promise<void>;
}

export interface ArticleContentGateway {
  load(content: LibraryContentRef, requestId: number, forceNetwork?: boolean): Promise<ArticleLoadResult>;
  completeExtraction(
    content: LibraryContentRef,
    pending: PendingExtraction,
    payload: string
  ): Promise<ScpArticleDocument>;
}

export interface ArticleViewStatePort {
  read(articleId: string): Promise<string[]>;
  save(articleId: string, expandedKeys: string[]): Promise<void>;
}

/**
 * 收藏端口：正文 ViewModel 只看到业务动作和只读状态，不依赖
 * FavoritesViewModel、RDB 或 AppStorageV2 的具体实现。
 */
export interface ArticleFavoritePort {
  readonly initialized: boolean;
  readonly loading: boolean;
  isFavorite(contentKey: string): boolean;
  initialize(): Promise<void>;
  toggle(content: LibraryContentRef): Promise<boolean>;
  subscribe(listener: () => void): () => void;
}

export interface ReadingSessionPort {
  attach(content: LibraryContentRef, offset: number): void;
  setContentReady(content: LibraryContentRef, ready: boolean, offset: number): void;
  setShown(content: LibraryContentRef, shown: boolean, ready: boolean, offset: number): void;
  setActive(content: LibraryContentRef, active: boolean, ready: boolean, offset: number): void;
  noteInteraction(content: LibraryContentRef, offset: number): void;
  setContinuousInteraction(content: LibraryContentRef, active: boolean, offset: number): void;
  checkpoint(content: LibraryContentRef, offset: number): void;
  release(contentKey: string, offset: number): void;
}
