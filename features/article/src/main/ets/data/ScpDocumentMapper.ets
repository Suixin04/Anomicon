import {
  ScpArticleDocument,
  ScpBlockType,
  ScpContentBlock,
  ScpFootnote,
  ScpTextSpan,
  ScpTextStyle
} from '../domain/ScpDocument';
const TRADITIONAL_TO_SIMPLIFIED: Map<string, string> = new Map<string, string>([
  ['萬', '万'], ['與', '与'], ['為', '为'], ['這', '这'], ['個', '个'], ['來', '来'],
  ['後', '后'], ['從', '从'], ['發', '发'], ['國', '国'], ['學', '学'], ['會', '会'],
  ['開', '开'], ['關', '关'], ['聯', '联'], ['類', '类'], ['級', '级'], ['號', '号'],
  ['標', '标'], ['題', '题'], ['體', '体'], ['長', '长'], ['無', '无'], ['時', '时'],
  ['間', '间'], ['現', '现'], ['實', '实'], ['見', '见'], ['對', '对'], ['應', '应'],
  ['該', '该'], ['點', '点'], ['當', '当'], ['動', '动'], ['過', '过'], ['進', '进'],
  ['還', '还'], ['將', '将'], ['專', '专'], ['業', '业'], ['兩', '两'], ['誰', '谁'],
  ['說', '说'], ['語', '语'], ['讀', '读'], ['頁', '页'], ['網', '网'], ['處', '处'],
  ['備', '备'], ['註', '注'], ['腳', '脚'], ['錄', '录'], ['擴', '扩'], ['張', '张'],
  ['簡', '简'], ['轉', '转'], ['換', '换'], ['訊', '讯'], ['測', '测'], ['試', '试'],
  ['際', '际'], ['繼', '继'], ['續', '续'], ['經', '经'], ['驗', '验'], ['錯', '错'],
  ['誤', '误'], ['檔', '档'], ['別', '别'], ['項', '项'], ['編', '编'], ['輯', '辑'],
  ['資', '资'], ['詳', '详'], ['細', '细'], ['預', '预'], ['覽', '览'], ['圖', '图'],
  ['鑑', '鉴'], ['顯', '显'], ['狀', '状'], ['態', '态'], ['擊', '击'], ['選', '选'],
  ['擇', '择'], ['復', '复'], ['歸', '归'], ['閉', '闭'], ['閱', '阅'], ['記', '记'],
  ['內', '内'], ['瀏', '浏'], ['絡', '络'], ['參', '参'], ['連', '连'], ['頭', '头'],
  ['務', '务'], ['門', '门'], ['隊', '队'], ['線', '线'], ['種', '种'], ['麼', '么'],
  ['樣', '样'], ['極', '极'], ['準', '准'], ['廣', '广'], ['義', '义'], ['則', '则'],
  ['單', '单'], ['據', '据'], ['論', '论'], ['邊', '边'], ['導', '导'], ['製', '制'],
  ['術', '术'], ['異', '异'], ['變', '变'], ['場', '场'], ['識', '识'], ['證', '证'],
  ['輔', '辅'], ['創', '创'], ['藝', '艺'], ['攝', '摄'], ['權', '权'], ['圖', '图'],
  ['產', '产'], ['專', '专'], ['護', '护'], ['敵', '敌'], ['殺', '杀'], ['傷', '伤'],
  ['與', '与'], ['聯', '联'], ['訊', '讯'], ['釋', '释'], ['針', '针'], ['錄', '录']
]);

function toSimplifiedChinese(value: string): string {
  let result: string = '';
  for (let index: number = 0; index < value.length; index++) {
    const character = value.charAt(index);
    result += TRADITIONAL_TO_SIMPLIFIED.get(character) ?? character;
  }
  return result;
}

interface RawSpan {
  s: string;
  t: string;
  u?: string;
  r?: string;
}

interface RawBlock {
  k: string;
  spans?: RawSpan[];
  level?: number;
  title?: string;
  blocks?: RawBlock[];
  src?: string;
  caption?: string;
}

interface RawImage {
  src: string;
  caption: string;
}

interface RawFootnote {
  id: string;
  index: number;
  blocks: RawBlock[];
}

interface PayloadValidationBudget {
  blockCount: number;
  spanCount: number;
}

const MAX_PAYLOAD_STRING_LENGTH: number = 1024 * 1024;
const MAX_PAYLOAD_TAGS: number = 512;
const MAX_PAYLOAD_IMAGES: number = 512;
const MAX_PAYLOAD_FOOTNOTES: number = 512;
const MAX_PAYLOAD_WARNINGS: number = 512;
const MAX_PAYLOAD_BLOCKS: number = 8192;
const MAX_PAYLOAD_SPANS: number = 32768;
const MAX_PAYLOAD_DEPTH: number = 32;
const NOISE_TAGS: string[] = [
  'scp', 'safe', 'euclid', 'keter', 'thaumiel', 'apollyon', 'neutralized',
  'pending', 'explained', 'esoteric-class', 'decommissioned', 'archived',
  'uncontained', 'unknown'
];

export interface ScpExtractPayload {
  parserVersion: number;
  ok: boolean;
  error: string;
  title: string;
  rating: string;
  pageVersion: string;
  tags: string[];
  images: RawImage[];
  blocks: RawBlock[];
  footnotes: RawFootnote[];
  warnings: string[];
}

/** 把统一 HTML 提取协议的输出投影为正式文档模型。 */
export class ScpDocumentMapper {
  toDocument(
    payload: ScpExtractPayload,
    sourceUrl: string,
    fetchedAt: number,
  ): ScpArticleDocument {
    const contractError = this.validatePayloadInternal(payload);
    if (contractError.length > 0) {
      throw new Error(contractError);
    }
    const itemId = this.itemIdOf(sourceUrl);
    const images: ScpContentBlock[] = [];
    for (let index: number = 0; index < payload.images.length; index++) {
      const image = payload.images[index];
      images.push(new ScpContentBlock(
        `${itemId}:image:${index}`,
        ScpBlockType.IMAGE,
        [],
        image.src,
        this.displayText(image.caption)
      ));
    }

    const blocks = this.mapBlocks(itemId, payload.blocks);
    const footnotes: ScpFootnote[] = [];
    for (let index: number = 0; index < payload.footnotes.length; index++) {
      const footnote = payload.footnotes[index];
      const blocks = this.mapFootnoteBlocks(
        itemId,
        footnote.blocks,
        `${itemId}:fn:${footnote.index}`
      );
      // A Wikidot footnote may contain only indentation, anchors or a trailing
      // <br>.  Do not create an empty visual row for that payload.
      if (blocks.length > 0) {
        footnotes.push(new ScpFootnote(footnote.id, footnote.index, blocks));
      }
    }

    const objectClass = this.objectClassOf(blocks);

    return new ScpArticleDocument(
      itemId,
      this.displayText(payload.title).trim(),
      objectClass,
      sourceUrl,
      fetchedAt,
      blocks,
      footnotes,
      '',
      this.parserWarningsOf(payload),
      this.displayText(payload.rating).trim(),
      this.filteredTags(payload.tags),
      this.displayText(payload.pageVersion).trim(),
      images
    );
  }

  private validatePayloadInternal(payload: ScpExtractPayload): string {
    if (payload === undefined || payload === null || typeof payload !== 'object' ||
      Array.isArray(payload)) {
      return '正文解析结果不是对象';
    }
    if (payload.ok !== true) {
      return `正文解析失败：${typeof payload.error === 'string' ? payload.error : '未知错误'}`;
    }
    if (payload.parserVersion !== ScpArticleDocument.CURRENT_PARSER_VERSION) {
      const version = typeof payload.parserVersion === 'number' ? `${payload.parserVersion}` : 'unknown';
      return `正文解析器版本不兼容：${version}`;
    }
    if (typeof payload.title !== 'string' || payload.title.trim().length === 0) {
      return '正文解析结果缺少标题';
    }
    if (typeof payload.error !== 'string' || typeof payload.rating !== 'string' ||
      typeof payload.pageVersion !== 'string' || payload.error.length > MAX_PAYLOAD_STRING_LENGTH ||
      payload.title.length > MAX_PAYLOAD_STRING_LENGTH ||
      payload.rating.length > MAX_PAYLOAD_STRING_LENGTH ||
      payload.pageVersion.length > MAX_PAYLOAD_STRING_LENGTH) {
      return '正文解析结果字段格式错误';
    }
    if (!Array.isArray(payload.blocks) || !Array.isArray(payload.images) ||
      !Array.isArray(payload.footnotes) || !Array.isArray(payload.tags)) {
      return '正文解析结果字段不完整';
    }
    if (payload.tags.length > MAX_PAYLOAD_TAGS || !this.validateTags(payload.tags)) {
      return '正文解析标签字段格式错误';
    }
    if (payload.images.length > MAX_PAYLOAD_IMAGES || !this.validateImages(payload.images)) {
      return '正文解析图片字段格式错误';
    }
    if (payload.footnotes.length > MAX_PAYLOAD_FOOTNOTES) {
      return '正文解析脚注数量超限';
    }
    const budget: PayloadValidationBudget = { blockCount: 0, spanCount: 0 };
    if (!this.validateBlocks(payload.blocks, 0, budget) ||
      !this.validateFootnotes(payload.footnotes, budget)) {
      return '正文解析正文结构格式错误';
    }
    if (!Array.isArray(payload.warnings) || payload.warnings.length > MAX_PAYLOAD_WARNINGS ||
      !this.validateWarnings(payload.warnings)) {
      return '正文解析警告字段格式错误';
    }
    if (!this.hasReadableBlocks(payload.blocks) && !this.hasReadableImage(payload.images)) {
      return '正文解析结果为空';
    }
    return '';
  }

  private validateTags(tags: string[]): boolean {
    for (let index: number = 0; index < tags.length; index++) {
      if (typeof tags[index] !== 'string' || tags[index].length > MAX_PAYLOAD_STRING_LENGTH) {
        return false;
      }
    }
    return true;
  }

  private validateWarnings(warnings: string[]): boolean {
    for (let index: number = 0; index < warnings.length; index++) {
      if (typeof warnings[index] !== 'string' || warnings[index].length > MAX_PAYLOAD_STRING_LENGTH) {
        return false;
      }
    }
    return true;
  }

  private validateImages(images: RawImage[]): boolean {
    for (let index: number = 0; index < images.length; index++) {
      const image = images[index];
      if (image === undefined || image === null || typeof image !== 'object' ||
        typeof image.src !== 'string' || image.src.length > MAX_PAYLOAD_STRING_LENGTH) {
        return false;
      }
      if (typeof image.caption !== 'string') {
        return false;
      }
      if (image.caption.length > MAX_PAYLOAD_STRING_LENGTH) {
        return false;
      }
    }
    return true;
  }

  private validateFootnotes(
    footnotes: RawFootnote[],
    budget: PayloadValidationBudget
  ): boolean {
    for (let index: number = 0; index < footnotes.length; index++) {
      const footnote = footnotes[index];
      if (footnote === undefined || footnote === null || typeof footnote !== 'object' ||
        typeof footnote.id !== 'string' || footnote.id.length > MAX_PAYLOAD_STRING_LENGTH ||
        typeof footnote.index !== 'number' || !Number.isFinite(footnote.index) ||
        footnote.index < 0 || !Array.isArray(footnote.blocks) ||
        !this.validateBlocks(footnote.blocks, 0, budget)) {
        return false;
      }
    }
    return true;
  }

  private validateBlocks(
    blocks: RawBlock[],
    depth: number,
    budget: PayloadValidationBudget
  ): boolean {
    if (depth > MAX_PAYLOAD_DEPTH || blocks.length > MAX_PAYLOAD_BLOCKS) {
      return false;
    }
    for (let index: number = 0; index < blocks.length; index++) {
      const block = blocks[index];
      if (block === undefined || block === null || typeof block !== 'object' ||
        typeof block.k !== 'string' || block.k.length === 0 ||
        block.k.length > 128) {
        return false;
      }
      budget.blockCount++;
      if (budget.blockCount > MAX_PAYLOAD_BLOCKS) {
        return false;
      }
      if (block.level !== undefined &&
        (typeof block.level !== 'number' || !Number.isFinite(block.level) ||
          block.level < 1 || block.level > 6)) {
        return false;
      }
      if (block.title !== undefined &&
        (typeof block.title !== 'string' || block.title.length > MAX_PAYLOAD_STRING_LENGTH)) {
        return false;
      }
      if (block.src !== undefined &&
        (typeof block.src !== 'string' || block.src.length > MAX_PAYLOAD_STRING_LENGTH)) {
        return false;
      }
      if (block.caption !== undefined &&
        (typeof block.caption !== 'string' || block.caption.length > MAX_PAYLOAD_STRING_LENGTH)) {
        return false;
      }
      if (block.spans !== undefined &&
        (!Array.isArray(block.spans) || !this.validateSpans(block.spans, budget))) {
        return false;
      }
      if (block.blocks !== undefined &&
        (!Array.isArray(block.blocks) || !this.validateBlocks(block.blocks, depth + 1, budget))) {
        return false;
      }
    }
    return true;
  }

  private validateSpans(spans: RawSpan[], budget: PayloadValidationBudget): boolean {
    if (spans.length > MAX_PAYLOAD_SPANS) {
      return false;
    }
    for (let index: number = 0; index < spans.length; index++) {
      const span = spans[index];
      if (span === undefined || span === null || typeof span !== 'object' ||
        typeof span.s !== 'string' || typeof span.t !== 'string' ||
        span.s.length > 128 || span.t.length > MAX_PAYLOAD_STRING_LENGTH ||
        (span.u !== undefined && (typeof span.u !== 'string' || span.u.length > MAX_PAYLOAD_STRING_LENGTH)) ||
        (span.r !== undefined && (typeof span.r !== 'string' || span.r.length > MAX_PAYLOAD_STRING_LENGTH))) {
        return false;
      }
      budget.spanCount++;
      if (budget.spanCount > MAX_PAYLOAD_SPANS) {
        return false;
      }
    }
    return true;
  }

  private hasReadableBlocks(blocks: RawBlock[]): boolean {
    for (let index: number = 0; index < blocks.length; index++) {
      const block = blocks[index];
      if (block === undefined || block === null) {
        continue;
      }
      const spans = block.spans ?? [];
      for (let spanIndex: number = 0; spanIndex < spans.length; spanIndex++) {
        const text = spans[spanIndex].t;
        if (typeof text === 'string' && text.trim().length > 0) {
          return true;
        }
      }
      if (block.k === 'embed' && typeof block.src === 'string' && block.src.trim().length > 0) {
        return true;
      }
      if (this.hasReadableBlocks(block.blocks ?? [])) {
        return true;
      }
    }
    return false;
  }

  private hasReadableImage(images: RawImage[]): boolean {
    for (let index: number = 0; index < images.length; index++) {
      if (typeof images[index].src === 'string' && images[index].src.trim().length > 0) {
        return true;
      }
    }
    return false;
  }

  private parserWarningsOf(payload: ScpExtractPayload): string[] {
    const result: string[] = [];
    const warnings = payload.warnings;
    for (let index: number = 0; index < warnings.length; index++) {
      const warning = warnings[index];
      const normalized = this.displayText(warning).trim();
      if (normalized.length > 0 && result.indexOf(normalized) < 0) {
        result.push(normalized);
      }
    }
    return result;
  }

  private mapBlocks(itemId: string, raw: RawBlock[]): ScpContentBlock[] {
    return this.mapBlocksWithPrefix(itemId, raw, `${itemId}:0`);
  }

  /**
   * Footnotes are extracted from inline DOM fragments and commonly contain
   * indentation-only paragraphs or separator nodes. Those nodes have no
   * reader-facing meaning and would otherwise render as blank lines above the
   * “返回正文” action. Keep only blocks with actual text/media content.
   */
  private mapFootnoteBlocks(itemId: string, raw: RawBlock[], prefix: string): ScpContentBlock[] {
    const mapped = this.mapBlocksWithPrefix(itemId, raw, prefix);
    const result: ScpContentBlock[] = [];
    for (let index: number = 0; index < mapped.length; index++) {
      if (this.hasReadableFootnoteBlock(mapped[index])) {
        result.push(mapped[index]);
      }
    }
    return result;
  }

  /** 嵌套层级各自携带父级前缀，保证块 key 全局唯一（ForEach key / 展开状态都依赖它）。 */
  private mapBlocksWithPrefix(itemId: string, raw: RawBlock[], prefix: string): ScpContentBlock[] {
    const result: ScpContentBlock[] = [];
    for (let index: number = 0; index < raw.length; index++) {
      const block = this.mapBlock(itemId, `${prefix}:${index}`, raw[index]);
      if (this.isMeaningfulBlock(block)) {
        result.push(block);
      }
    }
    return result;
  }

  private mapBlock(itemId: string, key: string, raw: RawBlock): ScpContentBlock {
    const spans = this.mapSpans(raw.spans);
    switch (raw.k) {
      case 'paragraph':
        return new ScpContentBlock(key, ScpBlockType.PARAGRAPH, spans);
      case 'heading':
        return new ScpContentBlock(key, ScpBlockType.HEADING, spans, '', '', raw.level ?? 2);
      case 'quote':
        return new ScpContentBlock(key, ScpBlockType.QUOTE, spans, '', '', 0,
          this.mapBlocksWithPrefix(itemId, raw.blocks ?? [], key));
      case 'collapsible':
        return new ScpContentBlock(key, ScpBlockType.COLLAPSIBLE, [], '', this.displayText(raw.title ?? ''), 0,
          this.mapBlocksWithPrefix(itemId, raw.blocks ?? [], key));
      case 'table':
        return new ScpContentBlock(key, ScpBlockType.TABLE, [], '', '', 0,
          this.mapBlocksWithPrefix(itemId, raw.blocks ?? [], key));
      case 'row':
        return new ScpContentBlock(key, ScpBlockType.TABLE_ROW, [], '', '', 0,
          this.mapBlocksWithPrefix(itemId, raw.blocks ?? [], key));
      case 'cell':
        return new ScpContentBlock(key, ScpBlockType.TABLE_CELL, spans);
      case 'divider':
        return new ScpContentBlock(key, ScpBlockType.DIVIDER);
      case 'embed':
        return new ScpContentBlock(key, ScpBlockType.EMBED, [], raw.src ?? '');
      case 'image':
        return new ScpContentBlock(key, ScpBlockType.IMAGE, [], raw.src ?? '',
          this.displayText(raw.caption ?? ''));
      default:
        return new ScpContentBlock(key, ScpBlockType.UNSUPPORTED, spans);
    }
  }

  private mapSpans(raw: RawSpan[] | undefined): ScpTextSpan[] {
    const result: ScpTextSpan[] = [];
    if (raw === undefined) {
      return result;
    }
    for (let index: number = 0; index < raw.length; index++) {
      const span = raw[index];
      // Keep code snippets byte-for-byte stable; every other span is reader
      // prose and can safely use the Traditional -> Simplified projection.
      const text = span.s === 'code' ? span.t : this.displayText(span.t);
      switch (span.s) {
        case 'strong':
          result.push(new ScpTextSpan(ScpTextStyle.STRONG, text));
          break;
        case 'em':
          result.push(new ScpTextSpan(ScpTextStyle.EMPHASIS, text));
          break;
        case 'del':
          result.push(new ScpTextSpan(ScpTextStyle.DELETED, text));
          break;
        case 'code':
          result.push(new ScpTextSpan(ScpTextStyle.CODE, text));
          break;
        case 'link':
          result.push(new ScpTextSpan(ScpTextStyle.LINK, text, span.u ?? ''));
          break;
        case 'footnote':
          result.push(new ScpTextSpan(ScpTextStyle.FOOTNOTE_REFERENCE, text.trim(), '', span.r ?? ''));
          break;
        default:
          result.push(new ScpTextSpan(ScpTextStyle.PLAIN, text));
          break;
      }
    }
    return this.trimSpanEdges(result);
  }

  private itemIdOf(sourceUrl: string): string {
    // CN originals use identifiers such as `scp-cn-963-j`; retain the full
    // route token so document/cache keys and image ids do not collapse to the
    // outer source URL.
    const match = /\/(scp-(?:(?:[a-z]{2,4}-)?\d+|[a-z0-9]*\d+[a-z0-9]*)(?:-[a-z0-9]+)*)(?:$|\/)/i.exec(sourceUrl);
    return match !== null ? match[1].toUpperCase() : sourceUrl;
  }

  private objectClassOf(blocks: ScpContentBlock[]): string {
    for (let index: number = 0; index < blocks.length; index++) {
      const text = this.plainText(blocks[index]);
      const match = /项目等级：?\s*([A-Za-z\u4e00-\u9fa5]+)/.exec(toSimplifiedChinese(text));
      if (match !== null) {
        return match[1];
      }
    }
    return '';
  }

  private plainText(block: ScpContentBlock): string {
    let text = '';
    for (let index: number = 0; index < block.spans.length; index++) {
      text += block.spans[index].text;
    }
    for (let index: number = 0; index < block.children.length; index++) {
      text += this.plainText(block.children[index]);
    }
    return text;
  }

  private displayText(value: string): string {
    // The DOM extractor represents <br> as newlines.  A pretty-printed
    // footnote can contain several adjacent breaks; keep a single intentional
    // line break while removing indentation around it.
    return toSimplifiedChinese(value)
      .replace(/\r\n?/g, '\n')
      .replace(/[ \t]*\n[ \t]*/g, '\n')
      .replace(/\n{2,}/g, '\n');
  }

  private trimSpanEdges(spans: ScpTextSpan[]): ScpTextSpan[] {
    const result: ScpTextSpan[] = [];
    for (let index: number = 0; index < spans.length; index++) {
      const span = spans[index];
      let text = span.text;
      if (index === 0) {
        text = text.replace(/^\s+/, '');
      }
      if (index === spans.length - 1) {
        text = text.replace(/\s+$/, '');
      }
      if (text.length === 0) {
        continue;
      }
      result.push(new ScpTextSpan(span.style, text, span.target, span.referenceId));
    }
    return result;
  }

  private isMeaningfulBlock(block: ScpContentBlock): boolean {
    if (block.type === ScpBlockType.DIVIDER) {
      return true;
    }
    if (block.source.trim().length > 0) {
      return true;
    }
    if (this.plainText(block).trim().length > 0) {
      return true;
    }
    return block.children.length > 0;
  }

  private hasReadableFootnoteBlock(block: ScpContentBlock): boolean {
    if (block.type === ScpBlockType.DIVIDER) {
      return false;
    }
    if (block.source.trim().length > 0 || this.plainText(block).trim().length > 0) {
      return true;
    }
    for (let index: number = 0; index < block.children.length; index++) {
      if (this.hasReadableFootnoteBlock(block.children[index])) {
        return true;
      }
    }
    return false;
  }

  private filteredTags(tags: string[]): string[] {
    const result: string[] = [];
    for (let index: number = 0; index < tags.length; index++) {
      const tag = this.displayText(tags[index]).trim();
      if (tag.length === 0 || this.isNoiseTag(tag)) {
        continue;
      }
      if (result.indexOf(tag) < 0) {
        result.push(tag);
      }
    }
    return result;
  }

  private isNoiseTag(tag: string): boolean {
    const normalized = tag.toLowerCase().replace(/[ _]/g, '-');
    if (NOISE_TAGS.indexOf(normalized) >= 0) {
      return true;
    }
    if (normalized.indexOf('containment-class') >= 0 ||
      normalized.indexOf('object-class') >= 0 ||
      normalized.indexOf('收容等级') >= 0 || normalized.indexOf('项目等级') >= 0) {
      return true;
    }
    return normalized.indexOf('containment-class-') === 0 ||
      normalized.indexOf('object-class-') === 0 ||
      normalized.indexOf('rating-') === 0 ||
      /^class-[a-z-]+$/.test(normalized);
  }
}
