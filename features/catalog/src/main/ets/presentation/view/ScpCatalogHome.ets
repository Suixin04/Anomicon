import {
  LazyColumnLayout,
  LazyColumnLayoutAttribute,
  LazyVWaterFlowLayout,
  LazyVWaterFlowLayoutAttribute,
  LengthMetrics
} from '@kit.ArkUI';
import { AppTypography, pageContentTop, SkeletonBlock } from 'anomiconbasic';
import { CatalogEntry, CatalogPreview } from '../../domain/CatalogContracts';
import { CATALOG_TOOLBAR_HEIGHT, ScpCatalogSearchState, sharedCatalogSearchState } from '../ScpCatalogSearchState';
import { CatalogViewModel } from '../viewmodel/CatalogViewModel';
import { CatalogPreviewState, ScpCatalogEntry } from '../ScpCatalogItem';
import { CatalogPreviewLoader, ScpCatalogCard } from './ScpCatalogCard';

const STATE_TOP_OFFSET: number = 140;

/**
 * 图鉴主视图。它只观察 ViewModel、投影卡片状态并发送用户事件；缓存、
 * HTML/RCP/RDB 和平台适配器均不在此层出现。
 */
@ComponentV2
export struct ScpCatalogHome {
  @Require @Param scroller: Scroller;
  @Require @Param onOpenArticle: (itemId: string, name: string) => void;
  @Require @Param viewModel: CatalogViewModel;
  @Require @Param previewLoader: CatalogPreviewLoader;
  @Require @Param resolveLocalPreviewSource: (path: string) => string;
  /** Product composition injects the reviewed 3D capability without making
   * the catalog feature depend on the archive3d renderer or manifest. */
  @Require @Param has3DModel: (itemId: string) => boolean;
  @Param active: boolean = true;
  @Param isReadCompleted: (itemId: string) => boolean = (_itemId: string): boolean => false;
  @Param completionRevision: number = 0;

  @Local private searchState: ScpCatalogSearchState = sharedCatalogSearchState();
  @Local private entries: ScpCatalogEntry[] = [];
  /** Single refresh generation shared by every visible preview card. */
  @Local private previewReloadToken: number = 0;
  /** Keep preview projections alive while search temporarily hides an item. */
  private readonly previewEntriesById: Map<string, ScpCatalogEntry> = new Map();
  private mountedEpoch: number = 0;

  aboutToAppear(): void {
    this.mountedEpoch++;
    if (this.active) {
      this.viewModel.activate();
    }
    this.syncEntries();
  }

  aboutToDisappear(): void {
    this.mountedEpoch++;
    this.viewModel.deactivate();
  }

  @Monitor('active')
  onActiveChanged(): void {
    if (this.active) {
      this.viewModel.activate();
      this.syncEntries();
    } else {
      this.viewModel.deactivate();
    }
  }

  @Monitor('searchState.query')
  onSearchQueryChanged(): void {
    this.viewModel.setQuery(this.searchState.query);
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
  }

  @Monitor('searchState.seriesId')
  onSearchSeriesChanged(): void {
    this.previewEntriesById.clear();
    this.viewModel.selectSeries(this.searchState.seriesId);
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
  }

  @SyncMonitor('viewModel.visibleEntries')
  onVisibleEntriesChanged(): void {
    this.syncEntries();
  }

  @Monitor('completionRevision')
  onCompletionRevisionChanged(): void {
    // The revision is deliberately consumed by the view so product-owned
    // history updates also refresh recycled WaterFlow cards.
  }

  private syncEntries(): void {
    const projected: ScpCatalogEntry[] = [];
    this.viewModel.visibleEntries.forEach((item: CatalogEntry) => {
      const previous = this.previewEntriesById.get(item.itemId);
      const next = previous !== undefined && previous.title === item.title ?
        previous : new ScpCatalogEntry(item.itemId, item.title);
      if (previous !== undefined && next !== previous) {
        next.previewPath = previous.previewPath;
        next.previewUrl = previous.previewUrl;
        // A title correction replaces the object while its old request may
        // still be in flight.  Invalidate that request only for this case.
        next.previewState = previous.previewState === CatalogPreviewState.LOADING ?
          CatalogPreviewState.IDLE : previous.previewState;
        next.previewGeneration = previous.previewGeneration +
          (previous.previewState === CatalogPreviewState.LOADING ? 1 : 0);
        next.previewRefreshPending = previous.previewRefreshPending;
        next.description = previous.description;
      }
      next.description = item.description.length > 0 ? item.description : next.description;
      this.previewEntriesById.set(item.itemId, next);
      projected.push(next);
    });
    this.entries = projected;
  }

  private onPreviewLoaded(entry: ScpCatalogEntry, preview: CatalogPreview): boolean {
    if (this.mountedEpoch <= 0 || !this.active) {
      return false;
    }
    if (this.previewEntriesById.get(entry.itemId) !== entry) {
      return false;
    }
    const description = preview.description.length > 0 ? preview.description : entry.description;
    // The preview contract distinguishes a valid no-image result from a
    // network/HTML failure.  Do not infer failure from an empty source alone.
    const nextState = preview.failed ? CatalogPreviewState.FAILED :
      (preview.path.length > 0 || preview.url.length > 0 ?
        CatalogPreviewState.READY : CatalogPreviewState.NO_IMAGE);
    if (entry.previewPath === preview.path && entry.previewUrl === preview.url &&
      entry.description === description && entry.previewState === nextState &&
      !entry.previewRefreshPending) {
      return true;
    }
    entry.previewPath = preview.path;
    entry.previewUrl = preview.url;
    entry.description = description;
    entry.previewState = nextState;
    entry.previewRefreshPending = false;
    return true;
  }

  private retry(): void {
    // Refresh is the single preview retry mechanism.  Clear every projected
    // result first so cards that remain mounted and cards entering later both
    // observe the same idle state.
    this.previewEntriesById.forEach((entry: ScpCatalogEntry): void => {
      entry.previewPath = '';
      entry.previewUrl = '';
      entry.previewState = CatalogPreviewState.IDLE;
      entry.previewGeneration++;
      entry.previewRefreshPending = true;
    });
    this.previewReloadToken++;
    this.viewModel.retry().catch((): void => {
      // The error is represented by the ViewModel snapshot.
    });
  }

  @Builder
  private topSpacer() {
    Blank().width('100%').height(pageContentTop() + CATALOG_TOOLBAR_HEIGHT);
  }

  @Builder
  private listHeader() {
    Column() {
      this.topSpacer();
      if (this.viewModel.errorMessage.length > 0 && this.viewModel.entries.length > 0) {
        this.partialBlock();
      }
    }
    .width('100%');
  }

  @Builder
  private catalogSkeletonCard(index: number) {
    Column() {
      Column({ space: 6 }) {
        // Preview images are intentionally absent here.  A catalog item starts
        // with its text geometry and grows only after a real image succeeds.
        SkeletonBlock({ animated: true, radius: 6 })
          .width(index % 2 === 0 ? '58%' : '72%')
          .height(14);
        SkeletonBlock({ animated: true, radius: 6 })
          .width(index % 2 === 0 ? '82%' : '68%')
          .height(15);
        SkeletonBlock({ animated: true, radius: 5 })
          .width(index % 2 === 0 ? '88%' : '74%')
          .height(10);
        SkeletonBlock({ animated: true, radius: 5 })
          .width(index % 2 === 0 ? '64%' : '52%')
          .height(10);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(12);
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true);
  }

  @Builder
  private loadingWaterfall() {
    ForEach([0, 1, 2, 3, 4, 5, 6, 7], (index: number) => {
      this.catalogSkeletonCard(index);
    }, (index: number) => `${index}`);
  }

  @Builder
  private errorBlock() {
    Column({ space: 12 }) {
      Text(this.viewModel.errorMessage.length > 0 ? this.viewModel.errorMessage : '目录加载失败')
        .fontSize(AppTypography.BODY_S)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })
      Button('重试', { stateEffect: false }).onClick(() => this.retry())
    }
    .width('100%')
    .margin({ top: STATE_TOP_OFFSET })
    .padding({ top: 40 })
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  private partialBlock() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(17)
        .fontColor([$r('sys.color.icon_secondary')])
      Text(this.viewModel.errorMessage.length > 0 ? this.viewModel.errorMessage :
        '目录更新失败，正在显示缓存内容')
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Button('重试', { stateEffect: false })
        .fontSize(AppTypography.CAPTION_L)
        .onClick(() => this.retry())
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(8)
  }

  @Builder
  private emptyBlock() {
    Column() {
      Text('无匹配条目')
        .fontSize(AppTypography.BODY_S)
        .fontColor($r('sys.color.font_tertiary'));
    }
    .width('100%')
    .margin({ top: STATE_TOP_OFFSET })
    .padding({ top: 40 })
    .justifyContent(FlexAlign.Center);
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Top }) {
        Refresh({ refreshing: this.viewModel.refreshing }) {
          Scroll(this.scroller) {
            LazyColumnLayout() {
              LazyVWaterFlowLayout() {
                if (this.viewModel.loading && this.entries.length === 0) {
                  this.loadingWaterfall();
                } else {
                  Repeat<ScpCatalogEntry>(this.entries)
                    .each((row: RepeatItem<ScpCatalogEntry>) => {
                      ScpCatalogCard({
                        entry: row.item,
                        loadPreview: this.previewLoader,
                        resolveLocalPreviewSource: this.resolveLocalPreviewSource,
                        refreshToken: this.previewReloadToken,
                        show3DModel: this.has3DModel(row.item.itemId),
                        readCompleted: this.isReadCompleted(row.item.itemId),
                        onOpen: (itemId: string, name: string) => this.onOpenArticle(itemId, name),
                        onPreviewLoaded: (loaded: ScpCatalogEntry, info: CatalogPreview) =>
                          this.onPreviewLoaded(loaded, info)
                      });
                    })
                    // The item id is the domain identity, but a title correction
                    // replaces the immutable ScpCatalogEntry object.  Include the
                    // title in the render key so ArkUI remounts the card and its
                    // onAppear-driven preview request for that replacement.
                    .key((entry: ScpCatalogEntry) =>
                      `${entry.itemId.length}:${entry.itemId}${entry.title.length}:${entry.title}`)
                    .virtualScroll();
                }
              }
              .columnsTemplate('1fr 1fr')
              .columnsGap(LengthMetrics.vp(12))
              .rowsGap(LengthMetrics.vp(12))
              .padding({ left: 16, right: 16, bottom: 160 });
            }
            .header(() => {
              this.listHeader();
            })
            .width('100%');
          }
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .layoutWeight(1)
          .width('100%');
        }
        .onRefreshing(() => this.retry())
        .layoutWeight(1)
        .width('100%');

        if (!this.viewModel.loading && this.viewModel.errorMessage.length > 0 &&
          this.viewModel.entries.length === 0 && this.entries.length === 0) {
          this.errorBlock();
        } else if (!this.viewModel.loading && this.entries.length === 0) {
          this.emptyBlock();
        }
      }
      .layoutWeight(1)
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'));
  }
}
