import { LengthMetrics, uiMaterial } from '@kit.ArkUI';
import {
  accentPillBackgroundColor,
  accentPillForegroundColor,
  adaptiveListLanesForWidth,
  adaptivePageMarginForWidth,
  AppMotion,
  AppTypography,
  CARD_PRESS_MODIFIER,
  materialCardBorderColor,
  materialCardSurfaceColor,
  PHONE_PAGE_MARGIN,
  pageContentTop,
  pressAnimation,
  ViewModelLoadState,
  WIDE_CONTENT_MAX_WIDTH,
  windowWidthVp
} from 'anomiconbasic';
import {
  CatalogEntry,
  CatalogTaleEntry
} from '../../domain/CatalogContracts';
import {
  CatalogDirectTarget,
  CatalogSearchTargetKind,
  resolveCatalogDirectTarget
} from '../../domain/CatalogDirectTarget';
import { ALL_SERIES_ID, isCnScpItemId } from '../../domain/ScpSeriesItem';
import { CatalogSearchViewModel } from '../viewmodel/CatalogSearchViewModel';
import { CatalogSeriesSelector } from './CatalogSeriesSelector';
import {
  CatalogSearchSelection,
  CatalogSearchSharedState,
  CatalogSearchViewContract
} from './SearchViewContracts';

const SEARCH_FIELD_HEIGHT: number = 40;
const UNIFIED_PREVIEW_CAP: number = 12;
/** 搜索页标题栏底部工具栏高度：搜索框 40vp + 间距 + 系列选择行。 */
export const CATALOG_SEARCH_HEADER_HEIGHT: number = 96;

enum SearchRowKind {
  DIRECT = 'direct',
  ARCHIVE = 'archive',
  TALE = 'tale',
  SHOW_MORE_ARCHIVES = 'show_more_archives',
  SHOW_MORE_TALES = 'show_more_tales'
}

class CatalogSearchDisplayRow {
  readonly kind: SearchRowKind;
  readonly key: string;
  readonly entry?: CatalogEntry;
  readonly tale?: CatalogTaleEntry;
  readonly direct?: CatalogDirectTarget;
  readonly actionLabel: string;

  constructor(
    kind: SearchRowKind,
    key: string,
    entry?: CatalogEntry,
    tale?: CatalogTaleEntry,
    direct?: CatalogDirectTarget,
    actionLabel: string = ''
  ) {
    this.kind = kind;
    this.key = key;
    this.entry = entry;
    this.tale = tale;
    this.direct = direct;
    this.actionLabel = actionLabel;
  }
}

/**
 * 搜索页标题栏底部工具栏：放入 HdsNavDestination.titleBar.bottomBuilder，
 * 使 Search 与系列胶囊处于系统沉浸材质作用域内。
 */
@ComponentV2
export struct CatalogSearchHeader {
  @Require @Param viewModel: CatalogSearchViewModel;
  @Require @Param sharedState: CatalogSearchSharedState;
  @Param materialEnabled: boolean = true;
  @Event onSubmitSelection: (selection: CatalogSearchSelection) => void =
    (_selection: CatalogSearchSelection): void => {};
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

  private submitSearch(value: string): void {
    this.applyQuery(value);
    const trimmed = value.trim();
    const direct = this.viewModel.snapshot.data?.directTarget ?? resolveCatalogDirectTarget(trimmed);
    if (direct !== undefined) {
      if (trimmed.length > 0) {
        this.viewModel.addHistory(trimmed);
      }
      this.onSubmitSelection(
        new CatalogSearchSelection(direct.kind, direct.itemId, direct.title, direct.anchor)
      );
      return;
    }
    if (trimmed.length > 0) {
      this.viewModel.addHistory(trimmed);
    }
  }

  build() {
    Column() {
      Column({ space: 8 }) {
        Search({
          placeholder: '搜索编号、标题、故事或 Wiki 链接',
          value: this.viewModel.snapshot.data?.query ?? ''
        })
          .height(SEARCH_FIELD_HEIGHT)
          .margin({ left: this.resolvedMargin(), right: this.resolvedMargin() })
          .backgroundColor(this.materialEnabled ?
            Color.Transparent : $r('sys.color.comp_background_primary'))
          .systemMaterial(this.materialEnabled ? this.searchBarMaterial : undefined)
          .placeholderColor($r('sys.color.font_secondary'))
          .accessibilityText('搜索编号、标题、故事或 Wiki 链接')
          .onChange((value: string) => this.applyQuery(value))
          .onSubmit((value: string) => this.submitSearch(value))

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
      .transition(AppMotion.fadeTransition(AppMotion.MICRO_DURATION))
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
 * remain in the product host. This View renders the unified SearchScreenData
 * (Main/CN archives, tales and direct targets) and emits structured selections.
 */
@ComponentV2
struct CatalogSearchContent {
  @Require @Param viewModel: CatalogSearchViewModel;
  @Require @Param scroller: Scroller;
  @Require @Param sharedState: CatalogSearchSharedState;
  @Require @Param onOpenContent: (selection: CatalogSearchSelection) => void;
  @Param materialEnabled: boolean = true;
  @Local private paneWidth: number = 0;
  @Local private resultFilter: number = 0;
  @Local private showAllArchives: boolean = false;
  @Local private showAllTales: boolean = false;
  @Local private resultsOverlayHeight: number = 0;

  private readonly pillMaterial: uiMaterial.ImmersiveMaterial = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN,
    applyShadow: false,
    interactive: true
  });

  @Monitor('viewModel.query', 'viewModel.seriesId')
  onQueryOrSeriesChange(): void {
    this.showAllArchives = false;
    this.showAllTales = false;
    if (this.viewModel.seriesId !== ALL_SERIES_ID) {
      this.resultFilter = 0;
    }
  }

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

  private isAllSeriesScope(): boolean {
    return (this.viewModel.snapshot.data?.seriesId ?? '') === ALL_SERIES_ID;
  }

  private effectiveResultFilter(): number {
    return this.isAllSeriesScope() ? this.resultFilter : 0;
  }

  private hasAnyQueryResults(): boolean {
    const data = this.viewModel.snapshot.data;
    return data?.directTarget !== undefined ||
      (data?.entries.length ?? 0) > 0 ||
      (data?.tales.length ?? 0) > 0;
  }

  private isLoadingAllSeries(): boolean {
    return this.isAllSeriesScope() &&
      (this.viewModel.snapshot.data?.allSeriesLoading ?? false);
  }

  private isLoadingTales(): boolean {
    return this.isAllSeriesScope() &&
      (this.viewModel.snapshot.data?.talesLoading ?? false);
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
    if (data?.seriesId === ALL_SERIES_ID &&
      ((data?.allSeriesLoading ?? false) || (data?.talesLoading ?? false))) {
      return data.loadedSeriesCount > 0 ?
        `正在检索全部系列与故事（已加载 ${data.loadedSeriesCount}/${data.totalSeriesCount}）…` :
        '正在加载全部系列与故事目录，请稍候…';
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
      (snapshot.data?.tales.length ?? 0) === 0 &&
      snapshot.data?.directTarget === undefined &&
      snapshot.error !== undefined;
  }

  private hasPartialError(): boolean {
    const snapshot = this.viewModel.snapshot;
    return (snapshot.state === ViewModelLoadState.ERROR ||
      snapshot.state === ViewModelLoadState.PARTIAL) &&
      ((snapshot.data?.entries.length ?? 0) > 0 ||
        (snapshot.data?.tales.length ?? 0) > 0 ||
        snapshot.data?.directTarget !== undefined) &&
      snapshot.error !== undefined;
  }

  private loadingProgressText(): string {
    const data = this.viewModel.snapshot.data;
    if (!this.isAllSeriesScope()) {
      return '';
    }
    if (data?.allSeriesLoading ?? false) {
      return `正在检索全部系列（已加载 ${data?.loadedSeriesCount ?? 0}/${data?.totalSeriesCount ?? 0}）…`;
    }
    if (data?.talesLoading ?? false) {
      return '正在同步故事目录…';
    }
    return '';
  }

  private hasResultsOverlay(): boolean {
    return this.isAllSeriesScope() ||
      this.hasPartialError() ||
      this.loadingProgressText().length > 0;
  }

  private resolvedResultsStartOffset(): number {
    const base = pageContentTop() + CATALOG_SEARCH_HEADER_HEIGHT;
    if (!this.hasResultsOverlay()) {
      return base + 6;
    }
    const overlayOffset = this.resultsOverlayHeight > 0 ? this.resultsOverlayHeight + 6 : 48;
    return base + overlayOffset;
  }

  private filterCountLabel(index: number): string {
    const data = this.viewModel.snapshot.data;
    const direct = data?.directTarget;
    const archiveCount = (data?.entries.length ?? 0) +
      (direct !== undefined && !direct.matched && direct.kind === CatalogSearchTargetKind.SCP ? 1 : 0);
    const taleCount = (data?.tales.length ?? 0) +
      (direct !== undefined && !direct.matched && direct.kind === CatalogSearchTargetKind.TALE ? 1 : 0);
    if (index === 0) {
      return '全部';
    }
    if (index === 1) {
      return archiveCount > 0 ? `档案 (${archiveCount})` : '档案';
    }
    return taleCount > 0 ? `故事 (${taleCount})` : '故事';
  }

  private selectResultFilter(index: number): void {
    if (this.resultFilter !== index) {
      this.resultFilter = index;
    }
  }

  @Computed
  get displayRows(): CatalogSearchDisplayRow[] {
    const data = this.viewModel.snapshot.data;
    if (data === undefined) {
      return [];
    }
    const filter = this.effectiveResultFilter();
    const direct = data.directTarget;
    const includeDirect = direct !== undefined && (
      filter === 0 ||
      (filter === 1 && direct.kind === CatalogSearchTargetKind.SCP) ||
      (filter === 2 && direct.kind === CatalogSearchTargetKind.TALE)
    );

    const rows: CatalogSearchDisplayRow[] = [];
    if (includeDirect && direct !== undefined) {
      rows.push(
        new CatalogSearchDisplayRow(
          SearchRowKind.DIRECT,
          `direct:${direct.kind}:${direct.itemId}:${direct.title}:${direct.anchor ?? ''}`,
          undefined,
          undefined,
          direct
        )
      );
    }

    const rawEntries = filter === 2 ? [] : data.entries;
    const filteredEntries: CatalogEntry[] = [];
    const dedupScpId = includeDirect && direct !== undefined && direct.matched &&
      direct.kind === CatalogSearchTargetKind.SCP ?
      direct.itemId.toUpperCase() : '';
    for (let index = 0; index < rawEntries.length; index++) {
      const entry = rawEntries[index];
      if (dedupScpId.length > 0 && entry.itemId.toUpperCase() === dedupScpId) {
        continue;
      }
      filteredEntries.push(entry);
    }

    const rawTales = filter === 1 || !this.isAllSeriesScope() ? [] : data.tales;
    const filteredTales: CatalogTaleEntry[] = [];
    const dedupTaleId = includeDirect && direct !== undefined && direct.matched &&
      direct.kind === CatalogSearchTargetKind.TALE ?
      direct.itemId.toLowerCase() : '';
    for (let index = 0; index < rawTales.length; index++) {
      const tale = rawTales[index];
      if (dedupTaleId.length > 0 && tale.id.toLowerCase() === dedupTaleId) {
        continue;
      }
      filteredTales.push(tale);
    }

    const shouldCapSections = filter === 0 &&
      filteredEntries.length > 0 &&
      filteredTales.length > 0;

    const archiveLimit = shouldCapSections && !this.showAllArchives ?
      Math.min(UNIFIED_PREVIEW_CAP, filteredEntries.length) : filteredEntries.length;
    for (let index = 0; index < archiveLimit; index++) {
      const entry = filteredEntries[index];
      rows.push(
        new CatalogSearchDisplayRow(SearchRowKind.ARCHIVE, `scp:${entry.itemId}`, entry)
      );
    }
    if (shouldCapSections && filteredEntries.length > UNIFIED_PREVIEW_CAP) {
      rows.push(
        new CatalogSearchDisplayRow(
          SearchRowKind.SHOW_MORE_ARCHIVES,
          `more:scp:${this.showAllArchives}`,
          undefined,
          undefined,
          undefined,
          this.showAllArchives ? '收起部分档案' : `展开全部 ${filteredEntries.length} 条档案`
        )
      );
    }

    const taleLimit = shouldCapSections && !this.showAllTales ?
      Math.min(UNIFIED_PREVIEW_CAP, filteredTales.length) : filteredTales.length;
    for (let index = 0; index < taleLimit; index++) {
      const tale = filteredTales[index];
      rows.push(
        new CatalogSearchDisplayRow(SearchRowKind.TALE, `tale:${tale.id}`, undefined, tale)
      );
    }
    if (shouldCapSections && filteredTales.length > UNIFIED_PREVIEW_CAP) {
      rows.push(
        new CatalogSearchDisplayRow(
          SearchRowKind.SHOW_MORE_TALES,
          `more:tale:${this.showAllTales}`,
          undefined,
          undefined,
          undefined,
          this.showAllTales ? '收起部分故事' : `展开全部 ${filteredTales.length} 篇故事`
        )
      );
    }

    return rows;
  }

  private categoryEmptyNotice(): string {
    if (this.displayRows.length > 0) {
      return '';
    }
    const filter = this.effectiveResultFilter();
    if (filter === 1) {
      return this.isLoadingAllSeries() ? '正在搜索档案目录…' : '当前检索词暂无匹配档案';
    }
    if (filter === 2) {
      return this.isLoadingTales() ? '正在加载故事目录…' : '当前检索词暂无匹配故事';
    }
    return '';
  }

  private directSecondaryBadge(direct: CatalogDirectTarget): string {
    if (direct.kind === CatalogSearchTargetKind.TALE) {
      return '故事';
    }
    return isCnScpItemId(direct.itemId) ? 'CN' : '';
  }

  private openDirectTarget(direct: CatalogDirectTarget): void {
    const query = this.viewModel.snapshot.data?.query ?? '';
    const historyValue = query.trim().length > 0 ? query.trim() : direct.itemId;
    this.viewModel.addHistory(historyValue);
    this.onOpenContent(
      new CatalogSearchSelection(direct.kind, direct.itemId, direct.title, direct.anchor)
    );
  }

  private openArchiveEntry(entry: CatalogEntry): void {
    const query = this.viewModel.snapshot.data?.query ?? '';
    const historyValue = query.trim().length > 0 ? query.trim() : entry.title;
    this.viewModel.addHistory(historyValue);
    this.onOpenContent(
      new CatalogSearchSelection(CatalogSearchTargetKind.SCP, entry.itemId, entry.title)
    );
  }

  private openTaleEntry(tale: CatalogTaleEntry): void {
    const query = this.viewModel.snapshot.data?.query ?? '';
    const historyValue = query.trim().length > 0 ? query.trim() : tale.title;
    this.viewModel.addHistory(historyValue);
    this.onOpenContent(
      new CatalogSearchSelection(CatalogSearchTargetKind.TALE, tale.id, tale.title)
    );
  }

  private handleShowMoreClick(kind: SearchRowKind): void {
    if (kind === SearchRowKind.SHOW_MORE_ARCHIVES) {
      this.showAllArchives = !this.showAllArchives;
      return;
    }
    if (kind === SearchRowKind.SHOW_MORE_TALES) {
      this.showAllTales = !this.showAllTales;
    }
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

  @Builder
  private filterPillButton(index: number) {
    Text(this.filterCountLabel(index))
      .fontSize(AppTypography.CAPTION_L)
      .fontWeight(this.resultFilter === index ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.resultFilter === index ?
        accentPillForegroundColor() : $r('sys.color.font_secondary'))
      .textAlign(TextAlign.Center)
      .height(30)
      .padding({ left: 12, right: 12 })
      .borderRadius(15)
      .backgroundColor(this.resultFilter === index ?
        accentPillBackgroundColor() :
        (this.materialEnabled ? Color.Transparent : $r('sys.color.comp_background_tertiary')))
      .systemMaterial(this.resultFilter !== index && this.materialEnabled ?
        this.pillMaterial : undefined)
      .onClick(() => this.selectResultFilter(index))
  }

  @Builder
  private resultsFilterBar() {
    Row({ space: 8 }) {
      this.filterPillButton(0)
      this.filterPillButton(1)
      this.filterPillButton(2)
    }
    .width('100%')
  }

  @Builder
  private directTargetCardRow(direct: CatalogDirectTarget) {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Text('直达')
          .fontSize(AppTypography.CAPTION_M)
          .fontWeight(FontWeight.Medium)
          .fontColor(accentPillForegroundColor())
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .borderRadius(8)
          .backgroundColor(accentPillBackgroundColor())
        if (this.directSecondaryBadge(direct).length > 0) {
          Text(this.directSecondaryBadge(direct))
            .fontSize(AppTypography.CAPTION_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(8)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
        }
        Text(direct.kind === CatalogSearchTargetKind.SCP ? direct.itemId : direct.title)
          .fontSize(AppTypography.BODY_S)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (direct.kind === CatalogSearchTargetKind.SCP && direct.title !== direct.itemId) {
          Text(direct.title)
            .fontSize(AppTypography.BODY_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          Blank().layoutWeight(1)
        }
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .width('100%')

      Text(direct.subtitle)
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .attributeModifier(CARD_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .constraintSize({ minHeight: 66 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 1, color: accentPillBackgroundColor() })
    .borderRadius(14)
    .onClick(() => this.openDirectTarget(direct))
  }

  @Builder
  private entryCardRow(entry: CatalogEntry) {
    Column({ space: 3 }) {
      Row({ space: 8 }) {
        if (isCnScpItemId(entry.itemId)) {
          Text('CN')
            .fontSize(AppTypography.CAPTION_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
            .padding({ left: 6, right: 6, top: 1, bottom: 1 })
            .borderRadius(7)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
        }
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
    .animation(pressAnimation())
    .width('100%')
    .constraintSize({ minHeight: 62 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .onClick(() => this.openArchiveEntry(entry))
  }

  @Builder
  private taleCardRow(tale: CatalogTaleEntry) {
    Column({ space: 3 }) {
      Row({ space: 8 }) {
        Text('故事')
          .fontSize(AppTypography.CAPTION_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 6, right: 6, top: 1, bottom: 1 })
          .borderRadius(7)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
        Text(tale.title)
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

      Text(`/${tale.id}`)
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .attributeModifier(CARD_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .constraintSize({ minHeight: 62 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .onClick(() => this.openTaleEntry(tale))
  }

  @Builder
  private showMoreRow(row: CatalogSearchDisplayRow) {
    Row({ space: 6 }) {
      Text(row.actionLabel)
        .fontSize(AppTypography.BODY_S)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
      SymbolGlyph($r('sys.symbol.chevron_down'))
        .fontSize(13)
        .fontColor([$r('sys.color.icon_secondary')])
    }
    .width('100%')
    .height(42)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(12)
    .onClick(() => this.handleShowMoreClick(row.kind))
  }

  @Builder
  private displayRowItem(row: CatalogSearchDisplayRow) {
    if (row.kind === SearchRowKind.DIRECT && row.direct !== undefined) {
      this.directTargetCardRow(row.direct)
    } else if (row.kind === SearchRowKind.ARCHIVE && row.entry !== undefined) {
      this.entryCardRow(row.entry)
    } else if (row.kind === SearchRowKind.TALE && row.tale !== undefined) {
      this.taleCardRow(row.tale)
    } else if (row.kind === SearchRowKind.SHOW_MORE_ARCHIVES ||
      row.kind === SearchRowKind.SHOW_MORE_TALES) {
      this.showMoreRow(row)
    }
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

  @Builder
  private resultsContent() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.categoryEmptyNotice().length > 0) {
        Column() {
          Text(this.categoryEmptyNotice())
            .fontSize(AppTypography.BODY_S)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')
        .height('100%')
        .padding({
          left: this.horizontalMargin(),
          right: this.horizontalMargin(),
          top: this.resolvedResultsStartOffset() + 48
        })
        .alignItems(HorizontalAlign.Center)
      } else {
        List({ scroller: this.scroller, space: 10 }) {
          Repeat<CatalogSearchDisplayRow>(this.displayRows)
            .each((row: RepeatItem<CatalogSearchDisplayRow>) => {
              ListItem() {
                this.displayRowItem(row.item)
              }
            })
            .key((row: CatalogSearchDisplayRow) => row.key)
            .virtualScroll({ reusable: false })
        }
        .lanes(this.listLanes(), 12)
        .contentStartOffset(this.resolvedResultsStartOffset())
        .contentEndOffset(32)
        .padding({ left: this.horizontalMargin(), right: this.horizontalMargin() })
        .clip(false)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }

      if (this.hasResultsOverlay()) {
        Column({ space: 6 }) {
          if (this.isAllSeriesScope()) {
            this.resultsFilterBar()
          }
          if (this.hasPartialError()) {
            this.partialErrorContent()
          }
          if (this.loadingProgressText().length > 0) {
            Text(this.loadingProgressText())
              .fontSize(AppTypography.CAPTION_M)
              .fontColor($r('sys.color.font_tertiary'))
              .width('100%')
          }
        }
        .width('100%')
        .margin({ top: pageContentTop() + CATALOG_SEARCH_HEADER_HEIGHT })
        .padding({
          left: this.horizontalMargin(),
          right: this.horizontalMargin(),
          top: 6,
          bottom: 8
        })
        .backgroundColor($r('sys.color.background_secondary'))
        .onAreaChange((_oldArea: Area, newArea: Area): void => {
          const height = Number(newArea.height);
          if (Number.isFinite(height) && height >= 0 &&
            Math.abs(height - this.resultsOverlayHeight) > 0.5) {
            this.resultsOverlayHeight = height;
          }
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
      } else if (!this.hasAnyQueryResults()) {
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
