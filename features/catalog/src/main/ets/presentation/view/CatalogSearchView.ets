import { LengthMetrics } from '@kit.ArkUI';
import {
  AppTypography,
  PHONE_PAGE_MARGIN,
  PHONE_TAB_CONTENT_MAX_WIDTH,
  pageContentTop,
  ViewModelLoadState
} from 'anomiconbasic';
import { CatalogEntry } from '../../domain/CatalogContracts';
import {
  CatalogSearchViewModel
} from '../viewmodel/CatalogSearchViewModel';
import { CatalogSeriesSelector } from './CatalogSeriesSelector';
import {
  CatalogSearchSharedState,
  CatalogSearchViewContract
} from './SearchViewContracts';

const SEARCH_FIELD_HEIGHT: number = 40;

/** Public, contract-shaped screen Builder consumed by product route hosts. */
@Builder
export function CatalogSearchView(contract: CatalogSearchViewContract) {
  CatalogSearchContent({
    viewModel: contract.viewModel,
    scroller: contract.scroller,
    sharedState: contract.sharedState,
    onOpenContent: contract.onOpenContent
  });
}

/**
 * Device-independent Catalog search content.
 *
 * HdsNavDestination, NavPathStack, AppStorageV2 creation and Article routing
 * remain in the product host. This View renders the screen ViewModel and emits
 * only an item identity when the user opens a result.
 */
@ComponentV2
struct CatalogSearchContent {
  @Require @Param viewModel: CatalogSearchViewModel;
  @Require @Param scroller: Scroller;
  @Require @Param sharedState: CatalogSearchSharedState;
  @Require @Param onOpenContent: (itemId: string, title: string) => void;

  aboutToAppear(): void {
    // Seed the screen VM before activation so the Catalog tab and route page
    // keep sharing exactly one series/query value through the product bridge.
    const initialData = this.viewModel.snapshot.data;
    if (this.sharedState.seriesId !== (initialData?.seriesId ?? '')) {
      this.viewModel.selectSeries(this.sharedState.seriesId);
    }
    const selectedData = this.viewModel.snapshot.data;
    if (this.sharedState.query !== (selectedData?.query ?? '')) {
      this.viewModel.setQuery(this.sharedState.query);
    }
    this.viewModel.activate();
  }

  aboutToDisappear(): void {
    this.viewModel.dispose();
  }

  private selectSeries(id: string): void {
    if (this.viewModel.snapshot.data?.seriesId === id) {
      return;
    }
    this.sharedState.setSeriesId(id);
    this.viewModel.selectSeries(id);
  }

  private applyQuery(value: string): void {
    this.sharedState.setQuery(value);
    this.viewModel.setQuery(value);
  }

  private emptyMessage(fallback: string): string {
    const snapshot = this.viewModel.snapshot;
    if (snapshot.data?.catalogPending ?? false) {
      return '该系列目录正在加载，请稍候…';
    }
    if (snapshot.state === ViewModelLoadState.ERROR && snapshot.error !== undefined) {
      return snapshot.error.message;
    }
    return fallback;
  }

  private hasColdLoadError(): boolean {
    const snapshot = this.viewModel.snapshot;
    return snapshot.state === ViewModelLoadState.ERROR &&
      (snapshot.data?.entries.length ?? 0) === 0 &&
      snapshot.error !== undefined;
  }

  private hasPartialError(): boolean {
    const snapshot = this.viewModel.snapshot;
    return (snapshot.state === ViewModelLoadState.ERROR ||
      snapshot.state === ViewModelLoadState.PARTIAL) &&
      (snapshot.data?.entries.length ?? 0) > 0 &&
      snapshot.error !== undefined;
  }

  @Builder
  private coldLoadErrorContent() {
    Column({ space: 12 }) {
      Text('目录暂时无法加载')
        .fontSize(AppTypography.BODY_M)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font'))
      Text(this.viewModel.snapshot.error?.message ?? '请检查网络后重试')
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Button('重试', { stateEffect: false })
        .height(40)
        .onClick(() => this.viewModel.retry())
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 56, bottom: 56 })
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
  }

  @Builder
  private partialErrorContent() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(17)
        .fontColor([$r('sys.color.icon_secondary')])
      Text(this.viewModel.snapshot.error?.message ?? '目录更新失败，正在显示已有结果')
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Button('重试', { stateEffect: false })
        .fontSize(AppTypography.CAPTION_L)
        .onClick(() => this.viewModel.retry())
    }
    .width('100%')
    .margin({ left: PHONE_PAGE_MARGIN, right: PHONE_PAGE_MARGIN })
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(8)
  }

  private openResult(entry: CatalogEntry): void {
    const query = this.viewModel.snapshot.data?.query ?? '';
    const historyValue = query.trim().length > 0 ? query.trim() : entry.title;
    this.viewModel.addHistory(historyValue);
    this.onOpenContent(entry.itemId, entry.title);
  }

  @Builder
  private resultRow(row: RepeatItem<CatalogEntry>) {
    Column({ space: 2 }) {
      Row({ space: 8 }) {
        Text(row.item.itemId)
          .fontSize(AppTypography.BODY_S)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
        Text(row.item.title)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .width('100%')
      if (row.item.description.length > 0) {
        Text(row.item.description)
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => this.openResult(row.item))
  }

  @Builder
  private idleContent() {
    Scroll(this.scroller) {
      Column({ space: 14 }) {
        if ((this.viewModel.snapshot.data?.history.length ?? 0) > 0) {
          Column({ space: 10 }) {
            Row() {
              Text('历史搜索')
                .fontSize(AppTypography.SUBTITLE_S)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font'))
              Blank()
              SymbolGlyph($r('sys.symbol.trash'))
                .fontSize(16)
                .fontColor([$r('sys.color.icon_secondary')])
                .onClick(() => {
                  this.viewModel.clearHistory();
                })
            }
            .width('100%')

            Flex({
              wrap: FlexWrap.Wrap,
              space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) }
            }) {
              ForEach(this.viewModel.snapshot.data?.history ?? [], (item: string) => {
                Text(item)
                  .fontSize(AppTypography.BODY_S)
                  .fontColor($r('sys.color.font_secondary'))
                  .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                  .backgroundColor($r('sys.color.comp_background_primary'))
                  .borderRadius(14)
                  .onClick(() => this.applyQuery(item))
              }, (item: string) => item)
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
        }

        if ((this.viewModel.snapshot.data?.random.length ?? 0) > 0) {
          Column({ space: 2 }) {
            Text('随机发现')
              .fontSize(AppTypography.SUBTITLE_S)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font'))
              .padding({ left: 16, right: 16, bottom: 6 })
              .width('100%')
            Repeat<CatalogEntry>(this.viewModel.snapshot.data?.random ?? [])
              .each((row: RepeatItem<CatalogEntry>) => {
                this.resultRow(row)
              })
              .key((entry: CatalogEntry) => entry.itemId)
          }
          .width('100%')
        } else {
          Text(this.emptyMessage('该系列暂无条目'))
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 24, bottom: 24 })
        }
      }
      .width('100%')
      .padding({ top: 8, bottom: 120 })
    }
    .scrollBar(BarState.Off)
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  private resultsContent() {
    List({ scroller: this.scroller }) {
      Repeat<CatalogEntry>(this.viewModel.snapshot.data?.entries ?? [])
        .each((row: RepeatItem<CatalogEntry>) => {
          ListItem() {
            this.resultRow(row)
          }
        })
        .key((entry: CatalogEntry) => entry.itemId)
        .virtualScroll()
    }
    .scrollBar(BarState.Off)
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  private searchContent() {
    Column({ space: 8 }) {
      Search({
        placeholder: '搜索编号或名称',
        value: this.viewModel.snapshot.data?.query ?? ''
      })
        .height(SEARCH_FIELD_HEIGHT)
        .margin({ left: PHONE_PAGE_MARGIN, right: PHONE_PAGE_MARGIN })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .placeholderColor($r('sys.color.font_secondary'))
        .onChange((value: string) => this.applyQuery(value))

      CatalogSeriesSelector({
        selectedSeriesId: this.viewModel.snapshot.data?.seriesId ?? this.sharedState.seriesId,
        onSelect: (seriesId: string) => this.selectSeries(seriesId)
      })

      if (this.hasPartialError()) {
        this.partialErrorContent()
      }

      if (this.hasColdLoadError()) {
        this.coldLoadErrorContent()
      } else if ((this.viewModel.snapshot.data?.query ?? '').trim().length === 0) {
        this.idleContent()
      } else if ((this.viewModel.snapshot.data?.entries.length ?? 0) === 0) {
        Column() {
          Text(this.emptyMessage('无匹配条目'))
            .fontSize(14)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')
        .padding({ top: 60 })
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else {
        this.resultsContent()
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: PHONE_TAB_CONTENT_MAX_WIDTH })
    .height('100%')
    .padding({ top: pageContentTop() + 8 })
  }

  build() {
    Column() {
      this.searchContent()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
