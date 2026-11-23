import { LengthMetrics } from '@kit.ArkUI';
import {
  AppTypography,
  badgeInfoBackgroundColor,
  ContentUpdateNotice,
  objectClassColor,
  PHONE_PAGE_MARGIN,
  ROW_PRESS_MODIFIER
} from 'anomiconbasic';
import { ArticleRelatedTale } from '../../domain/ArticleContracts';
import {
  ScpArticleDocument,
  ScpBlockType,
  ScpContentBlock,
  ScpFootnote,
  ScpTextSpan,
  ScpTextStyle
} from '../../domain/ScpDocument';
import { ArticleRenderer } from './ArticleRenderer';
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
  FOOTER = 8
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

function measureBlockWeight(block: ScpContentBlock): number {
  if (block.type === ScpBlockType.IMAGE) {
    return 260;
  }
  if (block.type === ScpBlockType.EMBED) {
    return 120;
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

  @Event onRetryPartial: () => void = () => {};
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

  @Local private galleryIndex: number = 0;
  @Local private sectionRows: ArticleSectionRow[] = [];
  @Local private blockRows: ArticleBlockRowState[] = [];
  @Local private imageRows: ArticleBlockRowState[] = [];
  @Local private footnoteRows: ArticleFootnoteRowState[] = [];
  @Local private relatedTaleRows: ArticleRelatedTaleRowState[] = [];
  @Local private highlightedAnchorKey: string = '';
  @Local private highlightOpacity: number = 0;
  private readonly galleryController: SwiperController = new SwiperController();
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
  }

  aboutToDisappear(): void {
    this.clearHighlightTimer();
  }

  @Monitor('document')
  onDocumentChange(): void {
    this.clearHighlightTimer();
    this.highlightedAnchorKey = '';
    this.highlightOpacity = 0;
    this.galleryIndex = 0;
    this.visibleStartIndex = -1;
    this.visibleEndIndex = -1;
    this.lastReportedPercent = -1;
    this.syncDocumentAndSections();
    this.galleryController.changeIndex(0, false);
  }

  @Monitor('relatedTales', 'partialNoticeVisible', 'galleryAfterBody')
  onLayoutInputsChange(): void {
    this.syncDocumentAndSections();
  }

  @Monitor('galleryReturnEpoch')
  onGalleryReturn(): void {
    if (this.document.images.length === 0) {
      return;
    }
    const next = Math.max(0, Math.min(this.galleryReturnIndex, this.document.images.length - 1));
    this.galleryIndex = next;
    this.galleryController.changeIndex(next, false);
  }

  private syncDocumentAndSections(): void {
    const nextBlocks = syncArticleBlockRows(this.blockRows, this.document.blocks);
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
    if (!this.galleryAfterBody && this.document.images.length > 0) {
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

    if (this.galleryAfterBody && this.document.images.length > 0) {
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
    return ArticleRenderer.isExpanded(this.expandedKeys, block.key);
  }

  private footnoteRefIds(block: ScpContentBlock): string[] {
    return ArticleRenderer.footnoteReferenceIds(block);
  }

  private textOf(block: ScpContentBlock): string {
    return ArticleRenderer.textOf(block);
  }

  @Builder
  private spanText(row: ArticleBlockRowState) {
    Text() {
      ForEach(row.spans, (spanRow: ArticleSpanRowState) => {
        if (spanRow.span.style === ScpTextStyle.FOOTNOTE_REFERENCE) {
          Span(`[${spanRow.span.text}]`)
            .fontSize(this.fontSize * 0.75)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_emphasize'))
            .onClick(() => this.jumpTo(`fn:${spanRow.span.referenceId}`))
        } else {
          Span(spanRow.span.text)
            .fontWeight(spanRow.span.style === ScpTextStyle.STRONG ? FontWeight.Bold : FontWeight.Regular)
            .fontStyle(spanRow.span.style === ScpTextStyle.EMPHASIS ? FontStyle.Italic : FontStyle.Normal)
            .decoration({
              type: spanRow.span.style === ScpTextStyle.DELETED ?
                TextDecorationType.LineThrough :
                (spanRow.span.style === ScpTextStyle.LINK ?
                  TextDecorationType.Underline : TextDecorationType.None),
              color: $r('sys.color.font_secondary')
            })
            .fontColor(spanRow.span.style === ScpTextStyle.CODE || spanRow.span.style === ScpTextStyle.LINK ?
              $r('sys.color.font_emphasize') : $r('sys.color.font'))
            .onClick(spanRow.span.style === ScpTextStyle.LINK ?
              () => this.onOpenArticleLink(spanRow.span.target, spanRow.span.text) : () => {
              })
        }
      }, (spanRow: ArticleSpanRowState) => spanRow.key)
    }
    .fontSize(this.fontSize)
    .lineHeightMultiple(this.lineHeightMultiple)
    .fontColor($r('sys.color.font'))
    .textAlign(TextAlign.JUSTIFY)
    .wordBreak(WordBreak.BREAK_WORD)
    .enableAutoSpacing(true)
    .background(this.anchorHighlightBackdrop(this.isParagraphHighlighted(row.block)))
    .width('100%')
  }

  @Builder
  private headingBlock(row: ArticleBlockRowState) {
    Text(this.textOf(row.block))
      .fontSize(this.fontSize *
        (row.block.level <= 1 ? 1.35 : (row.block.level === 2 ? 1.2 : 1.1)))
      .fontWeight(FontWeight.Bold)
      .fontColor($r('sys.color.font'))
      .width('100%')
      .margin({ top: 8 })
  }

  @Builder
  private quoteBlock(row: ArticleBlockRowState) {
    Column({ space: 8 }) {
      ForEach(row.children, (child: ArticleBlockRowState) => {
        this.blockView(child)
      }, (child: ArticleBlockRowState) => child.key)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .border({ width: { left: 3 }, color: $r('sys.color.comp_divider') })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(8)
  }

  @Builder
  private collapsibleBlock(row: ArticleBlockRowState) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.icon_secondary')])
          .rotate({ angle: this.isExpanded(row.block) ? 90 : 0 })
          .animation({ duration: 220, curve: Curve.FastOutSlowIn })
        Text(row.block.caption.length > 0 ? row.block.caption : '展开内容')
          .fontSize(this.fontSize)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
          .layoutWeight(1)
      }
      .attributeModifier(ROW_PRESS_MODIFIER)
      .animation({ duration: 120, curve: Curve.FastOutSlowIn })
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor($r('sys.color.comp_background_tertiary'))
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
            this.blockView(child)
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
  private tableBlock(blockRow: ArticleBlockRowState) {
    Column() {
      ForEach(blockRow.children, (row: ArticleBlockRowState) => {
        Row() {
          ForEach(row.children, (cell: ArticleBlockRowState) => {
            Text(this.textOf(cell.block))
              .fontSize(this.fontSize)
              .fontColor($r('sys.color.font'))
              .layoutWeight(1)
              .padding(6)
              .textAlign(TextAlign.Start)
          }, (cell: ArticleBlockRowState) => cell.key)
        }
        .width('100%')
      }, (row: ArticleBlockRowState) => row.key)
    }
    .width('100%')
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .borderRadius(8)
    .clip(true)
  }

  @Builder
  private embedBlock(row: ArticleBlockRowState) {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.rectangle_on_rectangle'))
        .fontSize(20)
        .fontColor([$r('sys.color.icon_secondary')])
      Text('嵌入网页组件')
        .fontSize(this.fontSize)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font'))
        .layoutWeight(1)
      Button('在浏览器中打开', { stateEffect: false })
        .fontSize(AppTypography.CAPTION_L)
        .height(32)
        .onClick(() => this.onOpenUrl(row.block.source))
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(10)
  }

  @Builder
  private standaloneImageBlock(row: ArticleBlockRowState) {
    Column({ space: 6 }) {
      ScpArticleImage({
        url: row.block.source,
        onOpen: () => this.onOpenUrl(row.block.source),
        onOpenInBrowser: (url: string) => this.onOpenUrl(url)
      })
      if (row.block.caption.length > 0) {
        Text(row.block.caption)
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private unsupportedBlock(row: ArticleBlockRowState) {
    if (row.spans.length > 0) {
      this.spanText(row)
    } else if (row.children.length > 0) {
      Column({ space: 12 }) {
        ForEach(row.children, (child: ArticleBlockRowState) => {
          this.blockView(child)
        }, (child: ArticleBlockRowState) => child.key)
      }
      .width('100%')
    } else {
      Text('该部分含特殊排版或交互，建议在浏览器中查看')
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_tertiary'))
        .padding(10)
        .width('100%')
    }
  }

  @Builder
  private blockView(row: ArticleBlockRowState) {
    if (row.block.type === ScpBlockType.PARAGRAPH) {
      this.spanText(row)
    } else if (row.block.type === ScpBlockType.HEADING) {
      this.headingBlock(row)
    } else if (row.block.type === ScpBlockType.QUOTE) {
      this.quoteBlock(row)
    } else if (row.block.type === ScpBlockType.COLLAPSIBLE) {
      this.collapsibleBlock(row)
    } else if (row.block.type === ScpBlockType.TABLE) {
      this.tableBlock(row)
    } else if (row.block.type === ScpBlockType.EMBED) {
      this.embedBlock(row)
    } else if (row.block.type === ScpBlockType.IMAGE) {
      this.standaloneImageBlock(row)
    } else if (row.block.type === ScpBlockType.UNSUPPORTED) {
      this.unsupportedBlock(row)
    } else if (row.block.type === ScpBlockType.DIVIDER) {
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
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
    .padding({ left: 4, right: 4, top: 4, bottom: 4 })
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

  build() {
    List({ scroller: this.scroller }) {
      Repeat<ArticleSectionRow>(this.sectionRows)
        .each((item: RepeatItem<ArticleSectionRow>) => {
          ListItem() {
            this.sectionView(item.item)
          }
          .width('100%')
          .constraintSize({ maxWidth: 680 })
          .padding({
            left: PHONE_PAGE_MARGIN,
            right: PHONE_PAGE_MARGIN,
            bottom: item.item.bottomGap
          })
        })
        .key((section: ArticleSectionRow) => section.key)
        .virtualScroll({ reusable: false })
    }
    .width('100%')
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
  }
}
