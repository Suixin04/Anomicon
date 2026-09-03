/** Narrow library feature出口; persistence adapters remain private to composition. */
export {
  LibraryContentKind,
  LibraryContentRef,
  LibraryFavorite,
  createLibraryContentRef,
  isLibraryContentTitlePlaceholder,
  isLibraryScpId,
  parseLibraryContentKind
} from './domain/LibraryContentRef';
export { FavoriteRepository, ReadingHistoryRepository } from './domain/LibraryRepositories';
export { LibraryFeatureGraph } from './domain/LibraryFeaturePorts';
export { createLibraryFeatureGraph } from './composition/LibraryFeatureFactory';
export { ReadingHistoryEntry } from './domain/ReadingHistoryEntry';
export { ResearchProgress } from './domain/ResearchProgress';
export {
  ResearchActivityRepo,
  ResearchActivitySink,
  ResearchActivitySnapshot,
  ResearchActivityMutationResult
} from './domain/ResearchActivityRepo';
export {
  FavoritesViewModel,
  FavoritesViewModelListener,
  ReadingHistoryViewModel,
  ReadingHistoryViewModelListener,
  ResearchProfileViewModel,
  ResearchProfileViewModelListener
} from './presentation/viewmodel/Index';
export { ReadingActivityCoord } from './application/ReadingActivityCoord';
export {
  LibraryCollectionItem,
  LibraryCollectionMode,
  parseLibraryCollectionMode
} from './domain/LibraryContracts';
export {
  LibraryCollectionScreenData,
  LibraryCollectionVM
} from './presentation/viewmodel/Index';
export { emptyResearchProgress } from './domain/ResearchProgress';
export { LibraryCollectionViewContract } from './presentation/view/Index';
export { LibraryCollectionView } from './presentation/view/Index';
