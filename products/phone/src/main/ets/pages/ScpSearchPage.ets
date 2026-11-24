import { schedulingOptimization } from '@kit.FASTKit';
import {
  HideMode,
  HdsNavDestination,
  HdsNavDestinationTitleMode
} from '@kit.UIDesignKit';
import {
  CATALOG_SEARCH_HEADER_HEIGHT,
  CatalogSearchHeader,
  CatalogSearchSelection,
  CatalogSearchTargetKind,
  CatalogSearchView,
  CatalogSearchViewInput,
  CatalogSearchViewModel,
  ScpCatalogSearchState,
  sharedCatalogSearchState
} from 'catalog';
import {
  LibraryContentKind,
  createLibraryContentRef
} from 'library';
import {
  AppRoutes,
  ScpArticleRouteParams
} from '../navigation/AppRoutes';
import { AppNavigationCoordinator } from '../navigation/AppNavigationCoordinator';
import { FastPerformanceHintScope } from '../composition/FastPerformanceHints';
import {
  createAppBackIcon,
  createAppTitleBarStyle,
  DestinationMotionState,
  NavigationTransitionRegistry,
  popNavigationDestination
} from 'anomiconbasic';
import { SettingsViewModel } from 'settings';

@Builder
export function ScpSearchPageBuilder(
  viewModel: CatalogSearchViewModel,
  settings?: SettingsViewModel
) {
  ScpSearchPage({
    viewModel: viewModel,
    settings: settings
  });
}

/**
 * Phone route host for Catalog search.
 *
 * The Catalog HAR owns the complete search content and ViewModel projection;
 * this product seam owns the HDS destination, app-scoped search-state binding,
 * NavPathStack and the push-to-Article navigation.
 */
@ComponentV2
struct ScpSearchPage {
  @Require @Param viewModel: CatalogSearchViewModel;
  @Param settings: SettingsViewModel | undefined = undefined;
  private pageStack: NavPathStack | undefined = undefined;
  private navDestinationId: string = '';
  @Local private readonly navMotion: DestinationMotionState = new DestinationMotionState();
  private readonly contentScroller: Scroller = new Scroller();
  private readonly searchLoadHint: FastPerformanceHintScope =
    new FastPerformanceHintScope(
      schedulingOptimization.SceneType.PAGE_LOAD,
      schedulingOptimization.DurationType.SHORT
    );
  private searchHintActive: boolean = false;
  @Local private readonly searchState: ScpCatalogSearchState = sharedCatalogSearchState();

  aboutToDisappear(): void {
    NavigationTransitionRegistry.unregister(this.navDestinationId);
    this.syncSearchLoadHint(false);
  }

  @Monitor('viewModel.allSeriesLoading')
  onAllSeriesLoadingChanged(): void {
    this.syncSearchLoadHint(this.viewModel.allSeriesLoading);
  }

  private syncSearchLoadHint(active: boolean): void {
    if (active) {
      if (!this.searchHintActive) {
        this.searchHintActive = true;
        this.searchLoadHint.begin();
      }
    } else if (this.searchHintActive) {
      this.searchHintActive = false;
      this.searchLoadHint.end();
    }
  }

  private openContent(selection: CatalogSearchSelection): void {
    const kind = selection.kind === CatalogSearchTargetKind.TALE ?
      LibraryContentKind.TALE : LibraryContentKind.SCP;
    const content = createLibraryContentRef(kind, selection.itemId, selection.title);
    const params: ScpArticleRouteParams = selection.anchor !== undefined && selection.anchor.length > 0 ?
      { content: content, anchor: selection.anchor } :
      { content: content };
    // Push Article above Search so returning from Article preserves the
    // user's query, scope and filtered results.
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.ARTICLE, params);
  }

  @Builder
  private searchHeaderBuilder() {
    CatalogSearchHeader({
      viewModel: this.viewModel,
      sharedState: this.searchState,
      materialEnabled: this.settings?.immersiveMaterialEnabled ?? true,
      onSubmitSelection: (selection: CatalogSearchSelection): void => this.openContent(selection)
    });
  }

  build() {
    HdsNavDestination() {
      CatalogSearchView(new CatalogSearchViewInput(
        this.viewModel,
        this.contentScroller,
        this.searchState,
        (selection: CatalogSearchSelection): void => this.openContent(selection),
        this.settings?.immersiveMaterialEnabled ?? true
      ));
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false,
      content: {
        title: { mainTitle: '搜索' },
        backIcon: createAppBackIcon('searchBackButton', (): void => {
          popNavigationDestination(this.pageStack, (): void => {
            this.searchState.clear();
          });
        }),
        bottomBuilder: {
          builder: (): void => this.searchHeaderBuilder(),
          height: CATALOG_SEARCH_HEADER_HEIGHT
        }
      },
      style: createAppTitleBarStyle(this.settings?.immersiveMaterialEnabled ?? true)
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .backgroundColor($r('sys.color.background_secondary'))
    .bindToScrollable([this.contentScroller])
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideBottomBuilder: false,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP,
      hideRatio: 1.5
    })
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
      this.navDestinationId = context.navDestinationId ?? '';
      NavigationTransitionRegistry.register(this.navDestinationId, this.navMotion);
    })
    .opacity(this.navMotion.opacity)
    .translate({ x: this.navMotion.translateX, y: this.navMotion.translateY })
    .scale({ x: this.navMotion.scaleX, y: this.navMotion.scaleY })
    .onActive(() => {
      this.viewModel.activate();
      this.syncSearchLoadHint(this.viewModel.allSeriesLoading);
    })
    .onInactive(() => {
      this.syncSearchLoadHint(false);
      this.viewModel.deactivate();
    })
    .onBackPressed(() => {
      this.searchState.clear();
      return false;
    })
    .onWillDisappear(() => {
      this.syncSearchLoadHint(false);
      this.searchState.clear();
    })
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    );
  }
}
