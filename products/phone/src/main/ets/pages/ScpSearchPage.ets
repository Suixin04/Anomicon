import { schedulingOptimization } from '@kit.FASTKit';
import {
  HideMode,
  HdsNavDestination,
  HdsNavDestinationTitleMode
} from '@kit.UIDesignKit';
import {
  CATALOG_SEARCH_HEADER_HEIGHT,
  CatalogSearchHeader,
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
import { createAppTitleBarStyle } from 'anomiconbasic';
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
  private readonly contentScroller: Scroller = new Scroller();
  private readonly searchLoadHint: FastPerformanceHintScope =
    new FastPerformanceHintScope(
      schedulingOptimization.SceneType.PAGE_LOAD,
      schedulingOptimization.DurationType.SHORT
    );
  private searchHintActive: boolean = false;
  @Local private readonly searchState: ScpCatalogSearchState = sharedCatalogSearchState();

  aboutToDisappear(): void {
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

  private openContent(itemId: string, title: string): void {
    const params: ScpArticleRouteParams = {
      content: createLibraryContentRef(LibraryContentKind.SCP, itemId, title)
    };
    // Push Article above Search so returning from Article preserves the
    // user's query, scope and filtered results.
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.ARTICLE, params);
  }

  @Builder
  private searchHeaderBuilder() {
    CatalogSearchHeader({
      viewModel: this.viewModel,
      sharedState: this.searchState,
      materialEnabled: this.settings?.immersiveMaterialEnabled ?? true
    });
  }

  build() {
    HdsNavDestination() {
      CatalogSearchView(new CatalogSearchViewInput(
        this.viewModel,
        this.contentScroller,
        this.searchState,
        (itemId: string, title: string): void => this.openContent(itemId, title),
        this.settings?.immersiveMaterialEnabled ?? true
      ));
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false,
      content: {
        title: { mainTitle: '搜索' },
        backIcon: { label: '返回', componentId: 'searchBackButton' },
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
    })
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
