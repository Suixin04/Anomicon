import {
  HideMode,
  HdsNavDestination,
  HdsNavDestinationTitleMode
} from '@kit.UIDesignKit';
import {
  ExploreCollectionMode,
  ExploreCollectionView,
  ExploreCollectionVM
} from 'explore';
import { LibraryContentRef } from 'library';
import {
  AppRoutes,
  ScpArticleRouteParams
} from '../navigation/AppRoutes';
import { parseExploreCollectionRoute } from '../navigation/RouteParamAdapters';
import { AppNavigationCoordinator } from '../navigation/AppNavigationCoordinator';
import {
  createAppBackIcon,
  createAppTitleBarStyle,
  DestinationMotionState,
  NavigationTransitionRegistry,
  popNavigationDestination
} from 'anomiconbasic';

@Builder
export function ExploreCollectionPageBuilder(viewModel: ExploreCollectionVM) {
  ExploreCollectionPage({
    viewModel: viewModel
  })
}

/**
 * Phone route host for the Explore collection.
 *
 * The product owns HDS navigation, untrusted route payloads and route effects;
 * Explore owns the screen content, lazy data source and rendering state.
 */
@ComponentV2
struct ExploreCollectionPage {
  @Require @Param viewModel: ExploreCollectionVM;
  private pageStack: NavPathStack | undefined = undefined;
  private navDestinationId: string = '';
  @Local private readonly navMotion: DestinationMotionState = new DestinationMotionState();
  private readonly scroller: Scroller = new Scroller();
  /** Route parameters must be validated before a screen-level load starts. */
  private routeResolved: boolean = false;

  aboutToDisappear(): void {
    NavigationTransitionRegistry.unregister(this.navDestinationId);
  }

  private pageTitle(): string {
    return this.viewModel.mode === ExploreCollectionMode.RECENT ? '最近更新' : '轻松一下';
  }

  private applyRouteParam(param: Object | null | undefined): void {
    const route = parseExploreCollectionRoute(param);
    if (route === undefined) {
      this.viewModel.setRouteMode(undefined);
      return;
    }
    this.viewModel.setRouteMode(route.mode);
  }

  private openContent(content: LibraryContentRef): void {
    const params: ScpArticleRouteParams = { content: content };
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.ARTICLE, params);
  }

  build() {
    HdsNavDestination() {
      ExploreCollectionView({
        viewModel: this.viewModel,
        scroller: this.scroller,
        onOpenContent: (content: LibraryContentRef) => this.openContent(content)
      })
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false,
      content: {
        title: { mainTitle: this.pageTitle() },
        backIcon: createAppBackIcon('exploreCollectionBackButton', (): void => {
          popNavigationDestination(this.pageStack);
        })
      },
      style: createAppTitleBarStyle()
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .backgroundColor($r('sys.color.background_secondary'))
    .bindToScrollable([this.scroller])
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP,
      hideRatio: 1.5
    })
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
      this.navDestinationId = context.navDestinationId ?? '';
      NavigationTransitionRegistry.register(this.navDestinationId, this.navMotion);
      this.applyRouteParam(context.pathInfo.param as Object | null | undefined);
      this.routeResolved = true;
      this.viewModel.activate();
    })
    .opacity(this.navMotion.opacity)
    .translate({ x: this.navMotion.translateX })
    .onActive(() => {
      if (this.routeResolved) {
        this.viewModel.activate();
      }
    })
    .onInactive(() => {
      this.viewModel.deactivate();
    })
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    )
  }
}
