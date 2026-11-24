import {
  StartupCoordinator,
  SYSTEM_START_MARK_PX
} from './StartupCoordinator';
import { ExploreRecommendationSkeleton } from 'explore';
import { ThemeMode } from 'settings';

/**
 * First-page continuation of the system Starting Window.
 *
 * This component owns visuals only. It never waits for repositories, network,
 * routes, or feature state, so the real home page can be laid out underneath.
 */
@ComponentV2
export struct StartupOverlay {
  @Require @Param coordinator: StartupCoordinator;
  @Param themeMode: ThemeMode = ThemeMode.SYSTEM;

  private backdropColor(): ResourceColor {
    if (this.themeMode === ThemeMode.DARK) {
      return '#000000';
    }
    if (this.themeMode === ThemeMode.LIGHT) {
      return '#F1F3F5';
    }
    return $r('app.color.start_window_background');
  }

  private markSize(): number {
    return this.getUIContext().px2vp(SYSTEM_START_MARK_PX);
  }

  @Builder
  private brandMark() {
    Stack({ alignContent: Alignment.Center }) {
      Image($r('app.media.startup_cube'))
        .width(this.markSize())
        .height(this.markSize())
        .objectFit(ImageFit.Contain)
        .opacity(this.coordinator.cubeOpacity)
        .scale({
          x: this.coordinator.cubeScale,
          y: this.coordinator.cubeScale
        })

      Image($r('app.media.startup_branch_primary'))
        .width(this.markSize())
        .height(this.markSize())
        .objectFit(ImageFit.Contain)
        .opacity(this.coordinator.branchOpacity)
        .scale({
          x: this.coordinator.branchScale,
          y: this.coordinator.branchScale
        })
        .translate({
          x: this.coordinator.primaryOffsetX,
          y: this.coordinator.primaryOffsetY
        })

      Image($r('app.media.startup_branch_accent'))
        .width(this.markSize())
        .height(this.markSize())
        .objectFit(ImageFit.Contain)
        .opacity(this.coordinator.branchOpacity)
        .scale({
          x: this.coordinator.branchScale,
          y: this.coordinator.branchScale
        })
        .translate({
          x: this.coordinator.accentOffsetX,
          y: this.coordinator.accentOffsetY
        })
    }
    .width(this.markSize())
    .height(this.markSize())
    .opacity(this.coordinator.markOpacity)
  }

  @Builder
  private archiveDeck() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        // AppGallery-style hand-off: the brand first becomes only the stable
        // card surface.  Media, text and shimmer are supplied by the already
        // laid-out Explore page after this container reaches its final anchor.
        ExploreRecommendationSkeleton({
          animated: false,
          detailProgress: 0,
          horizontal: this.coordinator.deckHeight > 0 && this.coordinator.deckHeight < 300
        })
      }
      .width(this.coordinator.deckWidth)
      .height(this.coordinator.deckHeight)
      // Scale on a child node so the outer translation stays in the overlay's
      // coordinate space.  Combining both transforms on one node lets scale
      // alter the translation matrix and produces a visible arcing detour.
      .scale({
        x: this.coordinator.deckScale,
        y: this.coordinator.deckScale
      })
    }
    .width(this.coordinator.deckWidth)
    .height(this.coordinator.deckHeight)
    .position({
      x: this.coordinator.deckX,
      y: this.coordinator.deckY
    })
    .translate({
      x: this.coordinator.deckTranslateX,
      y: this.coordinator.deckTranslateY
    })
    .opacity(this.coordinator.deckOpacity)
    .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {}
        .width(LayoutPolicy.matchParent)
        .height(LayoutPolicy.matchParent)
        .background(this.backdropColor(), {
          ignoresLayoutSafeAreaEdges: [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
        })
        .opacity(this.coordinator.backdropOpacity)

      this.brandMark()

      if (this.coordinator.deckVisible) {
        this.archiveDeck()
      }
    }
    .id('startup-overlay')
    // ignoreLayoutSafeArea only expands both position and size when the
    // component uses matchParent. Percentage sizing would move this overlay
    // into the top safe area without increasing its height, leaving an equal
    // uncovered strip at the bottom on gesture-navigation devices.
    .width(LayoutPolicy.matchParent)
    .height(LayoutPolicy.matchParent)
    .background(Color.Transparent, {
      ignoresLayoutSafeAreaEdges: [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    })
    .hitTestBehavior(HitTestMode.Block)
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    )
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      this.coordinator.updateOverlayArea(newArea);
    })
    .onAppear((): void => {
      this.coordinator.start(this.getUIContext());
    })
  }
}
