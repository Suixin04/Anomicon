/** Narrow public surface for cross-feature contracts. */
export {
  ViewModelLoadState,
  ViewModelLifecycle,
  ViewModelErrorInfo,
  ViewModelSnapshot
} from './mvvm/Index';
export {
  AppTypography,
  CACHE_FRESH_DURATION_MS
} from './foundation/Index';
export {
  AppInfoPort,
  HapticFeedbackPort,
  RuntimeClockPort,
  IdGeneratorPort,
  AppInfoAdapter,
  HapticFeedbackAdapter,
  RuntimeClockAdapter,
  IdGeneratorAdapter,
  ExternalUrlPolicy
} from './platform/Index';
export {
  BackgroundDownloadState,
  BackgroundDownloadErrorKind,
  BackgroundDownloadError,
  BackgroundDownloadRequest,
  BackgroundDownloadSnapshot,
  BackgroundDownloadListener,
  BackgroundDownloadTask,
  BackgroundDownloadClient,
  RequestAgentBackgroundDownloadAdapter,
  NetworkQualityTier,
  NetworkBoostScene,
  NetworkQoeStatus,
  NetworkConditionSnapshot,
  NetworkConditionListener,
  NetworkBoostPort,
  NetworkBoostAdapter
} from './platform/Index';
export {
  AtomicTextCacheFileStore,
  ANOMICON_DATABASE_NAME
} from './storage/Index';
export {
  ImagePreviewActions
} from './media/Index';
export {
  AppWidthBreakpoint,
  BREAKPOINT_MD_MIN_WIDTH,
  BREAKPOINT_LG_MIN_WIDTH,
  BREAKPOINT_XL_MIN_WIDTH,
  READING_CONTENT_MAX_WIDTH,
  WIDE_CONTENT_MAX_WIDTH,
  CATALOG_CONTENT_MAX_WIDTH,
  SPLIT_NAVIGATION_MIN_WIDTH,
  SPLIT_NAV_BAR_WIDTH,
  SPLIT_NAV_BAR_MIN_WIDTH,
  SPLIT_NAV_BAR_MAX_WIDTH,
  SPLIT_CONTENT_MIN_WIDTH,
  ARTICLE_SIDEBAR_MIN_WIDTH,
  ARTICLE_SIDEBAR_AUTO_OPEN_MIN_WIDTH,
  ARCHIVE_3D_WORKBENCH_MIN_WIDTH,
  resolveWidthBreakpoint,
  adaptivePageMarginForWidth,
  adaptiveListLanesForWidth,
  supportsSplitNavigation,
  supportsArticleSidePanel,
  autoOpenArticleSidePanel,
  shouldUseCenterSheet,
  resolveArticleSidebarWidth
} from './ui/Index';
export {
  objectClassColor,
  materialCardSurfaceColor,
  materialCardBorderColor,
  recommendationFallbackBackgroundColor,
  badgeInfoForegroundColor,
  badgeInfoBackgroundColor,
  badgeWarningForegroundColor,
  badgeWarningBackgroundColor,
  badgeDangerForegroundColor,
  badgeDangerBackgroundColor,
  accentPillBackgroundColor,
  accentPillForegroundColor,
  ContentUpdateNotice,
  PressFeedbackModifier,
  CARD_PRESS_MODIFIER,
  ROW_PRESS_MODIFIER,
  PHONE_TAB_CONTENT_MAX_WIDTH,
  PHONE_TAB_CONTENT_TOP_GAP,
  PHONE_TAB_CONTENT_BOTTOM_SPACE,
  PHONE_PAGE_MARGIN,
  HDS_TITLE_BAR_HEIGHT_MINI,
  updateWindowAvoidArea,
  updateWindowLayoutSize,
  windowWidthVp,
  windowHeightVp,
  windowWidthBreakpoint,
  adaptivePageMargin,
  isLargeWindow,
  isSplitNavigationActive,
  setSplitNavigationActive,
  isDetailFullscreen,
  setDetailFullscreen,
  isPreviewFullscreen,
  setPreviewFullscreen,
  isDarkModeActive,
  setDarkModeActive,
  notifyNavigationStackChanged,
  navigationStackRevision,
  popNavigationDestination,
  createAppBackIcon,
  windowAvoidTop,
  pageContentTop,
  immersiveMaterialSupported,
  uiImmersiveMaterialSupported,
  createAppTitleBarStyle,
  AppBodyText,
  ReadingBodyText,
  SkeletonBlock
} from './ui/Index';
