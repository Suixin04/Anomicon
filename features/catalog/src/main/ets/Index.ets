/**
 * 图鉴 feature 的窄化公开出口。
 *
 * HAR consumers receive domain contracts, application use cases, ViewModels,
 * Views and the feature graph only.  RDB/RCP/cache adapters stay private to
 * Catalog's composition factory.
 */
export {
  CatalogEntry,
  CatalogPreview,
  CatalogSnapshot,
  CatalogSnapshotSource,
  CatalogTaleEntry,
  TaleSnapshot,
  CatalogParser,
  CatalogParseResult,
  TaleParseResult
} from './domain/CatalogContracts';
export {
  ArticleHtmlRepository,
  ScpHtmlLoadResult,
  ScpHtmlSource,
  ScpHtmlRequestPriority
} from './domain/ArticleHtmlRepository';
export {
  SCP_CATALOG_PARSER_VERSION,
  TALE_LIST_PARSER_VERSION,
  ScpCatalogRawEntry,
  ScpCatalogPayload,
  TaleRawEntry,
  TalePayload
} from './domain/StaticCatalogContracts';
export {
  ALL_CATALOG_SERIES,
  ALL_SERIES_ID,
  ALL_SERIES_LABEL,
  branchOfSeriesId,
  catalogSeriesForBranch,
  DEFAULT_CN_SERIES_ID,
  DEFAULT_SERIES_ID,
  findCatalogSeriesById,
  isCnScpItemId,
  SCP_CN_SERIES,
  SCP_SERIES,
  ScpCatalogBranch,
  ScpSeriesDescriptor,
  articleUrlOf
} from './domain/ScpSeriesItem';
export {
  CatalogDirectTarget,
  CatalogSearchTargetKind,
  resolveCatalogDirectTarget
} from './domain/CatalogDirectTarget';
export {
  SeriesRelatedTaleEntry,
  SeriesTalesRepository,
  matchesExactScpReference,
  resolveSeriesTalesEditionPageId
} from './domain/SeriesTalesContracts';
export { DailyContentPolicy } from './domain/DailyContentPolicy';
export {
  CATALOG_TOOLBAR_HEIGHT,
  ScpCatalogSearchState,
  sharedCatalogSearchState
} from './presentation/ScpCatalogSearchState';
export { TALE_FILTER_BAR_HEIGHT, TaleFilterState } from './presentation/TaleFilterState';
export {
  CatalogRepository,
  TaleRepository,
  PreviewRepository,
  SearchHistoryRepository,
  CatalogTitleResolver,
  CatalogSnapshotListener,
  TaleSnapshotListener,
  PreviewRefreshListener
} from './domain/CatalogRepositories';
export { CatalogFeatureGraph } from './domain/CatalogFeaturePorts';
export { createCatalogFeatureGraph } from './composition/CatalogFeatureFactory';
export {
  CatalogContentUseCase,
  TaleContentUseCase,
  CatalogPreviewUseCase,
  SearchHistoryUseCase,
  CatalogSearchUseCase
} from './application/CatalogUseCases';
// Data adapters are intentionally private to products/phone/composition and
// must never be re-exported from this public feature surface.
export {
  CatalogViewModel
} from './presentation/viewmodel/CatalogViewModel';
export {
  TaleListViewModel
} from './presentation/viewmodel/TaleListViewModel';
export {
  CatalogSearchScreenData,
  CatalogSearchViewModel
} from './presentation/viewmodel/CatalogSearchViewModel';
export {
  CatalogSearchSelection,
  CatalogSearchSharedState,
  CatalogSearchViewContract,
  CatalogSearchViewInput,
  CATALOG_SEARCH_HEADER_HEIGHT,
  CatalogSearchHeader,
  CatalogSearchView,
  CatalogSeriesSelector,
  CatalogBranchSeriesBar,
  ScpCatalogHome,
  TaleList,
  TaleFeaturedSeriesCard,
  StoryFilterBar
} from './presentation/view/Index';
export { ScpCatalogEntry } from './presentation/ScpCatalogItem';
