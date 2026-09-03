/**
 * Explore feature 的窄化公开出口。
 * data adapter 不从这里导出，产品层通过 composition 注入 domain 端口实现。
 */
export {
  ExploreCombinedSnapshot,
  ExploreCollectionMode,
  ExploreContentItem,
  ExploreDataOrigin,
  ExploreEntry,
  ExploreLoadedPayload,
  ExplorePayload,
  ExplorePreview,
  ExploreRecommendation,
  ExploreRecommendationEntry,
  ExploreSource,
  ExploreSourceSnapshot,
  ExploreStoredSnapshot,
  EXPLORE_FRESH_CACHE_DURATION,
  exploreDayKey,
  exploreEntriesFromPayload,
  selectExploreIndexes
} from './domain/ExploreContracts';
export {
  ExploreListRepository,
  ExploreHtmlRepository,
  ExploreHtmlLoadResult,
  ExploreHtmlSource,
  ExploreFetchedPage,
  ExploreRecommendationPageGateway,
  ExploreTitleResolver,
  PreviewRepository,
  RecommendationRepository
} from './domain/ExploreRepositories';
export { ExploreContentUseCase } from './application/ExploreContentUseCase';
export { RecommendationUseCase } from './application/RecommendationUseCase';
export {
  ExploreFeatureDependencies,
  ExploreFeatureGraph
} from './composition/ExploreFeatureGraph';
export { createExploreFeatureGraph } from './composition/ExploreFeatureFactory';
export {
  ExploreCollectionEvent,
  ExploreCollectionEventType,
  ExploreCollectionScreenData,
  ExploreCollectionVM,
  ExploreHomeEvent,
  ExploreHomeEventType,
  ExploreHomeViewModel
} from './presentation/viewmodel/Index';
export {
  ExploreHeroAnchor,
  ExploreCollectionViewContract,
  ExploreHomeViewContract,
  ExploreNavigationEvent
} from './presentation/view/ExploreViewContracts';
export {
  ExploreCollectionView,
  ExploreHome,
  ExploreRecommendationSkeleton
} from './presentation/view/Index';
