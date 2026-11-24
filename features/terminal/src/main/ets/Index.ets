/** Public terminal feature surface; persistence remains in the library HAR. */
export { TerminalHome } from './presentation/view/TerminalHome';
export { FoundationHome } from './presentation/view/FoundationHome';
export { FoundationAssessmentView } from './presentation/view/FoundationAssessmentView';
export {
  TerminalViewModel,
  TerminalTitleResolver,
  TerminalViewModelListener,
  TerminalFavoritesPort,
  TerminalReadingHistoryPort,
  TerminalResearchProfilePort,
  TerminalOfflineArticleSummary,
  TerminalOfflineArticlesPort,
  TerminalEnrolledSeriesCard,
  TerminalStorySeriesPort,
  TerminalAssessmentsPort
} from './presentation/viewmodel/TerminalViewModel';
export {
  TerminalErrorState,
  TerminalLibrarySectionTitle,
  TerminalReadingHistoryList,
  TerminalEnrolledSeriesList,
  TerminalOfflineArticleList,
  TerminalCompactEmptyBanner,
  TerminalQuickWorkbenchBar
} from './presentation/view/TerminalLibraryComponents';
export { TerminalViewContract } from './presentation/view/TerminalViewContracts';
export {
  FOUNDATION_FEATURED_KNOWLEDGE,
  FOUNDATION_KNOWLEDGE_SECTIONS,
  FOUNDATION_MANUAL_GRID_ITEMS,
  FoundationKnowledgeIcon,
  FoundationKnowledgeItem,
  FoundationKnowledgeSection,
  FoundationKnowledgeSectionId
} from './presentation/model/FoundationKnowledge';
export {
  DailyActivityBar,
  buildRecentSevenDayActivity,
  formatTodayQuotaLabel
} from './presentation/model/TerminalProfileHelpers';
