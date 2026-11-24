import { LengthMetrics, uiMaterial } from '@kit.ArkUI';
import {
  accentPillBackgroundColor,
  accentPillForegroundColor,
  adaptivePageMarginForWidth,
  AppTypography,
  autoOpenArticleSidePanel,
  badgeInfoBackgroundColor,
  CARD_PRESS_MODIFIER,
  ContentUpdateNotice,
  isDarkModeActive,
  materialCardBorderColor,
  materialCardSurfaceColor,
  objectClassColor,
  PHONE_PAGE_MARGIN,
  READING_CONTENT_MAX_WIDTH,
  resolveArticleSidebarWidth,
  ROW_PRESS_MODIFIER,
  shouldUseCenterSheet,
  supportsArticleSidePanel,
  uiImmersiveMaterialSupported,
  windowWidthVp
} from 'anomiconbasic';
import { ArticleRelatedTale } from '../../domain/ArticleContracts';
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
import { ArticleRenderer, FootnoteSheetHeader } from './ArticleRenderer';
import { ScpArticleImage } from './ScpArticleImage';

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
  WEB_RECOMMEND_BANNER = 9
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

  constructor(
    key: string,
    kind: ArticleSectionKind,
    weight: number,
    blockRow: ArticleBlockRowState | undefined = undefined,
    footnoteRow: ArticleFootnoteRowState | undefined = undefined,
    quoteFirst: boolean = false,
    quoteLast: boolean = false,
    bottomGap: number = 16
  ) {
    this.key = key;
    this.kind = kind;
    this.weight = weight;
    this.blockRow = blockRow;
    this.footnoteRow = footnoteRow;
    this.quoteFirst = quoteFirst;
    this.quoteLast = quoteLast;
    this.bottomGap = bottomGap;
  }

  sync(
    blockRow: ArticleBlockRowState | undefined,
    footnoteRow: ArticleFootnoteRowState | undefined,
    quoteFirst: boolean,
    quoteLast: boolean,
    bottomGap: number
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

function collectFootnoteRefIdsRecursive(block: ScpContentBlock, output: string[]): void {
  for (let index: number = 0; index < block.spans.length; index++) {
    const span = block.spans[index];
    if (span.style === ScpTextStyle.FOOTNOTE_REFERENCE &&
      span.referenceId.length > 0 &&
      output.indexOf(span.referenceId) < 0) {
      output.push(span.referenceId);
    }
  }
  for (let index: number = 0; index < block.children.length; index++) {
    collectFootnoteRefIdsRecursive(block.children[index], output);
  }
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

  @Event onRetryPartial: () => void = () => {};
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
  @Event onOpenRelatedTale: (tale: ArticleRelatedTale) => void;
  @Event onContentLaidOut: () => void;
  @Event onSidePanelAvailabilityChange: (available: boolean, label: string) => void =
    (_available: boolean, _label: string): void => {};
  @Event onSidePanelOpenChange: (open: boolean) => void = (_open: boolean): void => {};

  @Local private galleryIndex: number = 0;
  @Local private sectionRows: ArticleSectionRow[] = [];
  @Local private blockRows: ArticleBlockRowState[] = [];
  @Local private imageRows: ArticleBlockRowState[] = [];
  @Local private footnoteRows: ArticleFootnoteRowState[] = [];
  @Local private relatedTaleRows: ArticleRelatedTaleRowState[] = [];
  @Local private highlightedAnchorKey: string = '';
  @Local private highlightOpacity: number = 0;
  @Local private footnoteSheetVisible: boolean = false;
  @Local private activeFootnoteIndex: number = -1;
  @Local private containerWidth: number = 0;
  @Local private activeWorkbenchTab: number = 0;
  @Local private userClosedSidePanel: boolean = false;
  @Local private revealedHiddenKeys: string[] = [];
  private readonly galleryController: SwiperController = new SwiperController();
  private readonly footnoteSheetScroller: Scroller = new Scroller();
  private readonly sidePanelScroller: Scroller = new Scroller();
  private readonly footnoteSheetDetents: [SheetSize, SheetSize, SheetSize] =
    [SheetSize.FIT_CONTENT, SheetSize.MEDIUM, SheetSize.LARGE];
  private readonly footnoteSheetMaterial: uiMaterial.ImmersiveMaterial =
    new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THICK,
      applyShadow: true
    });
  private lastDocumentItemId: string = '';
  private lastNotifiedAvailabilityKey: string = '';
  private viewportHeight: number = 0;
  private visibleStartIndex: number = -1;
  private visibleEndIndex: number = -1;
  private lastReportedPercent: number = -1;
  private cumulativeWeights: number[] = [0];
  private totalWeight: number = 0;
  private readonly anchorIndexByKey: Map<string, number> = new Map();
  private highlightTimer: number = -1;

  aboutToAppear(): void {
    this.syncDocumentAndSections();
    this.lastDocumentItemId = this.document.itemId;
    this.syncWorkbenchTabDefault();
    this.syncSidePanelAvailability();
  }

  aboutToDisappear(): void {
    this.clearHighlightTimer();
    this.closeFootnoteSheet();
  }

  @Monitor('document')
  onDocumentChange(): void {
    const sameItem = this.lastDocumentItemId.length > 0 &&
      this.lastDocumentItemId === this.document.itemId;
    const activeId = (sameItem && (this.footnoteSheetVisible || this.sidePanelOpen)) ?
      (this.currentFootnoteRow()?.footnote.id ?? '') : '';
    const previousIndex = this.activeFootnoteIndex;

    if (!sameItem) {
      this.userClosedSidePanel = false;
      this.revealedHiddenKeys = [];
    }
    this.clearHighlightTimer();
    this.highlightedAnchorKey = '';
    this.highlightOpacity = 0;
    this.galleryIndex = 0;
    this.visibleStartIndex = -1;
    this.visibleEndIndex = -1;
    this.lastReportedPercent = -1;
    this.syncDocumentAndSections();
    this.lastDocumentItemId = this.document.itemId;
    if (this.shouldRenderGallerySection()) {
      try {
        this.galleryController.changeIndex(0, false);
      } catch (_error) {
      }
    }
    this.syncWorkbenchTabDefault();

    if (sameItem && (this.footnoteSheetVisible || this.sidePanelOpen) && this.footnoteRows.length > 0) {
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
    } else if (!sameItem || !this.footnoteSheetVisible || this.footnoteRows.length === 0) {
      this.closeFootnoteSheet();
    }
    this.syncSidePanelAvailability();
  }

  @Monitor('relatedTales', 'partialNoticeVisible', 'galleryAfterBody', 'webModeHint')
  onLayoutInputsChange(): void {
    this.syncDocumentAndSections();
    this.syncWorkbenchTabDefault();
    this.syncSidePanelAvailability();
  }

  @Monitor('sidePanelOpen')
  onExternalSidePanelOpenChange(): void {
    if (this.sidePanelOpen) {
      this.userClosedSidePanel = false;
      this.footnoteSheetVisible = false;
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
    const nextImages = syncArticleBlockRows(this.imageRows, this.document.images);
    if (!sameArticleBlockRows(this.imageRows, nextImages)) {
      this.imageRows = nextImages;
    }
    const nextFootnotes = syncArticleFootnoteRows(this.footnoteRows, this.document.footnotes);
    if (!sameArticleFootnoteRows(this.footnoteRows, nextFootnotes)) {
      this.footnoteRows = nextFootnotes;
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
    this.anchorIndexByKey.clear();
    const pushSection = (
      key: string,
      kind: ArticleSectionKind,
      weight: number,
      blockRow: ArticleBlockRowState | undefined,
      footnoteRow: ArticleFootnoteRowState | undefined,
      quoteFirst: boolean,
      quoteLast: boolean,
      bottomGap: number
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
          bottomGap
        );
      } else {
        existing.sync(blockRow, footnoteRow, quoteFirst, quoteLast, bottomGap);
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
          const refIds: string[] = [];
          collectFootnoteRefIdsRecursive(child.block, refIds);
          for (let r: number = 0; r < refIds.length; r++) {
            const refKey = `ref:${refIds[r]}`;
            if (!this.anchorIndexByKey.has(refKey)) {
              this.anchorIndexByKey.set(refKey, sectionIndex);
            }
          }
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
        const refIds: string[] = [];
        collectFootnoteRefIdsRecursive(blockRow.block, refIds);
        for (let r: number = 0; r < refIds.length; r++) {
          const refKey = `ref:${refIds[r]}`;
          if (!this.anchorIndexByKey.has(refKey)) {
            this.anchorIndexByKey.set(refKey, sectionIndex);
          }
        }
      }
    }

    if (this.footnoteRows.length > 0) {
      pushSection(
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
        this.anchorIndexByKey.set(`fn:${fnRow.footnote.id}`, sectionIndex);
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

    if (this.document.pageVersion.length > 0) {
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
    }

    const prefixSums: number[] = [0];
    let running: number = 0;
    for (let index: number = 0; index < nextSections.length; index++) {
      running += nextSections[index].weight;
      prefixSums.push(running);
    }
    this.cumulativeWeights = prefixSums;
    this.totalWeight = running;

    if (!sameArticleSectionRows(this.sectionRows, nextSections)) {
      this.sectionRows = nextSections;
    }
  }

  private clampValue(value: number, min: number, max: number): number {
    return value < min ? min : (value > max ? max : value);
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

  private jumpTo(key: string): void {
    const targetIndex = this.anchorIndexByKey.get(key);
    if (targetIndex === undefined) {
      return;
    }
    this.onAnchorJump();
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
    this.triggerAnchorHighlight(key);
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
    return this.footnoteRows.length > 0 || this.relatedTaleRows.length > 0;
  }

  private canUseSidePanel(): boolean {
    return supportsArticleSidePanel(this.containerWidth) && this.hasWorkbenchContent();
  }

  private sidePanelVisible(): boolean {
    return this.canUseSidePanel() && this.sidePanelOpen;
  }

  private syncWorkbenchTabDefault(): void {
    if (this.footnoteRows.length === 0 && this.relatedTaleRows.length > 0) {
      this.activeWorkbenchTab = 1;
    } else if (this.relatedTaleRows.length === 0) {
      this.activeWorkbenchTab = 0;
    }
  }

  private sidePanelBadgeLabel(): string {
    const fnCount = this.footnoteRows.length;
    const taleCount = this.relatedTaleRows.length;
    if (fnCount > 0 && taleCount > 0) {
      return `研读 ${fnCount + taleCount}`;
    }
    if (fnCount > 0) {
      return `脚注 ${fnCount}`;
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
      this.jumpTo(`fn:${referenceId}`);
      return;
    }
    this.activeFootnoteIndex = targetIndex;
    if (this.canUseSidePanel()) {
      this.footnoteSheetVisible = false;
      this.userClosedSidePanel = false;
      this.activeWorkbenchTab = 0;
      if (!this.sidePanelOpen) {
        this.onSidePanelOpenChange(true);
      }
      this.onAnchorJump();
      this.triggerAnchorHighlight(`ref:${this.footnoteRows[targetIndex].footnote.id}`);
      this.scrollSidePanelToFootnote(targetIndex);
      return;
    }
    this.footnoteSheetVisible = true;
    this.onAnchorJump();
    this.scrollFootnoteSheetToTop();
  }

  private closeFootnoteSheet(): void {
    this.footnoteSheetVisible = false;
    if (!this.sidePanelVisible()) {
      this.activeFootnoteIndex = -1;
    }
  }

  private closeSidePanel(): void {
    this.userClosedSidePanel = true;
    if (this.sidePanelOpen) {
      this.onSidePanelOpenChange(false);
    }
  }

  private selectSidePanelFootnote(row: ArticleFootnoteRowState): void {
    this.activeFootnoteIndex = row.index;
    const refKey = `ref:${row.footnote.id}`;
    if (this.anchorIndexByKey.has(refKey)) {
      this.jumpTo(refKey);
      return;
    }
    this.onAnchorJump();
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
    if (this.footnoteSheetVisible) {
      this.scrollFootnoteSheetToTop();
    }
    if (this.sidePanelVisible()) {
      this.scrollSidePanelToFootnote(next);
    }
    const row = this.currentFootnoteRow();
    if (row !== undefined) {
      const refKey = `ref:${row.footnote.id}`;
      if (this.anchorIndexByKey.has(refKey)) {
        this.jumpTo(refKey);
        return;
      }
    }
    this.onAnchorJump();
  }

  private handleOpenArticleLink(url: string, title: string): void {
    if (this.footnoteSheetVisible && !url.trim().startsWith('#')) {
      this.closeFootnoteSheet();
    }
    this.onOpenArticleLink(url, title);
  }

  private handleOpenUrl(url: string): void {
    if (this.footnoteSheetVisible) {
      this.closeFootnoteSheet();
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

  private footnoteSheetOptions(): SheetOptions {
    const row = this.currentFootnoteRow();
    const header: FootnoteSheetHeader = row !== undefined ?
      ArticleRenderer.footnoteSheetHeader(
        row.footnote,
        this.activeFootnoteIndex,
        this.footnoteRows.length
      ) :
      { title: '脚注', subtitle: '' };
    const useCenter = shouldUseCenterSheet(windowWidthVp());
    const options: SheetOptions = {
      preferType: useCenter ? SheetType.CENTER : SheetType.BOTTOM,
      dragBar: true,
      showClose: true,
      title: header.subtitle.length > 0 ?
        { title: header.title, subtitle: header.subtitle } :
        { title: header.title },
      onWillDismiss: (action: DismissSheetAction): void => {
        this.closeFootnoteSheet();
        action.dismiss();
      },
      onDisappear: (): void => {
        this.closeFootnoteSheet();
      }
    };
    if (useCenter) {
      options.height = SheetSize.FIT_CONTENT;
    } else {
      options.detents = this.footnoteSheetDetents;
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

  private isParagraphHighlighted(block: ScpContentBlock): boolean {
    if (this.highlightedAnchorKey.length === 0) {
      return false;
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
    this.revealedHiddenKeys = next;
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
      ForEach(row.spans, (spanRow: ArticleSpanRowState) => {
        if (spanRow.span.style === ScpTextStyle.FOOTNOTE_REFERENCE) {
          Span(`[${spanRow.span.text}]`)
            .fontSize((baseSizeOverride > 0 ? baseSizeOverride : this.fontSize) * 0.75)
            .fontWeight(FontWeight.Medium)
            .fontColor(inTerminal ? '#67E8F9' : $r('sys.color.font_emphasize'))
            .baselineOffset(LengthMetrics.fp((baseSizeOverride > 0 ? baseSizeOverride : this.fontSize) * 0.24))
            .onClick(() => this.openFootnoteSheet(spanRow.span.referenceId, spanRow.span.text))
        } else if (spanRow.span.hiddenKind === ScpHiddenTextKind.NONE) {
          Span(spanRow.span.text)
            .fontSize(this.resolvedSpanFontSize(
              spanRow.span,
              baseSizeOverride > 0 ? baseSizeOverride : this.fontSize
            ))
            .fontWeight(boldAll || spanRow.span.bold ? FontWeight.Bold : FontWeight.Regular)
            .fontStyle(spanRow.span.italic ? FontStyle.Italic : FontStyle.Normal)
            .fontFamily(spanRow.span.monospace ? 'monospace' : 'HarmonyOS Sans')
            .baselineOffset(this.resolvedSpanBaseline(
              spanRow.span,
              baseSizeOverride > 0 ? baseSizeOverride : this.fontSize
            ))
            .decoration(this.resolvedSpanDecoration(spanRow.span, inTerminal))
            .fontColor(this.resolvedVisibleSpanColor(spanRow.span, inTerminal))
            .textBackgroundStyle(this.resolvedSpanBackground(spanRow.span, inTerminal))
            .onClick(spanRow.span.style === ScpTextStyle.LINK ?
              () => this.handleOpenArticleLink(spanRow.span.target, spanRow.span.text) : () => {
              })
        } else {
          Span((spanRow.span.hiddenKind !== ScpHiddenTextKind.ZERO_SIZE_WHISPER ||
            forceReveal || this.isHiddenKeyRevealed(spanRow.key)) ? spanRow.span.text : ' [···] ')
            .fontSize((spanRow.span.hiddenKind === ScpHiddenTextKind.ZERO_SIZE_WHISPER &&
              !forceReveal && !this.isHiddenKeyRevealed(spanRow.key)) ?
              Math.max(11, (baseSizeOverride > 0 ? baseSizeOverride : this.fontSize) * 0.78) :
              this.resolvedSpanFontSize(
                spanRow.span,
                baseSizeOverride > 0 ? baseSizeOverride : this.fontSize
              ))
            .fontWeight(boldAll || spanRow.span.bold ? FontWeight.Bold : FontWeight.Regular)
            .fontStyle(spanRow.span.italic ? FontStyle.Italic : FontStyle.Normal)
            .fontFamily(spanRow.span.monospace ? 'monospace' : 'HarmonyOS Sans')
            .baselineOffset(this.resolvedSpanBaseline(
              spanRow.span,
              baseSizeOverride > 0 ? baseSizeOverride : this.fontSize
            ))
            .decoration(this.resolvedHiddenDecoration(spanRow.span, spanRow.key, inTerminal, forceReveal))
            .fontColor(this.resolvedHiddenForeground(spanRow.span, spanRow.key, inTerminal, forceReveal))
            .textBackgroundStyle(this.resolvedHiddenBackground(spanRow.span, spanRow.key, inTerminal, forceReveal))
            .onClick(() => this.handleHiddenSpanClick(spanRow.span, spanRow.key, forceReveal))
        }
      }, (spanRow: ArticleSpanRowState) => spanRow.key)
    }
    .fontSize(baseSizeOverride > 0 ? baseSizeOverride : this.fontSize)
    .lineHeightMultiple(this.lineHeightMultiple)
    .fontColor(inTerminal ? '#E2E8F0' : $r('sys.color.font'))
    .textAlign(this.resolveBlockTextAlign(row.block.textAlign, startAlign))
    .wordBreak(WordBreak.BREAK_WORD)
    .enableAutoSpacing(true)
    .background(this.anchorHighlightBackdrop(this.isParagraphHighlighted(row.block)))
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
          .animation({ duration: 220, curve: Curve.FastOutSlowIn })
        Text((this.isExpanded(row.block) && row.block.closeCaption.length > 0) ?
          row.block.closeCaption :
          (row.block.caption.length > 0 ? row.block.caption : '展开内容'))
          .fontSize(this.fontSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(inTerminal ? '#F1F5F9' : $r('sys.color.font'))
          .layoutWeight(1)
      }
      .attributeModifier(ROW_PRESS_MODIFIER)
      .animation({ duration: 120, curve: Curve.FastOutSlowIn })
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(inTerminal ? '#232A34' : $r('sys.color.comp_background_tertiary'))
      .borderRadius(10)
      .onClick(() => {
        this.getUIContext().animateTo({
          duration: 240,
          curve: Curve.FastOutSlowIn
        }, (): void => {
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
          TransitionEffect.OPACITY.combine(TransitionEffect.move(TransitionEdge.TOP))
            .animation({ duration: 220, curve: Curve.FastOutSlowIn })
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
              .onClick(() => {
                row.activeTabIndex = index;
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
      }
    }
    .width('100%')
  }

  @Builder
  private calloutBlock(row: ArticleBlockRowState, parentInTerminal: boolean = false) {
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
  private standaloneImageBlock(row: ArticleBlockRowState, inTerminal: boolean = false) {
    Column({ space: 6 }) {
      ScpArticleImage({
        url: row.block.source,
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
  }

  @Builder
  private unsupportedBlock(row: ArticleBlockRowState, inTerminal: boolean = false) {
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

  @Builder
  private headerCard() {
    if (this.document.objectClass.length > 0 || this.document.rating.length > 0 ||
      this.document.tags.length > 0) {
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
          this.blockView(block)
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
        .animation({ duration: 120, curve: Curve.FastOutSlowIn })
        .constraintSize({ minHeight: 34 })
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(17)
        .onClick(() => this.jumpTo(`ref:${row.footnote.id}`))
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
        Text('关联故事')
          .fontSize(AppTypography.SUBTITLE_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .width('100%')
        ForEach(this.relatedTaleRows, (row: ArticleRelatedTaleRowState) => {
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
          .animation({ duration: 120, curve: Curve.FastOutSlowIn })
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(12)
          .onClick(() => this.onOpenRelatedTale(row.tale))
        }, (row: ArticleRelatedTaleRowState) => row.key)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private licenseFooter() {
    Column({ space: 6 }) {
      if (this.document.pageVersion.length > 0) {
        Text(this.document.pageVersion)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 16, bottom: 12 })
  }

  private hasHeaderCardContent(): boolean {
    return this.document.objectClass.length > 0 ||
      this.document.rating.length > 0 ||
      this.document.tags.length > 0;
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

  @Builder
  private sectionView(section: ArticleSectionRow) {
    if (section.kind === ArticleSectionKind.PARTIAL_NOTICE) {
      this.partialNoticeView()
    } else if (section.kind === ArticleSectionKind.WEB_RECOMMEND_BANNER) {
      this.webRecommendBannerView()
    } else if (section.kind === ArticleSectionKind.HEADER_CARD) {
      this.headerCard()
    } else if (section.kind === ArticleSectionKind.GALLERY) {
      this.imageGallery()
    } else if (section.kind === ArticleSectionKind.BLOCK && section.blockRow !== undefined) {
      this.blockView(section.blockRow)
    } else if (section.kind === ArticleSectionKind.QUOTE_CHILD) {
      this.quoteChildBlock(section)
    } else if (section.kind === ArticleSectionKind.FOOTNOTES_HEADER) {
      this.footnotesHeaderView()
    } else if (section.kind === ArticleSectionKind.FOOTNOTE && section.footnoteRow !== undefined) {
      this.footnoteItemView(section.footnoteRow)
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
      .animation({ duration: 120, curve: Curve.FastOutSlowIn })
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
  private footnoteSheetBuilder() {
    Column() {
      if (this.currentFootnoteRow() !== undefined) {
        Scroll(this.footnoteSheetScroller) {
          Column({ space: 10 }) {
            ForEach(this.currentFootnoteBlocks(), (block: ArticleBlockRowState) => {
              this.blockView(block)
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

  private showingFootnotesTab(): boolean {
    if (this.footnoteRows.length === 0) {
      return false;
    }
    if (this.relatedTaleRows.length === 0) {
      return true;
    }
    return this.activeWorkbenchTab === 0;
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
          this.blockView(block)
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
    .animation({ duration: 120, curve: Curve.FastOutSlowIn })
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
        if (this.footnoteRows.length > 0 && this.relatedTaleRows.length > 0) {
          Row({ space: 6 }) {
            this.workbenchTabPill(`脚注 ${this.footnoteRows.length}`, 0)
            this.workbenchTabPill(`故事 ${this.relatedTaleRows.length}`, 1)
          }
          .layoutWeight(1)
        } else {
          Text(this.footnoteRows.length > 0 ?
            `脚注 (${this.footnoteRows.length})` :
            `关联故事 (${this.relatedTaleRows.length})`)
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

      if (this.showingFootnotesTab()) {
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
      } else {
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
    .transition(
      TransitionEffect.OPACITY.combine(TransitionEffect.move(TransitionEdge.END))
        .animation({ duration: 220, curve: Curve.FastOutSlowIn })
    )
  }

  build() {
    Row() {
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
      .layoutWeight(1)
      .height('100%')
      .alignListItem(ListItemAlign.Center)
      .cachedCount(6)
      .contentStartOffset(this.topPadding)
      .contentEndOffset(48)
      .backgroundColor($r('sys.color.background_secondary'))
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const height = Number(newArea.height);
        if (Number.isFinite(height) && height > 0) {
          this.viewportHeight = height;
          this.onContentLaidOut();
          this.publishReadingProgress();
        }
      })
      .onScrollIndex((start: number, end: number, _center: number) => {
        this.visibleStartIndex = start;
        this.visibleEndIndex = end;
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
      .bindSheet(this.footnoteSheetVisible, this.footnoteSheetBuilder(), this.footnoteSheetOptions())

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
