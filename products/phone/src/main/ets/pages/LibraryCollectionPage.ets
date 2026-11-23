import {
  HideMode,
  HdsNavDestination,
  HdsNavDestinationTitleMode
} from '@kit.UIDesignKit';
import {
  LibraryCollectionMode,
  LibraryCollectionView,
  LibraryCollectionVM,
  LibraryContentRef
} from 'library';
import { createAppBackIcon, createAppTitleBarStyle, popNavigationDestination } from 'anomiconbasic';
import {
  AppRoutes,
  ScpArticleRouteParams
} from '../navigation/AppRoutes';
import { parseLibraryCollectionRoute } from '../navigation/RouteParamAdapters';
import { AppNavigationCoordinator } from '../navigation/AppNavigationCoordinator';

/** Product route adapter supplies an already-assembled screen ViewModel. */
@Builder
export function LibraryCollectionPageBuilder(viewModel: LibraryCollectionVM) {
  LibraryCollectionPage({ viewModel: viewModel });
}

/**
 * Phone-only navigation host.
 *
 * The feature owns the list UI. This shell alone sees NavPathStack and raw
 * route payloads, normalizes the route, and maps feature events to product
 * navigation effects.
 */
@ComponentV2
struct LibraryCollectionPage {
  @Require @Param viewModel: LibraryCollectionVM;

  private pageStack: NavPathStack | undefined = undefined;
  private readonly scroller: Scroller = new Scroller();
  private routeResolved: boolean = false;

  aboutToDisappear(): void {
    this.viewModel.dispose();
  }

  private pageTitle(): string {
    const mode = this.viewModel.snapshot.data?.mode ?? LibraryCollectionMode.RECENT;
    switch (mode) {
      case LibraryCollectionMode.FAVORITES:
        return '全部收藏';
      case LibraryCollectionMode.CONTINUE_READING:
        return '继续阅读';
      default:
        return '最近浏览';
    }
  }

  private resolveRoute(param: Object | null | undefined): void {
    const route = parseLibraryCollectionRoute(param);
    this.viewModel.setRouteMode(route?.mode);
  }

  private openContent(content: LibraryContentRef): void {
    const params: ScpArticleRouteParams = { content: content };
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.ARTICLE, params);
  }

  build() {
    HdsNavDestination() {
      LibraryCollectionView({
        viewModel: this.viewModel,
        scroller: this.scroller,
        onOpenContent: (content: LibraryContentRef): void => this.openContent(content)
      });
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false,
      content: {
        title: { mainTitle: this.pageTitle() },
        backIcon: createAppBackIcon('libraryCollectionBackButton', (): void => {
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
      this.resolveRoute(context.pathInfo.param as Object | null | undefined);
      this.routeResolved = true;
      this.viewModel.activate();
    })
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
    );
  }
}
