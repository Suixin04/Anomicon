import { LengthMetrics } from '@kit.ArkUI';
import { AppTypography, objectClassColor } from 'anomiconbasic';
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

/**
 * Device-independent native article body.
 *
 * The product route owns navigation, compatibility extraction, system effects
 * and the surrounding Scroll. This component owns only native body rendering
 * and ephemeral renderer state (gallery position and footnote anchors).
 */
@ComponentV2
export struct ArticleNativeRenderer {
  @Require @Param document: ScpArticleDocument;
  @Require @Param expandedKeys: string[];
  @Require @Param relatedTales: ArticleRelatedTale[];
  @Require @Param fontSize: number;
  @Require @Param lineHeightMultiple: number;
  /** Index selected when the product-owned full-screen preview closes. */
  @Param galleryReturnIndex: number = 0;
  /** Monotonic token that makes repeated returns to the same index observable. */
  @Param galleryReturnEpoch: number = 0;

  @Event onOpenUrl: (url: string) => void;
  @Event onOpenImage: (index: number) => void;
  @Event onToggleExpanded: (block: ScpContentBlock) => void;
  @Event onOpenRelatedTale: (tale: ArticleRelatedTale) => void;
  @Event onRequestScrollTo: (offset: number) => void;
  @Event onContentLaidOut: () => void;

  @Local private galleryIndex: number = 0;
  @Local private blockRows: ArticleBlockRowState[] = [];
  @Local private imageRows: ArticleBlockRowState[] = [];
  @Local private footnoteRows: ArticleFootnoteRowState[] = [];
  @Local private relatedTaleRows: ArticleRelatedTaleRowState[] = [];
  private readonly galleryController: SwiperController = new SwiperController();
  private contentTop: number = 0;
  private offsets: Map<string, number> = new Map();

  aboutToAppear(): void {
    this.syncDocumentRows();
    this.syncRelatedTaleRows();
  }

  @Monitor('document')
  onDocumentChange(): void {
    this.syncDocumentRows();
    this.galleryIndex = 0;
    this.contentTop = 0;
    this.offsets.clear();
    this.galleryController.changeIndex(0, false);
  }

  @Monitor('relatedTales')
  onRelatedTalesChange(): void {
    this.syncRelatedTaleRows();
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

  private syncDocumentRows(): void {
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
  }

  private syncRelatedTaleRows(): void {
    const next = syncArticleRelatedTaleRows(this.relatedTaleRows, this.relatedTales);
    if (!sameArticleRelatedTaleRows(this.relatedTaleRows, next)) {
      this.relatedTaleRows = next;
    }
  }

  private recordOffset(key: string, area: Area): void {
    const globalPosition = area.globalPosition;
    if (globalPosition === undefined || globalPosition.y === undefined) {
      return;
    }
    const offset = Number(globalPosition.y) - this.contentTop;
    if (offset >= 0) {
      this.offsets.set(key, offset);
    }
  }

  private jumpTo(key: string): void {
    const target = this.offsets.get(key);
    if (target !== undefined) {
      this.onRequestScrollTo(Math.max(0, target - 12));
    }
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
                TextDecorationType.LineThrough : TextDecorationType.None,
              color: $r('sys.color.font_secondary')
            })
            .fontColor(spanRow.span.style === ScpTextStyle.CODE ?
              $r('sys.color.font_emphasize') : $r('sys.color.font'))
            .onClick(spanRow.span.style === ScpTextStyle.LINK ?
              () => this.onOpenUrl(spanRow.span.target) : () => {
              })
        }
      }, (spanRow: ArticleSpanRowState) => spanRow.key)
    }
    .fontSize(this.fontSize)
    .lineHeightMultiple(this.lineHeightMultiple)
    .fontColor($r('sys.color.font'))
    .textAlign(TextAlign.JUSTIFY)
    .wordBreak(WordBreak.BREAK_ALL)
    .width('100%')
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.recordOffset(row.key, newArea);
      const refIds = this.footnoteRefIds(row.block);
      for (let index: number = 0; index < refIds.length; index++) {
        this.offsets.set(`ref:${refIds[index]}`, this.offsets.get(row.key) ?? 0);
      }
    })
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
        SymbolGlyph(this.isExpanded(row.block) ?
          $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.icon_secondary')])
        Text(row.block.caption.length > 0 ? row.block.caption : '展开内容')
          .fontSize(this.fontSize)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(10)
      .onClick(() => this.onToggleExpanded(row.block))

      if (this.isExpanded(row.block)) {
        Column({ space: 12 }) {
          ForEach(row.children, (child: ArticleBlockRowState) => {
            this.blockView(child)
          }, (child: ArticleBlockRowState) => child.key)
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
      }
    }
    .width('100%')
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
      Text('嵌入 HTML 内容')
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
      Text('此内容块暂无法在原生阅读器中展示')
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
  private footnotesSection() {
    if (this.document.footnotes.length > 0) {
      Column({ space: 12 }) {
        Divider()
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'))
        Text('脚注')
          .fontSize(AppTypography.SUBTITLE_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .width('100%')
        ForEach(this.footnoteRows, (row: ArticleFootnoteRowState) => {
          Row() {
            Text(`${row.footnote.index}.`)
              .fontSize(this.fontSize)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_emphasize'))
            Column({ space: 6 }) {
              ForEach(row.blocks, (block: ArticleBlockRowState) => {
                this.blockView(block)
              }, (block: ArticleBlockRowState) => block.key)
              Row() {
                SymbolGlyph($r('sys.symbol.arrow_up'))
                  .fontSize(13)
                  .fontColor([$r('sys.color.font_emphasize')])
                Text('返回正文')
                  .fontSize(AppTypography.CAPTION_L)
                  .fontColor($r('sys.color.font_emphasize'))
              }
              .onClick(() => this.jumpTo(`ref:${row.footnote.id}`))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            this.recordOffset(`fn:${row.footnote.id}`, newArea);
          })
        }, (row: ArticleFootnoteRowState) => row.key)
      }
      .width('100%')
    }
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

  build() {
    Column({ space: 16 }) {
      this.headerCard()
      this.imageGallery()
      ForEach(this.blockRows, (block: ArticleBlockRowState) => {
        this.blockView(block)
      }, (block: ArticleBlockRowState) => block.key)
      this.footnotesSection()
      this.relatedTalesSection()
      this.licenseFooter()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const globalPosition = newArea.globalPosition;
      if (globalPosition !== undefined && globalPosition.y !== undefined) {
        this.contentTop = Number(globalPosition.y);
      }
      if (newArea.height > 0) {
        this.onContentLaidOut();
      }
    })
  }
}
