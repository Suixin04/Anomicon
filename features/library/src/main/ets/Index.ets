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
  StorySeriesViewModelListener,
  AssessmentBonusXpCallback,
  AssessmentNowProvider,
  FoundationAssessmentViewModel,
  FoundationAssessmentViewModelListener,
  RaisaFeedbackNowProvider,
  RaisaFeedbackViewModel,
  RaisaFeedbackViewModelListener
} from './presentation/viewmodel/Index';
export {
  RAISA_CONTACT_MAX_LENGTH,
  RAISA_DETAILS_MAX_LENGTH,
  RAISA_DETAILS_MIN_LENGTH,
  RAISA_FEEDBACK_CATEGORIES,
  RAISA_GITHUB_ISSUES_URL,
  RAISA_RELAY_BASE_URL,
  RAISA_SUMMARY_MAX_LENGTH,
  RAISA_SUMMARY_MIN_LENGTH,
  RaisaDiagnosticSnapshot,
  RaisaFeedbackCategory,
  RaisaFeedbackCategoryDescriptor,
  RaisaFeedbackContext,
  RaisaFeedbackRelayGateway,
  RaisaFeedbackRepository,
  RaisaFeedbackSubmission,
  RaisaFeedbackSubmitResult,
  RaisaFeedbackTicket,
  emptyRaisaFeedbackContext,
  findRaisaFeedbackCategoryDescriptor,
  formatRaisaDiagnosticLines,
  formatRaisaTicketPlainReport,
  formatRaisaTicketTimestamp,
  parseRaisaFeedbackCategory,
  sanitizeFeedbackMultiline,
  sanitizeFeedbackSingleLine,
  validateRaisaFeedbackInput
} from './domain/RaisaFeedbackContracts';
export {
  FoundationAssessmentExam,
  FoundationAssessmentIcon,
  FoundationAssessmentQuestion,
  FoundationAssessmentRecord,
  FoundationAssessmentRepository,
  FoundationAssessmentSealSummary,
  FoundationAssessmentSubmissionResult,
  normalizeAssessmentExamId
} from './domain/FoundationAssessmentContracts';
export {
  findFoundationAssessmentExam,
  listFoundationAssessmentExams,
  totalFoundationAssessmentXp
} from './domain/FoundationAssessmentCatalog';
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
