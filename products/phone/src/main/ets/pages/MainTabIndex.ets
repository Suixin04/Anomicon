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
  ExploreHome,
  ExploreHomeViewModel,
  ExploreHeroAnchor
} from 'explore';
import {
  ScpCatalogHome,
  TaleList,
  StoryFilterBar,
  CatalogSeriesSelector,
  CATALOG_TOOLBAR_HEIGHT,
  ScpCatalogSearchState,
  sharedCatalogSearchState,
  TALE_FILTER_BAR_HEIGHT,
  TaleFilterState,
  CatalogPreview,
  CatalogViewModel,
  TaleListViewModel
} from 'catalog';
import {
  TerminalHome,
  TerminalViewModel
} from 'terminal';
import {
  LibraryContentKind,
  LibraryContentRef,
  createLibraryContentRef,
  ReadingHistoryViewModel
} from 'library';
import { HomeTabId, TabItem } from '../navigation/TabItem';
import { TabsViewModel } from '../navigation/TabsViewModel';
import {
  AppRoutes,
  ExploreCollectionMode,
  ExploreCollectionRouteParams,
  LibraryCollectionMode,
  LibraryCollectionRouteParams,
  ScpArticleRouteParams
} from '../navigation/AppRoutes';
import { AppNavigationCoordinator } from '../navigation/AppNavigationCoordinator';
import { createAppTitleBarStyle, immersiveMaterialSupported } from 'anomiconbasic';
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
  @Require @Param exploreSkeletonAnimated: boolean;
  @Event onExploreHeroAnchorChange: (anchor: ExploreHeroAnchor) => void;
  private pageStack: NavPathStack = new NavPathStack();
  /** 图鉴浏览状态：与独立搜索路由共享当前系列。 */
  @Local private searchState: ScpCatalogSearchState = sharedCatalogSearchState();
  /** 故事筛选只在首页会话内共享给筛选栏和列表。 */
  @Local private taleFilterState: TaleFilterState = new TaleFilterState();
  @Local private completionRevision: number = 0;
  private readingHistoryUnsubscribe: (() => void) | undefined = undefined;
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
    new Scroller()
  ];
  aboutToAppear(): void {
    this.readingHistoryUnsubscribe = this.readingHistory.subscribe((): void => {
      this.completionRevision++;
    });
    for (let index: number = 0; index < this.scrollers.length; index++) {
      this.tabsController.bindScroller(index, this.scrollers[index]);
    }
  }

  aboutToDisappear(): void {
    this.readingHistoryUnsubscribe?.();
    this.readingHistoryUnsubscribe = undefined;
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

  /** 图鉴搜索：点击标题栏菜单搜索图标，使用 Navigation 默认转场动画进入搜索页。 */
  private openCatalogSearchMenu(): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.SEARCH);
  }

  private openSettings(): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.SETTINGS);
  }

  private openArchive3DGallery(): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.ARCHIVE_3D_GALLERY);
  }

  private openContent(content: LibraryContentRef): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    const params: ScpArticleRouteParams = { content: content };
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.ARTICLE, params);
  }

  private isReadCompleted(contentId: string): boolean {
    const normalizedId = contentId.trim().toLowerCase();
    for (let index: number = 0; index < this.readingHistory.items.length; index++) {
      const entry = this.readingHistory.items[index];
      if (entry.completed && entry.content.id.trim().toLowerCase() === normalizedId) {
        return true;
      }
    }
    return false;
  }

  private openLibraryCollection(mode: LibraryCollectionMode): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    const params: LibraryCollectionRouteParams = { mode: mode };
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.LIBRARY_COLLECTION, params);
  }

  private openExploreCollection(mode: ExploreCollectionMode): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    const params: ExploreCollectionRouteParams = { mode: mode };
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.EXPLORE_COLLECTION, params);
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
    return this.tabsViewModel.currentIndex === HomeTabId.CATALOG ||
      this.tabsViewModel.currentIndex === HomeTabId.STORY;
  }

  /** 工具栏高度：图鉴 chips 行 48vp；故事搜索框+字母索引 88vp。 */
  private toolbarHeight(): number {
    if (this.tabsViewModel.currentIndex === HomeTabId.CATALOG) {
      return CATALOG_TOOLBAR_HEIGHT;
    }
    if (this.tabsViewModel.currentIndex === HomeTabId.STORY) {
      return TALE_FILTER_BAR_HEIGHT;
    }
    return 0;
  }

  /** 图鉴 Tab 工具栏：原生 ChipGroupV2 负责横滚、单选语义和状态反馈。 */
  @Builder
  private catalogToolbar() {
    CatalogSeriesSelector({
      selectedSeriesId: this.searchState.seriesId,
      onSelect: (seriesId: string) => {
        this.hapticService.playSelection(this.settings.hapticEnabled);
        this.searchState.clear();
        this.searchState.setSeriesId(seriesId);
      }
    })
  }

  /** 标题栏底部工具栏内容：按当前 Tab 分发。 */
  @Builder
  private toolbarBuilder() {
    if (this.tabsViewModel.currentIndex === HomeTabId.CATALOG) {
      this.catalogToolbar()
    } else if (this.tabsViewModel.currentIndex === HomeTabId.STORY) {
      StoryFilterBar({
        state: this.taleFilterState,
        hapticEnabled: this.settings.hapticEnabled,
        onHaptic: (enabled: boolean) => this.hapticService.playSelection(enabled)
      })
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
            if (item.id === HomeTabId.EXPLORE) {
              ExploreHome({
                scroller: this.scrollers[item.id],
                viewModel: this.exploreViewModel,
                materialEnabled: this.settings.immersiveMaterialEnabled,
                active: this.tabsViewModel.currentIndex === HomeTabId.EXPLORE,
                recommendationSkeletonAnimated: this.exploreSkeletonAnimated,
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
                completionRevision: this.completionRevision
              })
            } else if (item.id === HomeTabId.TERMINAL) {
              TerminalHome({
                scroller: this.scrollers[item.id],
                viewModel: this.terminalViewModel,
                settings: this.settings,
                active: this.tabsViewModel.currentIndex === HomeTabId.TERMINAL,
                onOpenContent: (content: LibraryContentRef) => this.openContent(content),
                onOpenCollection: (mode: LibraryCollectionMode) => this.openLibraryCollection(mode)
              })
            }
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
        barWidth: { smallWidth: 280, mediumWidth: 360, largeWidth: 420 },
        barBottomMargin: 28,
        gradientMask: {
          maskColor: $r('sys.color.comp_background_tertiary'),
          maskHeight: 92
        },
        systemMaterialEffect: {
          materialType: immersiveMaterialSupported() ?
            hdsMaterial.MaterialType.IMMERSIVE : hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      })
      .onChange((index: number) => {
        if (this.tabsViewModel.select(index)) {
          this.hapticService.playSelection(this.settings.hapticEnabled);
        }
      })
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false,
      content: {
        title: {
          mainTitle: this.tabsViewModel.currentTab.title
        },
        menu: this.tabsViewModel.currentTab.menu,
        // 标题栏底部工具栏：图鉴系列 chips / 故事搜索框+字母索引。
        // 随标题栏动态显隐一起上下移动（hideBottomBuilder: true）。
        bottomBuilder: this.hasToolbar() ? {
          builder: (): void => this.toolbarBuilder(),
          height: this.toolbarHeight()
        } : undefined
      },
      style: createAppTitleBarStyle(),
    })
    // 官方不建议多个可滚动容器同时驱动同一导航栏：隐藏 Tab 的顶部/底部状态
    // 会打断当前页面的显隐动画。这里只绑定当前可见 Tab。
    .bindToScrollable([this.scrollers[this.tabsViewModel.currentIndex]])
    // MINI 标题栏随滚动方向显隐；图鉴/故事的 bottomBuilder 作为筛选工具栏保持吸顶。
    .dynamicHideTitleBar({
      hideTitleArea: true,
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
