import { CatalogTaleEntry } from '../../domain/CatalogContracts';
import { TaleListViewModel } from '../viewmodel/TaleListViewModel';
import { TALE_FILTER_BAR_HEIGHT, TaleFilterState } from '../TaleFilterState';
import {
  adaptiveListLanesForWidth,
  adaptivePageMarginForWidth,
  AppTypography,
  CARD_PRESS_MODIFIER,
  ContentUpdateNotice,
  pageContentTop,
  PHONE_PAGE_MARGIN,
  PHONE_TAB_CONTENT_BOTTOM_SPACE,
  PHONE_TAB_CONTENT_TOP_GAP,
  SkeletonBlock,
  WIDE_CONTENT_MAX_WIDTH,
  windowWidthVp
} from 'anomiconbasic';

/**
 * 故事列表 View。所有缓存、网络和解析都由 TaleListViewModel 编排；此处
 * 只负责筛选事件、状态投影与列表布局。
 */
@ComponentV2
export struct TaleList {
  @Require @Param scroller: Scroller;
  @Require @Param filterState: TaleFilterState;
  @Require @Param onOpenTale: (id: string, name: string) => void;
  @Require @Param viewModel: TaleListViewModel;
  @Param active: boolean = true;
  @Param isReadCompleted: (id: string) => boolean = (_id: string): boolean => false;
  @Param completionRevision: number = 0;
  @Local private paneWidth: number = 0;

  private resolvedWidth(): number {
    return this.paneWidth > 0 ? this.paneWidth : windowWidthVp();
  }

  private horizontalMargin(): number {
    const width = this.resolvedWidth();
    return width > 0 ? adaptivePageMarginForWidth(width) : PHONE_PAGE_MARGIN;
  }

  private columnCount(): number {
    return adaptiveListLanesForWidth(this.resolvedWidth(), 680);
  }

  aboutToAppear(): void {
    if (this.active) {
      this.attachViewModel();
    }
  }

  aboutToDisappear(): void {
    this.viewModel.deactivate();
  }

  @Monitor('active')
  onActiveChange(): void {
    if (this.active) {
      this.attachViewModel();
    } else {
      this.viewModel.deactivate();
    }
  }

  private attachViewModel(): void {
    this.viewModel.setQuery(this.filterState.query);
    this.viewModel.setLetter(this.filterState.letter);
    this.viewModel.activate();
  }

  @Monitor('filterState.query')
  onTaleQueryChange(): void {
    this.viewModel.setQuery(this.filterState.query);
  }

  @Monitor('filterState.letter')
  onTaleLetterChange(): void {
    this.viewModel.setLetter(this.filterState.letter);
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
  }

  @Monitor('completionRevision')
  onCompletionRevisionChanged(): void {
    // Consume the product-owned revision so a completed story is reflected in
    // a recycled row without coupling Catalog to Library.
  }

  private retryCurrent(): void {
    this.viewModel.retry().catch((): void => {
      // Error is represented by the ViewModel state.
    });
  }

  @Builder
  private skeletonRow(index: number) {
    Row({ space: 10 }) {
      Column({ space: 7 }) {
        SkeletonBlock({ animated: true, radius: 7 })
          .width(index % 2 === 0 ? '78%' : '88%')
          .height(14)
        SkeletonBlock({ animated: true, radius: 5 })
          .width(index % 3 === 0 ? '42%' : '32%')
          .height(10)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SkeletonBlock({ animated: true, radius: 7 })
        .width(14)
        .height(14)
    }
    .width('100%')
    .height(68)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
  }

  @Builder
  private loadingBlock() {
    GridRow({ columns: this.columnCount(), gutter: { x: 12, y: 10 } }) {
      ForEach([0, 1, 2, 3, 4, 5], (index: number) => {
        GridCol({ span: 1 }) {
          this.skeletonRow(index)
        }
      }, (index: number) => `${index}`)
    }
    .width('100%')
    .margin({ top: pageContentTop() + TALE_FILTER_BAR_HEIGHT })
    .constraintSize({ maxWidth: WIDE_CONTENT_MAX_WIDTH })
    .padding({
      left: this.horizontalMargin(),
      right: this.horizontalMargin(),
      top: PHONE_TAB_CONTENT_TOP_GAP,
      bottom: 24
    })
  }

  private hasDirectoryUpdate(): boolean {
    return this.viewModel.tales.length > 0 && (this.viewModel.loading || this.viewModel.refreshing ||
      this.viewModel.errorMessage.length > 0 || this.viewModel.stale);
  }

  @Builder
  private errorBlock() {
    Column({ space: 12 }) {
      Text('暂时无法加载故事目录')
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })
      Button('重试', { stateEffect: false })
        .onClick(() => this.retryCurrent())
    }
    .width('100%')
    .margin({ top: pageContentTop() + TALE_FILTER_BAR_HEIGHT })
    .padding({ top: 40 })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private directoryUpdateBlock() {
    Column() {
      ContentUpdateNotice({
        message: this.viewModel.errorMessage.length > 0 ? '目录更新失败，仍可浏览已缓存的故事' :
          '暂未获取到最新目录，仍可浏览已缓存的故事',
        updating: this.viewModel.loading || this.viewModel.refreshing,
        updatingMessage: '正在更新目录',
        onRetry: () => this.retryCurrent()
      })
    }
    .width('100%')
    .constraintSize({ maxWidth: WIDE_CONTENT_MAX_WIDTH })
    .padding({ left: this.horizontalMargin(), right: this.horizontalMargin(), bottom: 8 })
  }

  @Builder
  private emptyBlock() {
    Column({ space: 12 }) {
      if (this.hasDirectoryUpdate()) {
        this.directoryUpdateBlock()
      }
      Text(this.filterState.active ? '没有匹配的故事' : '暂无故事')
        .fontSize(14)
        .fontColor($r('sys.color.font_tertiary'))
      if (this.filterState.active) {
        Button('清除筛选', { stateEffect: false })
          .height(40)
          .onClick(() => {
            this.filterState.clear();
            this.viewModel.clearFilter();
          })
      }
    }
    .width('100%')
    .margin({ top: pageContentTop() + TALE_FILTER_BAR_HEIGHT })
    .padding({ top: 40 })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private taleRow(row: RepeatItem<CatalogTaleEntry>) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(row.item.title)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(row.item.id)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.isReadCompleted(row.item.id)) {
          Text('✓ 已读完')
            .fontSize(AppTypography.CAPTION_M)
            .fontColor('#3C7A57')
            .maxLines(1)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([$r('sys.color.icon_secondary')])
    }
    .attributeModifier(CARD_PRESS_MODIFIER)
    .animation({ duration: 120, curve: Curve.FastOutSlowIn })
    .width('100%')
    .constraintSize({ minHeight: 76 })
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .onClick(() => this.onOpenTale(row.item.id, row.item.title))
  }

  private showVisibleDirectoryBanner(): boolean {
    return this.viewModel.visibleTales.length > 0 && this.hasDirectoryUpdate();
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Top }) {
        List({ scroller: this.scroller, space: 10 }) {
          Repeat<CatalogTaleEntry>(this.viewModel.visibleTales)
            .each((row: RepeatItem<CatalogTaleEntry>) => {
              ListItem() {
                this.taleRow(row)
              }
            })
            .key((tale: CatalogTaleEntry) => tale.id)
            .virtualScroll()
        }
        .lanes(this.columnCount(), 12)
        .contentStartOffset(
          pageContentTop() + TALE_FILTER_BAR_HEIGHT + PHONE_TAB_CONTENT_TOP_GAP +
            (this.showVisibleDirectoryBanner() ? 52 : 0)
        )
        .contentEndOffset(PHONE_TAB_CONTENT_BOTTOM_SPACE)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .constraintSize({ maxWidth: WIDE_CONTENT_MAX_WIDTH })
        .height('100%')
        .padding({ left: this.horizontalMargin(), right: this.horizontalMargin() })

        if (this.showVisibleDirectoryBanner()) {
          Column() {
            this.directoryUpdateBlock()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: pageContentTop() + TALE_FILTER_BAR_HEIGHT + PHONE_TAB_CONTENT_TOP_GAP })
        }

        if (this.viewModel.tales.length === 0 && this.viewModel.loading) {
          this.loadingBlock()
        } else if (this.viewModel.tales.length === 0 && this.viewModel.errorMessage.length > 0) {
          this.errorBlock()
        } else if (this.viewModel.visibleTales.length === 0) {
          this.emptyBlock()
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width = Number(newArea.width);
      if (Number.isFinite(width) && width > 0) {
        this.paneWidth = width;
      }
    })
  }
}
