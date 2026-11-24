import {
  CatalogEntry,
  CatalogPreview,
  CatalogSnapshot,
  TaleSnapshot
} from '../domain/CatalogContracts';
import {
  CatalogRepository,
  PreviewRefreshListener,
  PreviewRepository,
  SearchHistoryRepository,
  TaleRepository
} from '../domain/CatalogRepositories';
import { ScpHtmlRequestPriority } from '../domain/ArticleHtmlRepository';
import { ScpSeriesDescriptor } from '../domain/ScpSeriesItem';

/** 图鉴读取用例：快照读取与后台重验分开，明确 stale-while-revalidate 边界。 */
export class CatalogContentUseCase {
  private readonly repository: CatalogRepository;

  constructor(repository: CatalogRepository) {
    this.repository = repository;
  }

  load(
    series: ScpSeriesDescriptor,
    priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.USER_INITIATED
  ): Promise<CatalogSnapshot> {
    return this.repository.load(series, priority);
  }

  refresh(
    series: ScpSeriesDescriptor,
    priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.BACKGROUND
  ): Promise<CatalogSnapshot> {
    return this.repository.refresh(series, priority);
  }

  cached(seriesId: string): Promise<CatalogSnapshot | undefined> {
    return this.repository.getCached(seriesId);
  }

  observe(seriesId: string, listener: (snapshot: CatalogSnapshot) => void): () => void {
    return this.repository.subscribe(seriesId, listener);
  }
}

/** 故事列表用例。 */
export class TaleContentUseCase {
  private readonly repository: TaleRepository;

  constructor(repository: TaleRepository) {
    this.repository = repository;
  }

  load(priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.USER_INITIATED): Promise<TaleSnapshot> {
    return this.repository.load(priority);
  }

  refresh(priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.BACKGROUND): Promise<TaleSnapshot> {
    return this.repository.refresh(priority);
  }

  cached(): Promise<TaleSnapshot | undefined> {
    return this.repository.getCached();
  }

  observe(listener: (snapshot: TaleSnapshot) => void): () => void {
    return this.repository.subscribe(listener);
  }
}

/** 卡片预览用例：ViewModel 不需要知道图片缓存、HTML 提取或下载策略。 */
export class CatalogPreviewUseCase {
  private readonly repository: PreviewRepository;

  constructor(repository: PreviewRepository) {
    this.repository = repository;
  }

  execute(
    itemId: string,
    onRefreshed?: PreviewRefreshListener,
    priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.VISIBLE,
    forceRefresh: boolean = false
  ): Promise<CatalogPreview> {
    return this.repository.getPreview(itemId, onRefreshed, priority, forceRefresh);
  }

  prefetch(itemIds: string[]): void {
    this.repository.prefetch(itemIds);
  }

  cancelPrefetch(itemIds: string[]): void {
    this.repository.cancelQueuedPrefetch(itemIds);
  }

}

/** 搜索历史用例，保持输入清理和持久化实现隔离。 */
export class SearchHistoryUseCase {
  private readonly repository: SearchHistoryRepository;

  constructor(repository: SearchHistoryRepository) {
    this.repository = repository;
  }

  list(): string[] {
    return this.repository.list();
  }

  add(query: string): void {
    this.repository.add(query.trim());
  }

  clear(): void {
    this.repository.clear();
  }
}

/** 统一检索组合用例：集中处理主站/CN 目录、故事目录过滤与随机发现。 */
export class CatalogSearchUseCase {
  private readonly catalog: CatalogContentUseCase;
  private readonly history: SearchHistoryUseCase;
  private readonly tales?: TaleContentUseCase;

  constructor(
    catalog: CatalogContentUseCase,
    history: SearchHistoryUseCase,
    tales?: TaleContentUseCase
  ) {
    this.catalog = catalog;
    this.history = history;
    this.tales = tales;
  }

  hasTales(): boolean {
    return this.tales !== undefined;
  }

  load(
    series: ScpSeriesDescriptor,
    priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.USER_INITIATED
  ): Promise<CatalogSnapshot> {
    return this.catalog.load(series, priority);
  }

  /** Explicit user retry: bypass the cached snapshot and revalidate the source. */
  refresh(series: ScpSeriesDescriptor): Promise<CatalogSnapshot> {
    return this.catalog.refresh(series, ScpHtmlRequestPriority.USER_INITIATED);
  }

  cached(seriesId: string): Promise<CatalogSnapshot | undefined> {
    return this.catalog.cached(seriesId);
  }

  observe(seriesId: string, listener: (snapshot: CatalogSnapshot) => void): () => void {
    return this.catalog.observe(seriesId, listener);
  }

  async cachedTales(): Promise<TaleSnapshot | undefined> {
    if (this.tales === undefined) {
      return undefined;
    }
    return this.tales.cached();
  }

  async loadTales(
    priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.BACKGROUND
  ): Promise<TaleSnapshot | undefined> {
    if (this.tales === undefined) {
      return undefined;
    }
    return this.tales.load(priority);
  }

  async refreshTales(): Promise<TaleSnapshot | undefined> {
    if (this.tales === undefined) {
      return undefined;
    }
    return this.tales.refresh(ScpHtmlRequestPriority.USER_INITIATED);
  }

  observeTales(listener: (snapshot: TaleSnapshot) => void): () => void {
    if (this.tales === undefined) {
      return (): void => {};
    }
    return this.tales.observe(listener);
  }

  listHistory(): string[] {
    return this.history.list();
  }

  addHistory(query: string): void {
    this.history.add(query);
  }

  clearHistory(): void {
    this.history.clear();
  }

  /** 使用 Fisher-Yates 保留旧搜索页的随机发现语义。 */
  pickRandom(entries: CatalogEntry[], count: number): CatalogEntry[] {
    const copy = entries.slice();
    for (let index = copy.length - 1; index > 0; index--) {
      const swap = Math.floor(Math.random() * (index + 1));
      const current = copy[index];
      copy[index] = copy[swap];
      copy[swap] = current;
    }
    return copy.slice(0, Math.min(Math.max(0, count), copy.length));
  }
}
