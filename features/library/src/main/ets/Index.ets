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
export {
  READING_HISTORY_LIMIT,
  ReadingHistoryEntry,
  ReadingStateEntry
} from './domain/ReadingHistoryEntry';
export {
  RESEARCH_DAILY_CAP_MINUTES,
  ResearchDailyProgress,
  ResearchProgress,
  emptyResearchProgress,
  researchDayKeyAt
} from './domain/ResearchProgress';
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
  ResearchProfileViewModelListener,
  StorySeriesViewModel,
  StorySeriesViewModelListener
} from './presentation/viewmodel/Index';
export {
  ANTIMEMETICS_DIVISION_SERIES,
  ANTIMEMETICS_HUB_ID,
  ANTIMEMETICS_SERIES_ID,
  StorySeriesArticleContext,
  StorySeriesDefinition,
  StorySeriesEnrollment,
  StorySeriesEntry,
  StorySeriesGroup,
  StorySeriesProgressSnapshot,
  StorySeriesRepository,
  StorySeriesTier,
  buildStorySeriesArticleContext,
  containsSeriesEntry,
  countSeriesProgress,
  findStorySeriesByHubId,
  findStorySeriesById,
  findStorySeriesByMemberId,
  flattenSeriesEntries,
  listBuiltInStorySeries,
  listMainlineSeriesEntries,
  normalizeSeriesPageId,
  parseStorySeriesGroupsFromHubHtml,
  resolveSeriesResumeEntry
} from './domain/StorySeriesContracts';
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
export { LibraryCollectionViewContract } from './presentation/view/Index';
export { LibraryCollectionView } from './presentation/view/Index';
