import { ArticleHtmlRepository } from './ArticleHtmlRepository';
import { ImagePreviewActions } from 'anomiconbasic';
import {
  CatalogRepository,
  CatalogTitleResolver,
  PreviewRepository,
  SearchHistoryRepository,
  TaleRepository
} from './CatalogRepositories';
import { SeriesTalesRepository } from './SeriesTalesContracts';

/**
 * The product composition root receives this graph instead of importing
 * concrete catalog services.  All members are domain ports; the factory
 * implementation is the only place that knows the legacy RDB/cache classes.
 */
export interface CatalogFeatureGraph {
  readonly catalogRepository: CatalogRepository;
  readonly taleRepository: TaleRepository;
  readonly seriesTalesRepository: SeriesTalesRepository;
  readonly previewRepository: PreviewRepository;
  readonly searchHistoryRepository: SearchHistoryRepository;
  readonly articleHtmlRepository: ArticleHtmlRepository;
  readonly titleResolver: CatalogTitleResolver;
  /** Image save/open capability; the implementation stays in catalog data. */
  readonly imagePreviewActions: ImagePreviewActions;
  /** Downloads a validated HTTPS image into cacheDir and returns its local file path. */
  downloadImageToCache(url: string): Promise<string>;
  /** Initializes all catalog-owned persistence adapters idempotently. */
  initialize(): Promise<void>;
  /** Clears disposable page, image and preview caches while keeping catalog series index intact. */
  clearTemporaryCaches(): Promise<void>;
  /** Releases graph-owned native resources. Safe to call repeatedly. */
  dispose(): void;
}
