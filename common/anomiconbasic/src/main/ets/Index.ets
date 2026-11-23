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
  windowAvoidTop,
  pageContentTop,
  immersiveMaterialSupported,
  uiImmersiveMaterialSupported,
  createAppTitleBarStyle,
  AppBodyText,
  ReadingBodyText,
  SkeletonBlock
} from './ui/Index';
