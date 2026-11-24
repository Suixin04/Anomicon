/** Phone product entry shell; all feature UI is composed below this boundary. */
import { MainTabIndex } from './MainTabIndex';
import { AppContainer } from '../composition/AppContainer';
import { HapticFeedbackPort, popNavigationDestination } from 'anomiconbasic';
import { ExploreHeroAnchor, ExploreHomeViewModel } from 'explore';
import { CatalogViewModel, TaleListViewModel } from 'catalog';
import { TerminalViewModel } from 'terminal';
import { ReadingHistoryViewModel, StorySeriesViewModel } from 'library';
import { SettingsViewModel } from 'settings';
import { StartupCoordinator } from '../startup/StartupCoordinator';
import { StartupOverlay } from '../startup/StartupOverlay';

@Entry
@ComponentV2
struct PhoneIndex {
  // The entry is the product composition boundary.  Child Views receive
  // already-assembled capabilities and never resolve the singleton itself.
  @Local private settings: SettingsViewModel = AppContainer.getInstance().settings();
  @Local private hapticService: HapticFeedbackPort =
    AppContainer.getInstance().createHapticFeedback();
  @Local private exploreViewModel: ExploreHomeViewModel =
    AppContainer.getInstance().createExploreHomeViewModel();
  @Local private catalogViewModel: CatalogViewModel =
    AppContainer.getInstance().createCatalogViewModel();
  @Local private taleListViewModel: TaleListViewModel =
    AppContainer.getInstance().createTaleListViewModel();
  @Local private terminalViewModel: TerminalViewModel =
    AppContainer.getInstance().createTerminalViewModel();
  @Local private readingHistory: ReadingHistoryViewModel =
    AppContainer.getInstance().readingHistory();
  @Local private storySeries: StorySeriesViewModel =
    AppContainer.getInstance().storySeries();
  @Local private startupCoordinator: StartupCoordinator = new StartupCoordinator();
  private readonly pageStack: NavPathStack = new NavPathStack();

  aboutToDisappear(): void {
    this.startupCoordinator.dispose();
  }

  onBackPress(): boolean {
    if (this.pageStack.size() > 0) {
      return popNavigationDestination(this.pageStack);
    }
    return false;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      MainTabIndex({
        pageStack: this.pageStack,
        settings: this.settings,
        hapticService: this.hapticService,
        exploreViewModel: this.exploreViewModel,
        catalogViewModel: this.catalogViewModel,
        taleListViewModel: this.taleListViewModel,
        terminalViewModel: this.terminalViewModel,
        readingHistory: this.readingHistory,
        storySeries: this.storySeries,
        exploreSkeletonAnimated: this.startupCoordinator.homeSkeletonAnimated,
        onExploreHeroAnchorChange: (anchor: ExploreHeroAnchor): void =>
          this.startupCoordinator.updateHeroAnchor(anchor)
      });

      if (this.startupCoordinator.visible) {
        StartupOverlay({
          coordinator: this.startupCoordinator,
          themeMode: this.settings.themeMode
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'));
  }
}
