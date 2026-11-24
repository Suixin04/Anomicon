import { ExploreRecommendationDeck } from './ExploreRecommendationDeck';
import {
  ExploreMixedSection,
  ExploreTopRatedSection
} from './ExploreContentSections';
import {
  LibraryContentRef,
  LibraryContentKind,
  createLibraryContentRef
} from 'library';
import {
  adaptivePageMarginForWidth,
  pageContentTop,
  PHONE_PAGE_MARGIN,
  PHONE_TAB_CONTENT_BOTTOM_SPACE,
  PHONE_TAB_CONTENT_TOP_GAP,
  READING_CONTENT_MAX_WIDTH,
  WIDE_CONTENT_MAX_WIDTH
} from 'anomiconbasic';
import { ExploreCollectionMode } from '../../domain/ExploreContracts';
import { ExploreHomeViewModel } from '../viewmodel/ExploreHomeViewModel';
import { ExploreHeroAnchor } from './ExploreViewContracts';

const SECTION_SPACE: number = 24;
const EXPLORE_DUAL_SCREEN_MIN_WIDTH: number = 640;
const EXPLORE_TWO_COLUMN_MIN_WIDTH: number = 840;
const DUAL_COLUMN_GUTTER: number = 20;

/**
 * Explore View：只投影 ViewModel 状态并发出用户事件。
 * 数据缓存、网络请求、每日选择和请求 token 均由 ExploreHomeViewModel 管理。
 */
@ComponentV2
export struct ExploreHome {
  @Require @Param scroller: Scroller;
  @Require @Param viewModel: ExploreHomeViewModel;
  @Require @Param materialEnabled: boolean;
  @Require @Param onOpenContent: (content: LibraryContentRef) => void;
  @Require @Param onOpenCollection: (mode: ExploreCollectionMode) => void;
  @Event onSelection: () => void;
  @Event onHeroAnchorChange: (anchor: ExploreHeroAnchor) => void =
    (_anchor: ExploreHeroAnchor): void => {};
  @Param active: boolean = false;
  @Param recommendationSkeletonAnimated: boolean = true;
  @Local private sideBySide: boolean = false;
  @Local private dualScreen: boolean = false;
  @Local private horizontalMargin: number = PHONE_PAGE_MARGIN;

  aboutToAppear(): void {
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

  private retryTopRated(): void {
    this.viewModel.loadTopRated(true);
  }

  private retryRecent(): void {
    this.viewModel.loadRecent(true);
  }

  private retryJokes(): void {
    this.viewModel.loadJokes(true);
  }

  private refreshRecommendations(): void {
    if (!this.viewModel.recommendationLoading && !this.viewModel.recommendationRefreshing) {
      this.onSelection();
      this.viewModel.refreshRecommendations();
    }
  }

  private nextRecommendation(deckVersion: number): void {
    if (this.active && deckVersion === this.viewModel.recommendationDeckVersion &&
      this.viewModel.recommendations.length > 1) {
      this.onSelection();
      this.viewModel.nextRecommendation();
    }
  }

  private openContent(id: string, title: string, kind: LibraryContentKind): void {
    this.onOpenContent(createLibraryContentRef(kind, id, title));
  }

  @Builder
  private recommendationSection(horizontal: boolean = false) {
    ExploreRecommendationDeck({
      recommendations: this.viewModel.recommendations,
      currentIndex: this.viewModel.recommendationIndex,
      deckVersion: this.viewModel.recommendationDeckVersion,
      loading: this.viewModel.recommendationLoading,
      error: this.viewModel.recommendationError,
      status: this.viewModel.recommendationStatus,
      refreshing: this.viewModel.recommendationRefreshing,
      skeletonAnimated: this.recommendationSkeletonAnimated,
      horizontal: horizontal,
      materialEnabled: this.materialEnabled,
      onOpen: (itemId: string, name: string) =>
        this.openContent(itemId, name, LibraryContentKind.SCP),
      onDismiss: (deckVersion: number) => this.nextRecommendation(deckVersion),
      onRefresh: () => this.refreshRecommendations(),
      onHeroAnchorChange: (anchor: ExploreHeroAnchor): void =>
        this.onHeroAnchorChange(anchor)
    })
  }

  @Builder
  private topRatedSection() {
    ExploreTopRatedSection({
      entries: this.viewModel.topRatedEntries,
      loading: this.viewModel.topRatedLoading,
      error: this.viewModel.topRatedError,
      onOpenContent: (content: LibraryContentRef) => this.onOpenContent(content),
      onRetry: () => this.retryTopRated()
    })
  }

  @Builder
  private recentSection() {
    ExploreMixedSection({
      title: '最近更新',
      description: '按归档时间同步主站译文与中文原创',
      items: this.viewModel.recentItems,
      loading: this.viewModel.recentLoading,
      error: this.viewModel.recentError,
      showDate: true,
      mode: ExploreCollectionMode.RECENT,
      onOpenContent: (content: LibraryContentRef) => this.onOpenContent(content),
      onOpenCollection: (mode: ExploreCollectionMode) => this.onOpenCollection(mode),
      onRetry: () => this.retryRecent()
    })
  }

  @Builder
  private jokeSection(twoColumn: boolean = false) {
    ExploreMixedSection({
      title: '轻松一下',
      description: '每日轮换搞笑 SCP 与轻松故事',
      items: this.viewModel.jokeItems,
      loading: this.viewModel.jokeLoading,
      error: this.viewModel.jokeError,
      showDate: false,
      mode: ExploreCollectionMode.JOKE,
      twoColumn: twoColumn,
      onOpenContent: (content: LibraryContentRef) => this.onOpenContent(content),
      onOpenCollection: (mode: ExploreCollectionMode) => this.onOpenCollection(mode),
      onRetry: () => this.retryJokes()
    })
  }

  build() {
    Column() {
      Scroll(this.scroller) {
        Column() {
          if (this.sideBySide) {
            Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Start }) {
              Column({ space: SECTION_SPACE }) {
                this.recommendationSection(false)
                this.jokeSection(false)
              }
              .width('44%')

              Column({ space: SECTION_SPACE }) {
                this.topRatedSection()
                this.recentSection()
              }
              .width('56%')
              .padding({ left: SECTION_SPACE })
            }
            .width('100%')
          } else if (this.dualScreen) {
            Column({ space: SECTION_SPACE }) {
              this.recommendationSection(true)

              Row({ space: DUAL_COLUMN_GUTTER }) {
                Column() {
                  this.topRatedSection()
                }
                .layoutWeight(1)

                Column() {
                  this.recentSection()
                }
                .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)

              this.jokeSection(true)
            }
            .width('100%')
          } else {
            Column({ space: SECTION_SPACE }) {
              this.recommendationSection(false)
              this.topRatedSection()
              this.recentSection()
              this.jokeSection(false)
            }
            .width('100%')
          }
        }
        .width('100%')
        .constraintSize({
          maxWidth: this.sideBySide || this.dualScreen ? WIDE_CONTENT_MAX_WIDTH : READING_CONTENT_MAX_WIDTH
        })
        .padding({
          left: this.horizontalMargin,
          right: this.horizontalMargin,
          top: pageContentTop() + PHONE_TAB_CONTENT_TOP_GAP,
          bottom: PHONE_TAB_CONTENT_BOTTOM_SPACE
        })
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(this.sideBySide ? BarState.Auto : BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .layoutWeight(1)
      .width('100%')
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        const measuredWidth = Number(newArea.width);
        if (Number.isFinite(measuredWidth) && measuredWidth > 0) {
          this.horizontalMargin = adaptivePageMarginForWidth(measuredWidth);
          this.sideBySide = measuredWidth >= EXPLORE_TWO_COLUMN_MIN_WIDTH;
          this.dualScreen = measuredWidth >= EXPLORE_DUAL_SCREEN_MIN_WIDTH &&
            measuredWidth < EXPLORE_TWO_COLUMN_MIN_WIDTH;
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
