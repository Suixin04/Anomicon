import {
  ScpAcsMetadata,
  ScpArticleDocument,
  ScpBlockType,
  ScpCalloutTone,
  ScpContentBlock,
  ScpFootnote,
  ScpHiddenTextKind,
  ScpTextAlign,
  ScpTextSpan,
  ScpTextStyle
} from '../domain/ScpDocument';
import {
  isNoiseArticleAnchor,
  normalizeArticleAnchor
} from '../domain/ArticleNavigation';
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
  b?: boolean;
  i?: boolean;
  d?: boolean;
  ul?: boolean;
  m?: boolean;
  sup?: boolean;
  sub?: boolean;
  c?: string;
  fs?: number;
  h?: string;
}

interface RawAcsMetadata {
  itemNumber: string;
  clearanceLevel: string;
  containmentClass: string;
  secondaryClass: string;
  disruptionClass: string;
  riskClass: string;
  memoUrl: string;
}

interface RawBlock {
  k: string;
  spans?: RawSpan[];
  level?: number;
  title?: string;
  closeTitle?: string;
  expanded?: boolean;
  ordered?: boolean;
  isHeader?: boolean;
  tone?: string;
  preferredWidth?: number;
  acs?: RawAcsMetadata;
  align?: string;
  blocks?: RawBlock[];
  src?: string;
  caption?: string;
  anchors?: string[];
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
  creditBlocks?: RawBlock[];
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
    const creditBlocks = this.mapBlocksWithPrefix(itemId, payload.creditBlocks ?? [], `${itemId}:credit`);
    const footnotes: ScpFootnote[] = [];
    for (let index: number = 0; index < payload.footnotes.length; index++) {
      const footnote = payload.footnotes[index];
      const fnBlocks = this.mapFootnoteBlocks(
        itemId,
        footnote.blocks,
        `${itemId}:fn:${footnote.index}`,
        footnote.index,
        footnote.id
      );
      // A Wikidot footnote may contain only indentation, anchors or a trailing
      // <br>.  Do not create an empty visual row for that payload.
      if (fnBlocks.length > 0) {
        footnotes.push(new ScpFootnote(footnote.id, footnote.index, fnBlocks));
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
      images,
      creditBlocks
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
    if (payload.creditBlocks !== undefined &&
      (!Array.isArray(payload.creditBlocks) || !this.validateBlocks(payload.creditBlocks, 0, budget))) {
      return '正文解析著作信息格式错误';
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

  private validateAnchors(anchors: string[]): boolean {
    for (let index: number = 0; index < anchors.length; index++) {
      if (typeof anchors[index] !== 'string' || anchors[index].length > 128) {
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
          block.level < 0 || block.level > 32)) {
        return false;
      }
      if (block.title !== undefined &&
        (typeof block.title !== 'string' || block.title.length > MAX_PAYLOAD_STRING_LENGTH)) {
        return false;
      }
      if (block.closeTitle !== undefined &&
        (typeof block.closeTitle !== 'string' || block.closeTitle.length > MAX_PAYLOAD_STRING_LENGTH)) {
        return false;
      }
      if (block.expanded !== undefined && typeof block.expanded !== 'boolean') {
        return false;
      }
      if (block.ordered !== undefined && typeof block.ordered !== 'boolean') {
        return false;
      }
      if (block.isHeader !== undefined && typeof block.isHeader !== 'boolean') {
        return false;
      }
      if (block.tone !== undefined &&
        (typeof block.tone !== 'string' || block.tone.length > 64)) {
        return false;
      }
      if (block.preferredWidth !== undefined &&
        (typeof block.preferredWidth !== 'number' || !Number.isFinite(block.preferredWidth) ||
          block.preferredWidth < 0 || block.preferredWidth > 4096)) {
        return false;
      }
      if (block.acs !== undefined && !this.validateAcsMetadata(block.acs)) {
        return false;
      }
      if (block.align !== undefined && (typeof block.align !== 'string' || block.align.length > 16)) {
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
      if (block.anchors !== undefined &&
        (!Array.isArray(block.anchors) || block.anchors.length > 32 ||
          !this.validateAnchors(block.anchors))) {
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

  private validateAcsMetadata(acs: RawAcsMetadata): boolean {
    if (acs === null || typeof acs !== 'object' || Array.isArray(acs)) {
      return false;
    }
    const fields = [
      acs.itemNumber,
      acs.clearanceLevel,
      acs.containmentClass,
      acs.secondaryClass,
      acs.disruptionClass,
      acs.riskClass,
      acs.memoUrl
    ];
    for (let index: number = 0; index < fields.length; index++) {
      if (typeof fields[index] !== 'string' || fields[index].length > MAX_PAYLOAD_STRING_LENGTH) {
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
        (span.r !== undefined && (typeof span.r !== 'string' || span.r.length > MAX_PAYLOAD_STRING_LENGTH)) ||
        (span.b !== undefined && typeof span.b !== 'boolean') ||
        (span.i !== undefined && typeof span.i !== 'boolean') ||
        (span.d !== undefined && typeof span.d !== 'boolean') ||
        (span.ul !== undefined && typeof span.ul !== 'boolean') ||
        (span.m !== undefined && typeof span.m !== 'boolean') ||
        (span.sup !== undefined && typeof span.sup !== 'boolean') ||
        (span.sub !== undefined && typeof span.sub !== 'boolean') ||
        (span.c !== undefined && (typeof span.c !== 'string' || span.c.length > 16)) ||
        (span.fs !== undefined && (typeof span.fs !== 'number' || !Number.isFinite(span.fs) ||
          span.fs < 0.5 || span.fs > 3.0)) ||
        (span.h !== undefined && (typeof span.h !== 'string' || span.h.length > 32))) {
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
      if (block.k === 'image' && typeof block.src === 'string' && block.src.trim().length > 0) {
        return true;
      }
      if (block.k === 'acs_header' && block.acs !== undefined &&
        (block.acs.itemNumber.trim().length > 0 || block.acs.containmentClass.trim().length > 0)) {
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
  private mapFootnoteBlocks(
    itemId: string,
    raw: RawBlock[],
    prefix: string,
    footnoteIndex: number,
    footnoteId: string
  ): ScpContentBlock[] {
    const mapped = this.mapBlocksWithPrefix(itemId, raw, prefix);
    const cleaned = this.stripDuplicateFootnoteIndex(mapped, footnoteIndex, footnoteId);
    const result: ScpContentBlock[] = [];
    for (let index: number = 0; index < cleaned.length; index++) {
      if (this.hasReadableFootnoteBlock(cleaned[index])) {
        result.push(cleaned[index]);
      }
    }
    return result;
  }

  private footnoteIndexTokens(footnoteIndex: number, footnoteId: string): string[] {
    const tokens: string[] = [];
    if (Number.isFinite(footnoteIndex) && footnoteIndex > 0) {
      tokens.push(String(Math.floor(footnoteIndex)));
    }
    const normalizedId = footnoteId.trim();
    if (/^\d+$/.test(normalizedId) && tokens.indexOf(normalizedId) < 0) {
      tokens.push(normalizedId);
    }
    return tokens;
  }

  private matchesStandaloneFootnoteToken(text: string, tokens: string[]): boolean {
    const trimmed = text.trim();
    for (let index: number = 0; index < tokens.length; index++) {
      const token = tokens[index];
      if (trimmed === token || trimmed === `${token}.` || trimmed === `${token}．` ||
        trimmed === `${token}、` || trimmed === `${token}:` || trimmed === `[${token}]`) {
        return true;
      }
    }
    return false;
  }

  private cloneSpanWithText(span: ScpTextSpan, text: string): ScpTextSpan {
    return new ScpTextSpan(
      span.style,
      text,
      span.target,
      span.referenceId,
      span.bold,
      span.italic,
      span.deleted,
      span.underline,
      span.monospace,
      span.superscript,
      span.subscript,
      span.color,
      span.fontScale,
      span.hiddenKind
    );
  }

  private cloneBlockWithSpans(block: ScpContentBlock, spans: ScpTextSpan[]): ScpContentBlock {
    return new ScpContentBlock(
      block.key,
      block.type,
      spans,
      block.source,
      block.caption,
      block.level,
      block.children,
      block.closeCaption,
      block.initiallyExpanded,
      block.ordered,
      block.isHeader,
      block.calloutTone,
      block.preferredWidth,
      block.acs,
      block.textAlign,
      block.anchors
    );
  }

  private replaceLeadingSpanText(block: ScpContentBlock, nextFirstText: string): ScpContentBlock {
    const updated: ScpTextSpan[] = [];
    if (nextFirstText.length > 0) {
      const first = block.spans[0];
      updated.push(this.cloneSpanWithText(first, nextFirstText));
    }
    for (let index: number = 1; index < block.spans.length; index++) {
      updated.push(block.spans[index]);
    }
    return this.cloneBlockWithSpans(block, this.trimSpanEdges(updated));
  }

  private dropFirstSpanAndTrimLeading(
    block: ScpContentBlock,
    stripPunctuation: boolean
  ): ScpContentBlock {
    const updated: ScpTextSpan[] = [];
    for (let index: number = 1; index < block.spans.length; index++) {
      const span = block.spans[index];
      let text = span.text;
      if (index === 1 && stripPunctuation) {
        text = text.replace(/^\s*(?:\.(?!\d)|[．、:])\s*/, '');
      }
      if (text.length > 0) {
        updated.push(this.cloneSpanWithText(span, text));
      }
    }
    return this.cloneBlockWithSpans(block, this.trimSpanEdges(updated));
  }

  private stripDuplicateFootnoteIndex(
    blocks: ScpContentBlock[],
    footnoteIndex: number,
    footnoteId: string
  ): ScpContentBlock[] {
    const tokens = this.footnoteIndexTokens(footnoteIndex, footnoteId);
    if (tokens.length === 0 || blocks.length === 0) {
      return blocks;
    }

    // 兼容旧缓存中被拆成独立段落的 Wikidot 回跳编号块（如 ["1"] + [". 文本"]）。
    if (blocks.length >= 2 && blocks[0].type === ScpBlockType.PARAGRAPH &&
      this.matchesStandaloneFootnoteToken(this.plainText(blocks[0]), tokens)) {
      const rest = blocks.slice(1);
      if (rest[0].type === ScpBlockType.PARAGRAPH && rest[0].spans.length > 0) {
        const nextText = rest[0].spans[0].text.replace(/^\s*(?:\.(?!\d)|[．、:\]])\s*/, '');
        rest[0] = this.replaceLeadingSpanText(rest[0], nextText);
      }
      return rest;
    }

    const first = blocks[0];
    if (first.type !== ScpBlockType.PARAGRAPH || first.spans.length === 0) {
      return blocks;
    }

    const lead = first.spans[0].text.trim();
    if (first.spans.length >= 2) {
      for (let index: number = 0; index < tokens.length; index++) {
        const token = tokens[index];
        if (lead === token && /^\s*(?:\.(?!\d)|[．、:])/.test(first.spans[1].text)) {
          const next = blocks.slice();
          next[0] = this.dropFirstSpanAndTrimLeading(first, true);
          return next;
        }
        if (lead === `${token}.` || lead === `${token}．` ||
          lead === `${token}、` || lead === `${token}:` || lead === `[${token}]`) {
          const next = blocks.slice();
          next[0] = this.dropFirstSpanAndTrimLeading(first, lead === `[${token}]`);
          return next;
        }
      }
    }

    const rawFirstText = first.spans[0].text;
    for (let index: number = 0; index < tokens.length; index++) {
      const token = tokens[index];
      const pattern = new RegExp(
        `^\\s*(?:\\[${token}\\]\\s*(?:(?:\\.(?!\\d)|[．、:])\\s*|(?=\\S))|${token}\\s*(?:\\.(?!\\d)|[．、:])\\s*)`
      );
      if (pattern.test(rawFirstText)) {
        const stripped = rawFirstText.replace(pattern, '');
        const next = blocks.slice();
        next[0] = this.replaceLeadingSpanText(first, stripped);
        return next;
      }
    }
    return blocks;
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

  private mapCalloutTone(tone: string | undefined): ScpCalloutTone {
    switch ((tone ?? '').toLowerCase()) {
      case 'terminal':
        return ScpCalloutTone.TERMINAL;
      case 'warning':
        return ScpCalloutTone.WARNING;
      case 'note':
        return ScpCalloutTone.NOTE;
      default:
        return ScpCalloutTone.NEUTRAL;
    }
  }

  private mapTextAlign(align: string | undefined): ScpTextAlign {
    switch ((align ?? '').toLowerCase()) {
      case 'start':
      case 'left':
        return ScpTextAlign.START;
      case 'center':
        return ScpTextAlign.CENTER;
      case 'end':
      case 'right':
        return ScpTextAlign.END;
      case 'justify':
        return ScpTextAlign.JUSTIFY;
      default:
        return ScpTextAlign.DEFAULT;
    }
  }

  private mapHiddenKind(hidden: string | undefined): ScpHiddenTextKind {
    switch ((hidden ?? '').toLowerCase()) {
      case 'white_easter_egg':
        return ScpHiddenTextKind.WHITE_EASTER_EGG;
      case 'zero_size_whisper':
        return ScpHiddenTextKind.ZERO_SIZE_WHISPER;
      case 'blackbox':
        return ScpHiddenTextKind.BLACKBOX;
      default:
        return ScpHiddenTextKind.NONE;
    }
  }

  private sanitizeHexColor(raw: string | undefined): string {
    if (raw === undefined) {
      return '';
    }
    const trimmed = raw.trim();
    return /^#[0-9A-Fa-f]{6}$/.test(trimmed) ? trimmed.toUpperCase() : '';
  }

  private mapAnchors(raw: string[] | undefined): string[] {
    const result: string[] = [];
    if (raw === undefined) {
      return result;
    }
    for (let index: number = 0; index < raw.length && result.length < 32; index++) {
      const normalized = normalizeArticleAnchor(raw[index]);
      if (normalized.length > 0 && !isNoiseArticleAnchor(normalized) &&
        result.indexOf(normalized) < 0) {
        result.push(normalized);
      }
    }
    return result;
  }

  private mapBlock(itemId: string, key: string, raw: RawBlock): ScpContentBlock {
    const spans = this.mapSpans(raw.spans);
    const textAlign = this.mapTextAlign(raw.align);
    const anchors = this.mapAnchors(raw.anchors);
    switch (raw.k) {
      case 'paragraph':
        return new ScpContentBlock(
          key,
          ScpBlockType.PARAGRAPH,
          spans,
          '',
          '',
          0,
          [],
          '',
          false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          textAlign,
          anchors
        );
      case 'heading':
        return new ScpContentBlock(
          key,
          ScpBlockType.HEADING,
          spans,
          '',
          '',
          raw.level ?? 2,
          [],
          '',
          false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          textAlign,
          anchors
        );
      case 'quote':
        return new ScpContentBlock(
          key,
          ScpBlockType.QUOTE,
          spans,
          '',
          '',
          0,
          this.mapBlocksWithPrefix(itemId, raw.blocks ?? [], key),
          '',
          false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          ScpTextAlign.DEFAULT,
          anchors
        );
      case 'collapsible':
        return new ScpContentBlock(
          key,
          ScpBlockType.COLLAPSIBLE,
          [],
          '',
          this.displayText(raw.title ?? ''),
          0,
          this.mapBlocksWithPrefix(itemId, raw.blocks ?? [], key),
          this.displayText(raw.closeTitle ?? ''),
          raw.expanded ?? false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          ScpTextAlign.DEFAULT,
          anchors
        );
      case 'tabs':
        return new ScpContentBlock(
          key,
          ScpBlockType.TABS,
          [],
          '',
          '',
          0,
          this.mapBlocksWithPrefix(itemId, raw.blocks ?? [], key),
          '',
          false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          ScpTextAlign.DEFAULT,
          anchors
        );
      case 'tab_panel':
        return new ScpContentBlock(
          key,
          ScpBlockType.TAB_PANEL,
          [],
          '',
          this.displayText(raw.title ?? ''),
          0,
          this.mapBlocksWithPrefix(itemId, raw.blocks ?? [], key),
          '',
          false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          ScpTextAlign.DEFAULT,
          anchors
        );
      case 'callout':
        return new ScpContentBlock(
          key,
          ScpBlockType.CALLOUT,
          [],
          '',
          '',
          0,
          this.mapBlocksWithPrefix(itemId, raw.blocks ?? [], key),
          '',
          false,
          false,
          false,
          this.mapCalloutTone(raw.tone),
          0,
          undefined,
          ScpTextAlign.DEFAULT,
          anchors
        );
      case 'code_block':
        return new ScpContentBlock(
          key,
          ScpBlockType.CODE_BLOCK,
          spans,
          '',
          '',
          0,
          [],
          '',
          false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          ScpTextAlign.DEFAULT,
          anchors
        );
      case 'list':
        return new ScpContentBlock(
          key,
          ScpBlockType.LIST,
          [],
          '',
          '',
          raw.level ?? 0,
          this.mapBlocksWithPrefix(itemId, raw.blocks ?? [], key),
          '',
          false,
          raw.ordered ?? false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          ScpTextAlign.DEFAULT,
          anchors
        );
      case 'list_item':
        return new ScpContentBlock(
          key,
          ScpBlockType.LIST_ITEM,
          spans,
          '',
          '',
          raw.level ?? 0,
          this.mapBlocksWithPrefix(itemId, raw.blocks ?? [], key),
          '',
          false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          textAlign,
          anchors
        );
      case 'acs_header': {
        const rawAcs = raw.acs;
        const acs = rawAcs === undefined ? undefined : new ScpAcsMetadata(
          this.displayText(rawAcs.itemNumber).trim(),
          this.displayText(rawAcs.clearanceLevel).trim(),
          this.displayText(rawAcs.containmentClass).trim(),
          this.displayText(rawAcs.secondaryClass).trim(),
          this.displayText(rawAcs.disruptionClass).trim(),
          this.displayText(rawAcs.riskClass).trim(),
          rawAcs.memoUrl.trim()
        );
        return new ScpContentBlock(
          key,
          ScpBlockType.ACS_HEADER,
          [],
          '',
          '',
          0,
          [],
          '',
          false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          acs,
          ScpTextAlign.DEFAULT,
          anchors
        );
      }
      case 'table':
        return new ScpContentBlock(
          key,
          ScpBlockType.TABLE,
          [],
          '',
          '',
          0,
          this.mapBlocksWithPrefix(itemId, raw.blocks ?? [], key),
          '',
          false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          ScpTextAlign.DEFAULT,
          anchors
        );
      case 'row':
        return new ScpContentBlock(
          key,
          ScpBlockType.TABLE_ROW,
          [],
          '',
          '',
          0,
          this.mapBlocksWithPrefix(itemId, raw.blocks ?? [], key),
          '',
          false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          ScpTextAlign.DEFAULT,
          anchors
        );
      case 'cell':
        return new ScpContentBlock(
          key,
          ScpBlockType.TABLE_CELL,
          spans,
          '',
          '',
          0,
          [],
          '',
          false,
          false,
          raw.isHeader ?? false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          textAlign,
          anchors
        );
      case 'divider':
        return new ScpContentBlock(
          key,
          ScpBlockType.DIVIDER,
          [],
          '',
          '',
          0,
          [],
          '',
          false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          ScpTextAlign.DEFAULT,
          anchors
        );
      case 'embed':
        return new ScpContentBlock(
          key,
          ScpBlockType.EMBED,
          [],
          raw.src ?? '',
          '',
          0,
          [],
          '',
          false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          ScpTextAlign.DEFAULT,
          anchors
        );
      case 'image':
        return new ScpContentBlock(
          key,
          ScpBlockType.IMAGE,
          [],
          raw.src ?? '',
          this.displayText(raw.caption ?? ''),
          0,
          [],
          '',
          false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          raw.preferredWidth ?? 0,
          undefined,
          ScpTextAlign.DEFAULT,
          anchors
        );
      default:
        return new ScpContentBlock(
          key,
          ScpBlockType.UNSUPPORTED,
          spans,
          '',
          '',
          0,
          [],
          '',
          false,
          false,
          false,
          ScpCalloutTone.NEUTRAL,
          0,
          undefined,
          ScpTextAlign.DEFAULT,
          anchors
        );
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
      let style = ScpTextStyle.PLAIN;
      let target = '';
      let referenceId = '';
      let outputText = text;
      switch (span.s) {
        case 'strong':
          style = ScpTextStyle.STRONG;
          break;
        case 'em':
          style = ScpTextStyle.EMPHASIS;
          break;
        case 'del':
          style = ScpTextStyle.DELETED;
          break;
        case 'code':
          style = ScpTextStyle.CODE;
          break;
        case 'link':
          style = ScpTextStyle.LINK;
          target = span.u ?? '';
          break;
        case 'footnote':
          style = ScpTextStyle.FOOTNOTE_REFERENCE;
          outputText = this.normalizeFootnoteRefLabel(text);
          referenceId = span.r ?? '';
          break;
        default:
          style = ScpTextStyle.PLAIN;
          break;
      }
      const rawScale = span.fs;
      const fontScale = rawScale !== undefined && Number.isFinite(rawScale) ?
        Math.max(0.72, Math.min(1.85, rawScale)) : 1;
      result.push(new ScpTextSpan(
        style,
        outputText,
        target,
        referenceId,
        span.b ?? (style === ScpTextStyle.STRONG),
        span.i ?? (style === ScpTextStyle.EMPHASIS),
        span.d ?? (style === ScpTextStyle.DELETED),
        span.ul ?? false,
        span.m ?? (style === ScpTextStyle.CODE),
        span.sup ?? false,
        span.sub ?? false,
        this.sanitizeHexColor(span.c),
        fontScale,
        this.mapHiddenKind(span.h)
      ));
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

  private findAcsClass(blocks: ScpContentBlock[]): string {
    for (let index: number = 0; index < blocks.length; index++) {
      const block = blocks[index];
      if (block.type === ScpBlockType.ACS_HEADER && block.acs !== undefined) {
        const containment = block.acs.containmentClass.trim();
        const secondary = block.acs.secondaryClass.trim();
        if ((containment === '机密' || containment.toLowerCase() === 'esoteric') && secondary.length > 0) {
          return secondary;
        }
        if (containment.length > 0) {
          return containment;
        }
      }
      const nested = this.findAcsClass(block.children);
      if (nested.length > 0) {
        return nested;
      }
    }
    return '';
  }

  private objectClassOf(blocks: ScpContentBlock[]): string {
    const acsClass = this.findAcsClass(blocks);
    if (acsClass.length > 0) {
      return acsClass;
    }
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

  private normalizeFootnoteRefLabel(raw: string): string {
    return raw.trim().replace(/^\[+|\]+$/g, '').trim();
  }

  private trimSpanEdges(spans: ScpTextSpan[]): ScpTextSpan[] {
    const nonEmpty: ScpTextSpan[] = [];
    for (let index: number = 0; index < spans.length; index++) {
      if (spans[index].text.length > 0) {
        nonEmpty.push(spans[index]);
      }
    }
    const result: ScpTextSpan[] = [];
    for (let index: number = 0; index < nonEmpty.length; index++) {
      const span = nonEmpty[index];
      let text = span.text;
      if (index === 0) {
        text = text.replace(/^\s+/, '');
      }
      if (index === nonEmpty.length - 1) {
        text = text.replace(/\s+$/, '');
      }
      if (text.length === 0) {
        continue;
      }
      result.push(this.cloneSpanWithText(span, text));
    }
    return result;
  }

  private isMeaningfulBlock(block: ScpContentBlock): boolean {
    if (block.type === ScpBlockType.DIVIDER) {
      return true;
    }
    if (block.type === ScpBlockType.ACS_HEADER && block.acs !== undefined) {
      return block.acs.itemNumber.trim().length > 0 || block.acs.containmentClass.trim().length > 0;
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
