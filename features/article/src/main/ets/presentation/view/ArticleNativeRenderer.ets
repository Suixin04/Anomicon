import { LengthMetrics, uiMaterial } from '@kit.ArkUI';
import {
  accentPillBackgroundColor,
  accentPillForegroundColor,
  adaptivePageMarginForWidth,
  AppMotion,
  AppTypography,
  autoOpenArticleSidePanel,
  badgeInfoBackgroundColor,
  CARD_PRESS_MODIFIER,
  ContentUpdateNotice,
  isDarkModeActive,
  isReduceMotionEnabled,
  materialCardBorderColor,
  materialCardSurfaceColor,
  objectClassColor,
  PHONE_PAGE_MARGIN,
  pressAnimation,
  READING_CONTENT_MAX_WIDTH,
  resolveArticleSidebarWidth,
  ROW_PRESS_MODIFIER,
  shouldUseCenterSheet,
  supportsArticleSidePanel,
  uiImmersiveMaterialSupported,
  windowWidthVp
} from 'anomiconbasic';
import {
  ArticleRelatedTale,
  ArticleRelatedTaleSource
} from '../../domain/ArticleContracts';
import {
  ArticleOfflineSnapshot,
  normalizeOfflineImageUrl
} from '../../domain/ArticleOfflineContracts';
import {
  ScpArticleDocument,
  ScpBlockType,
  ScpCalloutTone,
  ScpContentBlock,
  ScpFootnote,
  ScpHiddenTextKind,
  ScpTextAlign,
  ScpTextSpan,
  ScpTextStyle
} from '../../domain/ScpDocument';
import {
  ArticleBlockLocation,
  ArticleIndexSectionInput,
  ArticleNavigationIndex,
  ArticleSearchHit,
  ArticleTocItem,
  ArticleTocKind,
  buildArticleNavigationIndex,
  normalizeArticleAnchor,
  resolveAnchorLocation,
  searchArticleDocument,
  splitTextForSearchHighlight
} from '../../domain/ArticleNavigation';
import { ArticleRenderer, FootnoteSheetHeader } from './ArticleRenderer';
import { ScpArticleImage } from './ScpArticleImage';
import {
  LibraryContentKind,
  StorySeriesArticleContext,
  StorySeriesEntry,
  StorySeriesGroup,
  StorySeriesTier
} from 'library';

/**
 * Stable presentation identity for one inline span.
 *
 * The document model is immutable and stale-while-revalidate replaces it with
 * a new object graph.  Keeping the structural key stable while tracing the
 * current value lets ArkUI update text/link attributes without rebuilding the
 * surrounding article block.
 */
@ObservedV2
class ArticleSpanRowState {
  readonly key: string;
  @Trace span: ScpTextSpan;

  constructor(key: string, span: ScpTextSpan) {
    this.key = key;
    this.span = span;
  }

  sync(span: ScpTextSpan): void {
    if (this.span !== span) {
      this.span = span;
    }
  }
}

/** Recursive stable row used by top-level and nested article blocks. */
@ObservedV2
class ArticleBlockRowState {
  readonly key: string;
  @Trace block: ScpContentBlock;
  @Trace index: number;
  @Trace activeTabIndex: number = 0;
  @Trace spans: ArticleSpanRowState[] = [];
  @Trace children: ArticleBlockRowState[] = [];

  constructor(block: ScpContentBlock, index: number) {
    this.key = block.key;
    this.block = block;
    this.index = index;
    this.spans = syncArticleSpanRows([], block.key, block.spans);
    this.children = syncArticleBlockRows([], block.children);
  }

  sync(block: ScpContentBlock, index: number): void {
    if (this.block !== block) {
      this.block = block;
    }
    if (this.index !== index) {
      this.index = index;
    }
    const nextSpans = syncArticleSpanRows(this.spans, block.key, block.spans);
    if (!sameArticleSpanRows(this.spans, nextSpans)) {
      this.spans = nextSpans;
    }
    const nextChildren = syncArticleBlockRows(this.children, block.children);
    if (!sameArticleBlockRows(this.children, nextChildren)) {
      this.children = nextChildren;
    }
    if (this.children.length > 0 && this.activeTabIndex >= this.children.length) {
      this.activeTabIndex = 0;
    }
  }
}

@ObservedV2
class ArticleFootnoteRowState {
  readonly key: string;
  @Trace footnote: ScpFootnote;
  @Trace index: number;
  @Trace blocks: ArticleBlockRowState[] = [];

  constructor(footnote: ScpFootnote, index: number) {
    this.key = footnote.id;
    this.footnote = footnote;
    this.index = index;
    this.blocks = syncArticleBlockRows([], footnote.blocks);
  }

  sync(footnote: ScpFootnote, index: number): void {
    if (this.footnote !== footnote) {
      this.footnote = footnote;
    }
    if (this.index !== index) {
      this.index = index;
    }
    const nextBlocks = syncArticleBlockRows(this.blocks, footnote.blocks);
    if (!sameArticleBlockRows(this.blocks, nextBlocks)) {
      this.blocks = nextBlocks;
    }
  }
}

@ObservedV2
class ArticleRelatedTaleRowState {
  readonly key: string;
  @Trace tale: ArticleRelatedTale;

  constructor(tale: ArticleRelatedTale) {
    this.key = tale.id;
    this.tale = tale;
  }

  sync(tale: ArticleRelatedTale): void {
    if (this.tale !== tale) {
      this.tale = tale;
    }
  }
}

function sameArticleSpanRows(before: ArticleSpanRowState[], after: ArticleSpanRowState[]): boolean {
  if (before.length !== after.length) {
    return false;
  }
  for (let index: number = 0; index < before.length; index++) {
    if (before[index] !== after[index]) {
      return false;
    }
  }
  return true;
}

function sameArticleBlockRows(before: ArticleBlockRowState[], after: ArticleBlockRowState[]): boolean {
  if (before.length !== after.length) {
    return false;
  }
  for (let index: number = 0; index < before.length; index++) {
    if (before[index] !== after[index]) {
      return false;
    }
  }
  return true;
}

function sameArticleFootnoteRows(
  before: ArticleFootnoteRowState[],
  after: ArticleFootnoteRowState[]
): boolean {
  if (before.length !== after.length) {
    return false;
  }
  for (let index: number = 0; index < before.length; index++) {
    if (before[index] !== after[index]) {
      return false;
    }
  }
  return true;
}

function sameArticleRelatedTaleRows(
  before: ArticleRelatedTaleRowState[],
  after: ArticleRelatedTaleRowState[]
): boolean {
  if (before.length !== after.length) {
    return false;
  }
  for (let index: number = 0; index < before.length; index++) {
    if (before[index] !== after[index]) {
      return false;
    }
  }
  return true;
}

function syncArticleSpanRows(
  previous: ArticleSpanRowState[],
  blockKey: string,
  spans: ScpTextSpan[]
): ArticleSpanRowState[] {
  const next: ArticleSpanRowState[] = [];
  const previousByKey: Map<string, ArticleSpanRowState> = new Map();
  for (let index: number = 0; index < previous.length; index++) {
    previousByKey.set(previous[index].key, previous[index]);
  }
  for (let index: number = 0; index < spans.length; index++) {
    const key = `${blockKey}:span:${index}`;
    let row: ArticleSpanRowState | undefined = previousByKey.get(key);
    if (row === undefined) {
      row = new ArticleSpanRowState(key, spans[index]);
    } else {
      row.sync(spans[index]);
    }
    next.push(row);
  }
  return next;
}

function syncArticleBlockRows(
  previous: ArticleBlockRowState[],
  blocks: ScpContentBlock[]
): ArticleBlockRowState[] {
  const next: ArticleBlockRowState[] = [];
  const previousByKey: Map<string, ArticleBlockRowState> = new Map();
  for (let index: number = 0; index < previous.length; index++) {
    previousByKey.set(previous[index].key, previous[index]);
  }
  for (let index: number = 0; index < blocks.length; index++) {
    const block = blocks[index];
    let row: ArticleBlockRowState | undefined = previousByKey.get(block.key);
    if (row === undefined) {
      row = new ArticleBlockRowState(block, index);
    } else {
      row.sync(block, index);
    }
    next.push(row);
  }
  return next;
}

function indexBlockRowsRecursive(
  rows: ArticleBlockRowState[],
  output: Map<string, ArticleBlockRowState>
): void {
  for (let index: number = 0; index < rows.length; index++) {
    const row = rows[index];
    output.set(row.key, row);
    if (row.children.length > 0) {
      indexBlockRowsRecursive(row.children, output);
    }
  }
}

function syncArticleFootnoteRows(
  previous: ArticleFootnoteRowState[],
  footnotes: ScpFootnote[]
): ArticleFootnoteRowState[] {
  const next: ArticleFootnoteRowState[] = [];
  const previousByKey: Map<string, ArticleFootnoteRowState> = new Map();
  for (let index: number = 0; index < previous.length; index++) {
    previousByKey.set(previous[index].key, previous[index]);
  }
  for (let index: number = 0; index < footnotes.length; index++) {
    const footnote = footnotes[index];
    let row: ArticleFootnoteRowState | undefined = previousByKey.get(footnote.id);
    if (row === undefined) {
      row = new ArticleFootnoteRowState(footnote, index);
    } else {
      row.sync(footnote, index);
    }
    next.push(row);
  }
  return next;
}

function syncArticleRelatedTaleRows(
  previous: ArticleRelatedTaleRowState[],
  tales: ArticleRelatedTale[]
): ArticleRelatedTaleRowState[] {
  const next: ArticleRelatedTaleRowState[] = [];
  const previousByKey: Map<string, ArticleRelatedTaleRowState> = new Map();
  for (let index: number = 0; index < previous.length; index++) {
    previousByKey.set(previous[index].key, previous[index]);
  }
  for (let index: number = 0; index < tales.length; index++) {
    const tale = tales[index];
    let row: ArticleRelatedTaleRowState | undefined = previousByKey.get(tale.id);
    if (row === undefined) {
      row = new ArticleRelatedTaleRowState(tale);
    } else {
      row.sync(tale);
    }
    next.push(row);
  }
  return next;
}

enum ArticleSectionKind {
  PARTIAL_NOTICE = 0,
  HEADER_CARD = 1,
  GALLERY = 2,
  BLOCK = 3,
  QUOTE_CHILD = 4,
  FOOTNOTES_HEADER = 5,
  FOOTNOTE = 6,
  RELATED_TALES = 7,
  FOOTER = 8,
  WEB_RECOMMEND_BANNER = 9,
  CALLOUT_CHILD = 10,
  SERIES_HUB_HEADER = 11,
  SERIES_FOOTER = 12
}

enum ArticleSheetMode {
  NONE = 0,
  FOOTNOTE = 1,
  TOC = 2,
  SERIES_CHECKLIST = 3
}

class WorkbenchTab {
  static readonly FOOTNOTES: number = 0;
  static readonly RELATED_TALES: number = 1;
  static readonly TOC: number = 2;
}

class SearchRenderSpanSlice {
  readonly key: string;
  readonly spanRow: ArticleSpanRowState;
  readonly text: string;
  readonly isSearchMatch: boolean;

  constructor(
    key: string,
    spanRow: ArticleSpanRowState,
    text: string,
    isSearchMatch: boolean
  ) {
    this.key = key;
    this.spanRow = spanRow;
    this.text = text;
    this.isSearchMatch = isSearchMatch;
  }
}

@ObservedV2
class ArticleSectionRow {
  readonly key: string;
  readonly kind: ArticleSectionKind;
  readonly weight: number;
  @Trace blockRow: ArticleBlockRowState | undefined;
  @Trace footnoteRow: ArticleFootnoteRowState | undefined;
  @Trace quoteFirst: boolean;
  @Trace quoteLast: boolean;
  @Trace bottomGap: number;
  @Trace calloutTone: ScpCalloutTone;

  constructor(
    key: string,
    kind: ArticleSectionKind,
    weight: number,
    blockRow: ArticleBlockRowState | undefined = undefined,
    footnoteRow: ArticleFootnoteRowState | undefined = undefined,
    quoteFirst: boolean = false,
    quoteLast: boolean = false,
    bottomGap: number = 16,
    calloutTone: ScpCalloutTone = ScpCalloutTone.NEUTRAL
  ) {
    this.key = key;
    this.kind = kind;
    this.weight = weight;
    this.blockRow = blockRow;
    this.footnoteRow = footnoteRow;
    this.quoteFirst = quoteFirst;
    this.quoteLast = quoteLast;
    this.bottomGap = bottomGap;
    this.calloutTone = calloutTone;
  }

  sync(
    blockRow: ArticleBlockRowState | undefined,
    footnoteRow: ArticleFootnoteRowState | undefined,
    quoteFirst: boolean,
    quoteLast: boolean,
    bottomGap: number,
    calloutTone: ScpCalloutTone = ScpCalloutTone.NEUTRAL
  ): void {
    if (this.blockRow !== blockRow) {
      this.blockRow = blockRow;
    }
    if (this.footnoteRow !== footnoteRow) {
      this.footnoteRow = footnoteRow;
    }
    if (this.quoteFirst !== quoteFirst) {
      this.quoteFirst = quoteFirst;
    }
    if (this.quoteLast !== quoteLast) {
      this.quoteLast = quoteLast;
    }
    if (this.bottomGap !== bottomGap) {
      this.bottomGap = bottomGap;
    }
    if (this.calloutTone !== calloutTone) {
      this.calloutTone = calloutTone;
    }
  }
}

function sameArticleSectionRows(before: ArticleSectionRow[], after: ArticleSectionRow[]): boolean {
  if (before.length !== after.length) {
    return false;
  }
  for (let index: number = 0; index < before.length; index++) {
    if (before[index] !== after[index]) {
      return false;
    }
  }
  return true;
}

function hasInlineImages(blocks: ScpContentBlock[]): boolean {
  for (let index: number = 0; index < blocks.length; index++) {
    if (blocks[index].type === ScpBlockType.IMAGE) {
      return true;
    }
    if (hasInlineImages(blocks[index].children)) {
      return true;
    }
  }
  return false;
}

function measureBlockWeight(block: ScpContentBlock): number {
  if (block.type === ScpBlockType.IMAGE) {
    return 240;
  }
  if (block.type === ScpBlockType.ACS_HEADER) {
    return 150;
  }
  if (block.type === ScpBlockType.EMBED) {
    return 120;
  }
  if (block.type === ScpBlockType.TABS && block.children.length > 0) {
    return measureBlockWeight(block.children[0]) + 48;
  }
  let textLen: number = block.caption.length;
  for (let index: number = 0; index < block.spans.length; index++) {
    textLen += block.spans[index].text.length;
  }
  for (let index: number = 0; index < block.children.length; index++) {
    textLen += measureBlockWeight(block.children[index]);
  }
  return Math.max(40, textLen);
}

function measureFootnoteWeight(footnote: ScpFootnote): number {
  let total: number = 24;
  for (let index: number = 0; index < footnote.blocks.length; index++) {
    total += measureBlockWeight(footnote.blocks[index]);
  }
  return Math.max(60, total);
}

/**
 * Device-independent native article body.
 *
 * The product route owns navigation, compatibility extraction, and system
 * effects. This component owns the virtualized List body and ephemeral renderer
 * state (gallery position and footnote anchors).
 */
@ComponentV2
export struct ArticleNativeRenderer {
  @Require @Param scroller: Scroller;
  @Require @Param document: ScpArticleDocument;
  @Require @Param expandedKeys: string[];
  @Require @Param relatedTales: ArticleRelatedTale[];
  @Require @Param fontSize: number;
  @Require @Param lineHeightMultiple: number;
  @Param topPadding: number = 0;
  @Param partialNoticeVisible: boolean = false;
  @Param partialRefreshing: boolean = false;
  @Param partialUpdateFailed: boolean = false;
  @Param galleryAfterBody: boolean = false;
  /** Index selected when the product-owned full-screen preview closes. */
  @Param galleryReturnIndex: number = 0;
  /** Monotonic token that makes repeated returns to the same index observable. */
  @Param galleryReturnEpoch: number = 0;
  @Param materialEnabled: boolean = true;
  @Param sidePanelOpen: boolean = false;
  @Param revealHiddenText: boolean = false;
  @Param justifyBodyText: boolean = true;
  @Param webModeHint: string = '';
  @Param targetAnchor: string = '';
  @Param targetAnchorEpoch: number = 0;
  @Param tocOpenEpoch: number = 0;
  @Param searchBarOpen: boolean = false;
  @Param completed: boolean = false;
  @Param offlineSnapshot: ArticleOfflineSnapshot | undefined = undefined;
  @Param offlineRevision: number = 0;
  @Param seriesContext: StorySeriesArticleContext | undefined = undefined;
  @Param seriesRevision: number = 0;
  @Param seriesChecklistOpenEpoch: number = 0;
  @Param isSeriesEntryCompleted: (entryId: string) => boolean = (_entryId: string): boolean => false;

  @Event onStartSeries: (seriesId: string) => void = (_seriesId: string): void => {};
  @Event onOpenSeriesEntry: (entry: StorySeriesEntry, markCurrentCompleted: boolean) => void =
    (_entry: StorySeriesEntry, _markCurrentCompleted: boolean): void => {};
  @Event onOpenSeriesHub: (hubId: string, title: string) => void =
    (_hubId: string, _title: string): void => {};

  @Event onRetryPartial: () => void = () => {};
  @Event onToggleCompleted: () => void = () => {};
  @Event onBottomPullHaptic: () => void = () => {};
  @Event onHiddenRevealInteraction: () => void = () => {};
  @Event onSwitchToWebMode: () => void = () => {};
  @Event onReadingProgressChange: (percent: number) => void = (_percent: number) => {};
  @Event onAnchorJump: () => void = () => {};
  @Event onScrollDidScroll: () => void = () => {};
  @Event onScrollStart: () => void = () => {};
  @Event onScrollStop: () => void = () => {};
  @Event onOpenUrl: (url: string) => void;
  /** Open a readable same-site article through the product route. */
  @Event onOpenArticleLink: (url: string, title: string) => void;
  @Event onOpenImage: (index: number) => void;
  @Event onToggleExpanded: (block: ScpContentBlock) => void;
  @Event onEnsureExpanded: (keysToToggle: string[]) => void = () => {};
  @Event onOpenRelatedTale: (tale: ArticleRelatedTale) => void;
  @Event onContentLaidOut: () => void;
  @Event onSidePanelAvailabilityChange: (available: boolean, label: string) => void =
    (_available: boolean, _label: string): void => {};
  @Event onSidePanelOpenChange: (open: boolean) => void = (_open: boolean): void => {};
  @Event onTocAvailabilityChange: (count: number) => void = (_count: number): void => {};
  @Event onSearchBarOpenChange: (open: boolean) => void = (_open: boolean): void => {};
  @Event onAnchorNotFound: (anchor: string) => void = (_anchor: string): void => {};

  @Local private galleryIndex: number = 0;
  @Local private sectionRows: ArticleSectionRow[] = [];
  @Local private blockRows: ArticleBlockRowState[] = [];
  @Local private imageRows: ArticleBlockRowState[] = [];
  @Local private footnoteRows: ArticleFootnoteRowState[] = [];
  @Local private relatedTaleRows: ArticleRelatedTaleRowState[] = [];
  @Local private tocItems: ArticleTocItem[] = [];
  @Local private tocFilterQuery: string = '';
  @Local private searchQuery: string = '';
  @Local private searchHits: ArticleSearchHit[] = [];
  @Local private activeSearchHitIndex: number = -1;
  @Local private visibleSectionIndex: number = 0;
  @Local private highlightedAnchorKey: string = '';
  @Local private highlightOpacity: number = 0;
  @Local private sheetMode: ArticleSheetMode = ArticleSheetMode.NONE;
  @Local private activeFootnoteIndex: number = -1;
  @Local private containerWidth: number = 0;
  @Local private activeWorkbenchTab: number = WorkbenchTab.FOOTNOTES;
  @Local private userClosedSidePanel: boolean = false;
  @Local private revealedHiddenKeys: string[] = [];
  @Local private expandAllRelatedTales: boolean = false;
  @Local private bottomPullProgress: number = 0;
  @Local private bottomPullReady: boolean = false;
  private readonly galleryController: SwiperController = new SwiperController();
  private readonly footnoteSheetScroller: Scroller = new Scroller();
  private readonly tocSheetScroller: Scroller = new Scroller();
  private readonly seriesChecklistScroller: Scroller = new Scroller();
  private readonly sidePanelScroller: Scroller = new Scroller();
  private readonly sidePanelTocScroller: Scroller = new Scroller();
  private readonly sheetDetents: [SheetSize, SheetSize, SheetSize] =
    [SheetSize.FIT_CONTENT, SheetSize.MEDIUM, SheetSize.LARGE];
  private readonly tocSheetDetents: [SheetSize, SheetSize] =
    [SheetSize.MEDIUM, SheetSize.LARGE];
  private readonly longTocSheetDetents: [SheetSize, SheetSize] =
    [SheetSize.LARGE, SheetSize.MEDIUM];
  private readonly footnoteSheetMaterial: uiMaterial.ImmersiveMaterial =
    new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THICK,
      applyShadow: true
    });
  private lastDocumentItemId: string = '';
  private lastNotifiedAvailabilityKey: string = '';
  private lastNotifiedTocCount: number = -1;
  private viewportHeight: number = 0;
  private visibleStartIndex: number = -1;
  private visibleEndIndex: number = -1;
  private lastReportedPercent: number = -1;
  private cumulativeWeights: number[] = [0];
  private totalWeight: number = 0;
  private readonly footnoteSectionById: Map<string, number> = new Map();
  private readonly blockRowByKey: Map<string, ArticleBlockRowState> = new Map();
  private navigationIndex: ArticleNavigationIndex =
    new ArticleNavigationIndex(new Map(), new Map(), []);
  private highlightTimer: number = -1;
  private pendingAnchorTimer: number = -1;
  private afterAnchorLayout: (() => void) | undefined = undefined;
  private pendingRouteAnchor: string = '';
  private hasLaidOutCurrentDoc: boolean = false;
  private readonly bottomPullTriggerVp: number = 72;
  private bottomPullTracking: boolean = false;
  private bottomPullAnchorY: number = 0;
  private bottomPullLastY: number = 0;

  aboutToAppear(): void {
    this.syncDocumentAndSections();
    this.lastDocumentItemId = this.document.itemId;
    this.syncWorkbenchTabDefault();
    this.syncSidePanelAvailability();
    if (this.targetAnchor.trim().length > 0) {
      this.pendingRouteAnchor = normalizeArticleAnchor(this.targetAnchor);
    }
  }

  aboutToDisappear(): void {
    this.clearHighlightTimer();
    this.clearPendingAnchorTimer();
    this.closeSheet();
  }

  @Monitor('document')
  onDocumentChange(): void {
    const sameItem = this.lastDocumentItemId.length > 0 &&
      this.lastDocumentItemId === this.document.itemId;
    const activeId = (sameItem && (this.sheetMode === ArticleSheetMode.FOOTNOTE || this.sidePanelOpen)) ?
      (this.currentFootnoteRow()?.footnote.id ?? '') : '';
    const previousIndex = this.activeFootnoteIndex;

    if (!sameItem) {
      this.userClosedSidePanel = false;
      this.revealedHiddenKeys = [];
      this.expandAllRelatedTales = false;
      this.tocFilterQuery = '';
      this.searchQuery = '';
      this.searchHits = [];
      this.activeSearchHitIndex = -1;
      this.hasLaidOutCurrentDoc = false;
      this.visibleSectionIndex = 0;
    }
    this.clearHighlightTimer();
    this.clearPendingAnchorTimer();
    this.highlightedAnchorKey = '';
    this.highlightOpacity = 0;
    this.galleryIndex = 0;
    this.visibleStartIndex = -1;
    this.visibleEndIndex = -1;
    this.lastReportedPercent = -1;
    this.resetBottomPullState();
    this.syncDocumentAndSections();
    this.lastDocumentItemId = this.document.itemId;
    if (this.searchBarOpen && this.searchQuery.trim().length > 0) {
      this.updateSearchResults(this.searchQuery, false);
    }
    if (this.shouldRenderGallerySection()) {
      try {
        this.galleryController.changeIndex(0, false);
      } catch (_error) {
      }
    }
    this.syncWorkbenchTabDefault();

    if (sameItem && (this.sheetMode === ArticleSheetMode.FOOTNOTE || this.sidePanelOpen) &&
      this.footnoteRows.length > 0) {
      const remapped = activeId.length > 0 ?
        ArticleRenderer.findFootnoteIndex(this.document.footnotes, activeId) : -1;
      if (remapped >= 0) {
        this.activeFootnoteIndex = remapped;
      } else if (previousIndex >= 0) {
        this.activeFootnoteIndex = Math.max(
          0,
          Math.min(previousIndex, this.footnoteRows.length - 1)
        );
      }
    } else if (!sameItem ||
      (this.sheetMode === ArticleSheetMode.FOOTNOTE && this.footnoteRows.length === 0) ||
      (this.sheetMode === ArticleSheetMode.TOC && this.tocItems.length === 0)) {
      this.closeSheet();
    }
    this.syncSidePanelAvailability();
    this.tryFlushPendingRouteAnchor();
  }

  @Monitor('relatedTales', 'partialNoticeVisible', 'galleryAfterBody', 'webModeHint', 'seriesContext', 'seriesRevision')
  onLayoutInputsChange(): void {
    this.syncDocumentAndSections();
    this.syncWorkbenchTabDefault();
    this.syncSidePanelAvailability();
  }

  @Monitor('seriesChecklistOpenEpoch')
  onSeriesChecklistOpenRequested(): void {
    if (this.seriesChecklistOpenEpoch <= 0 || this.seriesContext === undefined) {
      return;
    }
    this.sheetMode = ArticleSheetMode.SERIES_CHECKLIST;
  }

  @Monitor('targetAnchorEpoch')
  onTargetAnchorRequested(): void {
    const normalized = normalizeArticleAnchor(this.targetAnchor);
    if (normalized.length === 0) {
      return;
    }
    this.pendingRouteAnchor = normalized;
    this.tryFlushPendingRouteAnchor();
  }

  @Monitor('tocOpenEpoch')
  onTocOpenRequested(): void {
    if (this.tocOpenEpoch <= 0 || this.tocItems.length === 0) {
      return;
    }
    if (this.canUseSidePanel()) {
      this.userClosedSidePanel = false;
      this.activeWorkbenchTab = WorkbenchTab.TOC;
      this.sheetMode = ArticleSheetMode.NONE;
      if (!this.sidePanelOpen) {
        this.getUIContext().animateTo(AppMotion.layoutAnimateParam(), (): void => {
          this.onSidePanelOpenChange(true);
        });
      }
      return;
    }
    this.tocFilterQuery = '';
    this.sheetMode = ArticleSheetMode.TOC;
  }

  @Monitor('searchBarOpen')
  onSearchBarOpenChanged(): void {
    if (!this.searchBarOpen) {
      this.searchQuery = '';
      this.searchHits = [];
      this.activeSearchHitIndex = -1;
    }
  }

  @Monitor('sidePanelOpen')
  onExternalSidePanelOpenChange(): void {
    if (this.sidePanelOpen) {
      this.userClosedSidePanel = false;
      this.sheetMode = ArticleSheetMode.NONE;
    } else if (this.canUseSidePanel()) {
      this.userClosedSidePanel = true;
    }
  }

  @Monitor('galleryReturnEpoch')
  onGalleryReturn(): void {
    if (this.document.images.length === 0 || !this.shouldRenderGallerySection()) {
      return;
    }
    const next = Math.max(0, Math.min(this.galleryReturnIndex, this.document.images.length - 1));
    this.galleryIndex = next;
    try {
      this.galleryController.changeIndex(next, false);
    } catch (_error) {
    }
  }

  private shouldRenderGallerySection(): boolean {
    return !hasInlineImages(this.document.blocks) && this.document.images.length > 0;
  }

  private imageIndexOf(url: string): number {
    const trimmed = url.trim();
    if (trimmed.length === 0) {
      return -1;
    }
    for (let index: number = 0; index < this.document.images.length; index++) {
      if (this.document.images[index].source.trim() === trimmed) {
        return index;
      }
    }
    return -1;
  }

  private syncDocumentAndSections(): void {
    const baseBlocks = this.document.blocks.slice();
    if (this.document.creditBlocks.length > 0) {
      baseBlocks.push(new ScpContentBlock(
        `${this.document.itemId}:__credits__`,
        ScpBlockType.COLLAPSIBLE,
        [],
        '',
        '著作信息',
        0,
        this.document.creditBlocks,
        '收起著作信息',
        false
      ));
    }
    const nextBlocks = syncArticleBlockRows(this.blockRows, baseBlocks);
    if (!sameArticleBlockRows(this.blockRows, nextBlocks)) {
      this.blockRows = nextBlocks;
    }
    this.blockRowByKey.clear();
    indexBlockRowsRecursive(this.blockRows, this.blockRowByKey);
    const nextImages = syncArticleBlockRows(this.imageRows, this.document.images);
    if (!sameArticleBlockRows(this.imageRows, nextImages)) {
      this.imageRows = nextImages;
    }
    const nextFootnotes = syncArticleFootnoteRows(this.footnoteRows, this.document.footnotes);
    if (!sameArticleFootnoteRows(this.footnoteRows, nextFootnotes)) {
      this.footnoteRows = nextFootnotes;
    }
    for (const row of this.footnoteRows) {
      indexBlockRowsRecursive(row.blocks, this.blockRowByKey);
    }
    const nextTales = syncArticleRelatedTaleRows(this.relatedTaleRows, this.relatedTales);
    if (!sameArticleRelatedTaleRows(this.relatedTaleRows, nextTales)) {
      this.relatedTaleRows = nextTales;
    }

    const previousByKey: Map<string, ArticleSectionRow> = new Map();
    for (let index: number = 0; index < this.sectionRows.length; index++) {
      previousByKey.set(this.sectionRows[index].key, this.sectionRows[index]);
    }

    const nextSections: ArticleSectionRow[] = [];
    const navInputs: ArticleIndexSectionInput[] = [];
    let footnotesHeaderSectionIndex: number = -1;
    this.footnoteSectionById.clear();
    const pushSection = (
      key: string,
      kind: ArticleSectionKind,
      weight: number,
      blockRow: ArticleBlockRowState | undefined,
      footnoteRow: ArticleFootnoteRowState | undefined,
      quoteFirst: boolean,
      quoteLast: boolean,
      bottomGap: number,
      calloutTone: ScpCalloutTone = ScpCalloutTone.NEUTRAL
    ): number => {
      let existing = previousByKey.get(key);
      if (existing === undefined || existing.kind !== kind || existing.weight !== weight) {
        existing = new ArticleSectionRow(
          key,
          kind,
          weight,
          blockRow,
          footnoteRow,
          quoteFirst,
          quoteLast,
          bottomGap,
          calloutTone
        );
      } else {
        existing.sync(blockRow, footnoteRow, quoteFirst, quoteLast, bottomGap, calloutTone);
      }
      const sectionIndex = nextSections.length;
      nextSections.push(existing);
      return sectionIndex;
    };

    if (this.partialNoticeVisible) {
      pushSection(
        '__partial__',
        ArticleSectionKind.PARTIAL_NOTICE,
        60,
        undefined,
        undefined,
        false,
        false,
        12
      );
    }
    if (this.webModeHint.length > 0) {
      pushSection(
        '__web_recommend__',
        ArticleSectionKind.WEB_RECOMMEND_BANNER,
        68,
        undefined,
        undefined,
        false,
        false,
        12
      );
    }
    if (this.hasHeaderCardContent()) {
      pushSection(
        '__header__',
        ArticleSectionKind.HEADER_CARD,
        120,
        undefined,
        undefined,
        false,
        false,
        16
      );
    }
    if (this.seriesContext !== undefined && this.seriesContext.isHubPage) {
      pushSection(
        '__series_hub__',
        ArticleSectionKind.SERIES_HUB_HEADER,
        120,
        undefined,
        undefined,
        false,
        false,
        16
      );
    }
    if (!this.galleryAfterBody && this.shouldRenderGallerySection()) {
      pushSection(
        '__gallery_top__',
        ArticleSectionKind.GALLERY,
        260,
        undefined,
        undefined,
        false,
        false,
        16
      );
    }

    for (let index: number = 0; index < this.blockRows.length; index++) {
      const blockRow = this.blockRows[index];
      if (blockRow.block.type === ScpBlockType.QUOTE && blockRow.children.length > 0) {
        const childCount = blockRow.children.length;
        for (let childIndex: number = 0; childIndex < childCount; childIndex++) {
          const child = blockRow.children[childIndex];
          const sectionIndex = pushSection(
            `${blockRow.key}:q:${child.key}`,
            ArticleSectionKind.QUOTE_CHILD,
            measureBlockWeight(child.block),
            child,
            undefined,
            childIndex === 0,
            childIndex === childCount - 1,
            childIndex === childCount - 1 ? 16 : 0
          );
          navInputs.push({
            sectionIndex: sectionIndex,
            block: child.block,
            extraAnchors: childIndex === 0 ? blockRow.block.anchors : undefined
          });
        }
      } else if (blockRow.block.type === ScpBlockType.CALLOUT && blockRow.children.length > 0) {
        const childCount = blockRow.children.length;
        for (let childIndex: number = 0; childIndex < childCount; childIndex++) {
          const child = blockRow.children[childIndex];
          const sectionIndex = pushSection(
            `${blockRow.key}:c:${child.key}`,
            ArticleSectionKind.CALLOUT_CHILD,
            measureBlockWeight(child.block),
            child,
            undefined,
            childIndex === 0,
            childIndex === childCount - 1,
            childIndex === childCount - 1 ? 16 : 0,
            blockRow.block.calloutTone
          );
          navInputs.push({
            sectionIndex: sectionIndex,
            block: child.block,
            extraAnchors: childIndex === 0 ? blockRow.block.anchors : undefined
          });
        }
      } else {
        const sectionIndex = pushSection(
          blockRow.key,
          ArticleSectionKind.BLOCK,
          measureBlockWeight(blockRow.block),
          blockRow,
          undefined,
          false,
          false,
          16
        );
        navInputs.push({
          sectionIndex: sectionIndex,
          block: blockRow.block
        });
      }
    }

    if (this.footnoteRows.length > 0) {
      footnotesHeaderSectionIndex = pushSection(
        '__footnotes_header__',
        ArticleSectionKind.FOOTNOTES_HEADER,
        50,
        undefined,
        undefined,
        false,
        false,
        12
      );
      const count = this.footnoteRows.length;
      for (let index: number = 0; index < count; index++) {
        const fnRow = this.footnoteRows[index];
        const sectionIndex = pushSection(
          `fn_row:${fnRow.key}`,
          ArticleSectionKind.FOOTNOTE,
          measureFootnoteWeight(fnRow.footnote),
          undefined,
          fnRow,
          false,
          false,
          index === count - 1 ? 16 : 12
        );
        this.footnoteSectionById.set(fnRow.footnote.id, sectionIndex);
        for (let fb: number = 0; fb < fnRow.footnote.blocks.length; fb++) {
          navInputs.push({
            sectionIndex: sectionIndex,
            block: fnRow.footnote.blocks[fb],
            extraAnchors: fb === 0 ? [`footnote-${fnRow.footnote.id}`] : undefined
          });
        }
      }
    }

    if (this.galleryAfterBody && this.shouldRenderGallerySection()) {
      pushSection(
        '__gallery_bottom__',
        ArticleSectionKind.GALLERY,
        260,
        undefined,
        undefined,
        false,
        false,
        16
      );
    }

    if (this.seriesContext !== undefined && !this.seriesContext.isHubPage) {
      pushSection(
        '__series_footer__',
        ArticleSectionKind.SERIES_FOOTER,
        140,
        undefined,
        undefined,
        false,
        false,
        16
      );
    }

    if (this.relatedTaleRows.length > 0) {
      pushSection(
        '__related_tales__',
        ArticleSectionKind.RELATED_TALES,
        180,
        undefined,
        undefined,
        false,
        false,
        16
      );
    }

    pushSection(
      '__footer__',
      ArticleSectionKind.FOOTER,
      60,
      undefined,
      undefined,
      false,
      false,
      0
    );

    const prefixSums: number[] = [0];
    let running: number = 0;
    for (let index: number = 0; index < nextSections.length; index++) {
      running += nextSections[index].weight;
      prefixSums.push(running);
    }
    this.cumulativeWeights = prefixSums;
    this.totalWeight = running;

    this.navigationIndex = buildArticleNavigationIndex(
      navInputs,
      this.document.footnotes,
      footnotesHeaderSectionIndex
    );
    this.tocItems = this.navigationIndex.tocItems;
    if (this.lastNotifiedTocCount !== this.tocItems.length) {
      this.lastNotifiedTocCount = this.tocItems.length;
      this.onTocAvailabilityChange(this.tocItems.length);
    }

    if (!sameArticleSectionRows(this.sectionRows, nextSections)) {
      this.sectionRows = nextSections;
    }
  }

  private clampValue(value: number, min: number, max: number): number {
    return value < min ? min : (value > max ? max : value);
  }

  private isScrollerAtBottom(): boolean {
    try {
      return this.scroller.isAtEnd();
    } catch (_error) {
      return false;
    }
  }

  private resetBottomPullState(): void {
    this.bottomPullTracking = false;
    this.bottomPullProgress = 0;
    this.bottomPullReady = false;
  }

  private handleListTouch(event: TouchEvent): void {
    const touches = event.touches;
    const changed = event.changedTouches;
    const touch = touches.length > 0 ? touches[0] : (changed.length > 0 ? changed[0] : undefined);
    if (event.type === TouchType.Down) {
      this.cancelBlockAlignment();
      if (touch === undefined) {
        this.resetBottomPullState();
        return;
      }
      const touchY = touch.windowY;
      this.bottomPullLastY = touchY;
      this.bottomPullProgress = 0;
      this.bottomPullReady = false;
      if (this.isScrollerAtBottom()) {
        this.bottomPullTracking = true;
        this.bottomPullAnchorY = touchY;
      } else {
        this.bottomPullTracking = false;
      }
      return;
    }
    if (event.type === TouchType.Move) {
      if (touch === undefined) {
        return;
      }
      const touchY = touch.windowY;
      if (!this.bottomPullTracking) {
        if (this.isScrollerAtBottom() && touchY < this.bottomPullLastY) {
          this.bottomPullTracking = true;
          this.bottomPullAnchorY = touchY;
        }
        this.bottomPullLastY = touchY;
        return;
      }
      this.bottomPullLastY = touchY;
      const pullDelta = this.bottomPullAnchorY - touchY;
      if (pullDelta <= 0 || !this.isScrollerAtBottom()) {
        this.bottomPullProgress = 0;
        this.bottomPullReady = false;
        if (!this.isScrollerAtBottom()) {
          this.bottomPullTracking = false;
        } else {
          this.bottomPullAnchorY = touchY;
        }
        return;
      }
      this.bottomPullProgress = this.clampValue(pullDelta / this.bottomPullTriggerVp, 0, 1);
      if (!this.bottomPullReady && pullDelta >= this.bottomPullTriggerVp) {
        this.bottomPullReady = true;
        this.onBottomPullHaptic();
      } else if (this.bottomPullReady && pullDelta < this.bottomPullTriggerVp * 0.85) {
        this.bottomPullReady = false;
      }
      return;
    }
    if (event.type === TouchType.Up) {
      const shouldToggle = this.bottomPullTracking && this.bottomPullReady;
      this.resetBottomPullState();
      if (shouldToggle) {
        this.onToggleCompleted();
      }
      return;
    }
    if (event.type === TouchType.Cancel) {
      this.resetBottomPullState();
    }
  }

  private publishReadingProgress(): void {
    const count = this.sectionRows.length;
    if (count === 0 || this.totalWeight <= 0 || this.viewportHeight <= 0) {
      if (this.lastReportedPercent !== 0) {
        this.lastReportedPercent = 0;
        this.onReadingProgressChange(0);
      }
      return;
    }
    let atEnd: boolean = false;
    try {
      atEnd = this.scroller.isAtEnd();
    } catch (_error) {
      atEnd = false;
    }
    if (atEnd) {
      if (this.lastReportedPercent !== 100) {
        this.lastReportedPercent = 100;
        this.onReadingProgressChange(100);
      }
      return;
    }
    if (this.visibleStartIndex < 0 || this.visibleEndIndex < this.visibleStartIndex) {
      return;
    }
    const start = Math.max(0, Math.min(this.visibleStartIndex, count - 1));
    const end = Math.max(start, Math.min(this.visibleEndIndex, count - 1));

    let startFrac: number = 0;
    let endFrac: number = 1;
    try {
      const startRect = this.scroller.getItemRect(start);
      if (startRect.height > 0) {
        startFrac = this.clampValue((this.topPadding - startRect.y) / startRect.height, 0, 1);
      }
      const endRect = this.scroller.getItemRect(end);
      if (endRect.height > 0) {
        const endVisiblePx = this.clampValue(this.viewportHeight - endRect.y, 0, endRect.height);
        endFrac = this.clampValue(endVisiblePx / endRect.height, 0, 1);
      }
    } catch (_error) {
      startFrac = 0;
      endFrac = 1;
    }

    const a = (this.cumulativeWeights[start] + startFrac * this.sectionRows[start].weight) /
      this.totalWeight;
    const b = (this.cumulativeWeights[end] + endFrac * this.sectionRows[end].weight) /
      this.totalWeight;
    const denom = 1 - Math.max(0, b - a);
    const ratio = denom <= 0.001 ? 1 : this.clampValue(a / denom, 0, 1);
    const next = Math.round(ratio * 100);
    if (next !== this.lastReportedPercent) {
      this.lastReportedPercent = next;
      this.onReadingProgressChange(next);
    }
  }

  private clearPendingAnchorTimer(): void {
    this.cancelBlockAlignment();
    if (this.pendingAnchorTimer >= 0) {
      clearTimeout(this.pendingAnchorTimer);
      this.pendingAnchorTimer = -1;
    }
  }

  private tryFlushPendingRouteAnchor(): void {
    if (!this.hasLaidOutCurrentDoc || this.sectionRows.length === 0 ||
      this.pendingRouteAnchor.length === 0) {
      return;
    }
    const anchor = this.pendingRouteAnchor;
    this.pendingRouteAnchor = '';
    this.clearPendingAnchorTimer();
    this.pendingAnchorTimer = setTimeout((): void => {
      this.pendingAnchorTimer = -1;
      this.jumpToDocumentAnchor(anchor);
    }, 60);
  }

  private scrollToSectionIndex(targetIndex: number): void {
    if (targetIndex < 0 || targetIndex >= this.sectionRows.length) {
      return;
    }
    const distance = this.visibleStartIndex >= 0 ?
      Math.min(
        Math.abs(targetIndex - this.visibleStartIndex),
        Math.abs(targetIndex - this.visibleEndIndex)
      ) :
      999;
    this.scroller.scrollToIndex(
      targetIndex,
      distance <= 18,
      ScrollAlign.START,
      { extraOffset: LengthMetrics.vp(-12) }
    );
  }

  private blockNodeId(blockKey: string): string {
    return `article:${this.getUniqueId()}:block:${blockKey}`;
  }

  private listNodeId(): string {
    return `article:${this.getUniqueId()}:list`;
  }

  private cancelBlockAlignment(): void {
    if (this.afterAnchorLayout !== undefined) {
      this.getUIContext().getUIObserver().off('didLayout', this.afterAnchorLayout);
      this.afterAnchorLayout = undefined;
    }
  }

  private alignNestedBlock(location: ArticleBlockLocation, highlightKey: string): void {
    const context = this.getUIContext();
    const targetId = this.blockNodeId(location.blockKey);
    // The virtual List must mount the section and lay out its expanded children first.
    this.afterAnchorLayout = (): void => {
      const list = context.getFrameNodeById(this.listNodeId());
      if (list === null) {
        return;
      }
      const target = list.getFrameNodeById(targetId);
      if (target === null || target.getMeasuredSize().height <= 0) {
        return;
      }
      const inset = this.topPadding + (this.searchBarOpen ? 68 : 0) + 12;
      const delta = Number(target.getPositionToWindow().y) - Number(list.getPositionToWindow().y) - inset;
      this.cancelBlockAlignment();
      this.scroller.scrollBy(0, delta);
      this.triggerAnchorHighlight(highlightKey);
    };
    context.getUIObserver().on('didLayout', this.afterAnchorLayout);
    this.scroller.scrollToIndex(location.sectionIndex, false, ScrollAlign.START);
  }

  private jumpToBlockLocation(location: ArticleBlockLocation, highlightKey: string = `block:${location.blockKey}`): void {
    this.clearPendingAnchorTimer();
    const keysToToggle: string[] = [];
    for (let index: number = 0; index < location.expandCollapsibleKeys.length; index++) {
      const collapsibleKey = location.expandCollapsibleKeys[index];
      const row = this.blockRowByKey.get(collapsibleKey);
      if (row !== undefined && !this.isExpanded(row.block) &&
        keysToToggle.indexOf(collapsibleKey) < 0) {
        keysToToggle.push(collapsibleKey);
      }
    }
    if (keysToToggle.length > 0) {
      this.onEnsureExpanded(keysToToggle);
    }

    for (let index: number = 0; index < location.tabTargets.length; index++) {
      const targetTab = location.tabTargets[index];
      const tabsRow = this.blockRowByKey.get(targetTab.tabsBlockKey);
      if (tabsRow !== undefined && tabsRow.activeTabIndex !== targetTab.tabIndex) {
        tabsRow.activeTabIndex = targetTab.tabIndex;
      }
    }

    this.onAnchorJump();
    const section = this.sectionRows[location.sectionIndex];
    if (section.footnoteRow !== undefined || (section.blockRow !== undefined && section.blockRow.key !== location.blockKey)) {
      this.alignNestedBlock(location, highlightKey);
      return;
    }
    this.scrollToSectionIndex(location.sectionIndex);
    this.triggerAnchorHighlight(highlightKey);
  }

  private jumpToDocumentAnchor(rawAnchor: string): boolean {
    const target = normalizeArticleAnchor(rawAnchor);
    if (target.length === 0) {
      return false;
    }
    if (target.startsWith('footnote-')) {
      const fnId = target.substring(9);
      this.openFootnoteSheet(fnId, fnId);
      return true;
    }
    const location = resolveAnchorLocation(this.navigationIndex, target);
    if (location !== undefined) {
      const highlightKey = target.startsWith('footnoteref-') ? `ref:${target.substring(12)}` : `block:${location.blockKey}`;
      this.jumpToBlockLocation(location, highlightKey);
      return true;
    }
    if (target === 'page-top' || target === 'top') {
      this.clearPendingAnchorTimer();
      this.onAnchorJump();
      this.scroller.scrollToIndex(0, true, ScrollAlign.START);
      return true;
    }
    this.onAnchorNotFound(target);
    return false;
  }

  private updateSearchResults(rawQuery: string, jumpToFirst: boolean): void {
    this.searchQuery = rawQuery;
    if (rawQuery.trim().length === 0) {
      this.searchHits = [];
      this.activeSearchHitIndex = -1;
      return;
    }
    const hits = searchArticleDocument(this.document, this.navigationIndex, rawQuery);
    this.searchHits = hits;
    if (hits.length === 0) {
      this.activeSearchHitIndex = -1;
      return;
    }
    if (jumpToFirst) {
      this.activeSearchHitIndex = 0;
      this.jumpToSearchHit(hits[0]);
    } else if (this.activeSearchHitIndex >= hits.length) {
      this.activeSearchHitIndex = 0;
    }
  }

  private stepSearchHit(delta: number): void {
    const count = this.searchHits.length;
    if (count === 0) {
      return;
    }
    const base = this.activeSearchHitIndex < 0 ? 0 : this.activeSearchHitIndex;
    const next = (base + delta + count) % count;
    this.activeSearchHitIndex = next;
    this.jumpToSearchHit(this.searchHits[next]);
  }

  private jumpToSearchHit(hit: ArticleSearchHit): void {
    if (hit.isFootnote && this.canUseSidePanel() && hit.footnoteIndex >= 0 &&
      hit.footnoteIndex < this.footnoteRows.length) {
      this.activeFootnoteIndex = hit.footnoteIndex;
      this.userClosedSidePanel = false;
      this.activeWorkbenchTab = WorkbenchTab.FOOTNOTES;
      if (!this.sidePanelOpen) {
        this.onSidePanelOpenChange(true);
      }
      this.scrollSidePanelToFootnote(hit.footnoteIndex);
    }
    this.jumpToBlockLocation(hit.location);
  }

  private filteredTocItems(): ArticleTocItem[] {
    const filter = this.tocFilterQuery.trim().toLowerCase();
    if (filter.length === 0) {
      return this.tocItems;
    }
    return this.tocItems.filter((item: ArticleTocItem): boolean =>
      item.title.toLowerCase().indexOf(filter) >= 0);
  }

  private isTocItemActive(index: number, items: ArticleTocItem[]): boolean {
    if (index < 0 || index >= items.length) {
      return false;
    }
    const currentIdx = this.visibleSectionIndex;
    let activeIdx = 0;
    for (let i: number = 0; i < items.length; i++) {
      if (items[i].location.sectionIndex <= currentIdx + 1) {
        activeIdx = i;
      }
    }
    return index === activeIdx;
  }

  private clearHighlightTimer(): void {
    if (this.highlightTimer >= 0) {
      clearTimeout(this.highlightTimer);
      this.highlightTimer = -1;
    }
  }

  private triggerAnchorHighlight(key: string): void {
    this.clearHighlightTimer();
    this.highlightedAnchorKey = key;
    this.highlightOpacity = 1;
    this.highlightTimer = setTimeout((): void => {
      this.highlightTimer = -1;
      const targetKey = key;
      const uiContext = this.getUIContext();
      if (uiContext === undefined) {
        if (this.highlightedAnchorKey === targetKey) {
          this.highlightOpacity = 0;
          this.highlightedAnchorKey = '';
        }
        return;
      }
      uiContext.animateTo({
        duration: 680,
        curve: Curve.EaseOut,
        onFinish: (): void => {
          if (this.highlightedAnchorKey === targetKey) {
            this.highlightedAnchorKey = '';
          }
        }
      }, (): void => {
        if (this.highlightedAnchorKey === targetKey) {
          this.highlightOpacity = 0;
        }
      });
    }, 320);
  }

  private jumpToFootnoteReference(id: string): boolean {
    const location = resolveAnchorLocation(this.navigationIndex, `footnoteref-${id}`);
    if (location === undefined) {
      return false;
    }
    this.jumpToBlockLocation(location, `ref:${id}`);
    return true;
  }

  private currentFootnoteRow(): ArticleFootnoteRowState | undefined {
    if (this.activeFootnoteIndex >= 0 && this.activeFootnoteIndex < this.footnoteRows.length) {
      return this.footnoteRows[this.activeFootnoteIndex];
    }
    return undefined;
  }

  private currentFootnoteBlocks(): ArticleBlockRowState[] {
    return this.currentFootnoteRow()?.blocks ?? [];
  }

  private hasPreviousFootnote(): boolean {
    return this.activeFootnoteIndex > 0 && this.footnoteRows.length > 0;
  }

  private hasNextFootnote(): boolean {
    return this.footnoteRows.length > 0 && this.activeFootnoteIndex < this.footnoteRows.length - 1;
  }

  private hasWorkbenchContent(): boolean {
    return this.footnoteRows.length > 0 ||
      this.relatedTaleRows.length > 0 ||
      this.tocItems.length > 0;
  }

  private canUseSidePanel(): boolean {
    return supportsArticleSidePanel(this.containerWidth) && this.hasWorkbenchContent();
  }

  private sidePanelVisible(): boolean {
    return this.canUseSidePanel() && this.sidePanelOpen;
  }

  private workbenchTabAvailable(tab: number): boolean {
    if (tab === WorkbenchTab.FOOTNOTES) {
      return this.footnoteRows.length > 0;
    }
    if (tab === WorkbenchTab.RELATED_TALES) {
      return this.relatedTaleRows.length > 0;
    }
    if (tab === WorkbenchTab.TOC) {
      return this.tocItems.length > 0;
    }
    return false;
  }

  private availableWorkbenchTabCount(): number {
    let count = 0;
    if (this.footnoteRows.length > 0) {
      count++;
    }
    if (this.tocItems.length > 0) {
      count++;
    }
    if (this.relatedTaleRows.length > 0) {
      count++;
    }
    return count;
  }

  private syncWorkbenchTabDefault(): void {
    if (this.workbenchTabAvailable(this.activeWorkbenchTab)) {
      return;
    }
    if (this.footnoteRows.length > 0) {
      this.activeWorkbenchTab = WorkbenchTab.FOOTNOTES;
    } else if (this.tocItems.length > 0) {
      this.activeWorkbenchTab = WorkbenchTab.TOC;
    } else if (this.relatedTaleRows.length > 0) {
      this.activeWorkbenchTab = WorkbenchTab.RELATED_TALES;
    }
  }

  private sidePanelBadgeLabel(): string {
    const fnCount = this.footnoteRows.length;
    const taleCount = this.relatedTaleRows.length;
    const tocCount = this.tocItems.length;
    if (this.availableWorkbenchTabCount() > 1) {
      return '研读';
    }
    if (fnCount > 0) {
      return `脚注 ${fnCount}`;
    }
    if (tocCount > 0) {
      return `目录 ${tocCount}`;
    }
    if (taleCount > 0) {
      return `故事 ${taleCount}`;
    }
    return '';
  }

  private syncSidePanelAvailability(): void {
    const available = this.canUseSidePanel();
    const label = available ? this.sidePanelBadgeLabel() : '';
    const notifyKey = `${available ? '1' : '0'}:${label}`;
    if (notifyKey !== this.lastNotifiedAvailabilityKey) {
      this.lastNotifiedAvailabilityKey = notifyKey;
      this.onSidePanelAvailabilityChange(available, label);
    }
    if (!available) {
      if (this.sidePanelOpen) {
        this.onSidePanelOpenChange(false);
      }
      return;
    }
    if (autoOpenArticleSidePanel(this.containerWidth) && !this.userClosedSidePanel && !this.sidePanelOpen) {
      this.onSidePanelOpenChange(true);
    }
  }

  private scrollFootnoteSheetToTop(): void {
    try {
      this.footnoteSheetScroller.scrollEdge(Edge.Top);
    } catch (_error) {
      // Sheet Scroll is not bound yet on initial open; ignore harmless 100004 error.
    }
  }

  private scrollSidePanelToFootnote(index: number): void {
    if (index < 0 || index >= this.footnoteRows.length) {
      return;
    }
    try {
      this.sidePanelScroller.scrollToIndex(index, true, ScrollAlign.CENTER);
    } catch (_error) {
      // Sidebar List may not be attached yet during panel mount; onAppear will sync.
    }
  }

  private openFootnoteSheet(referenceId: string, labelText: string): void {
    const targetIndex = ArticleRenderer.findFootnoteIndex(
      this.document.footnotes,
      referenceId,
      labelText
    );
    if (targetIndex < 0 || targetIndex >= this.footnoteRows.length) {
      const section = this.footnoteSectionById.get(referenceId);
      if (section !== undefined) {
        this.clearPendingAnchorTimer();
        this.onAnchorJump();
        this.scrollToSectionIndex(section);
        this.triggerAnchorHighlight(`fn:${referenceId}`);
      }
      return;
    }
    this.activeFootnoteIndex = targetIndex;
    if (this.canUseSidePanel()) {
      this.sheetMode = ArticleSheetMode.NONE;
      this.userClosedSidePanel = false;
      this.activeWorkbenchTab = WorkbenchTab.FOOTNOTES;
      if (!this.sidePanelOpen) {
        this.onSidePanelOpenChange(true);
      }
      this.onAnchorJump();
      this.triggerAnchorHighlight(`ref:${this.footnoteRows[targetIndex].footnote.id}`);
      this.scrollSidePanelToFootnote(targetIndex);
      return;
    }
    this.sheetMode = ArticleSheetMode.FOOTNOTE;
    this.onAnchorJump();
    this.scrollFootnoteSheetToTop();
  }

  private closeSheet(): void {
    this.sheetMode = ArticleSheetMode.NONE;
    if (!this.sidePanelVisible()) {
      this.activeFootnoteIndex = -1;
    }
  }

  private closeSidePanel(): void {
    this.userClosedSidePanel = true;
    if (this.sidePanelOpen) {
      this.getUIContext().animateTo(AppMotion.layoutAnimateParam(), (): void => {
        this.onSidePanelOpenChange(false);
      });
    }
  }

  private selectSidePanelFootnote(row: ArticleFootnoteRowState): void {
    this.activeFootnoteIndex = row.index;
    if (!this.jumpToFootnoteReference(row.footnote.id)) {
      this.onAnchorJump();
    }
  }

  private stepFootnote(delta: number): void {
    const next = ArticleRenderer.stepFootnoteIndex(
      this.activeFootnoteIndex,
      delta,
      this.footnoteRows.length
    );
    if (next < 0 || next === this.activeFootnoteIndex) {
      return;
    }
    this.activeFootnoteIndex = next;
    if (this.sheetMode === ArticleSheetMode.FOOTNOTE) {
      this.scrollFootnoteSheetToTop();
    }
    if (this.sidePanelVisible()) {
      this.scrollSidePanelToFootnote(next);
    }
    const row = this.currentFootnoteRow();
    if (row === undefined || !this.jumpToFootnoteReference(row.footnote.id)) {
      this.onAnchorJump();
    }
  }

  private handleOpenArticleLink(url: string, title: string): void {
    const trimmed = url.trim();
    if (trimmed.startsWith('#')) {
      if (this.sheetMode !== ArticleSheetMode.NONE) {
        this.closeSheet();
      }
      this.jumpToDocumentAnchor(trimmed.substring(1));
      return;
    }
    if (this.sheetMode !== ArticleSheetMode.NONE) {
      this.closeSheet();
    }
    this.onOpenArticleLink(url, title);
  }

  private handleOpenUrl(url: string): void {
    if (this.sheetMode !== ArticleSheetMode.NONE) {
      this.closeSheet();
    }
    this.onOpenUrl(url);
  }

  private mainReadingAreaWidth(): number {
    const sidebarWidth = this.sidePanelVisible() ? resolveArticleSidebarWidth(this.containerWidth) : 0;
    const baseWidth = this.containerWidth > 0 ? this.containerWidth : windowWidthVp();
    return Math.max(0, baseWidth - sidebarWidth);
  }

  private mainHorizontalMargin(): number {
    return adaptivePageMarginForWidth(this.mainReadingAreaWidth());
  }

  private activeSheetOptions(): SheetOptions {
    const isToc = this.sheetMode === ArticleSheetMode.TOC;
    const isChecklist = this.sheetMode === ArticleSheetMode.SERIES_CHECKLIST;
    const isTallList = isToc || isChecklist;
    const useCenter = shouldUseCenterSheet(windowWidthVp());
    let sheetTitle = '脚注';
    let sheetSubtitle = '';
    if (isChecklist && this.seriesContext !== undefined) {
      sheetTitle = `${this.seriesContext.seriesTitle} · 系列顺序`;
      sheetSubtitle = `按 Wiki 推荐顺序 · 主线已读 ${this.seriesContext.mainlineCompleted}/${this.seriesContext.mainlineTotal}`;
    } else if (isToc) {
      sheetTitle = '章节目录';
      sheetSubtitle = `共 ${this.tocItems.length} 项`;
    } else {
      const row = this.currentFootnoteRow();
      const header: FootnoteSheetHeader = row !== undefined ?
        ArticleRenderer.footnoteSheetHeader(
          row.footnote,
          this.activeFootnoteIndex,
          this.footnoteRows.length
        ) :
        { title: '脚注', subtitle: '' };
      sheetTitle = header.title;
      sheetSubtitle = header.subtitle;
    }
    const options: SheetOptions = {
      preferType: useCenter ? SheetType.CENTER : SheetType.BOTTOM,
      dragBar: true,
      showClose: true,
      title: sheetSubtitle.length > 0 ?
        { title: sheetTitle, subtitle: sheetSubtitle } :
        { title: sheetTitle },
      onWillDismiss: (action: DismissSheetAction): void => {
        this.closeSheet();
        action.dismiss();
      },
      onDisappear: (): void => {
        this.closeSheet();
      }
    };
    if (useCenter) {
      options.height = isTallList ? SheetSize.LARGE : SheetSize.FIT_CONTENT;
    } else {
      options.detents = isChecklist ? this.longTocSheetDetents :
        (isToc ?
          (this.tocItems.length >= 10 ? this.longTocSheetDetents : this.tocSheetDetents) :
          this.sheetDetents);
      options.scrollSizeMode = ScrollSizeMode.CONTINUOUS;
    }
    if (this.materialEnabled) {
      if (uiImmersiveMaterialSupported()) {
        options.systemMaterial = this.footnoteSheetMaterial;
      } else {
        options.blurStyle = BlurStyle.COMPONENT_THICK;
      }
      options.backgroundColor = Color.Transparent;
    } else {
      options.backgroundColor = $r('sys.color.comp_background_primary');
    }
    return options;
  }

  private isBlockHighlighted(block: ScpContentBlock): boolean {
    if (this.highlightedAnchorKey.length === 0) {
      return false;
    }
    if (this.highlightedAnchorKey === `block:${block.key}`) {
      return true;
    }
    const refIds = this.footnoteRefIds(block);
    for (let index: number = 0; index < refIds.length; index++) {
      if (this.highlightedAnchorKey === `ref:${refIds[index]}`) {
        return true;
      }
    }
    return false;
  }

  private isFootnoteHighlighted(id: string): boolean {
    return this.highlightedAnchorKey === `fn:${id}`;
  }

  @Builder
  private anchorHighlightBackdrop(visible: boolean) {
    Column() {}
      .width('100%')
      .height('100%')
      .backgroundColor(badgeInfoBackgroundColor())
      .borderRadius(8)
      .opacity(visible ? this.highlightOpacity * 0.75 : 0)
  }

  @Builder
  private anchorHighlightOverlay(visible: boolean) {
    Column() {}
      .width('100%')
      .height('100%')
      .backgroundColor(badgeInfoBackgroundColor())
      .borderRadius(10)
      .opacity(visible ? this.highlightOpacity * 0.55 : 0)
      .hitTestBehavior(HitTestMode.None)
  }

  private isExpanded(block: ScpContentBlock): boolean {
    const toggled = ArticleRenderer.isExpanded(this.expandedKeys, block.key);
    return block.initiallyExpanded ? !toggled : toggled;
  }

  private footnoteRefIds(block: ScpContentBlock): string[] {
    return ArticleRenderer.footnoteReferenceIds(block);
  }

  private textOf(block: ScpContentBlock): string {
    return ArticleRenderer.textOf(block);
  }

  private maxTableColumnCount(tableRow: ArticleBlockRowState): number {
    let maxCols: number = 0;
    for (let index: number = 0; index < tableRow.children.length; index++) {
      const count = tableRow.children[index].children.length;
      if (count > maxCols) {
        maxCols = count;
      }
    }
    return maxCols;
  }

  private tableColumnWidth(maxCols: number): number {
    if (maxCols <= 0) {
      return 120;
    }
    return Math.max(115, Math.min(180, Math.floor(540 / maxCols)));
  }

  private effectiveDarkSurface(inTerminal: boolean): boolean {
    return inTerminal || isDarkModeActive();
  }

  private isHiddenKeyRevealed(key: string): boolean {
    return this.revealHiddenText || this.revealedHiddenKeys.indexOf(key) >= 0;
  }

  private toggleLocalHiddenKey(key: string): void {
    const next = this.revealedHiddenKeys.slice();
    const index = next.indexOf(key);
    if (index >= 0) {
      next.splice(index, 1);
    } else {
      next.push(key);
    }
    this.getUIContext().animateTo(AppMotion.microAnimateParam(), (): void => {
      this.revealedHiddenKeys = next;
    });
    this.onHiddenRevealInteraction();
  }

  private resolveBlockTextAlign(align: ScpTextAlign, fallbackStart: boolean): TextAlign {
    switch (align) {
      case ScpTextAlign.START:
        return TextAlign.Start;
      case ScpTextAlign.CENTER:
        return TextAlign.Center;
      case ScpTextAlign.END:
        return TextAlign.End;
      case ScpTextAlign.JUSTIFY:
        return TextAlign.JUSTIFY;
      default:
        return (fallbackStart || !this.justifyBodyText) ? TextAlign.Start : TextAlign.JUSTIFY;
    }
  }

  private resolvedSpanFontSize(span: ScpTextSpan, baseSize: number): number {
    let size = baseSize * (Number.isFinite(span.fontScale) && span.fontScale > 0 ? span.fontScale : 1);
    if (span.superscript || span.subscript) {
      size *= 0.76;
    } else if (span.monospace) {
      size *= 0.94;
    }
    return Math.max(10, Math.min(this.fontSize * 2.0, size));
  }

  private resolvedSpanBaseline(span: ScpTextSpan, baseSize: number): LengthMetrics {
    if (span.superscript) {
      return LengthMetrics.fp(baseSize * 0.28);
    }
    if (span.subscript) {
      return LengthMetrics.fp(-baseSize * 0.16);
    }
    return LengthMetrics.fp(0);
  }

  private resolvedVisibleSpanColor(span: ScpTextSpan, inTerminal: boolean): ResourceColor {
    const darkSurface = this.effectiveDarkSurface(inTerminal);
    if (span.color.length > 0) {
      const adapted = ArticleRenderer.resolveAdaptiveSpanColor(span.color, darkSurface);
      if (adapted.length > 0) {
        return adapted;
      }
    }
    if (inTerminal) {
      return span.style === ScpTextStyle.CODE || span.style === ScpTextStyle.LINK ? '#67E8F9' : '#E2E8F0';
    }
    return span.style === ScpTextStyle.CODE || span.style === ScpTextStyle.LINK ?
      $r('sys.color.font_emphasize') : $r('sys.color.font');
  }

  private resolvedSpanDecoration(
    span: ScpTextSpan,
    inTerminal: boolean
  ): DecorationStyleInterface {
    if (span.deleted) {
      return {
        type: TextDecorationType.LineThrough,
        color: this.resolvedVisibleSpanColor(span, inTerminal)
      };
    }
    if (span.underline || span.style === ScpTextStyle.LINK) {
      return {
        type: TextDecorationType.Underline,
        color: inTerminal ? '#94A3B8' : $r('sys.color.font_secondary')
      };
    }
    return { type: TextDecorationType.None };
  }

  private resolvedSpanBackground(span: ScpTextSpan, inTerminal: boolean): TextBackgroundStyle {
    const darkSurface = this.effectiveDarkSurface(inTerminal);
    if (span.style === ScpTextStyle.CODE) {
      return { color: darkSurface ? '#253040' : '#12000000', radius: 4 };
    }
    return { color: Color.Transparent, radius: 0 };
  }

  private resolvedHiddenForeground(
    span: ScpTextSpan,
    key: string,
    inTerminal: boolean,
    forceReveal: boolean
  ): ResourceColor {
    const revealed = forceReveal || this.isHiddenKeyRevealed(key);
    const darkSurface = this.effectiveDarkSurface(inTerminal);
    if (span.hiddenKind === ScpHiddenTextKind.WHITE_EASTER_EGG) {
      if (!revealed) {
        return Color.Transparent;
      }
      return darkSurface ? '#FCD34D' : '#92400E';
    }
    if (span.hiddenKind === ScpHiddenTextKind.BLACKBOX) {
      if (!revealed) {
        return darkSurface ? '#2D333B' : '#141414';
      }
      return '#FDE68A';
    }
    if (!revealed) {
      return inTerminal ? '#94A3B8' : $r('sys.color.font_tertiary');
    }
    return darkSurface ? '#C4B5FD' : '#6D28D9';
  }

  private resolvedHiddenBackground(
    span: ScpTextSpan,
    key: string,
    inTerminal: boolean,
    forceReveal: boolean
  ): TextBackgroundStyle {
    const revealed = forceReveal || this.isHiddenKeyRevealed(key);
    const darkSurface = this.effectiveDarkSurface(inTerminal);
    if (span.hiddenKind === ScpHiddenTextKind.WHITE_EASTER_EGG) {
      return {
        color: revealed ?
          (darkSurface ? '#2AF59E0B' : '#22F59E0B') :
          (darkSurface ? '#16FFFFFF' : '#0C000000'),
        radius: 4
      };
    }
    if (span.hiddenKind === ScpHiddenTextKind.BLACKBOX) {
      return {
        color: revealed ?
          (darkSurface ? '#3F3F46' : '#27272A') :
          (darkSurface ? '#2D333B' : '#141414'),
        radius: 3
      };
    }
    return {
      color: revealed ?
        (darkSurface ? '#268B5CF6' : '#1A8B5CF6') :
        (darkSurface ? '#1F334155' : '#12000000'),
      radius: 4
    };
  }

  private resolvedHiddenDecoration(
    span: ScpTextSpan,
    key: string,
    inTerminal: boolean,
    forceReveal: boolean
  ): DecorationStyleInterface {
    const revealed = forceReveal || this.isHiddenKeyRevealed(key);
    const darkSurface = this.effectiveDarkSurface(inTerminal);
    if (span.hiddenKind === ScpHiddenTextKind.WHITE_EASTER_EGG && !revealed) {
      return {
        type: TextDecorationType.Underline,
        color: darkSurface ? '#2EFFFFFF' : '#24000000',
        style: TextDecorationStyle.DOTTED
      };
    }
    if (revealed && span.deleted) {
      return {
        type: TextDecorationType.LineThrough,
        color: this.resolvedHiddenForeground(span, key, inTerminal, forceReveal)
      };
    }
    if (revealed && (span.underline || span.style === ScpTextStyle.LINK)) {
      return {
        type: TextDecorationType.Underline,
        color: this.resolvedHiddenForeground(span, key, inTerminal, forceReveal)
      };
    }
    return { type: TextDecorationType.None };
  }

  private handleHiddenSpanClick(span: ScpTextSpan, key: string, forceReveal: boolean): void {
    const revealed = forceReveal || this.isHiddenKeyRevealed(key);
    if (!revealed) {
      this.toggleLocalHiddenKey(key);
      return;
    }
    if (span.style === ScpTextStyle.LINK && span.target.length > 0) {
      this.handleOpenArticleLink(span.target, span.text);
      return;
    }
    if (!forceReveal && !this.revealHiddenText) {
      this.toggleLocalHiddenKey(key);
    }
  }

  private acsDisruptionColor(level: string): string {
    const lower = level.trim().toLowerCase();
    if (lower === 'amida' || lower === 'ekhi') {
      return '#D9383A';
    }
    if (lower === 'keneq') {
      return '#D97706';
    }
    if (lower === 'vlam') {
      return '#2563EB';
    }
    return '#475569';
  }

  private acsRiskColor(level: string): string {
    const lower = level.trim().toLowerCase();
    if (lower === '危急' || lower === 'critical' || lower === '危险' || lower === 'danger') {
      return '#D9383A';
    }
    if (lower === '警告' || lower === 'warning') {
      return '#D97706';
    }
    if (lower === '需谨慎' || lower === 'caution') {
      return '#0284C7';
    }
    return '#475569';
  }

  private isSearchHighlightActive(): boolean {
    return this.searchBarOpen && this.searchQuery.trim().length > 0;
  }

  private isBlockActiveSearchHit(blockKey: string): boolean {
    if (this.activeSearchHitIndex < 0 || this.activeSearchHitIndex >= this.searchHits.length) {
      return false;
    }
    return this.searchHits[this.activeSearchHitIndex].blockKey === blockKey;
  }

  private hasActiveSearchHit(): boolean {
    return this.activeSearchHitIndex >= 0 && this.activeSearchHitIndex < this.searchHits.length;
  }

  private activeSearchHitContextLabel(): string {
    if (!this.hasActiveSearchHit()) {
      return '';
    }
    return this.searchHits[this.activeSearchHitIndex].contextLabel;
  }

  private activeSearchHitSnippet(): string {
    if (!this.hasActiveSearchHit()) {
      return '';
    }
    return this.searchHits[this.activeSearchHitIndex].snippet;
  }

  private resolvedSliceFontColor(
    slice: SearchRenderSpanSlice,
    inTerminal: boolean,
    isActiveHitBlock: boolean
  ): ResourceColor {
    if (slice.isSearchMatch && isActiveHitBlock) {
      return '#111827';
    }
    return this.resolvedVisibleSpanColor(slice.spanRow.span, inTerminal);
  }

  private resolvedSliceBackground(
    slice: SearchRenderSpanSlice,
    inTerminal: boolean,
    isActiveHitBlock: boolean
  ): TextBackgroundStyle {
    if (slice.isSearchMatch) {
      return {
        color: isActiveHitBlock ? '#F59E0B' : '#55F59E0B',
        radius: 4
      };
    }
    return this.resolvedSpanBackground(slice.spanRow.span, inTerminal);
  }

  private resolvedHiddenSliceFontColor(
    slice: SearchRenderSpanSlice,
    inTerminal: boolean,
    forceReveal: boolean,
    isActiveHitBlock: boolean
  ): ResourceColor {
    if (slice.isSearchMatch && isActiveHitBlock) {
      return '#111827';
    }
    return this.resolvedHiddenForeground(
      slice.spanRow.span,
      slice.spanRow.key,
      inTerminal,
      forceReveal
    );
  }

  private resolvedHiddenSliceBackground(
    slice: SearchRenderSpanSlice,
    inTerminal: boolean,
    forceReveal: boolean,
    isActiveHitBlock: boolean
  ): TextBackgroundStyle {
    if (slice.isSearchMatch) {
      return {
        color: isActiveHitBlock ? '#F59E0B' : '#55F59E0B',
        radius: 4
      };
    }
    return this.resolvedHiddenBackground(
      slice.spanRow.span,
      slice.spanRow.key,
      inTerminal,
      forceReveal
    );
  }

  private buildHighlightedSpanSlices(
    row: ArticleBlockRowState,
    forceReveal: boolean
  ): SearchRenderSpanSlice[] {
    const query = this.searchBarOpen ? this.searchQuery.trim() : '';
    const slices: SearchRenderSpanSlice[] = [];
    for (let i: number = 0; i < row.spans.length; i++) {
      const spanRow = row.spans[i];
      const span = spanRow.span;
      const isHidden = span.hiddenKind !== ScpHiddenTextKind.NONE;
      const hiddenRevealed = !isHidden || forceReveal || this.isHiddenKeyRevealed(spanRow.key);
      if (query.length === 0 ||
        span.style === ScpTextStyle.FOOTNOTE_REFERENCE ||
        !hiddenRevealed) {
        slices.push(new SearchRenderSpanSlice(spanRow.key, spanRow, span.text, false));
        continue;
      }
      const segments = splitTextForSearchHighlight(span.text, query);
      if (segments.length <= 1 && (segments.length === 0 || !segments[0].matched)) {
        slices.push(new SearchRenderSpanSlice(spanRow.key, spanRow, span.text, false));
        continue;
      }
      const normalizedQuery = query.toLowerCase();
      for (let s: number = 0; s < segments.length; s++) {
        const seg = segments[s];
        slices.push(new SearchRenderSpanSlice(
          `${spanRow.key}::m::${normalizedQuery}::${s}:${seg.matched ? '1' : '0'}`,
          spanRow,
          seg.text,
          seg.matched
        ));
      }
    }
    return slices;
  }

  private activeTocItemKey(): string {
    const items = this.filteredTocItems();
    const currentIdx = this.visibleSectionIndex;
    let activeKey = '';
    for (let i: number = 0; i < items.length; i++) {
      if (items[i].location.sectionIndex <= currentIdx + 1) {
        activeKey = items[i].key;
      }
    }
    return activeKey;
  }

  private tocItemLeftPadding(item: ArticleTocItem): number {
    if (item.kind === ArticleTocKind.FOOTNOTES) {
      return 12;
    }
    const clampedLevel = Math.max(1, Math.min(4, item.level));
    return 12 + (clampedLevel - 1) * 12;
  }

  private sidePanelHeaderTitle(): string {
    if (this.footnoteRows.length > 0) {
      return `脚注 (${this.footnoteRows.length})`;
    }
    if (this.tocItems.length > 0) {
      return `章节目录 (${this.tocItems.length})`;
    }
    return `关联故事 (${this.relatedTaleRows.length})`;
  }

  private relatedTalesSourceBadge(): string {
    if (this.relatedTaleRows.length === 0) {
      return '';
    }
    const source = this.relatedTaleRows[0].tale.source;
    if (source === ArticleRelatedTaleSource.SERIES_TALES_EDITION) {
      return '收录于系列故事版';
    }
    if (source === ArticleRelatedTaleSource.TITLE_INDEX_FALLBACK) {
      return '按编号匹配';
    }
    return '';
  }

  private isCuratedRelatedTales(): boolean {
    return this.relatedTaleRows.length > 0 &&
      this.relatedTaleRows[0].tale.source === ArticleRelatedTaleSource.SERIES_TALES_EDITION;
  }

  private relatedTalesSidePanelCaption(): string {
    const badge = this.relatedTalesSourceBadge();
    if (badge.length === 0) {
      return '';
    }
    return `${badge} · 共 ${this.relatedTaleRows.length} 篇`;
  }

  private visibleBottomRelatedTaleRows(): ArticleRelatedTaleRowState[] {
    if (this.expandAllRelatedTales || this.relatedTaleRows.length <= 8) {
      return this.relatedTaleRows;
    }
    return this.relatedTaleRows.slice(0, 8);
  }

  private relatedTalesExpandLabel(): string {
    return this.expandAllRelatedTales ?
      '收起部分关联故事' : `展开全部 ${this.relatedTaleRows.length} 篇关联故事`;
  }

  @Builder
  private spanText(
    row: ArticleBlockRowState,
    inTerminal: boolean = false,
    boldAll: boolean = false,
    startAlign: boolean = false,
    baseSizeOverride: number = 0,
    forceReveal: boolean = false
  ) {
    Text() {
      ForEach(this.buildHighlightedSpanSlices(row, forceReveal), (slice: SearchRenderSpanSlice) => {
        if (slice.spanRow.span.style === ScpTextStyle.FOOTNOTE_REFERENCE) {
          Span(`[${slice.spanRow.span.text}]`)
            .fontSize((baseSizeOverride > 0 ? baseSizeOverride : this.fontSize) * 0.75)
            .fontWeight(FontWeight.Medium)
            .fontColor(inTerminal ? '#67E8F9' : $r('sys.color.font_emphasize'))
            .baselineOffset(LengthMetrics.fp((baseSizeOverride > 0 ? baseSizeOverride : this.fontSize) * 0.24))
            .onClick(() => this.openFootnoteSheet(
              slice.spanRow.span.referenceId,
              slice.spanRow.span.text
            ))
        } else if (slice.spanRow.span.hiddenKind === ScpHiddenTextKind.NONE) {
          Span(slice.text)
            .fontSize(this.resolvedSpanFontSize(
              slice.spanRow.span,
              baseSizeOverride > 0 ? baseSizeOverride : this.fontSize
            ))
            .fontWeight(boldAll || slice.spanRow.span.bold ? FontWeight.Bold : FontWeight.Regular)
            .fontStyle(slice.spanRow.span.italic ? FontStyle.Italic : FontStyle.Normal)
            .fontFamily(slice.spanRow.span.monospace ? 'monospace' : 'HarmonyOS Sans')
            .baselineOffset(this.resolvedSpanBaseline(
              slice.spanRow.span,
              baseSizeOverride > 0 ? baseSizeOverride : this.fontSize
            ))
            .decoration(this.resolvedSpanDecoration(slice.spanRow.span, inTerminal))
            .fontColor(this.resolvedSliceFontColor(
              slice,
              inTerminal,
              this.isBlockActiveSearchHit(row.block.key)
            ))
            .textBackgroundStyle(this.resolvedSliceBackground(
              slice,
              inTerminal,
              this.isBlockActiveSearchHit(row.block.key)
            ))
            .onClick(slice.spanRow.span.style === ScpTextStyle.LINK ?
              () => this.handleOpenArticleLink(slice.spanRow.span.target, slice.spanRow.span.text) :
              () => {
              })
        } else {
          Span((slice.spanRow.span.hiddenKind !== ScpHiddenTextKind.ZERO_SIZE_WHISPER ||
            forceReveal || this.isHiddenKeyRevealed(slice.spanRow.key)) ? slice.text : ' [···] ')
            .fontSize((slice.spanRow.span.hiddenKind === ScpHiddenTextKind.ZERO_SIZE_WHISPER &&
              !forceReveal && !this.isHiddenKeyRevealed(slice.spanRow.key)) ?
              Math.max(11, (baseSizeOverride > 0 ? baseSizeOverride : this.fontSize) * 0.78) :
              this.resolvedSpanFontSize(
                slice.spanRow.span,
                baseSizeOverride > 0 ? baseSizeOverride : this.fontSize
              ))
            .fontWeight(boldAll || slice.spanRow.span.bold ? FontWeight.Bold : FontWeight.Regular)
            .fontStyle(slice.spanRow.span.italic ? FontStyle.Italic : FontStyle.Normal)
            .fontFamily(slice.spanRow.span.monospace ? 'monospace' : 'HarmonyOS Sans')
            .baselineOffset(this.resolvedSpanBaseline(
              slice.spanRow.span,
              baseSizeOverride > 0 ? baseSizeOverride : this.fontSize
            ))
            .decoration(this.resolvedHiddenDecoration(
              slice.spanRow.span,
              slice.spanRow.key,
              inTerminal,
              forceReveal
            ))
            .fontColor(this.resolvedHiddenSliceFontColor(
              slice,
              inTerminal,
              forceReveal,
              this.isBlockActiveSearchHit(row.block.key)
            ))
            .textBackgroundStyle(this.resolvedHiddenSliceBackground(
              slice,
              inTerminal,
              forceReveal,
              this.isBlockActiveSearchHit(row.block.key)
            ))
            .onClick(() => this.handleHiddenSpanClick(
              slice.spanRow.span,
              slice.spanRow.key,
              forceReveal
            ))
        }
      }, (slice: SearchRenderSpanSlice) =>
        (this.isSearchHighlightActive() && slice.isSearchMatch) ?
          `${slice.key}:${this.activeSearchHitIndex}` : slice.key
      )
    }
    .fontSize(baseSizeOverride > 0 ? baseSizeOverride : this.fontSize)
    .lineHeightMultiple(this.lineHeightMultiple)
    .fontColor(inTerminal ? '#E2E8F0' : $r('sys.color.font'))
    .textAlign(this.resolveBlockTextAlign(row.block.textAlign, startAlign))
    .wordBreak(WordBreak.BREAK_WORD)
    .enableAutoSpacing(true)
    .background(this.anchorHighlightBackdrop(this.isBlockHighlighted(row.block)))
    .width('100%')
  }

  @Builder
  private pureWhisperBlock(row: ArticleBlockRowState, inTerminal: boolean = false) {
    if (this.isHiddenKeyRevealed(row.key)) {
      Column({ space: 6 }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.eye'))
            .fontSize(13)
            .fontColor([this.effectiveDarkSurface(inTerminal) ? '#C4B5FD' : '#6D28D9'])
          Text('隐藏低语（0px 彩蛋）')
            .fontSize(AppTypography.CAPTION_M)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.effectiveDarkSurface(inTerminal) ? '#C4B5FD' : '#6D28D9')
            .layoutWeight(1)
          if (!this.revealHiddenText) {
            Text('收起')
              .fontSize(AppTypography.CAPTION_M)
              .fontColor(inTerminal ? '#94A3B8' : $r('sys.color.font_secondary'))
              .onClick(() => this.toggleLocalHiddenKey(row.key))
          }
        }
        .width('100%')

        this.spanText(row, inTerminal, false, true, 0, true)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(this.effectiveDarkSurface(inTerminal) ? '#1F8B5CF6' : '#128B5CF6')
      .border({
        width: 0.8,
        style: BorderStyle.Dashed,
        color: this.effectiveDarkSurface(inTerminal) ? '#8B5CF6' : '#A78BFA'
      })
      .borderRadius(10)
    } else {
      Column() {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.eye'))
            .fontSize(13)
            .fontColor([inTerminal ? '#94A3B8' : $r('sys.color.font_tertiary')])
          Text('··· 隐藏低语 · 轻触显影')
            .fontSize(AppTypography.CAPTION_M)
            .fontColor(inTerminal ? '#94A3B8' : $r('sys.color.font_tertiary'))
        }
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor(inTerminal ? '#1E242C' : $r('sys.color.comp_background_tertiary'))
        .border({
          width: 0.8,
          style: BorderStyle.Dashed,
          color: inTerminal ? '#475569' : $r('sys.color.comp_divider')
        })
        .borderRadius(14)
        .onClick(() => this.toggleLocalHiddenKey(row.key))
      }
      .width('100%')
      .alignItems(row.block.textAlign === ScpTextAlign.CENTER ?
        HorizontalAlign.Center :
        (row.block.textAlign === ScpTextAlign.END ? HorizontalAlign.End : HorizontalAlign.Start))
    }
  }

  @Builder
  private headingBlock(row: ArticleBlockRowState, inTerminal: boolean = false) {
    Column() {
      this.spanText(
        row,
        inTerminal,
        true,
        true,
        this.fontSize * (row.block.level <= 1 ? 1.35 : (row.block.level === 2 ? 1.2 : 1.1))
      )
    }
    .width('100%')
    .margin({ top: 8 })
  }

  @Builder
  private quoteBlock(row: ArticleBlockRowState, inTerminal: boolean = false) {
    Column({ space: 8 }) {
      ForEach(row.children, (child: ArticleBlockRowState) => {
        this.blockView(child, inTerminal)
      }, (child: ArticleBlockRowState) => child.key)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .border({ width: { left: 3 }, color: inTerminal ? '#475569' : $r('sys.color.comp_divider') })
    .backgroundColor(inTerminal ? '#1E242C' : $r('sys.color.comp_background_tertiary'))
    .borderRadius(8)
  }

  @Builder
  private collapsibleBlock(row: ArticleBlockRowState, inTerminal: boolean = false) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([inTerminal ? '#94A3B8' : $r('sys.color.icon_secondary')])
          .rotate({ angle: this.isExpanded(row.block) ? 90 : 0 })
          .animation(AppMotion.springAnimateParam(false))
        Text((this.isExpanded(row.block) && row.block.closeCaption.length > 0) ?
          row.block.closeCaption :
          (row.block.caption.length > 0 ? row.block.caption : '展开内容'))
          .fontSize(this.fontSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(inTerminal ? '#F1F5F9' : $r('sys.color.font'))
          .layoutWeight(1)
      }
      .attributeModifier(ROW_PRESS_MODIFIER)
      .animation(pressAnimation())
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(inTerminal ? '#232A34' : $r('sys.color.comp_background_tertiary'))
      .borderRadius(10)
      .overlay(this.anchorHighlightOverlay(this.isBlockHighlighted(row.block)))
      .onClick(() => {
        this.getUIContext().animateTo(AppMotion.springAnimateParam(false), (): void => {
          this.onToggleExpanded(row.block);
        });
      })

      if (this.isExpanded(row.block)) {
        Column({ space: 12 }) {
          ForEach(row.children, (child: ArticleBlockRowState) => {
            this.blockView(child, inTerminal)
          }, (child: ArticleBlockRowState) => child.key)
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .transition(
          isReduceMotionEnabled() ? TransitionEffect.IDENTITY :
            TransitionEffect.OPACITY.combine(TransitionEffect.move(TransitionEdge.TOP))
              .animation(AppMotion.springAnimateParam(false))
        )
      }
    }
    .width('100%')
    .clip(true)
  }

  @Builder
  private tableCellContent(
    cell: ArticleBlockRowState,
    inTerminal: boolean,
    fixedWidth: number,
    cellIndex: number
  ) {
    Column() {
      if (cell.spans.length > 0) {
        this.spanText(cell, inTerminal, cell.block.isHeader, true)
      } else {
        Text('')
          .fontSize(this.fontSize)
      }
    }
    .id(this.blockNodeId(cell.key))
    .width(fixedWidth > 0 ? fixedWidth : undefined)
    .layoutWeight(fixedWidth > 0 ? 0 : 1)
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(cell.block.isHeader ?
      (inTerminal ? '#232A34' : $r('sys.color.comp_background_tertiary')) : Color.Transparent)
    .border({
      width: cellIndex > 0 ? { left: 0.5 } : 0,
      color: inTerminal ? '#334155' : $r('sys.color.comp_divider')
    })
  }

  @Builder
  private tableGrid(blockRow: ArticleBlockRowState, inTerminal: boolean, fixedWidth: number) {
    Column() {
      ForEach(blockRow.children, (row: ArticleBlockRowState, rowIndex: number) => {
        Row() {
          ForEach(row.children, (cell: ArticleBlockRowState, cellIndex: number) => {
            this.tableCellContent(cell, inTerminal, fixedWidth, cellIndex)
          }, (cell: ArticleBlockRowState) => cell.key)
        }
        .id(this.blockNodeId(row.key))
        .width(fixedWidth > 0 ? undefined : '100%')
        .alignItems(VerticalAlign.Top)
        .border({
          width: rowIndex > 0 ? { top: 0.5 } : 0,
          color: inTerminal ? '#334155' : $r('sys.color.comp_divider')
        })
      }, (row: ArticleBlockRowState) => row.key)
    }
    .width(fixedWidth > 0 ? undefined : '100%')
    .backgroundColor(inTerminal ? '#181E27' : $r('sys.color.comp_background_primary'))
    .border({ width: 0.8, color: inTerminal ? '#334155' : $r('sys.color.comp_divider') })
    .borderRadius(8)
    .clip(true)
  }

  @Builder
  private tableBlock(blockRow: ArticleBlockRowState, inTerminal: boolean = false) {
    if (this.maxTableColumnCount(blockRow) >= 3) {
      Scroll() {
        this.tableGrid(blockRow, inTerminal, this.tableColumnWidth(this.maxTableColumnCount(blockRow)))
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .align(Alignment.Start)
    } else {
      this.tableGrid(blockRow, inTerminal, 0)
    }
  }

  @Builder
  private acsBadgeChip(label: string, value: string, tintColor: ResourceColor) {
    Row({ space: 6 }) {
      Text(label)
        .fontSize(AppTypography.CAPTION_M)
        .fontColor($r('sys.color.font_secondary'))
      Text(value)
        .fontSize(AppTypography.CAPTION_L)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
        .backgroundColor(tintColor)
        .borderRadius(6)
    }
    .padding({ left: 8, right: 6, top: 4, bottom: 4 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(8)
  }

  @Builder
  private acsHeaderBlock(row: ArticleBlockRowState) {
    if (row.block.acs !== undefined) {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text(row.block.acs.itemNumber.length > 0 ?
            `SCP-${row.block.acs.itemNumber}` : '异常分类栏')
            .fontSize(AppTypography.SUBTITLE_M)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font'))
            .layoutWeight(1)
          if (row.block.acs.clearanceLevel.length > 0) {
            Text(`Level ${row.block.acs.clearanceLevel}`)
              .fontSize(AppTypography.CAPTION_L)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_emphasize'))
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(badgeInfoBackgroundColor())
              .borderRadius(8)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          if (row.block.acs.containmentClass.length > 0) {
            this.acsBadgeChip(
              '收容',
              row.block.acs.containmentClass,
              objectClassColor(row.block.acs.containmentClass)
            )
          }
          if (row.block.acs.secondaryClass.length > 0) {
            this.acsBadgeChip('次要', row.block.acs.secondaryClass, '#64748B')
          }
          if (row.block.acs.disruptionClass.length > 0) {
            this.acsBadgeChip(
              '扰动',
              row.block.acs.disruptionClass,
              this.acsDisruptionColor(row.block.acs.disruptionClass)
            )
          }
          if (row.block.acs.riskClass.length > 0) {
            this.acsBadgeChip(
              '风险',
              row.block.acs.riskClass,
              this.acsRiskColor(row.block.acs.riskClass)
            )
          }
        }
        .width('100%')

        if (row.block.acs.memoUrl.length > 0) {
          Text('查看分类委员会备忘录 ›')
            .fontSize(AppTypography.CAPTION_M)
            .fontColor($r('sys.color.font_emphasize'))
            .onClick(() => this.handleOpenArticleLink(row.block.acs!.memoUrl, '分类委员会备忘录'))
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(14)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 0.8, color: materialCardBorderColor(this.materialEnabled) })
      .borderRadius(12)
    }
  }

  @Builder
  private tabsBlock(row: ArticleBlockRowState, inTerminal: boolean = false) {
    Column({ space: 10 }) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(row.children, (panel: ArticleBlockRowState, index: number) => {
            Text(panel.block.caption.length > 0 ? panel.block.caption : `标签 ${index + 1}`)
              .id(this.blockNodeId(panel.key))
              .fontSize(AppTypography.CAPTION_L)
              .fontWeight(row.activeTabIndex === index ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(row.activeTabIndex === index ?
                accentPillForegroundColor() :
                (inTerminal ? '#CBD5E1' : $r('sys.color.font_secondary')))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(row.activeTabIndex === index ?
                accentPillBackgroundColor() :
                (inTerminal ? '#232A34' : $r('sys.color.comp_background_tertiary')))
              .borderRadius(16)
              .animation(pressAnimation())
              .onClick(() => {
                this.getUIContext().animateTo(AppMotion.microAnimateParam(), (): void => {
                  row.activeTabIndex = index;
                });
              })
          }, (panel: ArticleBlockRowState) => panel.key)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      if (row.children.length > 0) {
        Column({ space: 12 }) {
          ForEach(
            row.children[Math.max(0, Math.min(row.activeTabIndex, row.children.length - 1))].children,
            (child: ArticleBlockRowState) => {
              this.blockView(child, inTerminal)
            },
            (child: ArticleBlockRowState) => child.key
          )
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor(inTerminal ? '#1B212A' : $r('sys.color.comp_background_primary'))
        .border({ width: 0.8, color: inTerminal ? '#334155' : materialCardBorderColor(this.materialEnabled) })
        .borderRadius(12)
        .transition(AppMotion.fadeTransition(AppMotion.MICRO_DURATION))
      }
    }
    .width('100%')
  }

  @Builder
  private calloutBlock(
    row: ArticleBlockRowState,
    parentInTerminal: boolean = false
  ) {
    Column() {
      if (row.block.calloutTone === ScpCalloutTone.TERMINAL || parentInTerminal) {
        Column({ space: 10 }) {
          ForEach(row.children, (child: ArticleBlockRowState) => {
            this.blockView(child, true)
          }, (child: ArticleBlockRowState) => child.key)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(14)
        .backgroundColor('#15191F')
        .border({ width: 1, color: '#334155' })
        .borderRadius(12)
      } else if (row.block.calloutTone === ScpCalloutTone.WARNING) {
        Column({ space: 10 }) {
          ForEach(row.children, (child: ArticleBlockRowState) => {
            this.blockView(child, false)
          }, (child: ArticleBlockRowState) => child.key)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 14, right: 12, top: 12, bottom: 12 })
        .backgroundColor('#14D9383A')
        .border({ width: { left: 3 }, color: '#D9383A' })
        .borderRadius(10)
      } else if (row.block.calloutTone === ScpCalloutTone.NOTE) {
        Column({ space: 10 }) {
          ForEach(row.children, (child: ArticleBlockRowState) => {
            this.blockView(child, false)
          }, (child: ArticleBlockRowState) => child.key)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .border({
          width: 1,
          style: BorderStyle.Dashed,
          color: $r('sys.color.comp_divider')
        })
        .borderRadius(10)
      } else {
        Column({ space: 10 }) {
          ForEach(row.children, (child: ArticleBlockRowState) => {
            this.blockView(child, false)
          }, (child: ArticleBlockRowState) => child.key)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .border({ width: 0.8, color: materialCardBorderColor(this.materialEnabled) })
        .borderRadius(10)
      }
    }
    .width('100%')
    .overlay(this.anchorHighlightOverlay(this.isBlockHighlighted(row.block)))
  }

  @Builder
  private codeBlock(row: ArticleBlockRowState, inTerminal: boolean = false) {
    Scroll() {
      Text(this.textOf(row.block))
        .fontFamily('monospace')
        .fontSize(Math.max(12, this.fontSize - 2))
        .lineHeight(Math.max(18, this.fontSize * 1.35))
        .fontColor(inTerminal ? '#67E8F9' : $r('sys.color.font'))
        .padding(12)
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Start)
    .width('100%')
    .backgroundColor(inTerminal ? '#0F141A' : $r('sys.color.comp_background_tertiary'))
    .border({ width: 0.5, color: inTerminal ? '#334155' : $r('sys.color.comp_divider') })
    .borderRadius(10)
    .overlay(this.anchorHighlightOverlay(this.isBlockHighlighted(row.block)))
  }

  @Builder
  private listBlock(row: ArticleBlockRowState, inTerminal: boolean = false) {
    Column({ space: 6 }) {
      ForEach(row.children, (item: ArticleBlockRowState, itemIndex: number) => {
        Column({ space: 6 }) {
          if (item.spans.length > 0) {
            Row({ space: 8 }) {
              Text(row.block.ordered ? `${itemIndex + 1}.` : (item.block.level % 2 === 0 ? '•' : '◦'))
                .fontSize(this.fontSize)
                .lineHeightMultiple(this.lineHeightMultiple)
                .fontColor(inTerminal ? '#94A3B8' : $r('sys.color.font_secondary'))
                .fontWeight(row.block.ordered ? FontWeight.Medium : FontWeight.Bold)
              Column() {
                this.spanText(item, inTerminal, false, true)
              }
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }
          if (item.children.length > 0) {
            Column({ space: 6 }) {
              ForEach(item.children, (nested: ArticleBlockRowState) => {
                this.blockView(nested, inTerminal)
              }, (nested: ArticleBlockRowState) => nested.key)
            }
            .width('100%')
            .padding({ left: 16 })
          }
        }
        .id(this.blockNodeId(item.key))
        .width('100%')
      }, (item: ArticleBlockRowState) => item.key)
    }
    .width('100%')
    .padding({ left: row.block.level > 0 ? 4 : 0 })
  }

  @Builder
  private embedBlock(row: ArticleBlockRowState) {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.rectangle_on_rectangle'))
        .fontSize(20)
        .fontColor([$r('sys.color.icon_secondary')])
      Text('嵌入交互组件（建议原版网页打开）')
        .fontSize(this.fontSize)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font'))
        .layoutWeight(1)
      Button('原版网页打开', { stateEffect: false })
        .fontSize(AppTypography.CAPTION_L)
        .height(32)
        .onClick(() => this.onSwitchToWebMode())
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(10)
  }

  @Builder
  private standaloneImageBlock(
    row: ArticleBlockRowState,
    inTerminal: boolean = false
  ) {
    Column({ space: 6 }) {
      ScpArticleImage({
        url: row.block.source,
        localSource: this.resolveLocalImageUri(row.block.source),
        preferredWidth: row.block.preferredWidth,
        inlineMode: true,
        onOpen: () => {
          const galleryIndex = this.imageIndexOf(row.block.source);
          if (galleryIndex >= 0) {
            this.onOpenImage(galleryIndex);
          } else {
            this.handleOpenUrl(row.block.source);
          }
        },
        onOpenInBrowser: (url: string) => this.handleOpenUrl(url)
      })
      if (row.block.caption.length > 0) {
        Text(row.block.caption)
          .fontSize(AppTypography.CAPTION_L)
          .fontColor(inTerminal ? '#94A3B8' : $r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding(4)
    .background(this.anchorHighlightBackdrop(this.isBlockHighlighted(row.block)))
  }

  @Builder
  private unsupportedBlock(
    row: ArticleBlockRowState,
    inTerminal: boolean = false
  ) {
    if (row.spans.length > 0) {
      this.spanText(row, inTerminal)
    } else if (row.children.length > 0) {
      Column({ space: 12 }) {
        ForEach(row.children, (child: ArticleBlockRowState) => {
          this.blockView(child, inTerminal)
        }, (child: ArticleBlockRowState) => child.key)
      }
      .width('100%')
    } else {
      Text('该部分含特殊排版或交互，可切换原版网页查看')
        .fontSize(AppTypography.CAPTION_L)
        .fontColor(inTerminal ? '#94A3B8' : $r('sys.color.font_tertiary'))
        .padding(10)
        .width('100%')
    }
  }

  @Builder
  private blockView(row: ArticleBlockRowState, inTerminal: boolean = false) {
    Column() {
      this.blockContent(row, inTerminal)
    }
    .width('100%')
    .id(this.blockNodeId(row.key))
  }

  @Builder
  private blockContent(row: ArticleBlockRowState, inTerminal: boolean) {
    if (row.block.type === ScpBlockType.PARAGRAPH) {
      if (ArticleRenderer.isPureWhisperBlock(row.block)) {
        this.pureWhisperBlock(row, inTerminal)
      } else {
        this.spanText(row, inTerminal)
      }
    } else if (row.block.type === ScpBlockType.HEADING) {
      this.headingBlock(row, inTerminal)
    } else if (row.block.type === ScpBlockType.QUOTE) {
      this.quoteBlock(row, inTerminal)
    } else if (row.block.type === ScpBlockType.COLLAPSIBLE) {
      this.collapsibleBlock(row, inTerminal)
    } else if (row.block.type === ScpBlockType.ACS_HEADER) {
      this.acsHeaderBlock(row)
    } else if (row.block.type === ScpBlockType.TABS) {
      this.tabsBlock(row, inTerminal)
    } else if (row.block.type === ScpBlockType.CALLOUT) {
      this.calloutBlock(row, inTerminal)
    } else if (row.block.type === ScpBlockType.CODE_BLOCK) {
      this.codeBlock(row, inTerminal)
    } else if (row.block.type === ScpBlockType.LIST) {
      this.listBlock(row, inTerminal)
    } else if (row.block.type === ScpBlockType.TABLE) {
      this.tableBlock(row, inTerminal)
    } else if (row.block.type === ScpBlockType.EMBED) {
      this.embedBlock(row)
    } else if (row.block.type === ScpBlockType.IMAGE) {
      this.standaloneImageBlock(row, inTerminal)
    } else if (row.block.type === ScpBlockType.UNSUPPORTED) {
      this.unsupportedBlock(row, inTerminal)
    } else if (row.block.type === ScpBlockType.DIVIDER) {
      Divider()
        .strokeWidth(0.5)
        .color(inTerminal ? '#334155' : $r('sys.color.comp_divider'))
        .margin({ top: 8, bottom: 8 })
    }
  }

  private openSeriesChecklist(): void {
    if (this.seriesContext === undefined) {
      return;
    }
    this.sheetMode = ArticleSheetMode.SERIES_CHECKLIST;
  }

  private seriesTierLabel(tier: StorySeriesTier): string {
    if (tier === StorySeriesTier.SIDE) {
      return '支线';
    }
    if (tier === StorySeriesTier.EXTENDED) {
      return '延伸';
    }
    return '主线';
  }

  private seriesTierTextColor(tier: StorySeriesTier): ResourceColor {
    if (tier === StorySeriesTier.MAINLINE) {
      return $r('sys.color.font_emphasize');
    }
    return $r('sys.color.font_secondary');
  }

  private seriesTierBackgroundColor(tier: StorySeriesTier): ResourceColor {
    if (tier === StorySeriesTier.MAINLINE) {
      return badgeInfoBackgroundColor();
    }
    return $r('sys.color.comp_background_tertiary');
  }

  private isSeriesEntryActive(entry: StorySeriesEntry): boolean {
    return this.seriesContext !== undefined &&
      this.seriesContext.currentEntry !== undefined &&
      this.seriesContext.currentEntry.id === entry.id;
  }

  private isSeriesEntryNextResume(entry: StorySeriesEntry): boolean {
    if (this.seriesContext === undefined || this.isSeriesEntryActive(entry)) {
      return false;
    }
    return this.seriesContext.resumeEntry !== undefined &&
      this.seriesContext.resumeEntry.id === entry.id;
  }

  private seriesEntryCompleted(entry: StorySeriesEntry): boolean {
    if (this.seriesRevision < 0) {
      return false;
    }
    return this.isSeriesEntryCompleted(entry.id);
  }

  private seriesGroupCompletedCount(group: StorySeriesGroup): number {
    if (this.seriesRevision < 0) {
      return 0;
    }
    let done = 0;
    for (let index = 0; index < group.entries.length; index++) {
      if (this.isSeriesEntryCompleted(group.entries[index].id)) {
        done++;
      }
    }
    return done;
  }

  private seriesHubPrimaryLabel(): string {
    if (this.seriesContext === undefined) {
      return '开始跟读';
    }
    const resume = this.seriesContext.resumeEntry;
    if ((this.seriesContext.enrolled || this.seriesContext.mainlineCompleted > 0) &&
      resume !== undefined) {
      return `继续跟读 · ${resume.title}`;
    }
    return resume !== undefined ? `开始跟读 · ${resume.title}` : '开始跟读';
  }

  private seriesFooterPositionLabel(): string {
    if (this.seriesContext === undefined || this.seriesContext.currentGroupTitle.length === 0) {
      return '';
    }
    if (this.seriesContext.currentGroupTotal > 0 && this.seriesContext.currentGroupIndex > 0) {
      return `${this.seriesContext.currentGroupTitle} ${this.seriesContext.currentGroupIndex}/${this.seriesContext.currentGroupTotal}`;
    }
    return this.seriesContext.currentGroupTitle;
  }

  private seriesFooterNextSubtitle(): string {
    if (this.seriesContext === undefined || this.seriesContext.nextEntry === undefined) {
      return '';
    }
    const next = this.seriesContext.nextEntry;
    if (next.groupTitle.length > 0 && next.groupTitle !== this.seriesContext.currentGroupTitle) {
      return `进入《${next.groupTitle}》${next.note.length > 0 ? ` · ${next.note}` : ''}`;
    }
    return next.note;
  }

  private seriesEntryMetaText(entry: StorySeriesEntry): string {
    const kindLabel = entry.kind === LibraryContentKind.SCP ? 'SCP 档案' : '故事';
    if (entry.author.length > 0 && entry.note.length > 0) {
      return `${kindLabel} · ${entry.author} · ${entry.note}`;
    }
    if (entry.author.length > 0) {
      return `${kindLabel} · ${entry.author}`;
    }
    if (entry.note.length > 0) {
      return `${kindLabel} · ${entry.note}`;
    }
    return `${kindLabel} · ${entry.id}`;
  }

  @Builder
  private seriesHubHeaderCard() {
    if (this.seriesContext !== undefined && this.seriesContext.isHubPage && this.seriesRevision >= 0) {
      Column({ space: 12 }) {
        Row({ space: 8 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.list_book_fill'))
              .fontSize(17)
              .fontColor([$r('sys.color.icon_emphasize')])
          }
          .width(34)
          .height(34)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(badgeInfoBackgroundColor())
          .borderRadius(10)

          Column({ space: 2 }) {
            Text(`系列跟读 · ${this.seriesContext.seriesTitle}`)
              .fontSize(AppTypography.SUBTITLE_M)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font'))
              .maxLines(1)
            Text(`主线已读 ${this.seriesContext.mainlineCompleted}/${this.seriesContext.mainlineTotal} 篇 · 共 ${this.seriesContext.groups.length} 组`)
              .fontSize(AppTypography.CAPTION_L)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('Wiki 顺序')
            .fontSize(AppTypography.CAPTION_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_emphasize'))
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(badgeInfoBackgroundColor())
            .borderRadius(9)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 10 }) {
          Row({ space: 6 }) {
            Text(this.seriesHubPrimaryLabel())
              .fontSize(AppTypography.BODY_S)
              .fontWeight(FontWeight.Medium)
              .fontColor(accentPillForegroundColor())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(13)
              .fontColor([accentPillForegroundColor()])
          }
          .id('seriesHubStartButton')
          .attributeModifier(ROW_PRESS_MODIFIER)
          .animation(pressAnimation())
          .layoutWeight(1)
          .height(38)
          .padding({ left: 14, right: 12 })
          .backgroundColor(accentPillBackgroundColor())
          .borderRadius(19)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            if (this.seriesContext !== undefined) {
              this.onStartSeries(this.seriesContext.seriesId);
            }
          })

          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.list_bullet'))
              .fontSize(13)
              .fontColor([$r('sys.color.font')])
            Text('系列顺序')
              .fontSize(AppTypography.BODY_S)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font'))
          }
          .id('seriesHubChecklistButton')
          .attributeModifier(ROW_PRESS_MODIFIER)
          .animation(pressAnimation())
          .height(38)
          .padding({ left: 12, right: 12 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(19)
          .alignItems(VerticalAlign.Center)
          .onClick(() => this.openSeriesChecklist())
        }
        .width('100%')
      }
      .id('seriesHubHeaderCard')
      .width('100%')
      .padding(14)
      .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
      .border(this.materialEnabled ?
        { width: 0.5, color: materialCardBorderColor(true) } :
        { width: 0.5, color: $r('sys.color.comp_divider') })
      .borderRadius(16)
    }
  }

  @Builder
  private seriesFooterCard() {
    if (this.seriesContext !== undefined && !this.seriesContext.isHubPage && this.seriesRevision >= 0) {
      Column({ space: 12 }) {
        Divider()
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))

        Row({ space: 8 }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.list_book_fill'))
              .fontSize(14)
              .fontColor([$r('sys.color.icon_emphasize')])
            Text(`系列跟读 · ${this.seriesContext.seriesTitle}`)
              .fontSize(AppTypography.CAPTION_L)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_emphasize'))
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(badgeInfoBackgroundColor())
          .borderRadius(10)

          if (this.seriesFooterPositionLabel().length > 0) {
            Text(this.seriesFooterPositionLabel())
              .fontSize(AppTypography.CAPTION_M)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          } else {
            Blank()
          }

          Text(`主线 ${this.seriesContext.mainlineCompleted}/${this.seriesContext.mainlineTotal}`)
            .fontSize(AppTypography.CAPTION_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.seriesContext.nextEntry !== undefined) {
          Row({ space: 10 }) {
            Column({ space: 3 }) {
              Text(`下一篇 · ${this.seriesContext.nextEntry.title}`)
                .fontSize(AppTypography.BODY_M)
                .fontWeight(FontWeight.Bold)
                .fontColor(accentPillForegroundColor())
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (this.seriesFooterNextSubtitle().length > 0) {
                Text(this.seriesFooterNextSubtitle())
                  .fontSize(AppTypography.CAPTION_M)
                  .fontColor(accentPillForegroundColor())
                  .opacity(0.88)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(15)
              .fontColor([accentPillForegroundColor()])
          }
          .id('seriesFooterNextButton')
          .attributeModifier(CARD_PRESS_MODIFIER)
          .animation(pressAnimation())
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .backgroundColor(accentPillBackgroundColor())
          .borderRadius(14)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            if (this.seriesContext?.nextEntry !== undefined) {
              this.onOpenSeriesEntry(this.seriesContext.nextEntry, true);
            }
          })
        } else {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(16)
              .fontColor(['#16A34A'])
            Text(`已读至《${this.seriesContext.currentGroupTitle}》末尾`)
              .fontSize(AppTypography.BODY_S)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font'))
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(12)
        }

        Row({ space: 8 }) {
          if (this.seriesContext.previousEntry !== undefined) {
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.chevron_left'))
                .fontSize(12)
                .fontColor([$r('sys.color.font')])
              Text(`上一篇 · ${this.seriesContext.previousEntry.title}`)
                .fontSize(AppTypography.CAPTION_L)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .constraintSize({ maxWidth: '48%' })
            .height(34)
            .padding({ left: 10, right: 10 })
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(17)
            .onClick(() => {
              if (this.seriesContext?.previousEntry !== undefined) {
                this.onOpenSeriesEntry(this.seriesContext.previousEntry, false);
              }
            })
          }

          Blank()

          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.list_bullet'))
              .fontSize(12)
              .fontColor([$r('sys.color.font')])
            Text('系列顺序')
              .fontSize(AppTypography.CAPTION_L)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font'))
          }
          .id('seriesFooterChecklistButton')
          .height(34)
          .padding({ left: 11, right: 11 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(17)
          .onClick(() => this.openSeriesChecklist())

          Text('中心页')
            .fontSize(AppTypography.CAPTION_L)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font'))
            .height(34)
            .padding({ left: 11, right: 11 })
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(17)
            .onClick(() => {
              if (this.seriesContext !== undefined) {
                this.onOpenSeriesHub(this.seriesContext.hubId, this.seriesContext.seriesTitle);
              }
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .id('seriesFooterCard')
      .width('100%')
      .padding(14)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
    }
  }

  @Builder
  private headerCard() {
    if (this.hasHeaderCardContent()) {
      Column({ space: 10 }) {
        if (this.document.objectClass.length > 0 || this.document.rating.length > 0) {
          Row({ space: 10 }) {
            if (this.document.objectClass.length > 0) {
              Text(this.document.objectClass)
                .fontSize(AppTypography.SUBTITLE_S)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor(objectClassColor(this.document.objectClass))
                .borderRadius(6)
            }
            if (this.document.rating.length > 0) {
              Text(this.document.rating)
                .fontSize(AppTypography.SUBTITLE_S)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_secondary'))
            }
            Blank()
          }
          .width('100%')
        }

        if (this.document.tags.length > 0) {
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
            ForEach(this.document.tags, (tag: string) => {
              Text(tag)
                .fontSize(AppTypography.CAPTION_L)
                .fontColor($r('sys.color.font_secondary'))
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor($r('sys.color.comp_background_tertiary'))
                .borderRadius(6)
            }, (tag: string) => tag)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(14)
    }
  }

  @Builder
  private imageGallery() {
    if (this.document.images.length > 0) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Swiper(this.galleryController) {
          ForEach(this.imageRows, (row: ArticleBlockRowState) => {
            Column({ space: 6 }) {
              ScpArticleImage({
                url: row.block.source,
                localSource: this.resolveLocalImageUri(row.block.source),
                onOpen: () => this.onOpenImage(row.index),
                onOpenInBrowser: (url: string) => this.onOpenUrl(url)
              })
              if (row.block.caption.length > 0) {
                Text(row.block.caption)
                  .fontSize(AppTypography.CAPTION_L)
                  .fontColor($r('sys.color.font_secondary'))
                  .textAlign(TextAlign.Center)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
            }
            .width('100%')
          }, (row: ArticleBlockRowState) => row.key)
        }
        .width('100%')
        .height(280)
        .loop(this.document.images.length > 1)
        .indicator(false)
        .onChange((index: number) => {
          this.galleryIndex = index;
        })

        if (this.document.images.length > 1) {
          Text(`${this.galleryIndex + 1} / ${this.document.images.length}`)
            .fontSize(AppTypography.CAPTION_M)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#80000000')
            .borderRadius(12)
            .margin({ top: 10, right: 12 })
        }
      }
      .width('100%')
    }
  }

  @Builder
  private footnotesHeaderView() {
    Column({ space: 12 }) {
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
      Text('脚注')
        .fontSize(AppTypography.SUBTITLE_M)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font'))
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  private footnoteItemView(row: ArticleFootnoteRowState) {
    Row({ space: 6 }) {
      Text(`${row.footnote.index}.`)
        .fontSize(this.fontSize)
        .lineHeightMultiple(this.lineHeightMultiple)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_emphasize'))
      Column({ space: 6 }) {
        ForEach(row.blocks, (block: ArticleBlockRowState) => {
          this.blockView(block, false)
        }, (block: ArticleBlockRowState) => block.key)
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.arrow_up'))
            .fontSize(13)
            .fontColor([$r('sys.color.font_emphasize')])
          Text('返回正文')
            .fontSize(AppTypography.CAPTION_L)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_emphasize'))
        }
        .attributeModifier(ROW_PRESS_MODIFIER)
        .animation(pressAnimation())
        .constraintSize({ minHeight: 34 })
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(17)
        .onClick(() => this.jumpToFootnoteReference(row.footnote.id))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .background(this.anchorHighlightBackdrop(this.isFootnoteHighlighted(row.footnote.id)))
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private relatedTalesSection() {
    if (this.relatedTales.length > 0) {
      Column({ space: 10 }) {
        Divider()
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        Row({ space: 8 }) {
          Text('关联故事')
            .fontSize(AppTypography.SUBTITLE_M)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font'))
          if (this.relatedTalesSourceBadge().length > 0) {
            Text(this.relatedTalesSourceBadge())
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isCuratedRelatedTales() ?
                $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(9)
              .backgroundColor(this.isCuratedRelatedTales() ?
                badgeInfoBackgroundColor() : $r('sys.color.comp_background_tertiary'))
          }
          Blank()
          Text(`共 ${this.relatedTaleRows.length} 篇`)
            .fontSize(AppTypography.CAPTION_M)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        ForEach(this.visibleBottomRelatedTaleRows(), (row: ArticleRelatedTaleRowState) => {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text(row.tale.title)
                .fontSize(AppTypography.BODY_M)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(row.tale.id)
                .fontSize(AppTypography.CAPTION_M)
                .fontColor($r('sys.color.font_tertiary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(14)
              .fontColor([$r('sys.color.icon_secondary')])
          }
          .attributeModifier(ROW_PRESS_MODIFIER)
          .animation(pressAnimation())
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(12)
          .onClick(() => this.onOpenRelatedTale(row.tale))
        }, (row: ArticleRelatedTaleRowState) => row.key)

        if (this.relatedTaleRows.length > 8) {
          Row({ space: 6 }) {
            Text(this.relatedTalesExpandLabel())
              .fontSize(AppTypography.BODY_S)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_secondary'))
            SymbolGlyph($r('sys.symbol.chevron_down'))
              .fontSize(13)
              .fontColor([$r('sys.color.icon_secondary')])
              .rotate({ angle: this.expandAllRelatedTales ? 180 : 0 })
          }
          .attributeModifier(ROW_PRESS_MODIFIER)
          .animation(pressAnimation())
          .width('100%')
          .height(40)
          .justifyContent(FlexAlign.Center)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(12)
          .onClick(() => {
            this.expandAllRelatedTales = !this.expandAllRelatedTales;
          })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  private bottomPullPrimaryIcon(): Resource {
    if (!this.completed) {
      return this.bottomPullReady ?
        $r('sys.symbol.checkmark_circle_fill') :
        $r('sys.symbol.arrow_up');
    }
    if (this.bottomPullReady) {
      return $r('sys.symbol.arrow_counterclockwise');
    }
    return this.bottomPullProgress > 0 ?
      $r('sys.symbol.arrow_up') :
      $r('sys.symbol.checkmark_circle_fill');
  }

  private bottomPullPrimaryColor(): Resource | string {
    if (!this.completed) {
      if (this.bottomPullReady) {
        return '#16A34A';
      }
      return this.bottomPullProgress > 0 ?
        $r('sys.color.font_secondary') :
        $r('sys.color.font_tertiary');
    }
    return this.bottomPullProgress > 0 ?
      $r('sys.color.font_secondary') :
      '#16A34A';
  }

  private bottomPullPrimaryText(): string {
    if (!this.completed) {
      return this.bottomPullReady ? '松手标为已读并锁定进度' : '继续上滑标记已读完';
    }
    if (this.bottomPullReady) {
      return '松手取消已读并解锁进度';
    }
    return this.bottomPullProgress > 0 ?
      '继续上滑取消已读标记' :
      '已读完 · 进度已锁定';
  }

  private bottomPullPrimaryWeight(): FontWeight {
    if (this.bottomPullReady || (this.completed && this.bottomPullProgress === 0)) {
      return FontWeight.Medium;
    }
    return FontWeight.Regular;
  }

  private bottomPullBarFillColor(): Resource | string {
    return this.completed ? $r('sys.color.icon_secondary') : '#16A34A';
  }

  private bottomPullBarWidth(): number {
    return Math.round(48 * this.clampValue(this.bottomPullProgress, 0, 1));
  }

  @Builder
  private licenseFooter() {
    Column({ space: 6 }) {
      if (this.bottomPullProgress > 0) {
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width(48)
            .height(2)
            .borderRadius(1)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
          Row()
            .width(this.bottomPullBarWidth())
            .height(2)
            .borderRadius(1)
            .backgroundColor(this.bottomPullBarFillColor())
        }
        .width(48)
        .height(2)
      }

      Row({ space: 5 }) {
        SymbolGlyph(this.bottomPullPrimaryIcon())
          .fontSize(12)
          .fontColor([this.bottomPullPrimaryColor()])
        Text(this.bottomPullPrimaryText())
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(this.bottomPullPrimaryWeight())
          .fontColor(this.bottomPullPrimaryColor())
      }
      .alignItems(VerticalAlign.Center)

      Button(this.completed ? '取消已读标记' : '标为已读')
        .id('articleCompletionButton')
        .fontSize(AppTypography.CAPTION_L)
        .onClick((): void => this.onToggleCompleted())

      if (this.document.pageVersion.length > 0) {
        Text(this.document.pageVersion)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
          .margin({ top: 4 })
      }
    }
    .id('articleCompletionFooter')
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 18, bottom: 16 })
  }

  private hasArticleMetadataChips(): boolean {
    return this.document.objectClass.length > 0 ||
      this.document.rating.length > 0 ||
      this.document.tags.length > 0;
  }

  private hasHeaderCardContent(): boolean {
    return this.hasArticleMetadataChips();
  }

  private currentOfflineSnapshot(): ArticleOfflineSnapshot | undefined {
    if (this.offlineRevision < 0) {
      return undefined;
    }
    return this.offlineSnapshot;
  }

  private resolveLocalImageUri(rawUrl: string): string {
    const snapshot = this.currentOfflineSnapshot();
    if (snapshot === undefined) {
      return '';
    }
    const baseUrl = this.document.sourceUrl.length > 0 ? this.document.sourceUrl : snapshot.sourceUrl;
    const normalized = normalizeOfflineImageUrl(rawUrl, baseUrl);
    if (normalized.length === 0) {
      return '';
    }
    return snapshot.localImageUris.get(normalized) ?? '';
  }

  @Builder
  private partialNoticeView() {
    ContentUpdateNotice({
      message: this.partialUpdateFailed ? '更新失败，仍可阅读缓存正文' : '当前显示缓存正文',
      updating: this.partialRefreshing,
      updatingMessage: '正在更新正文…',
      onRetry: () => this.onRetryPartial()
    })
      .margin({ top: 8 })
  }

  @Builder
  private webRecommendBannerView() {
    Row({ space: 10 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.website'))
          .fontSize(17)
          .fontColor([$r('sys.color.icon_emphasize')])
      }
      .width(32)
      .height(32)
      .borderRadius(16)
      .backgroundColor(badgeInfoBackgroundColor())
      .justifyContent(FlexAlign.Center)

      Text(this.webModeHint)
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font'))
        .lineHeight(18)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Text('原版网页')
        .fontSize(AppTypography.CAPTION_M)
        .fontWeight(FontWeight.Medium)
        .fontColor(accentPillForegroundColor())
        .height(30)
        .padding({ left: 12, right: 12 })
        .borderRadius(15)
        .backgroundColor(accentPillBackgroundColor())
        .textAlign(TextAlign.Center)
        .onClick(() => this.onSwitchToWebMode())
        .accessibilityText('切换原版网页模式')
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 10, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.8, color: materialCardBorderColor(this.materialEnabled) })
    .borderRadius(14)
    .margin({ top: 8 })
  }

  @Builder
  private quoteChildBlock(section: ArticleSectionRow) {
    Column() {
      if (section.blockRow !== undefined) {
        this.blockView(section.blockRow)
      }
    }
    .width('100%')
    .padding({
      left: 12,
      right: 12,
      top: section.quoteFirst ? 10 : 4,
      bottom: section.quoteLast ? 10 : 4
    })
    .border({ width: { left: 3 }, color: $r('sys.color.comp_divider') })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius({
      topLeft: section.quoteFirst ? 8 : 0,
      topRight: section.quoteFirst ? 8 : 0,
      bottomLeft: section.quoteLast ? 8 : 0,
      bottomRight: section.quoteLast ? 8 : 0
    })
  }

  private calloutChildBackground(tone: ScpCalloutTone): ResourceColor {
    if (tone === ScpCalloutTone.TERMINAL) {
      return '#15191F';
    }
    if (tone === ScpCalloutTone.WARNING) {
      return '#14D9383A';
    }
    return $r('sys.color.comp_background_primary');
  }

  private calloutChildBorder(section: ArticleSectionRow): BorderOptions {
    const tone = section.calloutTone;
    if (tone === ScpCalloutTone.WARNING) {
      return { width: { left: 3 }, color: '#D9383A' };
    }
    const sideWidth = tone === ScpCalloutTone.TERMINAL || tone === ScpCalloutTone.NOTE ? 1 : 0.8;
    const borderColor: ResourceColor = tone === ScpCalloutTone.TERMINAL ?
      '#334155' :
      (tone === ScpCalloutTone.NOTE ?
        $r('sys.color.comp_divider') :
        materialCardBorderColor(this.materialEnabled));
    return {
      width: {
        left: sideWidth,
        right: sideWidth,
        top: section.quoteFirst ? sideWidth : 0,
        bottom: section.quoteLast ? sideWidth : 0
      },
      style: tone === ScpCalloutTone.NOTE ? BorderStyle.Dashed : BorderStyle.Solid,
      color: borderColor
    };
  }

  private calloutChildRadius(section: ArticleSectionRow): BorderRadiuses {
    const r = section.calloutTone === ScpCalloutTone.TERMINAL ? 12 : 10;
    return {
      topLeft: section.quoteFirst ? r : 0,
      topRight: section.quoteFirst ? r : 0,
      bottomLeft: section.quoteLast ? r : 0,
      bottomRight: section.quoteLast ? r : 0
    };
  }

  @Builder
  private calloutChildBlock(section: ArticleSectionRow) {
    Column() {
      if (section.blockRow !== undefined) {
        this.blockView(section.blockRow, section.calloutTone === ScpCalloutTone.TERMINAL)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: section.calloutTone === ScpCalloutTone.WARNING ||
        section.calloutTone === ScpCalloutTone.TERMINAL ? 14 : 12,
      right: section.calloutTone === ScpCalloutTone.TERMINAL ? 14 : 12,
      top: section.quoteFirst ? (section.calloutTone === ScpCalloutTone.TERMINAL ? 14 : 12) : 5,
      bottom: section.quoteLast ? (section.calloutTone === ScpCalloutTone.TERMINAL ? 14 : 12) : 5
    })
    .backgroundColor(this.calloutChildBackground(section.calloutTone))
    .border(this.calloutChildBorder(section))
    .borderRadius(this.calloutChildRadius(section))
  }

  @Builder
  private sectionView(section: ArticleSectionRow) {
    if (section.kind === ArticleSectionKind.PARTIAL_NOTICE) {
      this.partialNoticeView()
    } else if (section.kind === ArticleSectionKind.WEB_RECOMMEND_BANNER) {
      this.webRecommendBannerView()
    } else if (section.kind === ArticleSectionKind.HEADER_CARD) {
      this.headerCard()
    } else if (section.kind === ArticleSectionKind.SERIES_HUB_HEADER) {
      this.seriesHubHeaderCard()
    } else if (section.kind === ArticleSectionKind.GALLERY) {
      this.imageGallery()
    } else if (section.kind === ArticleSectionKind.BLOCK && section.blockRow !== undefined) {
      this.blockView(section.blockRow)
    } else if (section.kind === ArticleSectionKind.QUOTE_CHILD) {
      this.quoteChildBlock(section)
    } else if (section.kind === ArticleSectionKind.CALLOUT_CHILD) {
      this.calloutChildBlock(section)
    } else if (section.kind === ArticleSectionKind.FOOTNOTES_HEADER) {
      this.footnotesHeaderView()
    } else if (section.kind === ArticleSectionKind.FOOTNOTE && section.footnoteRow !== undefined) {
      this.footnoteItemView(section.footnoteRow)
    } else if (section.kind === ArticleSectionKind.SERIES_FOOTER) {
      this.seriesFooterCard()
    } else if (section.kind === ArticleSectionKind.RELATED_TALES) {
      this.relatedTalesSection()
    } else if (section.kind === ArticleSectionKind.FOOTER) {
      this.licenseFooter()
    }
  }

  @Builder
  private footnoteStepButton(delta: number) {
    Row() {
      Row({ space: 4 }) {
        if (delta < 0) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(14)
            .fontColor([$r('sys.color.font')])
        }
        Text(delta < 0 ? '上一条' : '下一条')
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
        if (delta > 0) {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(14)
            .fontColor([$r('sys.color.font')])
        }
      }
      .attributeModifier(ROW_PRESS_MODIFIER)
      .animation(pressAnimation())
      .constraintSize({ minHeight: 36 })
      .padding({
        left: delta < 0 ? 12 : 14,
        right: delta < 0 ? 14 : 12,
        top: 6,
        bottom: 6
      })
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(18)
      .onClick(() => this.stepFootnote(delta))
    }
    .opacity((delta < 0 ? this.hasPreviousFootnote() : this.hasNextFootnote()) ? 1 : 0.38)
    .enabled(delta < 0 ? this.hasPreviousFootnote() : this.hasNextFootnote())
    .accessibilityText(delta < 0 ? '上一条脚注' : '下一条脚注')
  }

  @Builder
  private tocFilterBar(horizontalPadding: number) {
    if (this.tocItems.length >= 10) {
      Column() {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(14)
            .fontColor([$r('sys.color.icon_secondary')])
          TextInput({ text: this.tocFilterQuery, placeholder: '筛选章节或折叠块…' })
            .fontSize(AppTypography.BODY_S)
            .fontColor($r('sys.color.font'))
            .placeholderColor($r('sys.color.font_tertiary'))
            .backgroundColor(Color.Transparent)
            .padding({ left: 0, right: 0 })
            .height(34)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.tocFilterQuery = value;
            })
          if (this.tocFilterQuery.length > 0) {
            Button({ type: ButtonType.Circle, stateEffect: false }) {
              SymbolGlyph($r('sys.symbol.xmark'))
                .fontSize(11)
                .fontColor([$r('sys.color.icon_secondary')])
            }
            .width(24)
            .height(24)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .accessibilityText('清除目录筛选')
            .onClick(() => {
              this.tocFilterQuery = '';
            })
          }
        }
        .width('100%')
        .padding({ left: 10, right: 8, top: 2, bottom: 2 })
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(12)
      }
      .width('100%')
      .padding({ left: horizontalPadding, right: horizontalPadding, top: 8, bottom: 6 })
    }
  }

  @Builder
  private tocItemCard(item: ArticleTocItem, inSheet: boolean) {
    Row({ space: 8 }) {
      if (item.kind === ArticleTocKind.COLLAPSIBLE) {
        Text('折叠')
          .fontSize(AppTypography.CAPTION_M)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.activeTocItemKey() === item.key ?
            $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(this.activeTocItemKey() === item.key ?
            badgeInfoBackgroundColor() : $r('sys.color.comp_background_tertiary'))
          .borderRadius(6)
      }
      Text(item.title)
        .fontSize(item.kind === ArticleTocKind.HEADING && item.level === 1 ?
          AppTypography.BODY_M : AppTypography.BODY_S)
        .fontWeight(this.activeTocItemKey() === item.key ||
          (item.kind === ArticleTocKind.HEADING && item.level === 1) ?
          FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.activeTocItemKey() === item.key ?
          $r('sys.color.font_emphasize') : $r('sys.color.font'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .attributeModifier(ROW_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: this.tocItemLeftPadding(item),
      right: 12,
      top: 10,
      bottom: 10
    })
    .backgroundColor(this.activeTocItemKey() === item.key ?
      badgeInfoBackgroundColor() : Color.Transparent)
    .borderRadius(12)
    .onClick(() => {
      if (inSheet) {
        this.closeSheet();
        this.clearPendingAnchorTimer();
        this.pendingAnchorTimer = setTimeout((): void => {
          this.pendingAnchorTimer = -1;
          this.jumpToBlockLocation(item.location);
        }, 150);
        return;
      }
      this.jumpToBlockLocation(item.location);
    })
  }

  @Builder
  private tocEmptyState() {
    Column({ space: 8 }) {
      Text('未找到匹配的目录项')
        .fontSize(AppTypography.BODY_S)
        .fontColor($r('sys.color.font_secondary'))
      if (this.tocFilterQuery.length > 0) {
        Text('清除筛选')
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_emphasize'))
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(12)
          .onClick(() => {
            this.tocFilterQuery = '';
          })
      }
    }
    .width('100%')
    .padding({ top: 32, bottom: 32 })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private seriesChecklistEntryRow(entry: StorySeriesEntry, indexInGroup: number) {
    Row({ space: 10 }) {
      if (this.seriesEntryCompleted(entry)) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(18)
          .fontColor(['#16A34A'])
      } else {
        Column() {
          Text(`${indexInGroup + 1}`)
            .fontSize(AppTypography.CAPTION_M)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isSeriesEntryActive(entry) ?
              $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
        }
        .width(20)
        .height(20)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.isSeriesEntryActive(entry) ?
          badgeInfoBackgroundColor() : $r('sys.color.comp_background_tertiary'))
        .borderRadius(10)
      }

      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(entry.title)
            .fontSize(AppTypography.BODY_M)
            .fontWeight(this.isSeriesEntryActive(entry) || this.isSeriesEntryNextResume(entry) ?
              FontWeight.Bold : FontWeight.Medium)
            .fontColor($r('sys.color.font'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.isSeriesEntryActive(entry)) {
            Text('当前')
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Medium)
              .fontColor(accentPillForegroundColor())
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(accentPillBackgroundColor())
              .borderRadius(8)
          } else if (this.isSeriesEntryNextResume(entry)) {
            Text('下一篇')
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_emphasize'))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(badgeInfoBackgroundColor())
              .borderRadius(8)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.seriesEntryMetaText(entry))
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(13)
        .fontColor([$r('sys.color.icon_tertiary')])
    }
    .attributeModifier(ROW_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(this.isSeriesEntryActive(entry) ?
      badgeInfoBackgroundColor() : $r('sys.color.comp_background_primary'))
    .borderRadius(12)
    .onClick(() => {
      this.closeSheet();
      this.onOpenSeriesEntry(entry, false);
    })
  }

  @Builder
  private seriesChecklistGroupCard(group: StorySeriesGroup) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(group.title)
          .fontSize(AppTypography.SUBTITLE_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.seriesTierLabel(group.tier))
          .fontSize(AppTypography.CAPTION_M)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.seriesTierTextColor(group.tier))
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .backgroundColor(this.seriesTierBackgroundColor(group.tier))
          .borderRadius(8)
        Blank()
        Text(`${this.seriesGroupCompletedCount(group)}/${group.entries.length}`)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (group.subtitle.length > 0) {
        Text(group.subtitle)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
      }

      Column({ space: 6 }) {
        ForEach(group.entries, (entry: StorySeriesEntry, idx: number) => {
          this.seriesChecklistEntryRow(entry, idx)
        }, (entry: StorySeriesEntry) =>
          `${this.seriesRevision}:${entry.id}:${this.seriesEntryCompleted(entry) ? 1 : 0}:${this.isSeriesEntryActive(entry) ? 1 : 0}`)
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private seriesChecklistSheetContent() {
    if (this.seriesContext !== undefined) {
      List({ scroller: this.seriesChecklistScroller, space: 12 }) {
        ForEach(this.seriesContext.groups, (group: StorySeriesGroup) => {
          ListItem() {
            this.seriesChecklistGroupCard(group)
          }
        }, (group: StorySeriesGroup) =>
          `${this.seriesRevision}:${group.id}:${this.seriesGroupCompletedCount(group)}`)
      }
      .width('100%')
      .flexShrink(1)
      .constraintSize({
        minHeight: 220,
        maxHeight: shouldUseCenterSheet(windowWidthVp()) ? 480 : 660
      })
      .padding({
        left: adaptivePageMarginForWidth(windowWidthVp()),
        right: adaptivePageMarginForWidth(windowWidthVp()),
        top: 6,
        bottom: 24
      })
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })
    }
  }

  @Builder
  private activeSheetBuilder() {
    Column() {
      if (this.sheetMode === ArticleSheetMode.SERIES_CHECKLIST && this.seriesContext !== undefined) {
        this.seriesChecklistSheetContent()
      } else if (this.sheetMode === ArticleSheetMode.TOC) {
        this.tocFilterBar(adaptivePageMarginForWidth(windowWidthVp()))

        if (this.filteredTocItems().length === 0) {
          this.tocEmptyState()
        } else {
          List({ scroller: this.tocSheetScroller, space: 4 }) {
            ForEach(this.filteredTocItems(), (item: ArticleTocItem) => {
              ListItem() {
                this.tocItemCard(item, true)
              }
            }, (item: ArticleTocItem) => item.key)
          }
          .width('100%')
          .flexShrink(1)
          .constraintSize({
            minHeight: 180,
            maxHeight: shouldUseCenterSheet(windowWidthVp()) ? 440 : 640
          })
          .padding({
            left: adaptivePageMarginForWidth(windowWidthVp()),
            right: adaptivePageMarginForWidth(windowWidthVp()),
            bottom: 24
          })
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)
          .nestedScroll({
            scrollForward: NestedScrollMode.PARENT_FIRST,
            scrollBackward: NestedScrollMode.SELF_FIRST
          })
        }
      } else if (this.currentFootnoteRow() !== undefined) {
        Scroll(this.footnoteSheetScroller) {
          Column({ space: 10 }) {
            ForEach(this.currentFootnoteBlocks(), (block: ArticleBlockRowState) => {
              this.blockView(block, false)
            }, (block: ArticleBlockRowState) => block.key)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({
            left: adaptivePageMarginForWidth(windowWidthVp()),
            right: adaptivePageMarginForWidth(windowWidthVp()),
            top: 4,
            bottom: this.footnoteRows.length > 1 ? 16 : 24
          })
        }
        .width('100%')
        .flexShrink(1)
        .constraintSize({
          minHeight: 56,
          maxHeight: shouldUseCenterSheet(windowWidthVp()) ? 400 : 520
        })
        .align(Alignment.Top)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST
        })

        if (this.footnoteRows.length > 1) {
          Divider()
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))
            .flexShrink(0)

          Row({ space: 8 }) {
            this.footnoteStepButton(-1)

            Blank()

            this.footnoteStepButton(1)
          }
          .width('100%')
          .padding({
            left: adaptivePageMarginForWidth(windowWidthVp()),
            right: adaptivePageMarginForWidth(windowWidthVp()),
            top: 10,
            bottom: 20
          })
          .alignItems(VerticalAlign.Center)
          .flexShrink(0)
        }
      }
    }
    .width('100%')
  }

  @Builder
  private workbenchTabPill(label: string, index: number) {
    Text(label)
      .fontSize(AppTypography.CAPTION_L)
      .fontWeight(this.activeWorkbenchTab === index ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.activeWorkbenchTab === index ?
        accentPillForegroundColor() : $r('sys.color.font_secondary'))
      .height(28)
      .padding({ left: 10, right: 10 })
      .borderRadius(14)
      .backgroundColor(this.activeWorkbenchTab === index ?
        accentPillBackgroundColor() : $r('sys.color.comp_background_tertiary'))
      .onClick(() => {
        this.activeWorkbenchTab = index;
      })
  }

  @Builder
  private sidePanelFootnoteCard(fnRow: ArticleFootnoteRowState) {
    Row({ space: 8 }) {
      Text(`${fnRow.footnote.index}.`)
        .fontSize(AppTypography.BODY_S)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_emphasize'))
      Column({ space: 6 }) {
        ForEach(fnRow.blocks, (block: ArticleBlockRowState) => {
          this.blockView(block, false)
        }, (block: ArticleBlockRowState) => block.key)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding(12)
    .backgroundColor(fnRow.index === this.activeFootnoteIndex ?
      badgeInfoBackgroundColor() : $r('sys.color.comp_background_primary'))
    .border({
      width: fnRow.index === this.activeFootnoteIndex ? 1 : 0.5,
      color: fnRow.index === this.activeFootnoteIndex ?
        $r('sys.color.font_emphasize') : materialCardBorderColor(this.materialEnabled)
    })
    .borderRadius(14)
    .onClick(() => this.selectSidePanelFootnote(fnRow))
  }

  @Builder
  private sidePanelRelatedTaleCard(taleRow: ArticleRelatedTaleRowState) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(taleRow.tale.title)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(taleRow.tale.id)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([$r('sys.color.icon_secondary')])
    }
    .attributeModifier(CARD_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 0.5, color: materialCardBorderColor(this.materialEnabled) })
    .borderRadius(12)
    .onClick(() => this.onOpenRelatedTale(taleRow.tale))
  }

  @Builder
  private researchSidePanelBuilder() {
    Column() {
      Row({ space: 8 }) {
        if (this.availableWorkbenchTabCount() > 1) {
          Row({ space: 6 }) {
            if (this.footnoteRows.length > 0) {
              this.workbenchTabPill(`脚注 ${this.footnoteRows.length}`, WorkbenchTab.FOOTNOTES)
            }
            if (this.tocItems.length > 0) {
              this.workbenchTabPill(`目录 ${this.tocItems.length}`, WorkbenchTab.TOC)
            }
            if (this.relatedTaleRows.length > 0) {
              this.workbenchTabPill(`故事 ${this.relatedTaleRows.length}`, WorkbenchTab.RELATED_TALES)
            }
          }
          .layoutWeight(1)
        } else {
          Text(this.sidePanelHeaderTitle())
            .fontSize(AppTypography.SUBTITLE_M)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font'))
            .layoutWeight(1)
            .maxLines(1)
        }

        Button({ type: ButtonType.Circle, stateEffect: false }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(13)
            .fontColor([$r('sys.color.icon_secondary')])
        }
        .width(28)
        .height(28)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .accessibilityText('收起研读侧栏')
        .onClick(() => this.closeSidePanel())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({
        left: 16,
        right: 16,
        top: this.topPadding + 8,
        bottom: 10
      })

      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))

      if (this.activeWorkbenchTab === WorkbenchTab.FOOTNOTES && this.footnoteRows.length > 0) {
        if (this.footnoteRows.length > 1) {
          Row({ space: 8 }) {
            this.footnoteStepButton(-1)
            Blank()
            Text(this.activeFootnoteIndex >= 0 ?
              `${this.activeFootnoteIndex + 1} / ${this.footnoteRows.length}` :
              `共 ${this.footnoteRows.length} 条`)
              .fontSize(AppTypography.CAPTION_M)
              .fontColor($r('sys.color.font_tertiary'))
            Blank()
            this.footnoteStepButton(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .alignItems(VerticalAlign.Center)

          Divider()
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))
        }

        List({ scroller: this.sidePanelScroller, space: 10 }) {
          ForEach(this.footnoteRows, (fnRow: ArticleFootnoteRowState) => {
            ListItem() {
              this.sidePanelFootnoteCard(fnRow)
            }
          }, (fnRow: ArticleFootnoteRowState) => fnRow.key)
        }
        .width('100%')
        .layoutWeight(1)
        .contentStartOffset(12)
        .contentEndOffset(32)
        .padding({ left: 16, right: 16 })
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Auto)
        .onAppear(() => {
          if (this.activeFootnoteIndex >= 0) {
            this.scrollSidePanelToFootnote(this.activeFootnoteIndex);
          }
        })
      } else if (this.activeWorkbenchTab === WorkbenchTab.TOC && this.tocItems.length > 0) {
        this.tocFilterBar(16)

        if (this.filteredTocItems().length === 0) {
          this.tocEmptyState()
        } else {
          List({ scroller: this.sidePanelTocScroller, space: 4 }) {
            ForEach(this.filteredTocItems(), (item: ArticleTocItem) => {
              ListItem() {
                this.tocItemCard(item, false)
              }
            }, (item: ArticleTocItem) => item.key)
          }
          .width('100%')
          .layoutWeight(1)
          .contentStartOffset(8)
          .contentEndOffset(32)
          .padding({ left: 12, right: 12 })
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Auto)
        }
      } else {
        if (this.relatedTalesSidePanelCaption().length > 0) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.list_book'))
              .fontSize(13)
              .fontColor([this.isCuratedRelatedTales() ?
                $r('sys.color.font_emphasize') : $r('sys.color.icon_secondary')])
            Text(this.relatedTalesSidePanelCaption())
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isCuratedRelatedTales() ?
                $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .alignItems(VerticalAlign.Center)

          Divider()
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))
        }

        List({ space: 10 }) {
          ForEach(this.relatedTaleRows, (taleRow: ArticleRelatedTaleRowState) => {
            ListItem() {
              this.sidePanelRelatedTaleCard(taleRow)
            }
          }, (taleRow: ArticleRelatedTaleRowState) => taleRow.key)
        }
        .width('100%')
        .layoutWeight(1)
        .contentStartOffset(12)
        .contentEndOffset(32)
        .padding({ left: 16, right: 16 })
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Auto)
      }
    }
    .width(resolveArticleSidebarWidth(this.containerWidth))
    .height('100%')
    .border({ width: { left: 0.5 }, color: $r('sys.color.comp_divider') })
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_THICK : undefined)
    .transition(AppMotion.panelEdgeTransition(TransitionEdge.END))
  }

  @Builder
  private articleSearchBar() {
    Column() {
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(15)
            .fontColor([$r('sys.color.icon_secondary')])

          TextInput({ text: this.searchQuery, placeholder: '在文内查找…' })
            .id('articleSearchInput')
            .defaultFocus(true)
            .enterKeyType(EnterKeyType.Search)
            .fontSize(AppTypography.BODY_S)
            .fontColor($r('sys.color.font'))
            .placeholderColor($r('sys.color.font_tertiary'))
            .backgroundColor(Color.Transparent)
            .padding({ left: 0, right: 0 })
            .height(34)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.updateSearchResults(value, true);
            })
            .onSubmit(() => {
              this.stepSearchHit(1);
            })

          if (this.searchQuery.trim().length > 0) {
            Text(this.searchHits.length > 0 ?
              `${this.activeSearchHitIndex + 1} / ${this.searchHits.length}` : '0 处')
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.searchHits.length > 0 ?
                $r('sys.color.font_secondary') : '#D97706')
              .maxLines(1)
          }

          Button({ type: ButtonType.Circle, stateEffect: false }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(13)
              .fontColor([$r('sys.color.font')])
          }
          .width(28)
          .height(28)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .enabled(this.searchHits.length > 0)
          .opacity(this.searchHits.length > 0 ? 1 : 0.35)
          .accessibilityText('上一处匹配')
          .onClick(() => this.stepSearchHit(-1))

          Button({ type: ButtonType.Circle, stateEffect: false }) {
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(13)
              .fontColor([$r('sys.color.font')])
          }
          .width(28)
          .height(28)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .enabled(this.searchHits.length > 0)
          .opacity(this.searchHits.length > 0 ? 1 : 0.35)
          .accessibilityText('下一处匹配')
          .onClick(() => this.stepSearchHit(1))

          Button({ type: ButtonType.Circle, stateEffect: false }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(12)
              .fontColor([$r('sys.color.icon_secondary')])
          }
          .width(28)
          .height(28)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .accessibilityText('关闭文内查找')
          .onClick(() => this.onSearchBarOpenChange(false))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.hasActiveSearchHit()) {
          Row({ space: 6 }) {
            if (this.activeSearchHitContextLabel().length > 0) {
              Text(this.activeSearchHitContextLabel())
                .fontSize(AppTypography.CAPTION_M)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_emphasize'))
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(badgeInfoBackgroundColor())
                .borderRadius(6)
                .maxLines(1)
            }
            Text(this.activeSearchHitSnippet())
              .fontSize(AppTypography.CAPTION_M)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({ top: 2, bottom: 2 })
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: READING_CONTENT_MAX_WIDTH })
      .padding({ left: 12, right: 10, top: 6, bottom: 6 })
      .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
      .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_THICK : undefined)
      .border({ width: 0.5, color: materialCardBorderColor(this.materialEnabled) })
      .borderRadius(16)
      .shadow({ radius: 12, color: '#1F000000', offsetY: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({
      top: this.topPadding + 6,
      left: this.mainHorizontalMargin(),
      right: this.mainHorizontalMargin()
    })
    .hitTestBehavior(HitTestMode.Transparent)
    .zIndex(2)
    .transition(AppMotion.fadeTransition(AppMotion.MICRO_DURATION))
  }

  build() {
    Row() {
      Stack({ alignContent: Alignment.Top }) {
        List({ scroller: this.scroller }) {
          Repeat<ArticleSectionRow>(this.sectionRows)
            .each((item: RepeatItem<ArticleSectionRow>) => {
              ListItem() {
                this.sectionView(item.item)
              }
              .width('100%')
              .constraintSize({ maxWidth: READING_CONTENT_MAX_WIDTH })
              .padding({
                left: this.mainHorizontalMargin(),
                right: this.mainHorizontalMargin(),
                bottom: item.item.bottomGap
              })
            })
            .key((section: ArticleSectionRow) => section.key)
            .virtualScroll({ reusable: false })
        }
        .width('100%')
        .height('100%')
        .id(this.listNodeId())
        .alignListItem(ListItemAlign.Center)
        .cachedCount(6)
        .contentStartOffset(this.topPadding + (this.searchBarOpen ? 68 : 0))
        .contentEndOffset(48)
        .backgroundColor($r('sys.color.background_secondary'))
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          const height = Number(newArea.height);
          if (Number.isFinite(height) && height > 0) {
            this.viewportHeight = height;
            this.hasLaidOutCurrentDoc = true;
            this.onContentLaidOut();
            this.tryFlushPendingRouteAnchor();
            this.publishReadingProgress();
          }
        })
        .onScrollIndex((start: number, end: number, _center: number) => {
          this.visibleStartIndex = start;
          this.visibleEndIndex = end;
          this.visibleSectionIndex = start;
          this.publishReadingProgress();
        })
        .onDidScroll((_scrollOffset: number, _scrollState: ScrollState) => {
          this.publishReadingProgress();
          this.onScrollDidScroll();
        })
        .onScrollStart(() => {
          this.onScrollStart();
        })
        .onScrollStop(() => {
          this.publishReadingProgress();
          this.onScrollStop();
        })
        .onTouch((event: TouchEvent): void => {
          this.handleListTouch(event);
        })
        .bindSheet(
          this.sheetMode !== ArticleSheetMode.NONE,
          this.activeSheetBuilder(),
          this.activeSheetOptions()
        )

        if (this.searchBarOpen) {
          this.articleSearchBar()
        }
      }
      .layoutWeight(1)
      .height('100%')

      if (this.sidePanelVisible()) {
        this.researchSidePanelBuilder()
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const measured = Number(newArea.width);
      if (Number.isFinite(measured) && measured > 0 && measured !== this.containerWidth) {
        this.containerWidth = measured;
        this.syncSidePanelAvailability();
      }
    })
  }
}
