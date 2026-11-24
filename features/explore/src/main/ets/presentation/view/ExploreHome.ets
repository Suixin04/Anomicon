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
  AppTypography,
  badgeInfoBackgroundColor,
  CARD_PRESS_MODIFIER,
  materialCardBorderColor,
  materialCardSurfaceColor,
  pageContentTop,
  PHONE_PAGE_MARGIN,
  PHONE_TAB_CONTENT_BOTTOM_SPACE,
  PHONE_TAB_CONTENT_TOP_GAP,
  pressAnimation,
  READING_CONTENT_MAX_WIDTH,
  ROW_PRESS_MODIFIER,
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
  @Param showStarterGuide: boolean = false;
  @Event onDismissStarterGuide: () => void = (): void => {};
  @Event onOpenStarterManual: () => void = (): void => {};
  @Event onOpenStarterSeries: () => void = (): void => {};
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
  private starterGuideActionButton(
    testId: string,
    symbol: Resource,
    title: string,
    subtitle: string,
    accent: boolean,
    onTap: () => void
  ) {
    Row({ space: 8 }) {
      Column() {
        SymbolGlyph(symbol)
          .fontSize(15)
          .fontColor([accent ? $r('sys.color.icon_emphasize') : $r('sys.color.icon_primary')])
      }
      .width(28)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(accent ? badgeInfoBackgroundColor() : $r('sys.color.comp_background_tertiary'))
      .borderRadius(8)

      Column({ space: 2 }) {
        Text(title)
          .fontSize(AppTypography.BODY_S)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
        Text(subtitle)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(11)
        .fontColor([$r('sys.color.icon_tertiary')])
    }
    .id(testId)
    .attributeModifier(ROW_PRESS_MODIFIER)
    .animation(pressAnimation())
    .layoutWeight(1)
    .padding({ left: 9, right: 8, top: 9, bottom: 9 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .borderRadius(12)
    .onClick(() => onTap())
  }

  @Builder
  private starterGuideSection() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.discover_fill'))
            .fontSize(15)
            .fontColor([$r('sys.color.icon_emphasize')])
          Text('初次接入格异录？')
            .fontSize(AppTypography.SUBTITLE_M)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font'))
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        Button({ type: ButtonType.Circle, stateEffect: false }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(12)
            .fontColor([$r('sys.color.icon_secondary')])
        }
        .id('starterGuideDismissButton')
        .width(26)
        .height(26)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .accessibilityText('关闭新人导览')
        .onClick(() => {
          this.onSelection();
          this.onDismissStarterGuide();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text('不确定从哪篇读起？可以先了解基金会基本设定，或按 Wiki 编排顺序跟读经典故事系列。')
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .lineHeightMultiple(1.45)
        .width('100%')

      Row({ space: 10 }) {
        this.starterGuideActionButton(
          'starterGuideManualButton',
          $r('sys.symbol.doc_text_fill'),
          '基础设定',
          '基金会简介',
          false,
          (): void => {
            this.onSelection();
            this.onOpenStarterManual();
          }
        )
        this.starterGuideActionButton(
          'starterGuideSeriesButton',
          $r('sys.symbol.list_book_fill'),
          '逆模因部',
          '从 055 跟读',
          true,
          (): void => {
            this.onSelection();
            this.onOpenStarterSeries();
          }
        )
      }
      .width('100%')
    }
    .id('starterGuideCard')
    .width('100%')
    .padding(14)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .border(this.materialEnabled ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(18)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
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
                if (this.showStarterGuide) {
                  this.starterGuideSection()
                }
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
              if (this.showStarterGuide) {
                this.starterGuideSection()
              }

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
              if (this.showStarterGuide) {
                this.starterGuideSection()
              }
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
