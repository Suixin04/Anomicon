/**
 * Phone product main Tab content.
 *
 * The entry wrapper lives beside this file so product composition stays
 * separate from the tab content implementation.
 */
// 从6.0.2(22)版本开始，无需手动导入HdsNavigationAttribute。具体请参考HdsNavigation的导入模块说明。
import {
  HideMode,
  hdsMaterial,
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController
} from '@kit.UIDesignKit';
import {
  SymbolGlyphModifier
} from '@kit.ArkUI';
import {
  ExploreHeroAnchor,
  ExploreHome,
  ExploreHomeViewModel
} from 'explore';
import {
  ScpCatalogHome,
  TaleList,
  StoryFilterBar,
  CatalogBranchSeriesBar,
  CATALOG_TOOLBAR_HEIGHT,
  ScpCatalogBranch,
  ScpCatalogSearchState,
  sharedCatalogSearchState,
  TALE_FILTER_BAR_HEIGHT,
  TaleFilterState,
  CatalogPreview,
  CatalogViewModel,
  TaleFeaturedSeriesCard,
  TaleListViewModel
} from 'catalog';
import {
  FoundationHome,
  TerminalHome,
  TerminalViewModel
} from 'terminal';
import {
  ANTIMEMETICS_HUB_ID,
  FoundationAssessmentViewModel,
  LibraryContentKind,
  LibraryContentRef,
  StorySeriesProgressSnapshot,
  StorySeriesViewModel,
  createLibraryContentRef,
  ReadingHistoryViewModel
} from 'library';
import { HomeTabId, TabItem } from '../navigation/TabItem';
import { TabsViewModel } from '../navigation/TabsViewModel';
import {
  AppRoutes,
  ExploreCollectionMode,
  ExploreCollectionRouteParams,
  FoundationAssessmentRouteParams,
  LibraryCollectionMode,
  LibraryCollectionRouteParams,
  ScpArticleRouteParams
} from '../navigation/AppRoutes';
import { AppNavigationCoordinator } from '../navigation/AppNavigationCoordinator';
import {
  adaptivePageMarginForWidth,
  AppMotion,
  createAppTitleBarStyle,
  DestinationMotionState,
  immersiveMaterialSupported,
  isDetailFullscreen,
  isLargeWindow,
  isPreviewFullscreen,
  isReduceMotionEnabled,
  navigationStackRevision,
  NavigationTransitionRegistry,
  setDetailFullscreen,
  setPreviewFullscreen,
  setSplitNavigationActive,
  SPLIT_CONTENT_MIN_WIDTH,
  SPLIT_NAV_BAR_MAX_WIDTH,
  SPLIT_NAV_BAR_MIN_WIDTH,
  SPLIT_NAV_BAR_WIDTH,
  supportsSplitNavigation,
  windowWidthVp
} from 'anomiconbasic';
import { HapticFeedbackPort } from 'anomiconbasic';
import {
  SettingsViewModel
} from 'settings';
import { hasScp3DModel } from 'archive3d';
import { resolveCatalogPreviewFileSource } from '../composition/CatalogPreviewSourceAdapter';

@ComponentV2
export struct MainTabIndex {
  /** All screen dependencies are assembled by the phone entry composition. */
  @Require @Param settings: SettingsViewModel;
  @Require @Param hapticService: HapticFeedbackPort;
  @Require @Param exploreViewModel: ExploreHomeViewModel;
  @Require @Param catalogViewModel: CatalogViewModel;
  @Require @Param taleListViewModel: TaleListViewModel;
  @Require @Param terminalViewModel: TerminalViewModel;
  @Require @Param readingHistory: ReadingHistoryViewModel;
  @Require @Param storySeries: StorySeriesViewModel;
  @Require @Param foundationAssessments: FoundationAssessmentViewModel;
  @Require @Param exploreSkeletonAnimated: boolean;
  @Event onExploreHeroAnchorChange: (anchor: ExploreHeroAnchor) => void;
  @Param pageStack: NavPathStack = new NavPathStack();
  /** 图鉴浏览状态：与独立搜索路由共享当前系列。 */
  @Local private searchState: ScpCatalogSearchState = sharedCatalogSearchState();
  /** 故事筛选只在首页会话内共享给筛选栏和列表。 */
  @Local private taleFilterState: TaleFilterState = new TaleFilterState();
  @Local private completionRevision: number = 0;
  @Local private seriesRevision: number = 0;
  // 顶部栏跟随页签选中；页面激活和滚动绑定仍等切页完成。
  @Local private titleTabIndex: number = HomeTabId.EXPLORE;
  @Local private tabContentOpacity: number = 1;
  @Local private tabContentOffsetY: number = 0;
  @Local private readonly navBarMotion: DestinationMotionState = new DestinationMotionState();
  @Local private stackDepth: number = 0;
  @Local private navPaneWidth: number = 0;
  private readingHistoryUnsubscribe: (() => void) | undefined = undefined;
  private storySeriesUnsubscribe: (() => void) | undefined = undefined;
  @Local private tabsViewModel: TabsViewModel = new TabsViewModel({
    onCatalogSearch: () => this.openCatalogSearchMenu(),
    onOpenSettings: () => this.openSettings(),
    onOpenArchive3DGallery: () => this.openArchive3DGallery()
  });

  private tabsController: HdsTabsController = new HdsTabsController();
  private scrollers: Scroller[] = [
    new Scroller(),
    new Scroller(),
    new Scroller(),
    new Scroller(),
    new Scroller()
  ];
  aboutToAppear(): void {
    this.readingHistoryUnsubscribe = this.readingHistory.subscribe((): void => {
      this.completionRevision++;
    });
    this.storySeriesUnsubscribe = this.storySeries.subscribe((): void => {
      this.seriesRevision++;
    });
    this.readingHistory.initialize().catch((): void => {});
    this.storySeries.initialize().catch((): void => {});
    for (let index: number = 0; index < this.scrollers.length; index++) {
      this.tabsController.bindScroller(index, this.scrollers[index]);
    }
    this.pageStack.setInterception({
      willShow: (): void => {
        this.syncNavigationStackState();
      },
      didShow: (): void => {
        this.syncNavigationStackState();
      }
    });
    this.syncNavigationStackState();
  }

  aboutToDisappear(): void {
    this.readingHistoryUnsubscribe?.();
    this.readingHistoryUnsubscribe = undefined;
    this.storySeriesUnsubscribe?.();
    this.storySeriesUnsubscribe = undefined;
    for (let index: number = 0; index < this.scrollers.length; index++) {
      this.tabsController.unbindScroller(this.scrollers[index]);
    }
    // These ViewModels are screen-scoped; release subscriptions and in-flight
    // work when the root page itself is destroyed. Shared settings/library VMs
    // remain owned by AppContainer and are intentionally not disposed here.
    this.exploreViewModel.dispose();
    this.catalogViewModel.dispose();
    this.taleListViewModel.dispose();
    this.terminalViewModel.dispose();
  }

  private topRouteSupportsDetailFullscreen(): boolean {
    const names = this.pageStack.getAllPathName();
    if (names.length === 0) {
      return false;
    }
    const topRoute = names[names.length - 1];
    return topRoute === AppRoutes.ARTICLE || topRoute === AppRoutes.ARCHIVE_3D;
  }

  private syncNavigationStackState(): void {
    const nextDepth = this.pageStack.size();
    if (nextDepth === 0 || !this.topRouteSupportsDetailFullscreen()) {
      setDetailFullscreen(false);
      setPreviewFullscreen(false);
    }
    this.stackDepth = nextDepth;
    this.syncSplitActiveState();
  }

  private shouldUseSplitMode(): boolean {
    const revision = navigationStackRevision();
    const activeDepth = this.pageStack.size();
    return revision >= 0 && (activeDepth > 0 && (this.stackDepth > 0 || activeDepth > 0)) &&
      supportsSplitNavigation(windowWidthVp());
  }

  private shouldHideNavBar(): boolean {
    return this.shouldUseSplitMode() &&
      this.topRouteSupportsDetailFullscreen() &&
      (isDetailFullscreen() || isPreviewFullscreen());
  }

  private isSplitNavBarVisible(): boolean {
    return this.shouldUseSplitMode() && !this.shouldHideNavBar();
  }

  private syncSplitActiveState(): void {
    setSplitNavigationActive(this.isSplitNavBarVisible());
  }

  private toolbarHorizontalMargin(): number {
    const measuredWidth = this.navPaneWidth > 0 ? this.navPaneWidth :
      (this.isSplitNavBarVisible() ? SPLIT_NAV_BAR_WIDTH : windowWidthVp());
    return adaptivePageMarginForWidth(measuredWidth);
  }

  /** 图鉴搜索：点击标题栏菜单搜索图标，大屏自动进入分栏，手机端全屏推入。 */
  private openCatalogSearchMenu(): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    AppNavigationCoordinator.openFromMaster(
      this.pageStack,
      AppRoutes.SEARCH,
      undefined,
      this.shouldUseSplitMode()
    );
  }

  private openSettings(): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    AppNavigationCoordinator.openFromMaster(
      this.pageStack,
      AppRoutes.SETTINGS,
      undefined,
      this.shouldUseSplitMode()
    );
  }

  private openArchive3DGallery(): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    AppNavigationCoordinator.openFromMaster(
      this.pageStack,
      AppRoutes.ARCHIVE_3D_GALLERY,
      undefined,
      this.shouldUseSplitMode()
    );
  }

  private openContent(content: LibraryContentRef, seriesId: string = ''): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    const params: ScpArticleRouteParams = seriesId.length > 0 ?
      { content: content, seriesId: seriesId } :
      { content: content };
    AppNavigationCoordinator.openFromMaster(
      this.pageStack,
      AppRoutes.ARTICLE,
      params,
      this.shouldUseSplitMode()
    );
  }

  private shouldShowStarterGuide(): boolean {
    return this.completionRevision >= 0 &&
      this.seriesRevision >= 0 &&
      this.readingHistory.initialized &&
      this.storySeries.initialized &&
      !this.settings.starterGuideDismissed &&
      this.readingHistory.items.length === 0 &&
      this.readingHistory.completedCount === 0 &&
      this.storySeries.enrolledCount === 0;
  }

  private dismissStarterGuide(): void {
    this.settings.setStarterGuideDismissed(true);
  }

  private openStarterManual(): void {
    this.openContent(createLibraryContentRef(
      LibraryContentKind.KNOWLEDGE,
      'about-the-scp-foundation',
      '关于 SCP 基金会'
    ));
  }

  private openStarterSeries(): void {
    this.openContent(createLibraryContentRef(
      LibraryContentKind.TALE,
      ANTIMEMETICS_HUB_ID,
      '逆模因部'
    ));
  }

  private featuredSeriesCards(): TaleFeaturedSeriesCard[] {
    if (this.seriesRevision < 0 || this.completionRevision < 0) {
      return [];
    }
    const snapshots: StorySeriesProgressSnapshot[] = this.storySeries.listProgressSnapshots();
    const cards: TaleFeaturedSeriesCard[] = [];
    for (let index: number = 0; index < snapshots.length; index++) {
      const snapshot = snapshots[index];
      const active = snapshot.enrolled || snapshot.mainlineCompleted > 0;
      const resumeTitle = snapshot.resumeEntry !== undefined ? snapshot.resumeEntry.title : '跟读';
      cards.push({
        seriesId: snapshot.series.id,
        hubId: snapshot.series.hubId,
        title: snapshot.series.title,
        subtitle: snapshot.series.subtitle,
        description: snapshot.series.description,
        progressLabel: active ?
          `主线 ${snapshot.mainlineCompleted}/${snapshot.mainlineTotal}` :
          `主线 ${snapshot.mainlineTotal} 篇`,
        actionLabel: active ? `继续 · ${resumeTitle}` : '开始跟读',
        enrolled: active
      });
    }
    return cards;
  }

  private async startFeaturedSeries(seriesId: string): Promise<void> {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    try {
      const entry = await this.storySeries.startSeries(seriesId);
      if (entry !== undefined) {
        this.openContent(entry.toContentRef(), seriesId);
      }
    } catch (_error) {
    }
  }

  private resolveMotionState(info: NavContentInfo): DestinationMotionState | undefined {
    if (info.index < 0) {
      return this.navBarMotion;
    }
    return NavigationTransitionRegistry.get(info.navDestinationId);
  }

  private resetTransitionParticipants(
    fromInfo: NavContentInfo,
    toInfo: NavContentInfo
  ): void {
    this.resolveMotionState(fromInfo)?.reset();
    this.resolveMotionState(toInfo)?.reset();
    this.navBarMotion.reset();
  }

  private buildAnimatedTransition(
    from: NavContentInfo,
    to: NavContentInfo,
    timeout: number,
    animateParamFactory: (onFinish: () => void) => AnimateParam,
    onSetupFrameZero: (
      fromState: DestinationMotionState | undefined,
      toState: DestinationMotionState
    ) => boolean,
    onAnimateTarget: (
      fromState: DestinationMotionState | undefined,
      toState: DestinationMotionState
    ) => void
  ): NavigationAnimatedTransition {
    let activeFrom: NavContentInfo = from;
    let activeTo: NavContentInfo = to;
    return {
      timeout: timeout,
      onTransitionEnd: (_success: boolean): void => {
        this.resetTransitionParticipants(activeFrom, activeTo);
      },
      transition: (transitionProxy: NavigationTransitionProxy): void => {
        activeFrom = transitionProxy.from;
        activeTo = transitionProxy.to;
        const fromState = this.resolveMotionState(activeFrom);
        const toState = this.resolveMotionState(activeTo);
        if (toState === undefined || !onSetupFrameZero(fromState, toState)) {
          this.resetTransitionParticipants(activeFrom, activeTo);
          transitionProxy.finishTransition();
          return;
        }
        let finished: boolean = false;
        const complete = (): void => {
          if (finished) {
            return;
          }
          finished = true;
          this.resetTransitionParticipants(activeFrom, activeTo);
          transitionProxy.finishTransition();
        };
        this.getUIContext().animateTo(animateParamFactory(complete), (): void => {
          onAnimateTarget(fromState, toState);
        });
      }
    };
  }

  private resolveNavTransition(
    from: NavContentInfo,
    to: NavContentInfo,
    operation: NavigationOperation
  ): NavigationAnimatedTransition | undefined {
    if (isReduceMotionEnabled()) {
      return undefined;
    }
    // Case A: Split mode master replacement cross-slide/fade.
    if (operation === NavigationOperation.REPLACE && from.index >= 0 && to.index >= 0) {
      return this.buildAnimatedTransition(
        from,
        to,
        360,
        (onFinish: () => void): AnimateParam => AppMotion.springAnimateParam(true, onFinish),
        (fromState: DestinationMotionState | undefined, toState: DestinationMotionState): boolean => {
          toState.opacity = 0;
          toState.translateX = 16;
          if (fromState !== undefined) {
            fromState.opacity = 1;
            fromState.translateX = 0;
          }
          return true;
        },
        (fromState: DestinationMotionState | undefined, toState: DestinationMotionState): void => {
          toState.opacity = 1;
          toState.translateX = 0;
          if (fromState !== undefined) {
            fromState.opacity = 0;
            fromState.translateX = -8;
          }
        }
      );
    }

    if (supportsSplitNavigation(windowWidthVp())) {
      return undefined;
    }

    // Single-screen Search light rise-fade (PUSH / POP).
    if (operation === NavigationOperation.PUSH && to.name === AppRoutes.SEARCH) {
      return this.buildAnimatedTransition(
        from,
        to,
        320,
        (onFinish: () => void): AnimateParam => AppMotion.springAnimateParam(false, onFinish),
        (fromState: DestinationMotionState | undefined, toState: DestinationMotionState): boolean => {
          toState.opacity = 0;
          toState.translateY = 18;
          toState.scaleX = 0.985;
          toState.scaleY = 0.985;
          if (fromState !== undefined) {
            fromState.opacity = 1;
          }
          return true;
        },
        (fromState: DestinationMotionState | undefined, toState: DestinationMotionState): void => {
          toState.opacity = 1;
          toState.translateY = 0;
          toState.scaleX = 1;
          toState.scaleY = 1;
          if (fromState !== undefined) {
            fromState.opacity = 0.94;
          }
        }
      );
    }

    if (operation === NavigationOperation.POP && from.name === AppRoutes.SEARCH) {
      return this.buildAnimatedTransition(
        from,
        to,
        280,
        (onFinish: () => void): AnimateParam => ({
          duration: AppMotion.MICRO_DURATION,
          curve: Curve.FastOutSlowIn,
          onFinish: onFinish
        }),
        (fromState: DestinationMotionState | undefined, toState: DestinationMotionState): boolean => {
          if (fromState === undefined) {
            return false;
          }
          fromState.reset();
          toState.opacity = 0.94;
          return true;
        },
        (fromState: DestinationMotionState | undefined, toState: DestinationMotionState): void => {
          if (fromState !== undefined) {
            fromState.opacity = 0;
            fromState.translateY = 14;
            fromState.scaleX = 0.985;
            fromState.scaleY = 0.985;
          }
          toState.opacity = 1;
        }
      );
    }
    return undefined;
  }

  private isReadCompleted(contentId: string): boolean {
    return this.readingHistory.isCompleted(contentId);
  }

  private openLibraryCollection(mode: LibraryCollectionMode): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    const params: LibraryCollectionRouteParams = { mode: mode };
    AppNavigationCoordinator.openFromMaster(
      this.pageStack,
      AppRoutes.LIBRARY_COLLECTION,
      params,
      this.shouldUseSplitMode()
    );
  }

  private openExploreCollection(mode: ExploreCollectionMode): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    const params: ExploreCollectionRouteParams = { mode: mode };
    AppNavigationCoordinator.openFromMaster(
      this.pageStack,
      AppRoutes.EXPLORE_COLLECTION,
      params,
      this.shouldUseSplitMode()
    );
  }

  private openAssessment(examId: string): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    const params: FoundationAssessmentRouteParams = { examId: examId };
    AppNavigationCoordinator.openFromMaster(
      this.pageStack,
      AppRoutes.ASSESSMENT,
      params,
      this.shouldUseSplitMode()
    );
  }

  private createTabBarStyle(item: TabItem): BottomTabBarStyle {
    const icon: TabBarSymbol = {
      normal: new SymbolGlyphModifier(item.iconNormal),
      selected: new SymbolGlyphModifier(item.iconSelected)
    };
    return new BottomTabBarStyle(icon, item.title);
  }

  /** 当前 Tab 是否有标题栏底部工具栏。 */
  private hasToolbar(): boolean {
    return this.titleTabIndex === HomeTabId.CATALOG || this.titleTabIndex === HomeTabId.STORY;
  }

  /** 工具栏高度：图鉴分支切换+系列 chips 行 86vp；故事搜索框+字母索引 88vp。 */
  private toolbarHeight(): number {
    if (this.titleTabIndex === HomeTabId.CATALOG) {
      return CATALOG_TOOLBAR_HEIGHT;
    }
    if (this.titleTabIndex === HomeTabId.STORY) {
      return TALE_FILTER_BAR_HEIGHT;
    }
    return 0;
  }

  /** 图鉴 Tab 工具栏：切换主站译文 / 中文原创，并在下行用原生 ChipGroupV2 切换系列。 */
  @Builder
  private catalogToolbar() {
    CatalogBranchSeriesBar({
      branch: this.searchState.branch,
      selectedSeriesId: this.searchState.seriesId,
      materialEnabled: this.settings.immersiveMaterialEnabled,
      horizontalMargin: this.toolbarHorizontalMargin(),
      onSelectBranch: (branch: ScpCatalogBranch) => {
        this.hapticService.playSelection(this.settings.hapticEnabled);
        this.searchState.clear();
        this.searchState.selectBranch(branch);
      },
      onSelectSeries: (seriesId: string) => {
        this.hapticService.playSelection(this.settings.hapticEnabled);
        this.searchState.clear();
        this.searchState.setSeriesId(seriesId);
      }
    })
  }

  /** 标题栏底部工具栏内容：按当前 Tab 分发。 */
  @Builder
  private toolbarBuilder() {
    if (this.titleTabIndex === HomeTabId.CATALOG) {
      Column() {
        this.catalogToolbar()
      }
      .width('100%')
      .transition(AppMotion.fadeTransition(AppMotion.MICRO_DURATION))
    } else if (this.titleTabIndex === HomeTabId.STORY) {
      Column() {
        StoryFilterBar({
          state: this.taleFilterState,
          hapticEnabled: this.settings.hapticEnabled,
          materialEnabled: this.settings.immersiveMaterialEnabled,
          horizontalMargin: this.toolbarHorizontalMargin(),
          onHaptic: (enabled: boolean) => this.hapticService.playSelection(enabled)
        })
      }
      .width('100%')
      .transition(AppMotion.fadeTransition(AppMotion.MICRO_DURATION))
    }
  }

  build() {
    HdsNavigation(this.pageStack) {
      HdsTabs({
        index: this.tabsViewModel.currentIndex,
        controller: this.tabsController
      }) {
        ForEach(this.tabsViewModel.items, (item: TabItem) => {
          TabContent() {
            Column() {
              if (item.id === HomeTabId.EXPLORE) {
                ExploreHome({
                  scroller: this.scrollers[item.id],
                  viewModel: this.exploreViewModel,
                  materialEnabled: this.settings.immersiveMaterialEnabled,
                  active: this.tabsViewModel.currentIndex === HomeTabId.EXPLORE,
                  recommendationSkeletonAnimated: this.exploreSkeletonAnimated,
                  showStarterGuide: this.shouldShowStarterGuide(),
                  onDismissStarterGuide: () => this.dismissStarterGuide(),
                  onOpenStarterManual: () => this.openStarterManual(),
                  onOpenStarterSeries: () => this.openStarterSeries(),
                  onOpenContent: (content: LibraryContentRef) => this.openContent(content),
                  onOpenCollection: (mode: ExploreCollectionMode) => this.openExploreCollection(mode),
                  onSelection: () => this.hapticService.playSelection(this.settings.hapticEnabled),
                  onHeroAnchorChange: (anchor: ExploreHeroAnchor): void =>
                    this.onExploreHeroAnchorChange(anchor)
                })
              } else if (item.id === HomeTabId.CATALOG) {
                ScpCatalogHome({
                  scroller: this.scrollers[item.id],
                  viewModel: this.catalogViewModel,
                  active: this.tabsViewModel.currentIndex === HomeTabId.CATALOG,
                  resolveLocalPreviewSource: resolveCatalogPreviewFileSource,
                  previewLoader: (itemId: string,
                    onRefreshed?: (preview: CatalogPreview) => void,
                    forceRefresh: boolean = false): Promise<CatalogPreview> =>
                    this.catalogViewModel.loadPreview(itemId, onRefreshed, forceRefresh),
                  onOpenArticle: (itemId: string, name: string) => this.openContent(
                    createLibraryContentRef(LibraryContentKind.SCP, itemId, name)
                  ),
                  has3DModel: (itemId: string): boolean => hasScp3DModel(itemId),
                  isReadCompleted: (itemId: string): boolean => this.isReadCompleted(itemId),
                  completionRevision: this.completionRevision
                })
              } else if (item.id === HomeTabId.FOUNDATION) {
                FoundationHome({
                  scroller: this.scrollers[item.id],
                  assessments: this.foundationAssessments,
                  settings: this.settings,
                  active: this.tabsViewModel.currentIndex === HomeTabId.FOUNDATION,
                  onOpenContent: (content: LibraryContentRef) => this.openContent(content),
                  onStartAssessment: (examId: string) => this.openAssessment(examId)
                })
              } else if (item.id === HomeTabId.STORY) {
                TaleList({
                  scroller: this.scrollers[item.id],
                  viewModel: this.taleListViewModel,
                  active: this.tabsViewModel.currentIndex === HomeTabId.STORY,
                  filterState: this.taleFilterState,
                  onOpenTale: (id: string, name: string) => this.openContent(
                    createLibraryContentRef(LibraryContentKind.TALE, id, name)
                  ),
                  isReadCompleted: (id: string): boolean => this.isReadCompleted(id),
                  completionRevision: this.completionRevision,
                  materialEnabled: this.settings.immersiveMaterialEnabled,
                  featuredSeries: this.featuredSeriesCards(),
                  seriesRevision: this.seriesRevision,
                  onOpenFeaturedSeriesHub: (hubId: string, title: string) => this.openContent(
                    createLibraryContentRef(LibraryContentKind.TALE, hubId, title)
                  ),
                  onStartFeaturedSeries: (seriesId: string) => {
                    this.startFeaturedSeries(seriesId);
                  }
                })
              } else if (item.id === HomeTabId.TERMINAL) {
                TerminalHome({
                  scroller: this.scrollers[item.id],
                  viewModel: this.terminalViewModel,
                  settings: this.settings,
                  active: this.tabsViewModel.currentIndex === HomeTabId.TERMINAL,
                  onOpenContent: (content: LibraryContentRef) => this.openContent(content),
                  onResumeSeries: (seriesId: string, content: LibraryContentRef) =>
                    this.openContent(content, seriesId),
                  onOpenSeriesHub: (hubId: string, title: string) => this.openContent(
                    createLibraryContentRef(LibraryContentKind.TALE, hubId, title)
                  ),
                  onOpenAssessment: (examId: string) => this.openAssessment(examId),
                  onOpenCollection: (mode: LibraryCollectionMode) => this.openLibraryCollection(mode),
                  onOpenArchive3DGallery: () => this.openArchive3DGallery(),
                  onOpenSettings: () => this.openSettings()
                })
              }
            }
            .width('100%')
            .height('100%')
            .opacity(this.tabContentOpacity)
            .translate({ y: this.tabContentOffsetY })
          }
          .tabBar(this.createTabBarStyle(item))
        }, (item: TabItem) => item.id.toString())
      }
      .scrollable(false)
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .vertical(false)
      // HDS 原生属性：0 关闭点击页签时的 TabContent 横向切换动画。
      .animationDuration(0)
      .barFloatingStyle({
        barWidth: this.isSplitNavBarVisible() ?
          { smallWidth: 300, mediumWidth: 320, largeWidth: 332 } :
          { smallWidth: 316, mediumWidth: 396, largeWidth: 460 },
        barBottomMargin: 28,
        gradientMask: {
          maskColor: $r('sys.color.background_secondary'),
          maskHeight: 92
        },
        systemMaterialEffect: {
          materialType: this.settings.immersiveMaterialEnabled && immersiveMaterialSupported() ?
            hdsMaterial.MaterialType.IMMERSIVE : hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      })
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        const measuredWidth = Number(newArea.width);
        if (Number.isFinite(measuredWidth) && measuredWidth > 0) {
          this.navPaneWidth = measuredWidth;
        }
      })
      .onSelected((index: number) => {
        if (index >= 0 && index < this.tabsViewModel.items.length) {
          this.titleTabIndex = index;
        }
      })
      .onChange((index: number) => {
        if (this.tabsViewModel.select(index)) {
          this.hapticService.playSelection(this.settings.hapticEnabled);
          if (isReduceMotionEnabled()) {
            this.tabContentOpacity = 1;
            this.tabContentOffsetY = 0;
            return;
          }
          this.tabContentOpacity = 0.86;
          this.tabContentOffsetY = 8;
          this.getUIContext().animateTo(AppMotion.springAnimateParam(true), (): void => {
            this.tabContentOpacity = 1;
            this.tabContentOffsetY = 0;
          });
        }
      })
      .opacity(this.navBarMotion.opacity)
    }
    .customNavContentTransition((
      from: NavContentInfo,
      to: NavContentInfo,
      operation: NavigationOperation
    ): NavigationAnimatedTransition | undefined =>
      this.resolveNavTransition(from, to, operation))
    // Full-screen tabs at home; Switch to Split when a detail page is pushed on LG+ windows.
    .mode(this.shouldUseSplitMode() ? NavigationMode.Split : NavigationMode.Stack)
    .hideNavBar(this.shouldHideNavBar())
    .navBarWidth(SPLIT_NAV_BAR_WIDTH)
    .navBarWidthRange({
      minWidth: SPLIT_NAV_BAR_MIN_WIDTH,
      maxWidth: SPLIT_NAV_BAR_MAX_WIDTH
    })
    .minContentWidth(SPLIT_CONTENT_MIN_WIDTH)
    .divider({ color: $r('sys.color.comp_divider') })
    .onNavigationModeChange((mode: NavigationMode): void => {
      setSplitNavigationActive(mode === NavigationMode.Split && !this.shouldHideNavBar());
    })
    .onNavBarStateChange((visible: boolean): void => {
      setSplitNavigationActive(this.shouldUseSplitMode() && visible);
    })
    .titleBar({
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false,
      content: {
        title: {
          mainTitle: this.tabsViewModel.items[this.titleTabIndex].title
        },
        menu: this.tabsViewModel.items[this.titleTabIndex].menu,
        // 图鉴系列 chips / 故事搜索框+字母索引；滚动隐藏标题时保持吸顶。
        bottomBuilder: this.hasToolbar() ? {
          builder: (): void => this.toolbarBuilder(),
          height: this.toolbarHeight()
        } : undefined
      },
      style: createAppTitleBarStyle(this.settings.immersiveMaterialEnabled),
    })
    // 官方不建议多个可滚动容器同时驱动同一导航栏：隐藏 Tab 的顶部/底部状态
    // 会打断当前页面的显隐动画。这里只绑定当前可见 Tab。
    .bindToScrollable([this.scrollers[this.tabsViewModel.currentIndex]])
    // MINI 标题栏在宽屏首页保持常驻以免右上角入口滚出视线；窄屏与分栏左栏随滚动隐藏。
    .dynamicHideTitleBar({
      hideTitleArea: !(isLargeWindow() && !this.isSplitNavBarVisible()),
      hideBottomBuilder: false,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP,
      hideRatio: 1.5
    })
    .hideBackButton(true)
    .titleMode(HdsNavigationTitleMode.MINI)
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
