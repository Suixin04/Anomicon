import { ResearchProfileCard } from './ResearchProfileCard';
import {
  TerminalCompactEmptyBanner,
  TerminalEnrolledSeriesList,
  TerminalErrorState,
  TerminalFavoriteCards,
  TerminalLibrarySectionTitle,
  TerminalOfflineArticleList,
  TerminalQuickWorkbenchBar,
  TerminalReadingHistoryList
} from './TerminalLibraryComponents';
import {
  FoundationAssessmentSealSummary,
  LibraryContentRef,
  LibraryFavorite
} from 'library';
import { ReadingHistoryEntry } from 'library';
import { ResearchProgress } from 'library';
import { LibraryCollectionMode } from 'library';
import {
  adaptivePageMarginForWidth,
  AppTypography,
  materialCardBorderColor,
  materialCardSurfaceColor,
  pageContentTop,
  PHONE_PAGE_MARGIN,
  READING_CONTENT_MAX_WIDTH
} from 'anomiconbasic';
import {
  TerminalEnrolledSeriesCard,
  TerminalOfflineArticleSummary,
  TerminalViewModel
} from '../viewmodel/TerminalViewModel';
import { SettingsViewModel } from 'settings';

const SECTION_SPACE: number = 20;

/**
 * 终端首页：紧凑研究员档案工牌（含资质印章）与专注本地阅读资产的个人资料库。
 *
 * 基金会设定手册与资质考核已独立承接于「基金会」中心页签。
 */
@ComponentV2
export struct TerminalHome {
  @Require @Param scroller: Scroller;
  @Require @Param active: boolean;
  @Require @Param onOpenContent: (content: LibraryContentRef) => void;
  @Require @Param onOpenOfflineCopy: (content: LibraryContentRef) => void;
  @Require @Param onOpenCollection: (mode: LibraryCollectionMode) => void;
  @Event onResumeSeries: (seriesId: string, content: LibraryContentRef) => void =
    (_seriesId: string, _content: LibraryContentRef): void => {};
  @Event onOpenSeriesHub: (hubId: string, title: string) => void =
    (_hubId: string, _title: string): void => {};
  @Event onOpenAssessment: (examId: string) => void = (_examId: string): void => {};
  @Event onOpenArchive3DGallery: () => void = () => {};
  @Event onOpenSettings: () => void = () => {};
  @Require @Param viewModel: TerminalViewModel;
  @Require @Param settings: SettingsViewModel;
  @Local private horizontalMargin: number = PHONE_PAGE_MARGIN;

  private isImmersiveMaterialEnabled(): boolean {
    return this.settings.immersiveMaterialEnabled;
  }

  aboutToAppear(): void {
    // TabContent can be mounted before it becomes the selected tab.  Do not
    // start title enrichment or shared-state subscriptions for a hidden tab;
    // the active monitor will activate the VM when it is actually visible.
    if (this.active) {
      this.viewModel.activate();
    }
  }

  aboutToDisappear(): void {
    this.viewModel.deactivate();
  }

  @Monitor('active')
  onActiveChange(): void {
    if (this.active) {
      this.viewModel.activate();
    } else {
      this.viewModel.deactivate();
    }
  }

  @Computed
  get favoriteEntries(): LibraryFavorite[] {
    return this.viewModel.favoriteEntries;
  }

  /** 首页推荐一篇，完整续读列表来自永久阅读进度。 */
  @Computed
  get resumeEntries(): ReadingHistoryEntry[] {
    return this.viewModel.resumeEntries;
  }

  @Computed
  get enrolledSeries(): TerminalEnrolledSeriesCard[] {
    return this.viewModel.enrolledSeries;
  }

  @Computed
  get assessmentSeals(): FoundationAssessmentSealSummary[] {
    return this.viewModel.assessmentSeals;
  }

  @Computed
  get offlineEntries(): TerminalOfflineArticleSummary[] {
    return this.viewModel.offlineEntries;
  }

  @Computed
  get offlineCount(): number {
    return this.viewModel.offlineCount;
  }

  /** 最近预览排除已经提升到“继续上次阅读”的条目，同一内容不重复出现。 */
  @Computed
  get recentEntries(): ReadingHistoryEntry[] {
    return this.viewModel.recentEntries;
  }

  @Computed
  get recentCount(): number {
    return this.viewModel.recentCount;
  }

  @Computed
  get favoriteCount(): number {
    return this.viewModel.favoriteCount;
  }

  @Computed
  get favoriteLoading(): boolean {
    return this.viewModel.favoriteLoading;
  }

  @Computed
  get favoriteError(): string {
    return this.viewModel.favoriteError;
  }

  @Computed
  get favoriteReady(): boolean {
    return this.viewModel.favoriteInitialized;
  }

  @Computed
  get historyCount(): number {
    return this.viewModel.historyCount;
  }

  @Computed
  get historyLoading(): boolean {
    return this.viewModel.historyLoading;
  }

  @Computed
  get historyError(): string {
    return this.viewModel.historyError;
  }

  @Computed
  get historyReady(): boolean {
    return this.viewModel.historyInitialized;
  }

  @Computed
  get researchSnapshot(): ResearchProgress {
    return this.viewModel.profile;
  }

  @Computed
  get researchLoading(): boolean {
    return this.viewModel.researchLoading;
  }

  @Computed
  get researchError(): string {
    return this.viewModel.researchError;
  }

  @Computed
  get researchReady(): boolean {
    return this.viewModel.researchInitialized;
  }

  private retryFavorites(): void {
    this.viewModel.refreshFavorites();
  }

  private retryHistory(): void {
    this.viewModel.refreshHistory();
  }

  private retryResearch(): void {
    this.viewModel.refreshResearch();
  }

  private researchProgressPercent(): number {
    const target = this.researchSnapshot.levelExperienceTarget;
    if (target <= 0) {
      return 100;
    }
    return Math.max(0, Math.min(100,
      this.researchSnapshot.levelExperience / target * 100
    ));
  }

  @Builder
  private sectionHeader(title: string, subtitle: string) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(AppTypography.TITLE_S)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font'))
      Text(subtitle)
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private emptyState(symbol: Resource, title: string, description: string) {
    Column({ space: 8 }) {
      SymbolGlyph(symbol)
        .fontSize(26)
        .fontColor([$r('sys.color.icon_tertiary')])
      Text(title)
        .fontSize(AppTypography.BODY_M)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font'))
      Text(description)
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 22, bottom: 22 })
    .backgroundColor(materialCardSurfaceColor(this.isImmersiveMaterialEnabled()))
    .border(this.isImmersiveMaterialEnabled() ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(16)
  }

  @Builder
  private loadingState(label: string) {
    Row({ space: 10 }) {
      LoadingProgress()
        .width(20)
        .height(20)
        .color($r('sys.color.icon_secondary'))
      Text(label)
        .fontSize(AppTypography.BODY_M)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height(76)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(materialCardSurfaceColor(this.isImmersiveMaterialEnabled()))
    .borderRadius(16)
  }

  @Builder
  private partialError(message: string, onRetry: () => void) {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(16)
        .fontColor([$r('sys.color.icon_secondary')])
      Text(message)
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text('重试')
        .fontSize(AppTypography.CAPTION_L)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_emphasize'))
        .onClick(() => onRetry())
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(12)
  }

  private leftPaneRightMargin(): number {
    return this.horizontalMargin;
  }

  @Builder
  private resumeReadingSection() {
    if (this.resumeEntries.length > 0 && !(this.historyLoading && this.historyCount === 0)) {
      Column({ space: 10 }) {
        if (this.viewModel.resumeCount > 1) {
          TerminalLibrarySectionTitle({
            symbol: $r('sys.symbol.list_book_fill'),
            title: '继续阅读',
            count: this.viewModel.resumeCount,
            showMore: true,
            onOpen: () => this.onOpenCollection(LibraryCollectionMode.CONTINUE_READING)
          })
        }
        TerminalReadingHistoryList({
          entries: this.resumeEntries,
          continueReading: true,
          materialEnabled: this.isImmersiveMaterialEnabled(),
          onOpenContent: (content: LibraryContentRef) => this.onOpenContent(content)
        })
      }
      .width('100%')
      .padding({ left: this.horizontalMargin, right: this.leftPaneRightMargin() })
    }
  }

  @Builder
  private enrolledSeriesSection() {
    if (this.enrolledSeries.length > 0) {
      Column({ space: 10 }) {
        TerminalLibrarySectionTitle({
          symbol: $r('sys.symbol.list_book_fill'),
          title: '正在跟读',
          count: this.enrolledSeries.length,
          showMore: false,
          onOpen: () => {}
        })
        TerminalEnrolledSeriesList({
          entries: this.enrolledSeries,
          materialEnabled: this.isImmersiveMaterialEnabled(),
          onResumeSeries: (seriesId: string, content: LibraryContentRef) =>
            this.onResumeSeries(seriesId, content),
          onOpenSeriesHub: (hubId: string, title: string) =>
            this.onOpenSeriesHub(hubId, title)
        })
      }
      .width('100%')
      .padding({ left: this.horizontalMargin, right: this.leftPaneRightMargin() })
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private offlineArticlesSection() {
    if (this.offlineCount > 0) {
      Column({ space: 10 }) {
        TerminalLibrarySectionTitle({
          symbol: $r('sys.symbol.archivebox_fill'),
          title: '离线保存',
          count: this.offlineCount,
          showMore: false,
          onOpen: () => {}
        })
        TerminalOfflineArticleList({
          entries: this.offlineEntries,
          materialEnabled: this.isImmersiveMaterialEnabled(),
          onOpenContent: (content: LibraryContentRef) => this.onOpenOfflineCopy(content)
        })
      }
      .width('100%')
      .padding({ left: this.horizontalMargin, right: this.leftPaneRightMargin() })
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private favoritesPreview() {
    Column({ space: 10 }) {
      Column() {
        TerminalLibrarySectionTitle({
          symbol: $r('sys.symbol.star_fill'),
          title: '收藏',
          count: this.favoriteCount,
          showMore: this.favoriteCount > 5,
          onOpen: () => this.onOpenCollection(LibraryCollectionMode.FAVORITES)
        })
      }
      .width('100%')
      .padding({ left: this.horizontalMargin, right: this.leftPaneRightMargin() })

      if (this.favoriteLoading && this.favoriteCount === 0) {
        Column() {
          this.loadingState('正在读取收藏…')
        }
        .width('100%')
        .padding({ left: this.horizontalMargin, right: this.leftPaneRightMargin() })
      } else if (this.favoriteError.length > 0 && this.favoriteCount === 0) {
        Column() {
          TerminalErrorState({
            message: this.favoriteError,
            onRetry: () => this.retryFavorites()
          })
        }
        .width('100%')
        .padding({ left: this.horizontalMargin, right: this.leftPaneRightMargin() })
      } else if (this.favoriteCount === 0) {
        Column() {
          TerminalCompactEmptyBanner({
            symbol: $r('sys.symbol.star'),
            title: '还没有收藏',
            description: '阅读档案或故事时，可在右上角菜单加入收藏。',
            materialEnabled: this.isImmersiveMaterialEnabled()
          })
        }
        .width('100%')
        .padding({ left: this.horizontalMargin, right: this.leftPaneRightMargin() })
      } else {
        Column({ space: 8 }) {
          Scroll() {
            TerminalFavoriteCards({
              entries: this.favoriteEntries,
              materialEnabled: this.isImmersiveMaterialEnabled(),
              horizontalPadding: this.horizontalMargin,
              onOpenContent: (content: LibraryContentRef) => this.onOpenContent(content)
            })
          }
          .width('100%')
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          if (this.favoriteError.length > 0) {
            Column() {
              this.partialError(this.favoriteError, () => this.retryFavorites())
            }
            .width('100%')
            .padding({ left: this.horizontalMargin, right: this.leftPaneRightMargin() })
          }
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private recentHistorySection() {
    Column({ space: 12 }) {
      if (this.historyLoading && this.historyCount === 0) {
        this.loadingState('正在读取阅读记录…')
      } else if (this.historyError.length > 0 && this.historyCount === 0) {
        TerminalErrorState({
          message: this.historyError,
          onRetry: () => this.retryHistory()
        })
      } else {
        if (this.historyCount === 0 || this.recentCount > 0) {
          Column({ space: 10 }) {
            TerminalLibrarySectionTitle({
              symbol: $r('sys.symbol.clock_fill'),
              title: '最近浏览',
              count: this.recentCount,
              showMore: this.historyCount > 4,
              onOpen: () => this.onOpenCollection(LibraryCollectionMode.RECENT)
            })
            if (this.historyCount === 0) {
              this.emptyState(
                $r('sys.symbol.clock'),
                '暂无阅读记录',
                '调阅任意档案、故事或手册后，记录将留存于此。'
              )
            } else {
              TerminalReadingHistoryList({
                entries: this.recentEntries,
                continueReading: false,
                materialEnabled: this.isImmersiveMaterialEnabled(),
                onOpenContent: (content: LibraryContentRef) => this.onOpenContent(content)
              })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        if (this.historyError.length > 0) {
          this.partialError(this.historyError, () => this.retryHistory())
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private personalLibrary() {
    Column({ space: 14 }) {
      Column() {
        this.sectionHeader('个人资料库', '阅读进度、藏品与常用本地入口')
      }
      .width('100%')
      .padding({ left: this.horizontalMargin, right: this.leftPaneRightMargin() })

      Column() {
        TerminalQuickWorkbenchBar({
          favoriteCount: this.favoriteCount,
          materialEnabled: this.isImmersiveMaterialEnabled(),
          onOpenArchive3DGallery: () => this.onOpenArchive3DGallery(),
          onOpenFavorites: () => this.onOpenCollection(LibraryCollectionMode.FAVORITES),
          onOpenSettings: () => this.onOpenSettings()
        })
      }
      .width('100%')
      .padding({ left: this.horizontalMargin, right: this.leftPaneRightMargin() })

      this.resumeReadingSection()

      this.enrolledSeriesSection()

      this.offlineArticlesSection()

      this.favoritesPreview()

      Column() {
        this.recentHistorySection()
      }
      .width('100%')
      .padding({ left: this.horizontalMargin, right: this.leftPaneRightMargin() })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: SECTION_SPACE }) {
        Column() {
          ResearchProfileCard({
            level: this.researchSnapshot.level,
            title: this.researchSnapshot.rankTitle,
            experience: this.researchSnapshot.experience,
            currentLevelXp: this.researchSnapshot.levelThreshold,
            nextLevelXp: this.researchSnapshot.nextLevelThreshold,
            progressPercent: this.researchProgressPercent(),
            effectiveActiveMs: this.researchSnapshot.creditedActiveMs,
            studiedCount: this.researchSnapshot.researchedContentCount,
            favoriteCount: this.favoriteCount,
            historyCount: this.historyCount,
            favoriteReady: this.favoriteReady,
            historyReady: this.historyReady,
            dailyProgress: this.researchSnapshot.daily,
            seals: this.assessmentSeals,
            loading: this.researchLoading ||
              (this.viewModel.loading && !this.researchReady && this.researchError.trim().length === 0),
            error: !this.researchReady && !this.researchLoading ? this.researchError : '',
            notice: this.researchReady ? this.researchError : '',
            materialEnabled: this.isImmersiveMaterialEnabled(),
            onRetry: () => this.retryResearch(),
            onOpenFavorites: () => this.onOpenCollection(LibraryCollectionMode.FAVORITES),
            onOpenHistory: () => this.onOpenCollection(LibraryCollectionMode.RECENT),
            onOpenSeal: (examId: string) => this.onOpenAssessment(examId)
          })
        }
        .width('100%')
        .padding({ left: this.horizontalMargin, right: this.horizontalMargin })

        this.personalLibrary()

        Blank()
          .width('100%')
          .height(120)
      }
      .width('100%')
      .constraintSize({ maxWidth: READING_CONTENT_MAX_WIDTH })
      .padding({
        top: pageContentTop() + 12,
        bottom: 24
      })
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .width('100%')
    .height('100%')
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const viewportWidth = Number(newArea.width);
      if (Number.isFinite(viewportWidth) && viewportWidth > 0) {
        this.horizontalMargin = adaptivePageMarginForWidth(viewportWidth);
      }
    })
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
