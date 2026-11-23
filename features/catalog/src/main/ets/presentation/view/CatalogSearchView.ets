import { LengthMetrics, uiMaterial } from '@kit.ArkUI';
import {
  adaptiveListLanesForWidth,
  adaptivePageMarginForWidth,
  AppTypography,
  CARD_PRESS_MODIFIER,
  materialCardBorderColor,
  materialCardSurfaceColor,
  PHONE_PAGE_MARGIN,
  pageContentTop,
  ViewModelLoadState,
  WIDE_CONTENT_MAX_WIDTH,
  windowWidthVp
} from 'anomiconbasic';
import { CatalogEntry } from '../../domain/CatalogContracts';
import { ALL_SERIES_ID } from '../../domain/ScpSeriesItem';
import {
  CatalogSearchViewModel
} from '../viewmodel/CatalogSearchViewModel';
import { CatalogSeriesSelector } from './CatalogSeriesSelector';
import {
  CatalogSearchSharedState,
  CatalogSearchViewContract
} from './SearchViewContracts';

const SEARCH_FIELD_HEIGHT: number = 40;
/** 搜索页标题栏底部工具栏高度：搜索框 40vp + 间距 + 系列选择行。 */
export const CATALOG_SEARCH_HEADER_HEIGHT: number = 96;

/**
 * 搜索页标题栏底部工具栏：放入 HdsNavDestination.titleBar.bottomBuilder，
 * 使 Search 与系列胶囊处于系统沉浸材质作用域内。
 */
@ComponentV2
export struct CatalogSearchHeader {
  @Require @Param viewModel: CatalogSearchViewModel;
  @Require @Param sharedState: CatalogSearchSharedState;
  @Param materialEnabled: boolean = true;
  @Local private headerWidth: number = 0;

  private readonly searchBarMaterial: uiMaterial.ImmersiveMaterial =
    new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      applyShadow: false
    });

  private resolvedMargin(): number {
    const width = this.headerWidth > 0 ? this.headerWidth : windowWidthVp();
    return width > 0 ? adaptivePageMarginForWidth(width) : PHONE_PAGE_MARGIN;
  }

  private selectSeries(id: string): void {
    if (this.viewModel.snapshot.data?.seriesId === id) {
      return;
    }
    if (id !== ALL_SERIES_ID) {
      this.sharedState.setSeriesId(id);
    }
    this.viewModel.selectSeries(id);
  }

  private applyQuery(value: string): void {
    const currentQuery = this.viewModel.snapshot.data?.query ?? '';
    if (value === currentQuery && value === this.sharedState.query) {
      return;
    }
    this.sharedState.setQuery(value);
    this.viewModel.setQuery(value);
  }

  build() {
    Column() {
      Column({ space: 8 }) {
        Search({
          placeholder: '搜索编号或名称',
          value: this.viewModel.snapshot.data?.query ?? ''
        })
          .height(SEARCH_FIELD_HEIGHT)
          .margin({ left: this.resolvedMargin(), right: this.resolvedMargin() })
          .backgroundColor(this.materialEnabled ?
            Color.Transparent : $r('sys.color.comp_background_primary'))
          .systemMaterial(this.materialEnabled ? this.searchBarMaterial : undefined)
          .placeholderColor($r('sys.color.font_secondary'))
          .accessibilityText('搜索编号或名称')
          .onChange((value: string) => this.applyQuery(value))

        CatalogSeriesSelector({
          selectedSeriesId: this.viewModel.snapshot.data?.seriesId ?? ALL_SERIES_ID,
          includeAll: true,
          materialEnabled: this.materialEnabled,
          horizontalMargin: this.resolvedMargin(),
          onSelect: (seriesId: string) => this.selectSeries(seriesId)
        })
      }
      .width('100%')
      .constraintSize({ maxWidth: WIDE_CONTENT_MAX_WIDTH })
      .padding({ top: 4, bottom: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width = Number(newArea.width);
      if (Number.isFinite(width) && width > 0) {
        this.headerWidth = width;
      }
    })
  }
}

/** Public, contract-shaped screen Builder consumed by product route hosts. */
@Builder
export function CatalogSearchView(contract: CatalogSearchViewContract) {
  CatalogSearchContent({
    viewModel: contract.viewModel,
    scroller: contract.scroller,
    sharedState: contract.sharedState,
    onOpenContent: contract.onOpenContent,
    materialEnabled: contract.materialEnabled
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
  @Param materialEnabled: boolean = true;
  @Local private paneWidth: number = 0;

  private resolvedWidth(): number {
    return this.paneWidth > 0 ? this.paneWidth : windowWidthVp();
  }

  private horizontalMargin(): number {
    const width = this.resolvedWidth();
    return width > 0 ? adaptivePageMarginForWidth(width) : PHONE_PAGE_MARGIN;
  }

  private listLanes(): number {
    return adaptiveListLanesForWidth(this.resolvedWidth(), 680);
  }

  private isLoadingAllSeries(): boolean {
    return (this.viewModel.snapshot.data?.seriesId ?? '') === ALL_SERIES_ID &&
      (this.viewModel.snapshot.data?.allSeriesLoading ?? false);
  }

  aboutToAppear(): void {
    const selectedData = this.viewModel.snapshot.data;
    if (this.sharedState.query.length > 0 &&
      this.sharedState.query !== (selectedData?.query ?? '')) {
      this.viewModel.setQuery(this.sharedState.query);
    }
    this.viewModel.activate();
  }

  aboutToDisappear(): void {
    this.viewModel.dispose();
  }

  private applyQuery(value: string): void {
    this.sharedState.setQuery(value);
    this.viewModel.setQuery(value);
  }

  private emptyMessage(fallback: string): string {
    const snapshot = this.viewModel.snapshot;
    const data = snapshot.data;
    if (data?.seriesId === ALL_SERIES_ID && (data?.allSeriesLoading ?? false)) {
      return data.loadedSeriesCount > 0 ?
        `正在检索全部系列（已加载 ${data.loadedSeriesCount}/${data.totalSeriesCount}）…` :
        '正在加载全部系列目录，请稍候…';
    }
    if (data?.catalogPending ?? false) {
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
    .padding({
      left: 24,
      right: 24,
      top: pageContentTop() + CATALOG_SEARCH_HEADER_HEIGHT + 24,
      bottom: 56
    })
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
  private entryCardRow(entry: CatalogEntry) {
    Column({ space: 3 }) {
      Row({ space: 8 }) {
        Text(entry.itemId)
          .fontSize(AppTypography.BODY_S)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
        Text(entry.title)
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
      if (entry.description.length > 0) {
        Text(entry.description)
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .attributeModifier(CARD_PRESS_MODIFIER)
    .animation({ duration: 120, curve: Curve.FastOutSlowIn })
    .width('100%')
    .constraintSize({ minHeight: 62 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .onClick(() => this.openResult(entry))
  }

  @Builder
  private idleContent() {
    Scroll(this.scroller) {
      Column({ space: 18 }) {
        if (this.hasPartialError()) {
          this.partialErrorContent()
        }

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
                  .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
                  .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_THIN : undefined)
                  .border(this.materialEnabled ?
                    { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
                  .borderRadius(14)
                  .onClick(() => this.applyQuery(item))
              }, (item: string) => item)
            }
            .width('100%')
          }
          .width('100%')
        }

        if ((this.viewModel.snapshot.data?.random.length ?? 0) > 0) {
          Column({ space: 10 }) {
            Text('随机发现')
              .fontSize(AppTypography.SUBTITLE_S)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font'))
              .width('100%')

            GridRow({ columns: this.listLanes(), gutter: { x: 12, y: 10 } }) {
              ForEach(this.viewModel.snapshot.data?.random ?? [], (entry: CatalogEntry) => {
                GridCol({ span: 1 }) {
                  this.entryCardRow(entry)
                }
              }, (entry: CatalogEntry) => entry.itemId)
            }
            .width('100%')
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
      .padding({
        left: this.horizontalMargin(),
        right: this.horizontalMargin(),
        top: pageContentTop() + CATALOG_SEARCH_HEADER_HEIGHT + 6,
        bottom: 120
      })
    }
    .align(Alignment.Top)
    .clip(false)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .layoutWeight(1)
    .width('100%')
  }

  private resultsHeaderNoticeHeight(): number {
    let extra: number = 0;
    if (this.hasPartialError()) {
      extra += 52;
    }
    if (this.isLoadingAllSeries()) {
      extra += 26;
    }
    return extra;
  }

  @Builder
  private resultsContent() {
    Stack({ alignContent: Alignment.Top }) {
      List({ scroller: this.scroller, space: 10 }) {
        Repeat<CatalogEntry>(this.viewModel.snapshot.data?.entries ?? [])
          .each((row: RepeatItem<CatalogEntry>) => {
            ListItem() {
              this.entryCardRow(row.item)
            }
          })
          .key((entry: CatalogEntry) => entry.itemId)
          .virtualScroll({ reusable: false })
      }
      .lanes(this.listLanes(), 12)
      .contentStartOffset(
        pageContentTop() + CATALOG_SEARCH_HEADER_HEIGHT + 6 + this.resultsHeaderNoticeHeight()
      )
      .contentEndOffset(32)
      .padding({ left: this.horizontalMargin(), right: this.horizontalMargin() })
      .clip(false)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

      if (this.hasPartialError() || this.isLoadingAllSeries()) {
        Column({ space: 6 }) {
          if (this.hasPartialError()) {
            this.partialErrorContent()
          }
          if (this.isLoadingAllSeries()) {
            Text(`正在检索全部系列（已加载 ${this.viewModel.snapshot.data?.loadedSeriesCount ?? 0}/${this.viewModel.snapshot.data?.totalSeriesCount ?? 0}）…`)
              .fontSize(AppTypography.CAPTION_M)
              .fontColor($r('sys.color.font_tertiary'))
              .width('100%')
          }
        }
        .width('100%')
        .padding({
          left: this.horizontalMargin(),
          right: this.horizontalMargin(),
          top: pageContentTop() + CATALOG_SEARCH_HEADER_HEIGHT + 6
        })
      }
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  private searchContent() {
    Column() {
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
        .padding({
          left: this.horizontalMargin(),
          right: this.horizontalMargin(),
          top: pageContentTop() + CATALOG_SEARCH_HEADER_HEIGHT + 60
        })
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else {
        this.resultsContent()
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: WIDE_CONTENT_MAX_WIDTH })
    .height('100%')
  }

  build() {
    Column() {
      this.searchContent()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('sys.color.background_secondary'))
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width = Number(newArea.width);
      if (Number.isFinite(width) && width > 0) {
        this.paneWidth = width;
      }
    })
  }
}
