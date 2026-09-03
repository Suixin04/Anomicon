import { CatalogTaleEntry } from '../../domain/CatalogContracts';
import { TaleListViewModel } from '../viewmodel/TaleListViewModel';
import { TALE_FILTER_BAR_HEIGHT, TaleFilterState } from '../TaleFilterState';
import {
  LazyColumnLayout,
  LazyColumnLayoutAttribute
} from '@kit.ArkUI';
import { pageContentTop, AppTypography, SkeletonBlock } from 'anomiconbasic';

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
    Column({ space: 8 }) {
      ForEach([0, 1, 2, 3, 4, 5], (index: number) => {
        this.skeletonRow(index)
      }, (index: number) => `${index}`)
    }
    .width('100%')
    .margin({ top: pageContentTop() + TALE_FILTER_BAR_HEIGHT })
    .padding({ left: 16, right: 16, top: 16, bottom: 24 })
  }

  @Builder
  private errorBlock() {
    Column({ space: 12 }) {
      Text(this.viewModel.errorMessage.length > 0 ? this.viewModel.errorMessage : '故事目录加载失败')
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
  private partialBlock() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(16)
        .fontColor([$r('sys.color.icon_secondary')])
      Text(this.viewModel.errorMessage)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Button('重试', { stateEffect: false })
        .fontSize(13)
        .onClick(() => this.retryCurrent())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(8)
  }

  @Builder
  private emptyBlock() {
    Column({ space: 12 }) {
      Text('无匹配故事')
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
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .onClick(() => this.onOpenTale(row.item.id, row.item.title))
  }

  @Builder
  private topSpacer() {
    Blank()
      .width('100%')
      .height(pageContentTop() + TALE_FILTER_BAR_HEIGHT)
  }

  @Builder
  private listHeader() {
    Column() {
      this.topSpacer()
      if (this.viewModel.errorMessage.length > 0 && this.viewModel.visibleTales.length > 0) {
        this.partialBlock()
      }
    }
    .width('100%')
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Top }) {
        Scroll(this.scroller) {
          LazyColumnLayout() {
            Repeat<CatalogTaleEntry>(this.viewModel.visibleTales)
              .each((row: RepeatItem<CatalogTaleEntry>) => {
                Column() {
                  this.taleRow(row)
                }
                .width('100%')
                .padding({ left: 16, right: 16, bottom: 8 })
              })
              .key((tale: CatalogTaleEntry) => tale.id)
              .virtualScroll()
          }
          .header(() => {
            this.listHeader()
          })
          .width('100%')
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .layoutWeight(1)
        .width('100%')

        if (this.viewModel.loading) {
          this.loadingBlock()
        } else if (this.viewModel.errorMessage.length > 0 && this.viewModel.visibleTales.length === 0) {
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
  }
}
