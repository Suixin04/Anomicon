import { ScpExtractPayload } from './ScpDocumentMapper';
import { ScpArticleDocument } from '../domain/ScpDocument';
import {
  isNoiseArticleAnchor,
  normalizeArticleAnchor
} from '../domain/ArticleNavigation';

/**
 * A deliberately small, dependency-free HTML parser for the article surface.
 *
 * Wikidot article HTML is regular enough that parsing the response directly is
 * both faster and more predictable than creating an off-screen ArkWeb page.
 * This parser produces the same payload consumed by ScpDocumentMapper, so the
 * validation and Traditional -> Simplified projection remain in one place.
 */

class HtmlNode {
  readonly tag: string;
  readonly attrs: Map<string, string> = new Map<string, string>();
  readonly children: HtmlNode[] = [];
  text: string = '';

  constructor(tag: string) {
    this.tag = tag.toLowerCase();
  }
}

interface NativeSpan {
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

interface NativeAcsMetadata {
  itemNumber: string;
  clearanceLevel: string;
  containmentClass: string;
  secondaryClass: string;
  disruptionClass: string;
  riskClass: string;
  memoUrl: string;
}

interface NativeBlock {
  k: string;
  spans?: NativeSpan[];
  level?: number;
  title?: string;
  closeTitle?: string;
  expanded?: boolean;
  ordered?: boolean;
  isHeader?: boolean;
  tone?: string;
  preferredWidth?: number;
  acs?: NativeAcsMetadata;
  align?: string;
  blocks?: NativeBlock[];
  src?: string;
  caption?: string;
  anchors?: string[];
}

interface ParsedRgba {
  r: number;
  g: number;
  b: number;
  a: number;
}

interface ParsedFontSize {
  isZero: boolean;
  scale: number;
}

interface BlockStyleContext {
  textAlign: string;
  inDarkContainer: boolean;
}

interface InlineStyleContext {
  bold: boolean;
  italic: boolean;
  deleted: boolean;
  underline: boolean;
  monospace: boolean;
  isCodeTag: boolean;
  superscript: boolean;
  subscript: boolean;
  color: string;
  fontScale: number;
  hiddenKind: string;
  inDarkContainer: boolean;
  linkTarget: string;
}

interface NativeImage {
  src: string;
  caption: string;
}

interface NativeFootnote {
  id: string;
  index: number;
  blocks: NativeBlock[];
}

interface NativePayload {
  parserVersion: number;
  ok: boolean;
  error: string;
  title: string;
  rating: string;
  pageVersion: string;
  tags: string[];
  images: NativeImage[];
  blocks: NativeBlock[];
  footnotes: NativeFootnote[];
  warnings: string[];
  creditBlocks?: NativeBlock[];
}

const VOID_TAGS: string[] = [
  'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta',
  'param', 'source', 'track', 'wbr'
];

const INLINE_FLOW_TAGS: string[] = [
  'span', 'strong', 'b', 'em', 'i', 'del', 's', 'strike', 'code', 'tt', 'kbd',
  'samp', 'a', 'sup', 'sub', 'u', 'ins', 'br', 'ruby', 'small', 'big', 'font',
  'mark', 'abbr', 'cite', 'q', 'time'
];

const BLOCK_STRUCTURE_TAGS: string[] = [
  'div', 'p', 'blockquote', 'table', 'ul', 'ol', 'pre', 'hr', 'section',
  'article', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'footer', 'nav',
  'figure', 'figcaption', 'form', 'audio', 'video', 'canvas', 'svg',
  'object', 'math'
];

const AUTO_CLOSE_P_TAGS: string[] = [
  'div', 'p', 'blockquote', 'table', 'ul', 'ol', 'pre', 'hr', 'section',
  'article', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'footer', 'nav',
  'figure', 'figcaption', 'form'
];

const NOISE_CLASSES: string[] = [
  'info-container', 'page-options', 'page-tags', 'footnotes-footer',
  'footer-wikiwalk-nav', 'page-rate-widget-box', 'creditrate',
  'rate-box-with-credit-button', 'credit-back', 'fader'
];

// Wikidot injects these nodes into otherwise valid article content. They are
// presentation chrome, not document semantics, so they are filtered while
// traversing the parsed tree (including unquoted HTML attributes).
const NOISE_IDS: string[] = ['ads', 'adend'];

const CSS_NAMED_COLORS: Map<string, number[]> = new Map<string, number[]>([
  ['white', [255, 255, 255]],
  ['black', [0, 0, 0]],
  ['red', [220, 38, 38]],
  ['green', [22, 163, 74]],
  ['blue', [37, 99, 235]],
  ['orange', [234, 88, 12]],
  ['yellow', [202, 138, 4]],
  ['purple', [147, 51, 234]],
  ['gray', [107, 114, 128]],
  ['grey', [107, 114, 128]],
  ['silver', [192, 192, 192]],
  ['maroon', [128, 0, 0]],
  ['navy', [0, 0, 128]],
  ['teal', [0, 128, 128]],
  ['olive', [128, 128, 0]],
  ['lime', [0, 255, 0]],
  ['aqua', [0, 255, 255]],
  ['cyan', [0, 188, 212]],
  ['fuchsia', [255, 0, 255]],
  ['magenta', [219, 39, 119]],
  ['darkred', [139, 0, 0]],
  ['darkgreen', [0, 100, 0]],
  ['darkblue', [0, 0, 139]],
  ['crimson', [220, 20, 60]],
  ['firebrick', [178, 34, 34]],
  ['orangered', [255, 69, 0]],
  ['brown', [165, 42, 42]],
  ['gold', [212, 160, 23]],
  ['indigo', [75, 0, 130]],
  ['violet', [138, 43, 226]],
  ['pink', [236, 72, 153]],
  ['coral', [255, 127, 80]],
  ['salmon', [250, 128, 114]],
  ['chocolate', [210, 105, 30]],
  ['royalblue', [65, 105, 225]],
  ['steelblue', [70, 130, 180]],
  ['rebeccapurple', [102, 51, 153]],
  ['darkgray', [169, 169, 169]],
  ['darkgrey', [169, 169, 169]],
  ['lightgray', [211, 211, 211]],
  ['lightgrey', [211, 211, 211]],
  ['dimgray', [105, 105, 105]],
  ['dimgrey', [105, 105, 105]]
]);

export class ScpNativeHtmlParser {
  static parse(html: string): ScpExtractPayload {
    const out: NativePayload = {
      parserVersion: ScpArticleDocument.CURRENT_PARSER_VERSION,
      ok: false,
      error: '',
      title: '',
      rating: '',
      pageVersion: '',
      tags: [] as string[],
      images: [] as NativeImage[],
      blocks: [] as NativeBlock[],
      footnotes: [] as NativeFootnote[],
      warnings: [] as string[],
      creditBlocks: [] as NativeBlock[]
    };

    try {
      if (html.length === 0) {
        throw new Error('empty article html');
      }
      const root = ScpNativeHtmlParser.parseTree(html);
      const pageContent = ScpNativeHtmlParser.firstById(root, 'page-content');
      if (pageContent === undefined) {
        throw new Error('page-content node not found');
      }

      const titleNode = ScpNativeHtmlParser.firstById(root, 'page-title');
      out.title = titleNode === undefined ? '' : ScpNativeHtmlParser.textContent(titleNode).trim();
      const ratingNode = ScpNativeHtmlParser.firstByIdPrefix(root, 'prw');
      out.rating = ratingNode === undefined ? '' : ScpNativeHtmlParser.textContent(ratingNode).trim();
      const pageInfo = ScpNativeHtmlParser.firstById(root, 'page-info');
      out.pageVersion = pageInfo === undefined ? '' : ScpNativeHtmlParser.textContent(pageInfo).trim();

      const tagLinks = ScpNativeHtmlParser.byClass(root, 'page-tags');
      for (let index: number = 0; index < tagLinks.length; index++) {
        const links = ScpNativeHtmlParser.descendantsByTag(tagLinks[index], 'a');
        for (let linkIndex: number = 0; linkIndex < links.length; linkIndex++) {
          const tag = ScpNativeHtmlParser.textContent(links[linkIndex]).trim();
          if (tag.length > 0 && out.tags.indexOf(tag) < 0) {
            out.tags.push(tag);
          }
        }
      }

      const creditBlocks: NativeBlock[] = [];
      ScpNativeHtmlParser.walkBlocks(pageContent, out.blocks, out.images, out.warnings, creditBlocks);
      ScpNativeHtmlParser.detectComplexPageWarnings(root, pageContent, out.warnings);
      out.blocks = ScpNativeHtmlParser.coalesceWhisperParagraphs(out.blocks);
      out.creditBlocks = ScpNativeHtmlParser.coalesceWhisperParagraphs(creditBlocks);
      const footnotes = ScpNativeHtmlParser.byClass(pageContent, 'footnotes-footer');
      if (footnotes.length > 0) {
        const items = ScpNativeHtmlParser.byClass(footnotes[0], 'footnote-footer');
        for (let index: number = 0; index < items.length; index++) {
          const itemBlocks = ScpNativeHtmlParser.coalesceWhisperParagraphs(
            ScpNativeHtmlParser.parseFootnoteBlocks(
              items[index],
              out.images,
              out.warnings
            )
          );
          const itemId = ScpNativeHtmlParser.attr(items[index], 'id')
            .replace(/^footnote-/i, '');
          out.footnotes.push({ id: itemId, index: index + 1, blocks: itemBlocks });
        }
      }

      if (out.title.length === 0) {
        throw new Error('page-title is empty');
      }
      if (!ScpNativeHtmlParser.hasReadableBlocks(out.blocks) &&
        !ScpNativeHtmlParser.hasReadableImages(out.images)) {
        throw new Error('page-content contains no readable article body');
      }
      out.ok = true;
    } catch (error) {
      out.error = error instanceof Error ? error.message : 'native article parse failed';
    }
    return out as ScpExtractPayload;
  }

  private static parseTree(html: string): HtmlNode {
    const root = new HtmlNode('#root');
    const stack: HtmlNode[] = [root];
    let cursor: number = 0;
    while (cursor < html.length) {
      const open = html.indexOf('<', cursor);
      if (open < 0) {
        ScpNativeHtmlParser.addText(stack[stack.length - 1], html.substring(cursor));
        break;
      }
      if (open > cursor) {
        ScpNativeHtmlParser.addText(stack[stack.length - 1], html.substring(cursor, open));
      }
      if (html.substring(open, open + 4) === '<!--') {
        const commentEnd = html.indexOf('-->', open + 4);
        cursor = commentEnd < 0 ? html.length : commentEnd + 3;
        continue;
      }
      const end = ScpNativeHtmlParser.tagEnd(html, open + 1);
      if (end < 0) {
        ScpNativeHtmlParser.addText(stack[stack.length - 1], html.substring(open));
        break;
      }
      let token = html.substring(open + 1, end).trim();
      cursor = end + 1;
      if (token.length === 0 || token.charAt(0) === '!') {
        continue;
      }
      if (token.charAt(0) === '/') {
        const closeTag = token.substring(1).trim().split(/\s+/)[0].toLowerCase();
        for (let index: number = stack.length - 1; index > 0; index--) {
          if (stack[index].tag === closeTag) {
            stack.splice(index);
            break;
          }
        }
        continue;
      }
      const selfClosing = /\/\s*$/.test(token);
      token = token.replace(/\/\s*$/, '').trim();
      const nameMatch = /^([^\s/>]+)/.exec(token);
      if (nameMatch === null) {
        continue;
      }
      const node = new HtmlNode(nameMatch[1]);
      const rest = token.substring(nameMatch[0].length);
      const attrPattern: RegExp = /([^\s=/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g;
      let attrMatch: RegExpExecArray | null = attrPattern.exec(rest);
      while (attrMatch !== null) {
        const value = attrMatch[2] ?? attrMatch[3] ?? attrMatch[4] ?? '';
        node.attrs.set(attrMatch[1].toLowerCase(), ScpNativeHtmlParser.decode(value));
        attrMatch = attrPattern.exec(rest);
      }
      if (AUTO_CLOSE_P_TAGS.indexOf(node.tag) >= 0 && stack[stack.length - 1].tag === 'p') {
        stack.pop();
      }
      stack[stack.length - 1].children.push(node);
      if (!selfClosing && (node.tag === 'script' || node.tag === 'style')) {
        const closeRegex = new RegExp(`</${node.tag}\\s*>`, 'i');
        const tail = html.substring(cursor);
        const closeMatch = closeRegex.exec(tail);
        if (closeMatch === null) {
          ScpNativeHtmlParser.addText(node, tail);
          cursor = html.length;
        } else {
          ScpNativeHtmlParser.addText(node, tail.substring(0, closeMatch.index));
          cursor += closeMatch.index + closeMatch[0].length;
        }
        continue;
      }
      if (!selfClosing && VOID_TAGS.indexOf(node.tag) < 0) {
        stack.push(node);
      }
    }
    return root;
  }

  private static tagEnd(html: string, start: number): number {
    let quote: string = '';
    for (let index: number = start; index < html.length; index++) {
      const character = html.charAt(index);
      if (quote.length > 0) {
        if (character === quote) {
          quote = '';
        }
      } else if (character === '"' || character === "'") {
        quote = character;
      } else if (character === '>') {
        return index;
      }
    }
    return -1;
  }

  private static addText(parent: HtmlNode, raw: string): void {
    if (raw.length === 0) {
      return;
    }
    const text = new HtmlNode('#text');
    text.text = ScpNativeHtmlParser.decode(raw);
    parent.children.push(text);
  }

  private static decode(value: string): string {
    return value.replace(/&(?:nbsp;?|amp;|lt;|gt;|quot;|apos;|#x[\da-f]+;|#\d+;)/gi, (entity: string): string => {
      switch (entity.toLowerCase()) {
        case '&nbsp':
        case '&nbsp;': return ' ';
        case '&amp;': return '&';
        case '&lt;': return '<';
        case '&gt;': return '>';
        case '&quot;': return '"';
        case '&apos;': return "'";
      }
      const hex = entity.charAt(2).toLowerCase() === 'x';
      const scalar = Number.parseInt(entity.slice(hex ? 3 : 2, -1), hex ? 16 : 10);
      if (scalar === 0 || scalar > 0x10FFFF || (scalar >= 0xD800 && scalar <= 0xDFFF)) {
        return '\uFFFD';
      }
      return String.fromCodePoint(scalar);
    });
  }

  private static attr(node: HtmlNode, name: string): string {
    return node.attrs.get(name.toLowerCase()) ?? '';
  }

  private static classes(node: HtmlNode): string {
    return ` ${ScpNativeHtmlParser.attr(node, 'class').replace(/\s+/g, ' ').trim().toLowerCase()} `;
  }

  private static hasClass(node: HtmlNode, name: string): boolean {
    return ScpNativeHtmlParser.classes(node).indexOf(` ${name.toLowerCase()} `) >= 0;
  }

  private static hasNoiseId(node: HtmlNode): boolean {
    const id = ScpNativeHtmlParser.attr(node, 'id').trim().toLowerCase();
    return id.length > 0 && NOISE_IDS.indexOf(id) >= 0;
  }

  private static mergeAnchorsInto(target: string[], incoming: string[]): void {
    for (let index: number = 0; index < incoming.length && target.length < 16; index++) {
      const normalized = normalizeArticleAnchor(incoming[index]);
      if (normalized.length > 0 && !isNoiseArticleAnchor(normalized) &&
        target.indexOf(normalized) < 0) {
        target.push(normalized);
      }
    }
  }

  private static collectDirectNodeAnchors(node: HtmlNode): string[] {
    const collected: string[] = [];
    const idAttr = ScpNativeHtmlParser.attr(node, 'id');
    if (idAttr.length > 0) {
      ScpNativeHtmlParser.mergeAnchorsInto(collected, [idAttr]);
    }
    if (node.tag === 'a') {
      const nameAttr = ScpNativeHtmlParser.attr(node, 'name');
      if (nameAttr.length > 0) {
        ScpNativeHtmlParser.mergeAnchorsInto(collected, [nameAttr]);
      }
    }
    return collected;
  }

  private static collectInlineDescendantAnchors(node: HtmlNode, output: string[]): void {
    ScpNativeHtmlParser.mergeAnchorsInto(output, ScpNativeHtmlParser.collectDirectNodeAnchors(node));
    for (let index: number = 0; index < node.children.length; index++) {
      const child = node.children[index];
      if (child.tag === '#text' || BLOCK_STRUCTURE_TAGS.indexOf(child.tag) >= 0) {
        continue;
      }
      ScpNativeHtmlParser.collectInlineDescendantAnchors(child, output);
    }
  }

  private static attachAnchorsToBlock(block: NativeBlock, anchors: string[]): void {
    if (anchors.length === 0) {
      return;
    }
    const existing = block.anchors ?? [];
    const merged: string[] = existing.slice();
    ScpNativeHtmlParser.mergeAnchorsInto(merged, anchors);
    if (merged.length > 0) {
      block.anchors = merged;
    }
  }

  private static consumeAndAttachAnchors(
    block: NativeBlock,
    pendingAnchors: string[],
    extraAnchors: string[] = []
  ): void {
    if (pendingAnchors.length === 0 && extraAnchors.length === 0) {
      return;
    }
    const combined: string[] = [];
    ScpNativeHtmlParser.mergeAnchorsInto(combined, pendingAnchors);
    ScpNativeHtmlParser.mergeAnchorsInto(combined, extraAnchors);
    pendingAnchors.length = 0;
    ScpNativeHtmlParser.attachAnchorsToBlock(block, combined);
  }

  private static firstById(root: HtmlNode, id: string): HtmlNode | undefined {
    if (ScpNativeHtmlParser.attr(root, 'id') === id) {
      return root;
    }
    for (let index: number = 0; index < root.children.length; index++) {
      const found = ScpNativeHtmlParser.firstById(root.children[index], id);
      if (found !== undefined) {
        return found;
      }
    }
    return undefined;
  }

  private static firstByIdPrefix(root: HtmlNode, prefix: string): HtmlNode | undefined {
    if (ScpNativeHtmlParser.attr(root, 'id').toLowerCase().indexOf(prefix.toLowerCase()) === 0) {
      return root;
    }
    for (let index: number = 0; index < root.children.length; index++) {
      const found = ScpNativeHtmlParser.firstByIdPrefix(root.children[index], prefix);
      if (found !== undefined) {
        return found;
      }
    }
    return undefined;
  }

  private static byClass(root: HtmlNode, name: string): HtmlNode[] {
    const result: HtmlNode[] = [];
    if (ScpNativeHtmlParser.hasClass(root, name)) {
      result.push(root);
    }
    for (let index: number = 0; index < root.children.length; index++) {
      const nested = ScpNativeHtmlParser.byClass(root.children[index], name);
      for (let nestedIndex: number = 0; nestedIndex < nested.length; nestedIndex++) {
        result.push(nested[nestedIndex]);
      }
    }
    return result;
  }

  private static descendantsByTag(root: HtmlNode, tag: string): HtmlNode[] {
    const result: HtmlNode[] = [];
    for (let index: number = 0; index < root.children.length; index++) {
      const child = root.children[index];
      if (child.tag === tag.toLowerCase()) {
        result.push(child);
      }
      const nested = ScpNativeHtmlParser.descendantsByTag(child, tag);
      for (let nestedIndex: number = 0; nestedIndex < nested.length; nestedIndex++) {
        result.push(nested[nestedIndex]);
      }
    }
    return result;
  }

  private static isDisplayNone(node: HtmlNode): boolean {
    const style = ScpNativeHtmlParser.attr(node, 'style');
    if (style.length === 0) {
      return false;
    }
    const lower = style.toLowerCase();
    if (lower.indexOf('syntax error near') >= 0) {
      return true;
    }
    return /(?:^|;)\s*display\s*:\s*none\b/.test(lower);
  }

  private static isDecorativeAvatarImg(node: HtmlNode): boolean {
    const src = ScpNativeHtmlParser.imageSource(node).toLowerCase();
    if (src.length === 0) {
      return false;
    }
    if (/avatar\.php|userkarma\.php/i.test(src)) {
      return true;
    }
    return ScpNativeHtmlParser.hasClass(node, 'small') && src.indexOf('wikidot.com') >= 0;
  }

  private static cleanImageCaption(rawAlt: string, src: string = ''): string {
    const trimmed = rawAlt.trim();
    if (trimmed.length === 0) {
      return '';
    }
    if (/^[a-z0-9_\-. ]+\.(?:png|jpe?g|gif|webp|svg|bmp)$/i.test(trimmed)) {
      return '';
    }
    if (src.length > 0) {
      const pathOnly = src.split('#')[0].split('?')[0];
      const slashIndex = pathOnly.lastIndexOf('/');
      const tail = (slashIndex >= 0 ? pathOnly.substring(slashIndex + 1) : pathOnly).trim().toLowerCase();
      if (tail.length > 0 && trimmed.toLowerCase() === tail) {
        return '';
      }
    }
    return trimmed;
  }

  private static parseImagePreferredWidth(node: HtmlNode, parent?: HtmlNode): number {
    const check = (target: HtmlNode | undefined): number => {
      if (target === undefined) {
        return 0;
      }
      const style = ScpNativeHtmlParser.attr(target, 'style');
      const pxMatch = /(?:^|;|\s)width\s*:\s*(\d+(?:\.\d+)?)\s*px\b/i.exec(style);
      if (pxMatch !== null) {
        const px = Math.round(Number.parseFloat(pxMatch[1]));
        if (Number.isFinite(px) && px > 0) {
          return Math.max(24, Math.min(600, px));
        }
      }
      const widthAttr = ScpNativeHtmlParser.attr(target, 'width').trim();
      if (/^\d+(?:\.\d+)?(?:px)?$/i.test(widthAttr)) {
        const px = Math.round(Number.parseFloat(widthAttr));
        if (Number.isFinite(px) && px > 0) {
          return Math.max(24, Math.min(600, px));
        }
      }
      return 0;
    };
    const direct = check(node);
    if (direct > 0) {
      return direct;
    }
    if (parent !== undefined && parent.tag === 'div' &&
      ScpNativeHtmlParser.hasClass(parent, 'scp-image-block')) {
      return check(parent);
    }
    return 0;
  }

  private static isRubyNode(node: HtmlNode): boolean {
    return node.tag === 'ruby' || ScpNativeHtmlParser.hasClass(node, 'ruby');
  }

  private static childrenTextContent(node: HtmlNode): string {
    let result = '';
    for (let index: number = 0; index < node.children.length; index++) {
      result += ScpNativeHtmlParser.textContent(node.children[index]);
    }
    return result;
  }

  private static rubyText(node: HtmlNode): string {
    let base = '';
    const readings: string[] = [];
    for (let index: number = 0; index < node.children.length; index++) {
      const child = node.children[index];
      if (child.tag === 'rt' || ScpNativeHtmlParser.hasClass(child, 'rt')) {
        const reading = ScpNativeHtmlParser.childrenTextContent(child).trim();
        if (reading.length > 0) {
          readings.push(reading);
        }
      } else if (child.tag !== 'rp' && !ScpNativeHtmlParser.hasClass(child, 'rp')) {
        base += ScpNativeHtmlParser.textContent(child);
      }
    }
    return readings.length === 0 ? base : `${base}（${readings.join(' / ')}）`;
  }

  private static containsBlockDescendant(node: HtmlNode): boolean {
    for (let index: number = 0; index < node.children.length; index++) {
      const child = node.children[index];
      if (BLOCK_STRUCTURE_TAGS.indexOf(child.tag) >= 0) {
        return true;
      }
      if (ScpNativeHtmlParser.containsBlockDescendant(child)) {
        return true;
      }
    }
    return false;
  }

  private static isInlineFlowNode(node: HtmlNode): boolean {
    if (node.tag === '#text') {
      return true;
    }
    if (INLINE_FLOW_TAGS.indexOf(node.tag) < 0) {
      return false;
    }
    if (ScpNativeHtmlParser.hasNoiseId(node) || ScpNativeHtmlParser.isDisplayNone(node)) {
      return false;
    }
    return !ScpNativeHtmlParser.containsBlockDescendant(node);
  }

  private static directChildByClass(node: HtmlNode, className: string): HtmlNode | undefined {
    for (let index: number = 0; index < node.children.length; index++) {
      if (ScpNativeHtmlParser.hasClass(node.children[index], className)) {
        return node.children[index];
      }
    }
    return undefined;
  }

  private static hasDirectImgContent(node: HtmlNode): boolean {
    for (let index: number = 0; index < node.children.length; index++) {
      const child = node.children[index];
      if (child.tag === 'img' && !ScpNativeHtmlParser.isDecorativeAvatarImg(child) &&
        ScpNativeHtmlParser.imageSource(child).length > 0) {
        return true;
      }
      if ((child.tag === 'a' || child.tag === 'span') && ScpNativeHtmlParser.hasDirectImgContent(child)) {
        return true;
      }
    }
    return false;
  }

  private static hasDirectEmbedIframe(node: HtmlNode): boolean {
    for (let index: number = 0; index < node.children.length; index++) {
      const child = node.children[index];
      if (child.tag === 'iframe') {
        return true;
      }
      if ((child.tag === 'a' || child.tag === 'span') && ScpNativeHtmlParser.hasDirectEmbedIframe(child)) {
        return true;
      }
    }
    return false;
  }

  private static textContent(node: HtmlNode): string {
    if (node.tag === '#text') {
      return node.text;
    }
    if (node.tag === 'img' || node.tag === 'rp' || node.tag === 'rt' ||
      node.tag === 'style' || node.tag === 'script' || node.tag === 'noscript' ||
      node.tag === 'head' || node.tag === 'meta' || node.tag === 'link' || node.tag === 'title') {
      return '';
    }
    if (ScpNativeHtmlParser.hasNoiseId(node) || ScpNativeHtmlParser.hasClass(node, 'lang-tr') ||
      ScpNativeHtmlParser.hasClass(node, 'rp') || ScpNativeHtmlParser.hasClass(node, 'rt') ||
      ScpNativeHtmlParser.isDisplayNone(node)) {
      return '';
    }
    if (ScpNativeHtmlParser.isRubyNode(node)) {
      return ScpNativeHtmlParser.rubyText(node);
    }
    let result = '';
    for (let index: number = 0; index < node.children.length; index++) {
      result += ScpNativeHtmlParser.textContent(node.children[index]);
    }
    return result;
  }

  private static rawTextContent(node: HtmlNode): string {
    if (node.tag === '#text') {
      return node.text;
    }
    if (node.tag === 'br') {
      return '\n';
    }
    if (node.tag === 'style' || node.tag === 'script' || node.tag === 'noscript' ||
      ScpNativeHtmlParser.hasNoiseId(node) || ScpNativeHtmlParser.hasClass(node, 'lang-tr') ||
      ScpNativeHtmlParser.isDisplayNone(node)) {
      return '';
    }
    let result = '';
    for (let index: number = 0; index < node.children.length; index++) {
      result += ScpNativeHtmlParser.rawTextContent(node.children[index]);
    }
    return result;
  }

  private static warning(warnings: string[], code: string): void {
    if (warnings.indexOf(code) < 0) {
      warnings.push(code);
    }
  }

  private static imageSource(node: HtmlNode): string {
    return ScpNativeHtmlParser.attr(node, 'src') ||
      ScpNativeHtmlParser.attr(node, 'data-src') ||
      ScpNativeHtmlParser.attr(node, 'data-original');
  }

  private static recordImage(images: NativeImage[], node: HtmlNode, caption: string): string {
    const src = ScpNativeHtmlParser.imageSource(node);
    if (src.length === 0) {
      return '';
    }
    const alt = caption.trim();
    for (let index: number = 0; index < images.length; index++) {
      if (images[index].src === src) {
        if (images[index].caption.length === 0 && alt.length > 0) {
          images[index].caption = alt;
        }
        return src;
      }
    }
    images.push({ src: src, caption: alt });
    return src;
  }

  private static emptyBlockContext(): BlockStyleContext {
    return { textAlign: '', inDarkContainer: false };
  }

  private static defaultInlineContext(
    inDarkContainer: boolean = false,
    inheritedStyle: string = 'plain'
  ): InlineStyleContext {
    return {
      bold: inheritedStyle === 'strong',
      italic: inheritedStyle === 'em',
      deleted: inheritedStyle === 'del',
      underline: false,
      monospace: inheritedStyle === 'code',
      isCodeTag: inheritedStyle === 'code',
      superscript: false,
      subscript: false,
      color: '',
      fontScale: 1,
      hiddenKind: '',
      inDarkContainer: inDarkContainer,
      linkTarget: ''
    };
  }

  private static cloneInlineContext(ctx: InlineStyleContext): InlineStyleContext {
    return {
      bold: ctx.bold,
      italic: ctx.italic,
      deleted: ctx.deleted,
      underline: ctx.underline,
      monospace: ctx.monospace,
      isCodeTag: ctx.isCodeTag,
      superscript: ctx.superscript,
      subscript: ctx.subscript,
      color: ctx.color,
      fontScale: ctx.fontScale,
      hiddenKind: ctx.hiddenKind,
      inDarkContainer: ctx.inDarkContainer,
      linkTarget: ctx.linkTarget
    };
  }

  private static parseInlineCss(style: string): Map<string, string> {
    const result: Map<string, string> = new Map<string, string>();
    if (style.trim().length === 0) {
      return result;
    }
    const parts = style.split(';');
    for (let index: number = 0; index < parts.length; index++) {
      const part = parts[index];
      const colon = part.indexOf(':');
      if (colon <= 0) {
        continue;
      }
      const key = part.substring(0, colon).trim().toLowerCase();
      const val = part.substring(colon + 1).replace(/!important\b/gi, '').trim().toLowerCase();
      if (key.length > 0 && val.length > 0) {
        result.set(key, val);
      }
    }
    return result;
  }

  private static parseCssColor(raw: string): ParsedRgba | undefined {
    const val = raw.trim().toLowerCase();
    if (val.length === 0) {
      return undefined;
    }
    if (val === 'transparent') {
      return { r: 0, g: 0, b: 0, a: 0 };
    }
    const named = CSS_NAMED_COLORS.get(val);
    if (named !== undefined) {
      return { r: named[0], g: named[1], b: named[2], a: 1 };
    }
    const hex3 = /^#([0-9a-f]{3})$/i.exec(val);
    if (hex3 !== null) {
      const h = hex3[1];
      return {
        r: Number.parseInt(h.charAt(0) + h.charAt(0), 16),
        g: Number.parseInt(h.charAt(1) + h.charAt(1), 16),
        b: Number.parseInt(h.charAt(2) + h.charAt(2), 16),
        a: 1
      };
    }
    const hex4 = /^#([0-9a-f]{4})$/i.exec(val);
    if (hex4 !== null) {
      const h = hex4[1];
      return {
        r: Number.parseInt(h.charAt(0) + h.charAt(0), 16),
        g: Number.parseInt(h.charAt(1) + h.charAt(1), 16),
        b: Number.parseInt(h.charAt(2) + h.charAt(2), 16),
        a: Number.parseInt(h.charAt(3) + h.charAt(3), 16) / 255
      };
    }
    const hex6 = /^#([0-9a-f]{6})$/i.exec(val);
    if (hex6 !== null) {
      const h = hex6[1];
      return {
        r: Number.parseInt(h.substring(0, 2), 16),
        g: Number.parseInt(h.substring(2, 4), 16),
        b: Number.parseInt(h.substring(4, 6), 16),
        a: 1
      };
    }
    const hex8 = /^#([0-9a-f]{8})$/i.exec(val);
    if (hex8 !== null) {
      const h = hex8[1];
      return {
        r: Number.parseInt(h.substring(0, 2), 16),
        g: Number.parseInt(h.substring(2, 4), 16),
        b: Number.parseInt(h.substring(4, 6), 16),
        a: Number.parseInt(h.substring(6, 8), 16) / 255
      };
    }
    const rgbMatch = /^rgba?\(\s*([^)]+)\s*\)$/i.exec(val);
    if (rgbMatch !== null) {
      const parts = rgbMatch[1].replace(/\//g, ',').split(/[,\s]+/);
      const nums: number[] = [];
      for (let index: number = 0; index < parts.length; index++) {
        if (parts[index].length > 0) {
          nums.push(Number.parseFloat(parts[index]));
        }
      }
      if (nums.length >= 3 && Number.isFinite(nums[0]) && Number.isFinite(nums[1]) &&
        Number.isFinite(nums[2])) {
        const a = nums.length >= 4 && Number.isFinite(nums[3]) ? nums[3] : 1;
        return {
          r: Math.max(0, Math.min(255, Math.round(nums[0]))),
          g: Math.max(0, Math.min(255, Math.round(nums[1]))),
          b: Math.max(0, Math.min(255, Math.round(nums[2]))),
          a: Math.max(0, Math.min(1, a))
        };
      }
    }
    return undefined;
  }

  private static extractBackgroundColor(css: Map<string, string>): ParsedRgba | undefined {
    const bgColor = css.get('background-color');
    if (bgColor !== undefined) {
      const parsed = ScpNativeHtmlParser.parseCssColor(bgColor);
      if (parsed !== undefined) {
        return parsed;
      }
    }
    const bg = css.get('background');
    if (bg === undefined) {
      return undefined;
    }
    const direct = ScpNativeHtmlParser.parseCssColor(bg);
    if (direct !== undefined) {
      return direct;
    }
    const stripped = bg.replace(/url\([^)]*\)/gi, ' ');
    const rgbMatch = /rgba?\([^)]+\)/i.exec(stripped);
    if (rgbMatch !== null) {
      const parsed = ScpNativeHtmlParser.parseCssColor(rgbMatch[0]);
      if (parsed !== undefined) {
        return parsed;
      }
    }
    const tokens = stripped.split(/\s+/);
    for (let index: number = 0; index < tokens.length; index++) {
      const token = tokens[index].trim();
      if (token.length === 0 || token === 'none' || token === 'inherit' ||
        token === 'initial' || token === 'transparent') {
        continue;
      }
      const parsed = ScpNativeHtmlParser.parseCssColor(token);
      if (parsed !== undefined) {
        return parsed;
      }
    }
    return undefined;
  }

  private static relativeLuminance(c: ParsedRgba): number {
    return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) / 255;
  }

  private static isNearWhiteOrTransparent(c: ParsedRgba): boolean {
    if (c.a < 0.08) {
      return true;
    }
    return c.a > 0 && ScpNativeHtmlParser.relativeLuminance(c) >= 0.90;
  }

  private static isNearBlack(c: ParsedRgba): boolean {
    return c.a >= 0.85 && ScpNativeHtmlParser.relativeLuminance(c) <= 0.12;
  }

  private static isNeutralInk(c: ParsedRgba): boolean {
    if (c.a < 0.85 || ScpNativeHtmlParser.relativeLuminance(c) > 0.22) {
      return false;
    }
    const spread = Math.max(c.r, c.g, c.b) - Math.min(c.r, c.g, c.b);
    return spread <= 18;
  }

  private static toHexRgb(c: ParsedRgba): string {
    const hex = (n: number): string => {
      const clamped = Math.max(0, Math.min(255, Math.round(n)));
      const s = clamped.toString(16).toUpperCase();
      return s.length < 2 ? `0${s}` : s;
    };
    return `#${hex(c.r)}${hex(c.g)}${hex(c.b)}`;
  }

  private static parseCssFontSize(raw: string): ParsedFontSize {
    const val = raw.trim().toLowerCase();
    if (val.length === 0) {
      return { isZero: false, scale: 1 };
    }
    if (/^0+(?:\.0+)?(?:px|%|em|rem|pt|ex|ch)?$/i.test(val)) {
      return { isZero: true, scale: 1 };
    }
    const pctMatch = /^(\d+(?:\.\d+)?)%$/i.exec(val);
    if (pctMatch !== null) {
      const pct = Number.parseFloat(pctMatch[1]);
      if (Number.isFinite(pct) && pct <= 5) {
        return { isZero: true, scale: 1 };
      }
      if (Number.isFinite(pct)) {
        return { isZero: false, scale: Math.max(0.72, Math.min(1.80, pct / 100)) };
      }
    }
    const emMatch = /^(\d+(?:\.\d+)?)(?:em|rem)$/i.exec(val);
    if (emMatch !== null) {
      const em = Number.parseFloat(emMatch[1]);
      if (Number.isFinite(em) && em <= 0.05) {
        return { isZero: true, scale: 1 };
      }
      if (Number.isFinite(em)) {
        return { isZero: false, scale: Math.max(0.72, Math.min(1.80, em)) };
      }
    }
    const pxMatch = /^(\d+(?:\.\d+)?)px$/i.exec(val);
    if (pxMatch !== null) {
      const px = Number.parseFloat(pxMatch[1]);
      if (Number.isFinite(px) && px <= 0.5) {
        return { isZero: true, scale: 1 };
      }
      if (Number.isFinite(px)) {
        return { isZero: false, scale: Math.max(0.72, Math.min(1.80, px / 14)) };
      }
    }
    switch (val) {
      case 'xx-small':
        return { isZero: false, scale: 0.72 };
      case 'x-small':
        return { isZero: false, scale: 0.78 };
      case 'small':
      case 'smaller':
        return { isZero: false, scale: 0.88 };
      case 'medium':
        return { isZero: false, scale: 1.0 };
      case 'large':
      case 'larger':
        return { isZero: false, scale: 1.18 };
      case 'x-large':
        return { isZero: false, scale: 1.35 };
      case 'xx-large':
        return { isZero: false, scale: 1.55 };
      default:
        return { isZero: false, scale: 1 };
    }
  }

  private static extractTextAlign(node: HtmlNode, inherited: string): string {
    if (node.tag === 'center' || ScpNativeHtmlParser.hasClass(node, 'aligncenter')) {
      return 'center';
    }
    if (ScpNativeHtmlParser.hasClass(node, 'alignright')) {
      return 'end';
    }
    if (ScpNativeHtmlParser.hasClass(node, 'alignleft')) {
      return 'start';
    }
    const style = ScpNativeHtmlParser.attr(node, 'style');
    if (style.length > 0) {
      const css = ScpNativeHtmlParser.parseInlineCss(style);
      const align = css.get('text-align') ?? '';
      if (align === 'center') {
        return 'center';
      }
      if (align === 'right' || align === 'end') {
        return 'end';
      }
      if (align === 'left' || align === 'start') {
        return 'start';
      }
      if (align === 'justify') {
        return 'justify';
      }
    }
    const alignAttr = ScpNativeHtmlParser.attr(node, 'align').trim().toLowerCase();
    if (alignAttr === 'center') {
      return 'center';
    }
    if (alignAttr === 'right') {
      return 'end';
    }
    if (alignAttr === 'left') {
      return 'start';
    }
    return inherited;
  }

  private static hasDarkBackground(node: HtmlNode): boolean {
    if (ScpNativeHtmlParser.hasClass(node, 'terminal')) {
      return true;
    }
    const style = ScpNativeHtmlParser.attr(node, 'style');
    if (style.length === 0) {
      return false;
    }
    const css = ScpNativeHtmlParser.parseInlineCss(style);
    const bg = ScpNativeHtmlParser.extractBackgroundColor(css);
    return bg !== undefined && bg.a >= 0.6 && ScpNativeHtmlParser.relativeLuminance(bg) <= 0.25;
  }

  private static deriveBlockContext(node: HtmlNode, parent: BlockStyleContext): BlockStyleContext {
    const nextAlign = ScpNativeHtmlParser.extractTextAlign(node, parent.textAlign);
    const nextDark = parent.inDarkContainer || ScpNativeHtmlParser.hasDarkBackground(node);
    return {
      textAlign: nextAlign,
      inDarkContainer: nextDark
    };
  }

  private static primarySpanStyle(ctx: InlineStyleContext): string {
    if (ctx.linkTarget.length > 0) {
      return 'link';
    }
    if (ctx.isCodeTag) {
      return 'code';
    }
    if (ctx.bold) {
      return 'strong';
    }
    if (ctx.italic) {
      return 'em';
    }
    if (ctx.deleted) {
      return 'del';
    }
    return 'plain';
  }

  private static inlineSpans(
    node: HtmlNode,
    images: NativeImage[],
    warnings: string[],
    inherited: string | InlineStyleContext = 'plain',
    skipLists: boolean = false
  ): NativeSpan[] {
    const result: NativeSpan[] = [];
    const baseCtx = typeof inherited === 'string' ?
      ScpNativeHtmlParser.defaultInlineContext(false, inherited) :
      inherited;

    const appendSpan = (
      text: string,
      ctx: InlineStyleContext,
      overrideStyle: string = '',
      reference: string = ''
    ): void => {
      if (text.length === 0) {
        return;
      }
      const style = overrideStyle.length > 0 ? overrideStyle : ScpNativeHtmlParser.primarySpanStyle(ctx);
      const span: NativeSpan = {
        s: style,
        t: text,
        u: style === 'link' ? ctx.linkTarget : '',
        r: reference
      };
      if (ctx.bold) {
        span.b = true;
      }
      if (ctx.italic) {
        span.i = true;
      }
      if (ctx.deleted) {
        span.d = true;
      }
      if (ctx.underline) {
        span.ul = true;
      }
      if (ctx.monospace) {
        span.m = true;
      }
      if (ctx.superscript) {
        span.sup = true;
      }
      if (ctx.subscript) {
        span.sub = true;
      }
      if (ctx.color.length > 0) {
        span.c = ctx.color;
      }
      if (Math.abs(ctx.fontScale - 1) > 0.02) {
        span.fs = Math.round(ctx.fontScale * 100) / 100;
      }
      if (ctx.hiddenKind.length > 0) {
        span.h = ctx.hiddenKind;
      }
      result.push(span);
    };

    const trailingNewlineCount = (): number => {
      let count: number = 0;
      for (let index: number = result.length - 1; index >= 0; index--) {
        const t = result[index].t;
        if (t === '\n') {
          count++;
        } else if (t === ' ') {
          continue;
        } else {
          break;
        }
      }
      return count;
    };

    const applyNodeStyles = (current: HtmlNode, parentCtx: InlineStyleContext): InlineStyleContext => {
      const next = ScpNativeHtmlParser.cloneInlineContext(parentCtx);
      const tag = current.tag;
      if (tag === 'strong' || tag === 'b') {
        next.bold = true;
      } else if (tag === 'em' || tag === 'i') {
        next.italic = true;
      } else if (tag === 'del' || tag === 's' || tag === 'strike') {
        next.deleted = true;
      } else if (tag === 'u' || tag === 'ins') {
        next.underline = true;
      } else if (tag === 'code') {
        next.isCodeTag = true;
        next.monospace = true;
      } else if (tag === 'tt' || tag === 'kbd' || tag === 'samp') {
        next.monospace = true;
      } else if (tag === 'sup') {
        next.superscript = true;
      } else if (tag === 'sub') {
        next.subscript = true;
      } else if (tag === 'small') {
        next.fontScale = Math.max(0.72, next.fontScale * 0.85);
      } else if (tag === 'big') {
        next.fontScale = Math.min(1.80, next.fontScale * 1.18);
      } else if (tag === 'font') {
        const fontColorAttr = ScpNativeHtmlParser.attr(current, 'color');
        if (fontColorAttr.length > 0) {
          const parsed = ScpNativeHtmlParser.parseCssColor(fontColorAttr);
          if (parsed !== undefined) {
            if (!next.inDarkContainer && ScpNativeHtmlParser.isNearWhiteOrTransparent(parsed)) {
              next.hiddenKind = 'white_easter_egg';
              next.color = '';
            } else if (!next.inDarkContainer && ScpNativeHtmlParser.isNeutralInk(parsed)) {
              next.color = '';
            } else {
              next.color = ScpNativeHtmlParser.toHexRgb(parsed);
            }
          }
        }
      }

      if (ScpNativeHtmlParser.hasClass(current, 'blackbox') ||
        ScpNativeHtmlParser.hasClass(current, 'dblock')) {
        next.hiddenKind = 'blackbox';
        next.color = '';
      }

      const styleAttr = ScpNativeHtmlParser.attr(current, 'style');
      if (styleAttr.length === 0) {
        return next;
      }
      const css = ScpNativeHtmlParser.parseInlineCss(styleAttr);

      const fontWeight = css.get('font-weight');
      if (fontWeight !== undefined) {
        const numeric = Number.parseInt(fontWeight, 10);
        if (fontWeight === 'bold' || fontWeight === 'bolder' ||
          (Number.isFinite(numeric) && numeric >= 600)) {
          next.bold = true;
        } else if (fontWeight === 'normal' || fontWeight === 'lighter' ||
          (Number.isFinite(numeric) && numeric <= 500)) {
          next.bold = false;
        }
      }

      const fontStyle = css.get('font-style');
      if (fontStyle !== undefined) {
        if (fontStyle === 'italic' || fontStyle === 'oblique') {
          next.italic = true;
        } else if (fontStyle === 'normal') {
          next.italic = false;
        }
      }

      const textDeco = css.get('text-decoration') ?? css.get('text-decoration-line');
      if (textDeco !== undefined) {
        if (textDeco.indexOf('none') >= 0) {
          next.deleted = false;
          next.underline = false;
        }
        if (textDeco.indexOf('line-through') >= 0) {
          next.deleted = true;
        }
        if (textDeco.indexOf('underline') >= 0) {
          next.underline = true;
        }
      }

      const fontFamily = css.get('font-family');
      if (fontFamily !== undefined &&
        (fontFamily.indexOf('monospace') >= 0 || fontFamily.indexOf('courier') >= 0 ||
          fontFamily.indexOf('consolas') >= 0 || fontFamily.indexOf('menlo') >= 0 ||
          fontFamily.indexOf('monaco') >= 0)) {
        next.monospace = true;
      }

      const fontSizeRaw = css.get('font-size');
      let fontSizeIsZero = false;
      if (fontSizeRaw !== undefined) {
        const parsedSize = ScpNativeHtmlParser.parseCssFontSize(fontSizeRaw);
        if (parsedSize.isZero) {
          fontSizeIsZero = true;
        } else {
          next.fontScale = parsedSize.scale;
        }
      }

      const opacityRaw = css.get('opacity');
      const opacityVal = opacityRaw !== undefined ? Number.parseFloat(opacityRaw) : 1;
      const isZeroOpacity = opacityRaw !== undefined && Number.isFinite(opacityVal) && opacityVal <= 0.05;

      const bgRgba = ScpNativeHtmlParser.extractBackgroundColor(css);
      const colorRaw = css.get('color');
      const fgRgba = colorRaw !== undefined ? ScpNativeHtmlParser.parseCssColor(colorRaw) : undefined;
      const bgIsDark = bgRgba !== undefined && ScpNativeHtmlParser.isNearBlack(bgRgba);

      if (fontSizeIsZero) {
        next.hiddenKind = 'zero_size_whisper';
      } else if (next.hiddenKind === 'blackbox' ||
        (bgIsDark && (fgRgba === undefined || ScpNativeHtmlParser.isNearBlack(fgRgba) || fgRgba.a < 0.08))) {
        next.hiddenKind = 'blackbox';
        next.color = '';
      } else {
        if (bgIsDark) {
          next.inDarkContainer = true;
        }
        if (!next.inDarkContainer &&
          (isZeroOpacity || (fgRgba !== undefined && ScpNativeHtmlParser.isNearWhiteOrTransparent(fgRgba)))) {
          next.hiddenKind = 'white_easter_egg';
          next.color = '';
        } else if (fgRgba !== undefined) {
          if (!next.inDarkContainer && ScpNativeHtmlParser.isNeutralInk(fgRgba)) {
            next.color = '';
          } else {
            next.color = ScpNativeHtmlParser.toHexRgb(fgRgba);
            if (next.hiddenKind === 'white_easter_egg' &&
              !ScpNativeHtmlParser.isNearWhiteOrTransparent(fgRgba)) {
              next.hiddenKind = '';
            }
          }
        }
      }
      return next;
    };

    const walk = (current: HtmlNode, ctx: InlineStyleContext): void => {
      if (current.tag === '#text') {
        const text = current.text.replace(/\r\n?/g, '\n').replace(/[ \t\n]+/g, ' ');
        const trimmed = text.trim();
        if (trimmed.length > 0) {
          if (ctx.hiddenKind === 'white_easter_egg' && trimmed.length <= 3 &&
            /^[.．。…_—\-·]+$/.test(trimmed)) {
            return;
          }
          appendSpan(text, ctx);
        } else if (result.length > 0 && !result[result.length - 1].t.endsWith('\n')) {
          appendSpan(' ', ctx);
        }
        return;
      }
      if (current.tag === 'style' || current.tag === 'script' || current.tag === 'noscript' ||
        current.tag === 'head' || current.tag === 'meta' || current.tag === 'link' ||
        current.tag === 'title') {
        return;
      }
      if (ScpNativeHtmlParser.hasNoiseId(current) || ScpNativeHtmlParser.isDisplayNone(current)) {
        return;
      }
      if (current.tag === 'br') {
        if (trailingNewlineCount() < 2) {
          appendSpan('\n', ctx);
        }
        return;
      }
      if (skipLists && (current.tag === 'ul' || current.tag === 'ol')) {
        return;
      }
      if (current.tag === 'img') {
        if (ScpNativeHtmlParser.isDecorativeAvatarImg(current)) {
          return;
        }
        const alt = (ScpNativeHtmlParser.attr(current, 'alt') ||
          ScpNativeHtmlParser.attr(current, 'title')).trim();
        const caption = ScpNativeHtmlParser.cleanImageCaption(alt, ScpNativeHtmlParser.imageSource(current));
        const src = ScpNativeHtmlParser.recordImage(images, current, caption);
        const label = caption.length > 0 ? `[图片：${caption}]` : '[图片]';
        const target = ctx.linkTarget.length > 0 ? ctx.linkTarget : src;
        if (target.length > 0) {
          const imgCtx = ScpNativeHtmlParser.cloneInlineContext(ctx);
          imgCtx.linkTarget = target;
          appendSpan(label, imgCtx, 'link');
        } else {
          appendSpan(label, ctx);
        }
        ScpNativeHtmlParser.warning(warnings, 'degraded:inline-image-placement');
        return;
      }
      const nextCtx = applyNodeStyles(current, ctx);
      if (ScpNativeHtmlParser.isRubyNode(current)) {
        const ruby = ScpNativeHtmlParser.rubyText(current);
        if (ruby.trim().length > 0) {
          appendSpan(ruby, nextCtx);
        }
        ScpNativeHtmlParser.warning(warnings, 'degraded:ruby-annotation');
        return;
      }
      const currentClass = ScpNativeHtmlParser.classes(current);
      // Original CN articles often render Simplified/Traditional labels in
      // parallel `.lang-cn`/`.lang-tr` spans. The website's CSS hides one
      // branch; native extraction has no CSS cascade, so keep the Simplified
      // branch and drop the Traditional duplicate at the HTML boundary.
      if (currentClass.indexOf(' lang-tr ') >= 0) {
        return;
      }
      for (let classIndex: number = 0; classIndex < NOISE_CLASSES.length; classIndex++) {
        if (currentClass.indexOf(` ${NOISE_CLASSES[classIndex]} `) >= 0) {
          return;
        }
      }
      if (current.tag === 'sup' && currentClass.indexOf(' footnoteref ') >= 0) {
        const link = ScpNativeHtmlParser.descendantsByTag(current, 'a');
        const footnote = link.length > 0 ? link[0] : current;
        const id = ScpNativeHtmlParser.attr(footnote, 'id').replace(/^footnoteref-/i, '');
        const label = ScpNativeHtmlParser.normalizeFootnoteRefLabel(
          ScpNativeHtmlParser.textContent(footnote)
        );
        appendSpan(label, ctx, 'footnote', id);
        return;
      }
      if (current.tag === 'a') {
        if (currentClass.indexOf(' footnoteref ') >= 0) {
          const id = ScpNativeHtmlParser.attr(current, 'id').replace(/^footnoteref-/i, '');
          const label = ScpNativeHtmlParser.normalizeFootnoteRefLabel(
            ScpNativeHtmlParser.textContent(current)
          );
          appendSpan(label, ctx, 'footnote', id);
          return;
        }
        const href = ScpNativeHtmlParser.attr(current, 'href').trim();
        if (href.length > 0 && href !== 'javascript:;') {
          nextCtx.linkTarget = href;
        }
        for (let index: number = 0; index < current.children.length; index++) {
          walk(current.children[index], nextCtx);
        }
        return;
      }
      for (let index: number = 0; index < current.children.length; index++) {
        walk(current.children[index], nextCtx);
      }
    };
    walk(node, baseCtx);
    return ScpNativeHtmlParser.trimSpans(result);
  }

  private static trimSpans(spans: NativeSpan[]): NativeSpan[] {
    const result: NativeSpan[] = [];
    for (let index: number = 0; index < spans.length; index++) {
      const span = spans[index];
      let text = span.t;
      if (index === 0) {
        text = text.replace(/^\s+/, '');
      }
      if (index === spans.length - 1) {
        text = text.replace(/\s+$/, '');
      }
      if (text.length > 0) {
        const copy: NativeSpan = { s: span.s, t: text, u: span.u, r: span.r };
        if (span.b) {
          copy.b = true;
        }
        if (span.i) {
          copy.i = true;
        }
        if (span.d) {
          copy.d = true;
        }
        if (span.ul) {
          copy.ul = true;
        }
        if (span.m) {
          copy.m = true;
        }
        if (span.sup) {
          copy.sup = true;
        }
        if (span.sub) {
          copy.sub = true;
        }
        if (span.c !== undefined && span.c.length > 0) {
          copy.c = span.c;
        }
        if (span.fs !== undefined && Math.abs(span.fs - 1) > 0.02) {
          copy.fs = span.fs;
        }
        if (span.h !== undefined && span.h.length > 0) {
          copy.h = span.h;
        }
        result.push(copy);
      }
    }
    return result;
  }

  private static directChildrenByTag(node: HtmlNode, tag: string): HtmlNode[] {
    const result: HtmlNode[] = [];
    for (let index: number = 0; index < node.children.length; index++) {
      if (node.children[index].tag === tag) {
        result.push(node.children[index]);
      }
    }
    return result;
  }

  private static directListItems(node: HtmlNode): HtmlNode[] {
    return ScpNativeHtmlParser.directChildrenByTag(node, 'li');
  }

  private static walkList(
    node: HtmlNode,
    blocks: NativeBlock[],
    images: NativeImage[],
    warnings: string[],
    depth: number,
    creditBlocks?: NativeBlock[],
    context: BlockStyleContext = ScpNativeHtmlParser.emptyBlockContext()
  ): void {
    const listCtx = ScpNativeHtmlParser.deriveBlockContext(node, context);
    const ordered = node.tag === 'ol';
    const items = ScpNativeHtmlParser.directListItems(node);
    const listItems: NativeBlock[] = [];
    for (let index: number = 0; index < items.length; index++) {
      const li = items[index];
      const liCtx = ScpNativeHtmlParser.deriveBlockContext(li, listCtx);
      const spans = ScpNativeHtmlParser.inlineSpans(
        li,
        images,
        warnings,
        ScpNativeHtmlParser.defaultInlineContext(liCtx.inDarkContainer),
        true
      );
      const nestedBlocks: NativeBlock[] = [];
      for (let childIndex: number = 0; childIndex < li.children.length; childIndex++) {
        const liChild = li.children[childIndex];
        if (liChild.tag === 'ul' || liChild.tag === 'ol') {
          ScpNativeHtmlParser.walkList(
            liChild,
            nestedBlocks,
            images,
            warnings,
            depth + 1,
            creditBlocks,
            liCtx
          );
        }
      }
      if (spans.length > 0 || nestedBlocks.length > 0) {
        const itemAnchors: string[] = [];
        ScpNativeHtmlParser.collectInlineDescendantAnchors(li, itemAnchors);
        const itemBlock: NativeBlock = {
          k: 'list_item',
          level: depth,
          spans: spans,
          blocks: nestedBlocks
        };
        if (liCtx.textAlign.length > 0) {
          itemBlock.align = liCtx.textAlign;
        }
        ScpNativeHtmlParser.attachAnchorsToBlock(itemBlock, itemAnchors);
        listItems.push(itemBlock);
      }
    }
    if (listItems.length > 0) {
      blocks.push({
        k: 'list',
        ordered: ordered,
        level: depth,
        blocks: listItems
      });
    }
  }

  private static unsupportedFallback(
    node: HtmlNode,
    blocks: NativeBlock[],
    images: NativeImage[],
    warnings: string[],
    context: BlockStyleContext = ScpNativeHtmlParser.emptyBlockContext()
  ): void {
    const labels = new Map<string, string>([
      ['audio', '音频'], ['video', '视频'], ['canvas', '画布'], ['svg', '矢量图'],
      ['object', '外部对象'], ['math', '数学公式']
    ]);
    const spans = ScpNativeHtmlParser.inlineSpans(
      node,
      images,
      warnings,
      ScpNativeHtmlParser.defaultInlineContext(context.inDarkContainer)
    );
    if (spans.length === 0) {
      const source = ScpNativeHtmlParser.attr(node, 'src') || ScpNativeHtmlParser.attr(node, 'data');
      spans.push({
        s: source.length > 0 ? 'link' : 'plain',
        u: source,
        t: `[暂不支持的${labels.get(node.tag) ?? '内容'}]`
      });
    }
    const block: NativeBlock = { k: 'paragraph', spans: spans };
    if (context.textAlign.length > 0) {
      block.align = context.textAlign;
    }
    blocks.push(block);
    ScpNativeHtmlParser.warning(warnings, `unsupported:${node.tag}`);
  }

  private static normalizeFootnoteRefLabel(raw: string): string {
    return raw.trim().replace(/^\[+|\]+$/g, '').trim();
  }

  private static isFootnoteBacklink(node: HtmlNode): boolean {
    if (node.tag !== 'a') {
      return false;
    }
    const onclick = ScpNativeHtmlParser.attr(node, 'onclick').toLowerCase();
    if (onclick.indexOf('scrolltoreference') >= 0) {
      return true;
    }
    const href = ScpNativeHtmlParser.attr(node, 'href').trim().toLowerCase();
    const label = ScpNativeHtmlParser.textContent(node).trim();
    return href === 'javascript:;' && /^\[?\d+\]?\.?$/.test(label);
  }

  private static isFootnoteBlockTag(tag: string): boolean {
    if (/^h[1-6]$/.test(tag)) {
      return true;
    }
    return tag === 'p' || tag === 'div' || tag === 'section' || tag === 'article' ||
      tag === 'blockquote' || tag === 'ul' || tag === 'ol' || tag === 'table' ||
      tag === 'pre' || tag === 'hr' || tag === 'iframe' || tag === 'audio' ||
      tag === 'video' || tag === 'canvas' || tag === 'svg' || tag === 'object' ||
      tag === 'math';
  }

  /**
   * Parse one `.footnote-footer` container while stripping Wikidot's leading
   * backlink anchor and keeping inline siblings in a single paragraph block.
   */
  private static parseFootnoteBlocks(
    item: HtmlNode,
    images: NativeImage[],
    warnings: string[]
  ): NativeBlock[] {
    const blocks: NativeBlock[] = [];
    let inlineNodes: HtmlNode[] = [];
    let seenContent = false;
    let strippedBacklink = false;

    const flushInline = (): void => {
      if (inlineNodes.length === 0) {
        return;
      }
      const wrapper = new HtmlNode('span');
      for (let index: number = 0; index < inlineNodes.length; index++) {
        wrapper.children.push(inlineNodes[index]);
      }
      const spans = ScpNativeHtmlParser.inlineSpans(wrapper, images, warnings);
      if (spans.length > 0) {
        blocks.push({ k: 'paragraph', spans: spans });
      }
      inlineNodes = [];
    };

    for (let index: number = 0; index < item.children.length; index++) {
      const child = item.children[index];
      if (!seenContent && child.tag === '#text') {
        if (child.text.trim().length === 0) {
          continue;
        }
        let text = child.text;
        if (strippedBacklink) {
          text = text.replace(/^\s*[.．、:]\s*/, '');
          strippedBacklink = false;
          if (text.trim().length === 0) {
            continue;
          }
        }
        const cleaned = new HtmlNode('#text');
        cleaned.text = text;
        seenContent = true;
        inlineNodes.push(cleaned);
        continue;
      }
      if (!seenContent && ScpNativeHtmlParser.isFootnoteBacklink(child)) {
        strippedBacklink = true;
        continue;
      }
      if (!seenContent && child.tag === 'br') {
        continue;
      }
      if (ScpNativeHtmlParser.isFootnoteBlockTag(child.tag)) {
        flushInline();
        strippedBacklink = false;
        seenContent = true;
        ScpNativeHtmlParser.walkBlockChild(child, blocks, images, warnings);
        continue;
      }
      strippedBacklink = false;
      if (child.tag !== '#text' || child.text.trim().length > 0 || seenContent) {
        if (child.tag === 'img' || child.tag === 'br' ||
          ScpNativeHtmlParser.textContent(child).trim().length > 0) {
          seenContent = true;
        }
        inlineNodes.push(child);
      }
    }
    flushInline();
    return blocks;
  }

  private static walkBlocks(
    node: HtmlNode,
    blocks: NativeBlock[],
    images: NativeImage[],
    warnings: string[],
    creditBlocks?: NativeBlock[],
    context: BlockStyleContext = ScpNativeHtmlParser.emptyBlockContext(),
    pendingAnchors: string[] = []
  ): void {
    const nodeCtx = ScpNativeHtmlParser.deriveBlockContext(node, context);
    let inlineBuffer: HtmlNode[] = [];
    const flushInline = (): void => {
      if (inlineBuffer.length === 0) {
        return;
      }
      const wrapper = new HtmlNode('p');
      const inlineAnchors: string[] = [];
      for (let index: number = 0; index < inlineBuffer.length; index++) {
        wrapper.children.push(inlineBuffer[index]);
        ScpNativeHtmlParser.collectInlineDescendantAnchors(inlineBuffer[index], inlineAnchors);
      }
      inlineBuffer = [];
      const beforeLen = blocks.length;
      ScpNativeHtmlParser.walkParagraphNode(wrapper, blocks, images, warnings, nodeCtx);
      if (blocks.length > beforeLen) {
        ScpNativeHtmlParser.consumeAndAttachAnchors(blocks[beforeLen], pendingAnchors, inlineAnchors);
      } else {
        ScpNativeHtmlParser.mergeAnchorsInto(pendingAnchors, inlineAnchors);
      }
    };

    for (let index: number = 0; index < node.children.length; index++) {
      const child = node.children[index];
      if (ScpNativeHtmlParser.isInlineFlowNode(child)) {
        inlineBuffer.push(child);
        continue;
      }
      flushInline();
      ScpNativeHtmlParser.walkBlockChild(
        child,
        blocks,
        images,
        warnings,
        creditBlocks,
        nodeCtx,
        pendingAnchors
      );
    }
    flushInline();
  }

  private static emitImageBlock(
    imgNode: HtmlNode,
    caption: string,
    preferredWidth: number,
    blocks: NativeBlock[],
    images: NativeImage[]
  ): void {
    if (ScpNativeHtmlParser.isDecorativeAvatarImg(imgNode)) {
      return;
    }
    const cleanCaption = caption.trim();
    const src = ScpNativeHtmlParser.recordImage(images, imgNode, cleanCaption);
    if (src.length === 0) {
      return;
    }
    blocks.push({
      k: 'image',
      src: src,
      caption: cleanCaption,
      preferredWidth: preferredWidth
    });
  }

  private static walkParagraphNode(
    pNode: HtmlNode,
    blocks: NativeBlock[],
    images: NativeImage[],
    warnings: string[],
    context: BlockStyleContext = ScpNativeHtmlParser.emptyBlockContext()
  ): void {
    const pCtx = ScpNativeHtmlParser.deriveBlockContext(pNode, context);
    const baseInline = ScpNativeHtmlParser.defaultInlineContext(pCtx.inDarkContainer);
    const emitParagraph = (spans: NativeSpan[]): void => {
      if (spans.length === 0) {
        return;
      }
      const block: NativeBlock = { k: 'paragraph', spans: spans };
      if (pCtx.textAlign.length > 0) {
        block.align = pCtx.textAlign;
      }
      blocks.push(block);
    };
    if (!ScpNativeHtmlParser.hasDirectImgContent(pNode) &&
      !ScpNativeHtmlParser.hasDirectEmbedIframe(pNode)) {
      emitParagraph(ScpNativeHtmlParser.inlineSpans(pNode, images, warnings, baseInline));
      return;
    }
    let pendingNodes: HtmlNode[] = [];
    const flushPending = (): void => {
      if (pendingNodes.length === 0) {
        return;
      }
      const wrapper = new HtmlNode('span');
      for (let index: number = 0; index < pendingNodes.length; index++) {
        wrapper.children.push(pendingNodes[index]);
      }
      pendingNodes = [];
      emitParagraph(ScpNativeHtmlParser.inlineSpans(wrapper, images, warnings, baseInline));
    };

    const visitInlineChild = (child: HtmlNode): void => {
      if (child.tag === 'iframe') {
        flushPending();
        ScpNativeHtmlParser.walkBlockChild(child, blocks, images, warnings, undefined, pCtx);
        return;
      }
      if (child.tag === 'img') {
        if (ScpNativeHtmlParser.isDecorativeAvatarImg(child)) {
          return;
        }
        flushPending();
        const alt = (ScpNativeHtmlParser.attr(child, 'alt') ||
          ScpNativeHtmlParser.attr(child, 'title')).trim();
        ScpNativeHtmlParser.emitImageBlock(
          child,
          ScpNativeHtmlParser.cleanImageCaption(alt, ScpNativeHtmlParser.imageSource(child)),
          ScpNativeHtmlParser.parseImagePreferredWidth(child),
          blocks,
          images
        );
        return;
      }
      if ((child.tag === 'a' || child.tag === 'span') &&
        (ScpNativeHtmlParser.hasDirectImgContent(child) || ScpNativeHtmlParser.hasDirectEmbedIframe(child))) {
        for (let index: number = 0; index < child.children.length; index++) {
          visitInlineChild(child.children[index]);
        }
        return;
      }
      pendingNodes.push(child);
    };

    for (let index: number = 0; index < pNode.children.length; index++) {
      visitInlineChild(pNode.children[index]);
    }
    flushPending();
  }

  private static collectTableRows(tableNode: HtmlNode): HtmlNode[] {
    const rows: HtmlNode[] = [];
    for (let index: number = 0; index < tableNode.children.length; index++) {
      const child = tableNode.children[index];
      if (child.tag === 'tr') {
        rows.push(child);
      } else if (child.tag === 'thead' || child.tag === 'tbody' || child.tag === 'tfoot') {
        for (let rowIndex: number = 0; rowIndex < child.children.length; rowIndex++) {
          if (child.children[rowIndex].tag === 'tr') {
            rows.push(child.children[rowIndex]);
          }
        }
      }
    }
    return rows;
  }

  private static parseAcsHeader(node: HtmlNode): NativeBlock | undefined {
    const cleanField = (raw: string): string => {
      const normalized = raw.replace(/\s+/g, ' ').trim();
      const lower = normalized.toLowerCase();
      if (normalized.length === 0 || lower === 'none' || lower === 'n/a' || /^\{\$[^}]+\}$/.test(normalized)) {
        return '';
      }
      return normalized;
    };

    const classTokens = ScpNativeHtmlParser.attr(node, 'class').trim().split(/\s+/);
    let itemNumber: string = '';
    let clearanceLevel: string = '';
    for (let index: number = 0; index < classTokens.length; index++) {
      const token = classTokens[index];
      if (/^item-/i.test(token) && itemNumber.length === 0) {
        itemNumber = cleanField(token.substring(5));
      } else if (/^clear-(\d+)$/i.test(token) && clearanceLevel.length === 0) {
        clearanceLevel = token.substring(6);
      }
    }

    const numberNodes = ScpNativeHtmlParser.byClass(node, 'number');
    if (numberNodes.length > 0) {
      const found = cleanField(ScpNativeHtmlParser.textContent(numberNodes[0]));
      if (found.length > 0) {
        itemNumber = found;
      }
    }
    const levelNodes = ScpNativeHtmlParser.byClass(node, 'level');
    if (levelNodes.length > 0) {
      const levelText = ScpNativeHtmlParser.textContent(levelNodes[0]);
      const digitMatch = /(\d+)/.exec(levelText);
      if (digitMatch !== null) {
        clearanceLevel = digitMatch[1];
      }
    }

    const classTextIn = (containerClass: string): string => {
      const containers = ScpNativeHtmlParser.byClass(node, containerClass);
      if (containers.length === 0) {
        return '';
      }
      const textNodes = ScpNativeHtmlParser.byClass(containers[0], 'class-text');
      if (textNodes.length > 0) {
        return cleanField(ScpNativeHtmlParser.textContent(textNodes[0]));
      }
      return cleanField(ScpNativeHtmlParser.textContent(containers[0]));
    };

    const containmentClass = classTextIn('contain-class');
    const secondaryClass = classTextIn('second-class');
    const disruptionClass = classTextIn('disrupt-class');
    const riskClass = classTextIn('risk-class');

    let memoUrl: string = '';
    const diamonds = ScpNativeHtmlParser.byClass(node, 'danger-diamond');
    if (diamonds.length > 0) {
      const links = ScpNativeHtmlParser.descendantsByTag(diamonds[0], 'a');
      if (links.length > 0) {
        memoUrl = ScpNativeHtmlParser.attr(links[0], 'href').trim();
      }
    }

    if (itemNumber.length === 0 && containmentClass.length === 0) {
      return undefined;
    }

    return {
      k: 'acs_header',
      acs: {
        itemNumber: itemNumber,
        clearanceLevel: clearanceLevel,
        containmentClass: containmentClass,
        secondaryClass: secondaryClass,
        disruptionClass: disruptionClass,
        riskClass: riskClass,
        memoUrl: memoUrl
      }
    };
  }

  private static parseTabsBlock(
    node: HtmlNode,
    images: NativeImage[],
    warnings: string[],
    creditBlocks?: NativeBlock[],
    context: BlockStyleContext = ScpNativeHtmlParser.emptyBlockContext()
  ): NativeBlock | undefined {
    const tabsCtx = ScpNativeHtmlParser.deriveBlockContext(node, context);
    const nav = ScpNativeHtmlParser.directChildByClass(node, 'yui-nav');
    const content = ScpNativeHtmlParser.directChildByClass(node, 'yui-content');
    if (nav === undefined || content === undefined) {
      return undefined;
    }
    const navItems = ScpNativeHtmlParser.directChildrenByTag(nav, 'li');
    const panelDivs = ScpNativeHtmlParser.directChildrenByTag(content, 'div');
    const count = Math.min(navItems.length, panelDivs.length);
    const panels: NativeBlock[] = [];
    for (let index: number = 0; index < count; index++) {
      const title = ScpNativeHtmlParser.textContent(navItems[index]).replace(/\s+/g, ' ').trim();
      const panelBlocks: NativeBlock[] = [];
      const panelPending: string[] = [];
      ScpNativeHtmlParser.walkBlocks(
        panelDivs[index],
        panelBlocks,
        images,
        warnings,
        creditBlocks,
        tabsCtx,
        panelPending
      );
      if (panelBlocks.length > 0 && panelPending.length > 0) {
        ScpNativeHtmlParser.consumeAndAttachAnchors(
          panelBlocks[panelBlocks.length - 1],
          panelPending
        );
      }
      if (panelBlocks.length > 0) {
        const panelBlock: NativeBlock = {
          k: 'tab_panel',
          title: title.length > 0 ? title : `标签 ${index + 1}`,
          blocks: panelBlocks
        };
        ScpNativeHtmlParser.attachAnchorsToBlock(
          panelBlock,
          ScpNativeHtmlParser.collectDirectNodeAnchors(panelDivs[index])
        );
        panels.push(panelBlock);
      }
    }
    if (panels.length === 0) {
      return undefined;
    }
    return {
      k: 'tabs',
      blocks: panels
    };
  }

  private static parseColmodBlock(
    node: HtmlNode,
    images: NativeImage[],
    warnings: string[],
    creditBlocks?: NativeBlock[],
    context: BlockStyleContext = ScpNativeHtmlParser.emptyBlockContext()
  ): NativeBlock | undefined {
    const colCtx = ScpNativeHtmlParser.deriveBlockContext(node, context);
    const uls = ScpNativeHtmlParser.directChildrenByTag(node, 'ul');
    let targetLi: HtmlNode | undefined = undefined;
    let unfolded: boolean = false;
    for (let ulIndex: number = 0; ulIndex < uls.length && targetLi === undefined; ulIndex++) {
      const lis = ScpNativeHtmlParser.directChildrenByTag(uls[ulIndex], 'li');
      for (let liIndex: number = 0; liIndex < lis.length; liIndex++) {
        const li = lis[liIndex];
        if (ScpNativeHtmlParser.hasClass(li, 'folded') || ScpNativeHtmlParser.hasClass(li, 'unfolded')) {
          targetLi = li;
          unfolded = ScpNativeHtmlParser.hasClass(li, 'unfolded');
          break;
        }
      }
    }
    if (targetLi === undefined) {
      return undefined;
    }
    const linkTop = ScpNativeHtmlParser.directChildByClass(targetLi, 'colmod-link-top') ??
      ScpNativeHtmlParser.directChildByClass(targetLi, 'foldable-list-container');
    let openTitle: string = '';
    let closeTitle: string = '';
    if (linkTop !== undefined) {
      const links = ScpNativeHtmlParser.descendantsByTag(linkTop, 'a');
      if (links.length > 0) {
        openTitle = ScpNativeHtmlParser.textContent(links[0]).trim();
      }
      if (links.length > 1) {
        closeTitle = ScpNativeHtmlParser.textContent(links[1]).trim();
        if (/^-?\s*hide\s+block$/i.test(closeTitle)) {
          closeTitle = '';
        }
      }
    }
    const contentDiv = ScpNativeHtmlParser.directChildByClass(targetLi, 'colmod-content');
    const inner: NativeBlock[] = [];
    const innerPending: string[] = [];
    if (contentDiv !== undefined) {
      ScpNativeHtmlParser.walkBlocks(
        contentDiv,
        inner,
        images,
        warnings,
        creditBlocks,
        colCtx,
        innerPending
      );
      if (inner.length > 0 && innerPending.length > 0) {
        ScpNativeHtmlParser.consumeAndAttachAnchors(inner[inner.length - 1], innerPending);
      }
    }
    if (inner.length === 0) {
      return undefined;
    }
    const block: NativeBlock = {
      k: 'collapsible',
      title: openTitle,
      closeTitle: closeTitle,
      expanded: unfolded,
      blocks: inner
    };
    ScpNativeHtmlParser.attachAnchorsToBlock(block, innerPending);
    return block;
  }

  private static extractCreditBlocks(
    node: HtmlNode,
    warnings: string[],
    creditBlocks: NativeBlock[]
  ): void {
    const creditNodes = ScpNativeHtmlParser.byClass(node, 'credit');
    const contentTargets = creditNodes.length > 0 ? creditNodes :
      (ScpNativeHtmlParser.byClass(node, 'collapsible-block-content').length > 0 ?
        ScpNativeHtmlParser.byClass(node, 'collapsible-block-content') : [node]);
    const creditImages: NativeImage[] = [];
    const parsed: NativeBlock[] = [];
    for (let index: number = 0; index < contentTargets.length; index++) {
      ScpNativeHtmlParser.walkBlocks(contentTargets[index], parsed, creditImages, warnings);
    }
    for (let index: number = 0; index < parsed.length; index++) {
      const block = parsed[index];
      if (block.k === 'heading' || block.k === 'paragraph') {
        const text = (block.spans ?? []).map((span: NativeSpan): string => span.t).join('').trim();
        if (text === '著作信息' || text === '作者信息') {
          continue;
        }
      }
      creditBlocks.push(block);
    }
  }

  private static parseAdultWarningModal(node: HtmlNode): NativeBlock {
    const labels: string[] = [];
    const spans = ScpNativeHtmlParser.descendantsByTag(node, 'span');
    for (let index: number = 0; index < spans.length; index++) {
      const span = spans[index];
      const style = ScpNativeHtmlParser.attr(span, 'style').toLowerCase();
      if (!/(?:^|;)\s*display\s*:\s*block\b/.test(style)) {
        continue;
      }
      const raw = ScpNativeHtmlParser.textContent(span).replace(/\s+/g, ' ').trim();
      if (raw.length === 0 || raw.indexOf('{$') >= 0) {
        continue;
      }
      const colonIndex = raw.search(/[：:]/);
      const label = (colonIndex > 0 ? raw.substring(0, colonIndex) : raw).trim();
      if (label.length > 0 && labels.indexOf(label) < 0) {
        labels.push(label);
      }
    }
    const detail = labels.length > 0 ?
      `本文含以下敏感/成人内容提示：${labels.join('、')}。` :
      '本文章包含成人内容，可能并不适合所有读者阅读。';
    return {
      k: 'callout',
      tone: 'warning',
      blocks: [{
        k: 'paragraph',
        spans: [
          { s: 'strong', t: '成人内容提示：' },
          { s: 'plain', t: detail }
        ]
      }]
    };
  }

  private static detectCalloutTone(node: HtmlNode): string {
    const cls = ScpNativeHtmlParser.classes(node);
    const style = ScpNativeHtmlParser.attr(node, 'style').toLowerCase();
    const hasClassCue = cls.indexOf(' content-panel ') >= 0 || cls.indexOf(' terminal ') >= 0 ||
      cls.indexOf(' email ') >= 0 || cls.indexOf(' paper ') >= 0 ||
      cls.indexOf(' warning ') >= 0 || cls.indexOf(' yui-box ') >= 0;
    const hasVisibleBorder = /\bborder\s*:/.test(style) &&
      !/\bborder\s*:\s*(?:none|0(?:px)?)\s*(?:;|$)/.test(style);
    const hasVisibleBg = /\bbackground(?:-color)?\s*:/.test(style) &&
      !/\bbackground(?:-color)?\s*:\s*(?:none|transparent|inherit)\b/.test(style);
    if (!hasClassCue && !hasVisibleBorder && !hasVisibleBg) {
      return '';
    }
    if (cls.indexOf(' terminal ') >= 0 ||
      /\bbackground(?:-color)?\s*:\s*(?:black|#000(?:000)?|#111|#1a|#222|rgb\(\s*0\s*,\s*0\s*,\s*0\s*\))/.test(style)) {
      return 'terminal';
    }
    if (cls.indexOf(' warning ') >= 0 ||
      /(?:#ff2929|#b01|#901|#d9383a|red\b)/.test(style)) {
      return 'warning';
    }
    if (cls.indexOf(' email ') >= 0 || cls.indexOf(' paper ') >= 0 ||
      /\bdashed\b/.test(style) ||
      /(?:#f5f5f5|#f4f4f4|#f9e79f|#fdf6d7)/.test(style)) {
      return 'note';
    }
    return 'neutral';
  }

  private static walkBlockChild(
    child: HtmlNode,
    blocks: NativeBlock[],
    images: NativeImage[],
    warnings: string[],
    creditBlocks?: NativeBlock[],
    context: BlockStyleContext = ScpNativeHtmlParser.emptyBlockContext(),
    pendingAnchors: string[] = []
  ): void {
      if (child.tag === '#text') {
        if (child.text.trim().length > 0) {
          const textBlock: NativeBlock = { k: 'paragraph', spans: [{ s: 'plain', t: child.text }] };
          if (context.textAlign.length > 0) {
            textBlock.align = context.textAlign;
          }
          ScpNativeHtmlParser.consumeAndAttachAnchors(textBlock, pendingAnchors);
          blocks.push(textBlock);
        }
        return;
      }
      if (ScpNativeHtmlParser.hasNoiseId(child)) {
        return;
      }
      const idLower = ScpNativeHtmlParser.attr(child, 'id').trim().toLowerCase();
      if (idLower === 'u-credit-view' || idLower === 'u-credit-otherwise') {
        if (creditBlocks !== undefined) {
          ScpNativeHtmlParser.extractCreditBlocks(child, warnings, creditBlocks);
        }
        return;
      }
      const classNames = ScpNativeHtmlParser.classes(child);
      if (classNames.indexOf(' modalcontainer ') >= 0 || classNames.indexOf(' modalbox ') >= 0 ||
        classNames.indexOf(' licensebox ') >= 0) {
        if (creditBlocks !== undefined) {
          ScpNativeHtmlParser.extractCreditBlocks(child, warnings, creditBlocks);
        }
        return;
      }
      let skipped = false;
      for (let classIndex: number = 0; classIndex < NOISE_CLASSES.length; classIndex++) {
        if (classNames.indexOf(` ${NOISE_CLASSES[classIndex]} `) >= 0) {
          skipped = true;
          break;
        }
      }
      if (skipped || child.tag === 'style' || child.tag === 'script' || child.tag === 'noscript' ||
        child.tag === 'head' || child.tag === 'meta' || child.tag === 'link' ||
        child.tag === 'title') {
        return;
      }
      const ownDirectAnchors = ScpNativeHtmlParser.collectDirectNodeAnchors(child);
      if (classNames.indexOf(' modal-wrapper ') >= 0 || idLower === 'u-adult-warning') {
        const warningBlock = ScpNativeHtmlParser.parseAdultWarningModal(child);
        ScpNativeHtmlParser.consumeAndAttachAnchors(warningBlock, pendingAnchors, ownDirectAnchors);
        blocks.push(warningBlock);
        return;
      }
      const childCtx = ScpNativeHtmlParser.deriveBlockContext(child, context);
      if (classNames.indexOf(' list-pages-box ') >= 0) {
        ScpNativeHtmlParser.mergeAnchorsInto(pendingAnchors, ownDirectAnchors);
        ScpNativeHtmlParser.walkBlocks(
          child,
          blocks,
          images,
          warnings,
          creditBlocks,
          childCtx,
          pendingAnchors
        );
        ScpNativeHtmlParser.warning(warnings, 'compat:list-pages-box-content');
        return;
      }
      // Match Wikidot interactive foldables & tabviews BEFORE `display: none`
      // filtering, because folded panels and inactive tabs intentionally carry
      // `style="display:none"` in initial HTML.
      if (child.tag === 'div' && classNames.indexOf(' collapsible-block ') >= 0) {
        const foldedDiv = ScpNativeHtmlParser.directChildByClass(child, 'collapsible-block-folded');
        const unfoldedDiv = ScpNativeHtmlParser.directChildByClass(child, 'collapsible-block-unfolded');
        const initiallyExpanded = foldedDiv !== undefined &&
          ScpNativeHtmlParser.isDisplayNone(foldedDiv) &&
          unfoldedDiv !== undefined &&
          !ScpNativeHtmlParser.isDisplayNone(unfoldedDiv);
        const openLinks = foldedDiv !== undefined ?
          ScpNativeHtmlParser.byClass(foldedDiv, 'collapsible-block-link') :
          ScpNativeHtmlParser.byClass(child, 'collapsible-block-link');
        const closeLinkWrap = unfoldedDiv !== undefined ?
          ScpNativeHtmlParser.directChildByClass(unfoldedDiv, 'collapsible-block-unfolded-link') :
          undefined;
        const closeLinks = closeLinkWrap !== undefined ?
          ScpNativeHtmlParser.byClass(closeLinkWrap, 'collapsible-block-link') :
          [];
        const contentNode = unfoldedDiv !== undefined ?
          (ScpNativeHtmlParser.directChildByClass(unfoldedDiv, 'collapsible-block-content') ?? unfoldedDiv) :
          ScpNativeHtmlParser.directChildByClass(child, 'collapsible-block-content');
        const inner: NativeBlock[] = [];
        const innerPending: string[] = [];
        if (contentNode !== undefined) {
          const innerCtx = ScpNativeHtmlParser.deriveBlockContext(contentNode, childCtx);
          if (contentNode === unfoldedDiv) {
            const filtered = new HtmlNode(contentNode.tag);
            contentNode.attrs.forEach((value: string, key: string): void => {
              filtered.attrs.set(key, value);
            });
            for (let i: number = 0; i < contentNode.children.length; i++) {
              const sub = contentNode.children[i];
              if (!ScpNativeHtmlParser.hasClass(sub, 'collapsible-block-unfolded-link')) {
                filtered.children.push(sub);
              }
            }
            ScpNativeHtmlParser.walkBlocks(
              filtered,
              inner,
              images,
              warnings,
              creditBlocks,
              innerCtx,
              innerPending
            );
          } else {
            ScpNativeHtmlParser.walkBlocks(
              contentNode,
              inner,
              images,
              warnings,
              creditBlocks,
              innerCtx,
              innerPending
            );
          }
          if (inner.length > 0 && innerPending.length > 0) {
            ScpNativeHtmlParser.consumeAndAttachAnchors(inner[inner.length - 1], innerPending);
          }
        }
        const collapsibleBlock: NativeBlock = {
          k: 'collapsible',
          title: openLinks.length > 0 ? ScpNativeHtmlParser.textContent(openLinks[0]).trim() : '',
          closeTitle: closeLinks.length > 0 ? ScpNativeHtmlParser.textContent(closeLinks[0]).trim() : '',
          expanded: initiallyExpanded,
          blocks: inner
        };
        ScpNativeHtmlParser.consumeAndAttachAnchors(collapsibleBlock, pendingAnchors, ownDirectAnchors);
        ScpNativeHtmlParser.attachAnchorsToBlock(collapsibleBlock, innerPending);
        blocks.push(collapsibleBlock);
        return;
      }
      if (child.tag === 'div' && classNames.indexOf(' colmod-block ') >= 0) {
        const colmodBlock = ScpNativeHtmlParser.parseColmodBlock(child, images, warnings, creditBlocks, childCtx);
        if (colmodBlock !== undefined) {
          ScpNativeHtmlParser.consumeAndAttachAnchors(colmodBlock, pendingAnchors, ownDirectAnchors);
          blocks.push(colmodBlock);
          return;
        }
      }
      if (child.tag === 'div' && classNames.indexOf(' yui-navset ') >= 0) {
        const tabsBlock = ScpNativeHtmlParser.parseTabsBlock(child, images, warnings, creditBlocks, childCtx);
        if (tabsBlock !== undefined) {
          ScpNativeHtmlParser.consumeAndAttachAnchors(tabsBlock, pendingAnchors, ownDirectAnchors);
          blocks.push(tabsBlock);
          return;
        }
      }
      if (ScpNativeHtmlParser.isDisplayNone(child)) {
        return;
      }
      if (child.tag === 'div' && classNames.indexOf(' anom-bar-container ') >= 0 &&
        (ScpNativeHtmlParser.byClass(child, 'anom-bar').length > 0 ||
          ScpNativeHtmlParser.byClass(child, 'contain-class').length > 0)) {
        const acsBlock = ScpNativeHtmlParser.parseAcsHeader(child);
        if (acsBlock !== undefined) {
          ScpNativeHtmlParser.consumeAndAttachAnchors(acsBlock, pendingAnchors, ownDirectAnchors);
          blocks.push(acsBlock);
          return;
        }
      }
      if (ScpNativeHtmlParser.attr(child, 'data-interactive') === 'true') {
        ScpNativeHtmlParser.warning(warnings, 'interactive:html-block-iframe');
      }
      if (child.tag === 'ul' || child.tag === 'ol') {
        const beforeLen = blocks.length;
        ScpNativeHtmlParser.walkList(child, blocks, images, warnings, 0, creditBlocks, childCtx);
        if (blocks.length > beforeLen) {
          ScpNativeHtmlParser.consumeAndAttachAnchors(blocks[beforeLen], pendingAnchors, ownDirectAnchors);
        } else {
          ScpNativeHtmlParser.mergeAnchorsInto(pendingAnchors, ownDirectAnchors);
        }
      } else if (child.tag === 'pre') {
        const preAnchors: string[] = [];
        ScpNativeHtmlParser.collectInlineDescendantAnchors(child, preAnchors);
        const code = ScpNativeHtmlParser.rawTextContent(child).replace(/^\n+|\n+$/g, '');
        if (code.length > 0) {
          const codeBlock: NativeBlock = { k: 'code_block', spans: [{ s: 'code', t: code, m: true }] };
          ScpNativeHtmlParser.consumeAndAttachAnchors(codeBlock, pendingAnchors, preAnchors);
          blocks.push(codeBlock);
        } else {
          ScpNativeHtmlParser.mergeAnchorsInto(pendingAnchors, preAnchors);
        }
      } else if (child.tag === 'p') {
        const pAnchors: string[] = [];
        ScpNativeHtmlParser.collectInlineDescendantAnchors(child, pAnchors);
        const beforeLen = blocks.length;
        ScpNativeHtmlParser.walkParagraphNode(child, blocks, images, warnings, childCtx);
        if (blocks.length > beforeLen) {
          ScpNativeHtmlParser.consumeAndAttachAnchors(blocks[beforeLen], pendingAnchors, pAnchors);
        } else {
          ScpNativeHtmlParser.mergeAnchorsInto(pendingAnchors, pAnchors);
        }
      } else if (/^h[1-6]$/.test(child.tag)) {
        const hAnchors: string[] = [];
        ScpNativeHtmlParser.collectInlineDescendantAnchors(child, hAnchors);
        const heading: NativeBlock = {
          k: 'heading',
          level: Number.parseInt(child.tag.charAt(1), 10),
          spans: ScpNativeHtmlParser.inlineSpans(
            child,
            images,
            warnings,
            ScpNativeHtmlParser.defaultInlineContext(childCtx.inDarkContainer)
          )
        };
        if (childCtx.textAlign.length > 0) {
          heading.align = childCtx.textAlign;
        }
        ScpNativeHtmlParser.consumeAndAttachAnchors(heading, pendingAnchors, hAnchors);
        blocks.push(heading);
      } else if (child.tag === 'blockquote') {
        const quote: NativeBlock[] = [];
        const quotePending: string[] = [];
        ScpNativeHtmlParser.walkBlocks(
          child,
          quote,
          images,
          warnings,
          creditBlocks,
          childCtx,
          quotePending
        );
        if (quote.length > 0 && quotePending.length > 0) {
          ScpNativeHtmlParser.consumeAndAttachAnchors(quote[quote.length - 1], quotePending);
        }
        const quoteBlock: NativeBlock = { k: 'quote', blocks: quote };
        ScpNativeHtmlParser.consumeAndAttachAnchors(quoteBlock, pendingAnchors, ownDirectAnchors);
        ScpNativeHtmlParser.attachAnchorsToBlock(quoteBlock, quotePending);
        blocks.push(quoteBlock);
      } else if (child.tag === 'hr') {
        const dividerBlock: NativeBlock = { k: 'divider' };
        ScpNativeHtmlParser.consumeAndAttachAnchors(dividerBlock, pendingAnchors, ownDirectAnchors);
        blocks.push(dividerBlock);
      } else if (child.tag === 'table') {
        const rows: NativeBlock[] = [];
        const trs = ScpNativeHtmlParser.collectTableRows(child);
        for (let rowIndex: number = 0; rowIndex < trs.length; rowIndex++) {
          const rowCtx = ScpNativeHtmlParser.deriveBlockContext(trs[rowIndex], childCtx);
          const cells: NativeBlock[] = [];
          for (let cellIndex: number = 0; cellIndex < trs[rowIndex].children.length; cellIndex++) {
            const cell = trs[rowIndex].children[cellIndex];
            if (cell.tag === 'th' || cell.tag === 'td') {
              const cellCtx = ScpNativeHtmlParser.deriveBlockContext(cell, rowCtx);
              const cellAnchors: string[] = [];
              ScpNativeHtmlParser.collectInlineDescendantAnchors(cell, cellAnchors);
              const cellBlock: NativeBlock = {
                k: 'cell',
                isHeader: cell.tag === 'th',
                spans: ScpNativeHtmlParser.inlineSpans(
                  cell,
                  images,
                  warnings,
                  ScpNativeHtmlParser.defaultInlineContext(cellCtx.inDarkContainer)
                )
              };
              if (cellCtx.textAlign.length > 0) {
                cellBlock.align = cellCtx.textAlign;
              }
              ScpNativeHtmlParser.attachAnchorsToBlock(cellBlock, cellAnchors);
              cells.push(cellBlock);
            }
          }
          if (cells.length > 0) {
            const rowBlock: NativeBlock = { k: 'row', blocks: cells };
            ScpNativeHtmlParser.attachAnchorsToBlock(
              rowBlock,
              ScpNativeHtmlParser.collectDirectNodeAnchors(trs[rowIndex])
            );
            rows.push(rowBlock);
          }
        }
        const tableBlock: NativeBlock = { k: 'table', blocks: rows };
        ScpNativeHtmlParser.consumeAndAttachAnchors(tableBlock, pendingAnchors, ownDirectAnchors);
        blocks.push(tableBlock);
      } else if (child.tag === 'iframe') {
        const source = ScpNativeHtmlParser.attr(child, 'src');
        const lowerSource = source.toLowerCase();
        if (lowerSource.indexOf('interwikiframe') < 0 &&
          lowerSource.indexOf('styleframe') < 0 &&
          lowerSource.indexOf('credit%3abackmodule') < 0 &&
          lowerSource.indexOf('credit%253abackmodule') < 0 &&
          lowerSource.indexOf('credit:backmodule') < 0) {
          const embedBlock: NativeBlock = { k: 'embed', src: source };
          ScpNativeHtmlParser.consumeAndAttachAnchors(embedBlock, pendingAnchors, ownDirectAnchors);
          blocks.push(embedBlock);
          if (classNames.indexOf(' html-block-iframe ') >= 0 ||
            ScpNativeHtmlParser.attr(child, 'data-interactive') === 'true') {
            ScpNativeHtmlParser.warning(warnings, 'interactive:html-block-iframe');
          }
        }
      } else if (child.tag === 'img') {
        const alt = (ScpNativeHtmlParser.attr(child, 'alt') ||
          ScpNativeHtmlParser.attr(child, 'title')).trim();
        const beforeLen = blocks.length;
        ScpNativeHtmlParser.emitImageBlock(
          child,
          ScpNativeHtmlParser.cleanImageCaption(alt, ScpNativeHtmlParser.imageSource(child)),
          ScpNativeHtmlParser.parseImagePreferredWidth(child),
          blocks,
          images
        );
        if (blocks.length > beforeLen) {
          ScpNativeHtmlParser.consumeAndAttachAnchors(blocks[beforeLen], pendingAnchors, ownDirectAnchors);
        } else {
          ScpNativeHtmlParser.mergeAnchorsInto(pendingAnchors, ownDirectAnchors);
        }
      } else if (child.tag === 'div' && classNames.indexOf(' scp-image-block ') >= 0) {
        const foundImages = ScpNativeHtmlParser.descendantsByTag(child, 'img');
        const captions = ScpNativeHtmlParser.byClass(child, 'scp-image-caption');
        const caption = captions.length > 0 ? ScpNativeHtmlParser.textContent(captions[0]).trim() : '';
        const beforeLen = blocks.length;
        if (foundImages.length > 0) {
          ScpNativeHtmlParser.emitImageBlock(
            foundImages[0],
            caption,
            ScpNativeHtmlParser.parseImagePreferredWidth(foundImages[0], child),
            blocks,
            images
          );
        }
        if (blocks.length > beforeLen) {
          ScpNativeHtmlParser.consumeAndAttachAnchors(blocks[beforeLen], pendingAnchors, ownDirectAnchors);
        } else {
          ScpNativeHtmlParser.mergeAnchorsInto(pendingAnchors, ownDirectAnchors);
        }
      } else if (child.tag === 'div' && classNames.indexOf(' image-container ') >= 0) {
        const foundImages = ScpNativeHtmlParser.descendantsByTag(child, 'img');
        const beforeLen = blocks.length;
        for (let imgIndex: number = 0; imgIndex < foundImages.length; imgIndex++) {
          const imgNode = foundImages[imgIndex];
          const alt = (ScpNativeHtmlParser.attr(imgNode, 'alt') ||
            ScpNativeHtmlParser.attr(imgNode, 'title')).trim();
          ScpNativeHtmlParser.emitImageBlock(
            imgNode,
            ScpNativeHtmlParser.cleanImageCaption(alt, ScpNativeHtmlParser.imageSource(imgNode)),
            ScpNativeHtmlParser.parseImagePreferredWidth(imgNode, child),
            blocks,
            images
          );
        }
        if (blocks.length > beforeLen) {
          ScpNativeHtmlParser.consumeAndAttachAnchors(blocks[beforeLen], pendingAnchors, ownDirectAnchors);
        } else {
          ScpNativeHtmlParser.mergeAnchorsInto(pendingAnchors, ownDirectAnchors);
        }
      } else if (child.tag === 'audio' || child.tag === 'video' || child.tag === 'canvas' ||
        child.tag === 'svg' || child.tag === 'object' || child.tag === 'math') {
        const extraAnchors: string[] = [];
        ScpNativeHtmlParser.collectInlineDescendantAnchors(child, extraAnchors);
        const beforeLen = blocks.length;
        ScpNativeHtmlParser.unsupportedFallback(child, blocks, images, warnings, childCtx);
        if (blocks.length > beforeLen) {
          ScpNativeHtmlParser.consumeAndAttachAnchors(blocks[beforeLen], pendingAnchors, extraAnchors);
        }
      } else if (child.tag === 'html' || child.tag === 'body' || child.tag === 'main' ||
        child.tag === 'header' || child.tag === 'footer' || child.tag === 'nav' ||
        child.tag === 'figure' || child.tag === 'figcaption' || child.tag === 'center') {
        ScpNativeHtmlParser.mergeAnchorsInto(pendingAnchors, ownDirectAnchors);
        ScpNativeHtmlParser.walkBlocks(
          child,
          blocks,
          images,
          warnings,
          creditBlocks,
          childCtx,
          pendingAnchors
        );
      } else if (child.tag === 'div' || child.tag === 'section' || child.tag === 'article') {
        const tone = ScpNativeHtmlParser.detectCalloutTone(child);
        if (tone.length > 0) {
          const calloutCtx: BlockStyleContext = {
            textAlign: childCtx.textAlign,
            inDarkContainer: childCtx.inDarkContainer || tone === 'terminal'
          };
          const inner: NativeBlock[] = [];
          const innerPending: string[] = [];
          ScpNativeHtmlParser.walkBlocks(
            child,
            inner,
            images,
            warnings,
            creditBlocks,
            calloutCtx,
            innerPending
          );
          if (inner.length > 0 && innerPending.length > 0) {
            ScpNativeHtmlParser.consumeAndAttachAnchors(inner[inner.length - 1], innerPending);
          }
          if (inner.length === 1 && inner[0].k === 'callout' && inner[0].tone === tone) {
            ScpNativeHtmlParser.consumeAndAttachAnchors(inner[0], pendingAnchors, ownDirectAnchors);
            ScpNativeHtmlParser.attachAnchorsToBlock(inner[0], innerPending);
            blocks.push(inner[0]);
          } else if (inner.length > 0) {
            const calloutBlock: NativeBlock = { k: 'callout', tone: tone, blocks: inner };
            ScpNativeHtmlParser.consumeAndAttachAnchors(calloutBlock, pendingAnchors, ownDirectAnchors);
            ScpNativeHtmlParser.attachAnchorsToBlock(calloutBlock, innerPending);
            blocks.push(calloutBlock);
          } else {
            ScpNativeHtmlParser.mergeAnchorsInto(pendingAnchors, ownDirectAnchors);
            ScpNativeHtmlParser.mergeAnchorsInto(pendingAnchors, innerPending);
          }
        } else {
          ScpNativeHtmlParser.mergeAnchorsInto(pendingAnchors, ownDirectAnchors);
          ScpNativeHtmlParser.walkBlocks(
            child,
            blocks,
            images,
            warnings,
            creditBlocks,
            childCtx,
            pendingAnchors
          );
        }
      } else if (ScpNativeHtmlParser.hasDirectImgContent(child)) {
        const imgAnchors: string[] = [];
        ScpNativeHtmlParser.collectInlineDescendantAnchors(child, imgAnchors);
        const beforeLen = blocks.length;
        ScpNativeHtmlParser.walkParagraphNode(child, blocks, images, warnings, childCtx);
        if (blocks.length > beforeLen) {
          ScpNativeHtmlParser.consumeAndAttachAnchors(blocks[beforeLen], pendingAnchors, imgAnchors);
        } else {
          ScpNativeHtmlParser.mergeAnchorsInto(pendingAnchors, imgAnchors);
        }
      } else {
        const inlineAnchors: string[] = [];
        ScpNativeHtmlParser.collectInlineDescendantAnchors(child, inlineAnchors);
        const spans = ScpNativeHtmlParser.inlineSpans(
          child,
          images,
          warnings,
          ScpNativeHtmlParser.defaultInlineContext(childCtx.inDarkContainer)
        );
        if (spans.length > 0) {
          const fallbackBlock: NativeBlock = { k: 'paragraph', spans: spans };
          if (childCtx.textAlign.length > 0) {
            fallbackBlock.align = childCtx.textAlign;
          }
          ScpNativeHtmlParser.consumeAndAttachAnchors(fallbackBlock, pendingAnchors, inlineAnchors);
          blocks.push(fallbackBlock);
        } else {
          ScpNativeHtmlParser.mergeAnchorsInto(pendingAnchors, inlineAnchors);
        }
      }
  }

  private static detectComplexPageWarnings(
    root: HtmlNode,
    pageContent: HtmlNode,
    warnings: string[]
  ): void {
    if (ScpNativeHtmlParser.containsListPagesOffsetLink(pageContent)) {
      ScpNativeHtmlParser.warning(warnings, 'interactive:listpages-offset');
    }
    if (ScpNativeHtmlParser.containsFormatScrewStylesheet(root)) {
      ScpNativeHtmlParser.warning(warnings, 'format-screw:custom-css');
    }
  }

  private static containsListPagesOffsetLink(
    node: HtmlNode,
    insideInteractive: boolean = false
  ): boolean {
    if (ScpNativeHtmlParser.hasNoiseId(node) || ScpNativeHtmlParser.hasClass(node, 'lang-tr')) {
      return false;
    }
    const idLower = ScpNativeHtmlParser.attr(node, 'id').trim().toLowerCase();
    if (idLower === 'u-credit-view' || idLower === 'u-credit-otherwise') {
      return false;
    }
    const classNames = ScpNativeHtmlParser.classes(node);
    if (classNames.indexOf(' modalcontainer ') >= 0 || classNames.indexOf(' modalbox ') >= 0 ||
      classNames.indexOf(' licensebox ') >= 0) {
      return false;
    }
    for (let i: number = 0; i < NOISE_CLASSES.length; i++) {
      if (classNames.indexOf(` ${NOISE_CLASSES[i]} `) >= 0) {
        return false;
      }
    }
    const nextInteractive = insideInteractive ||
      classNames.indexOf(' collapsible-block') >= 0 ||
      classNames.indexOf(' colmod') >= 0 ||
      classNames.indexOf(' yui-') >= 0;
    if (!nextInteractive && ScpNativeHtmlParser.isDisplayNone(node)) {
      return false;
    }
    if (node.tag === 'a') {
      const href = ScpNativeHtmlParser.attr(node, 'href').trim();
      if (/\/offset\/\d+(?:[/?#]|$)/i.test(href)) {
        return true;
      }
    }
    for (let index: number = 0; index < node.children.length; index++) {
      if (ScpNativeHtmlParser.containsListPagesOffsetLink(node.children[index], nextInteractive)) {
        return true;
      }
    }
    return false;
  }

  private static styleNodeText(styleNode: HtmlNode): string {
    let result = '';
    for (let index: number = 0; index < styleNode.children.length; index++) {
      result += styleNode.children[index].text;
    }
    return result;
  }

  private static containsFormatScrewStylesheet(root: HtmlNode): boolean {
    const styles = ScpNativeHtmlParser.descendantsByTag(root, 'style');
    for (let index: number = 0; index < styles.length; index++) {
      const styleNode = styles[index];
      if (ScpNativeHtmlParser.attr(styleNode, 'id').trim().toLowerCase() === 'internal-style') {
        continue;
      }
      const css = ScpNativeHtmlParser.styleNodeText(styleNode);
      if (css.length < 4000) {
        continue;
      }
      const low = css.toLowerCase();
      if (low.indexOf('anom-bar') >= 0 ||
        low.indexOf('bhl.scpwikicn') >= 0 ||
        low.indexOf('black-highlighter') >= 0 ||
        (low.indexOf('info-container') >= 0 && low.indexOf('modal-wrapper') >= 0)) {
        continue;
      }
      if (low.indexOf('@keyframes') >= 0 ||
        low.indexOf('animation:') >= 0 ||
        low.indexOf('grid-template') >= 0 ||
        low.indexOf('clip-path') >= 0) {
        return true;
      }
    }
    return false;
  }

  private static isPureWhisperParagraph(block: NativeBlock): boolean {
    if (block.k !== 'paragraph' || block.spans === undefined || block.spans.length === 0) {
      return false;
    }
    let hasText = false;
    for (let index: number = 0; index < block.spans.length; index++) {
      const span = block.spans[index];
      if (span.t.trim().length === 0) {
        continue;
      }
      hasText = true;
      if (span.h !== 'zero_size_whisper') {
        return false;
      }
    }
    return hasText;
  }

  private static coalesceWhisperParagraphs(blocks: NativeBlock[]): NativeBlock[] {
    const out: NativeBlock[] = [];
    for (let index: number = 0; index < blocks.length; index++) {
      const block = blocks[index];
      if (block.blocks !== undefined && block.blocks.length > 0) {
        block.blocks = ScpNativeHtmlParser.coalesceWhisperParagraphs(block.blocks);
      }
      if (ScpNativeHtmlParser.isPureWhisperParagraph(block)) {
        const mergedSpans: NativeSpan[] = [];
        const mergedAnchors: string[] = [];
        ScpNativeHtmlParser.mergeAnchorsInto(mergedAnchors, block.anchors ?? []);
        const srcSpans = block.spans ?? [];
        for (let s: number = 0; s < srcSpans.length; s++) {
          mergedSpans.push(srcSpans[s]);
        }
        let cursor = index + 1;
        while (cursor < blocks.length && ScpNativeHtmlParser.isPureWhisperParagraph(blocks[cursor])) {
          mergedSpans.push({ s: 'plain', t: '\n', u: '', r: '', h: 'zero_size_whisper' });
          ScpNativeHtmlParser.mergeAnchorsInto(mergedAnchors, blocks[cursor].anchors ?? []);
          const nextSpans = blocks[cursor].spans ?? [];
          for (let s: number = 0; s < nextSpans.length; s++) {
            mergedSpans.push(nextSpans[s]);
          }
          cursor++;
        }
        const mergedBlock: NativeBlock = {
          k: 'paragraph',
          spans: mergedSpans
        };
        if (block.align !== undefined && block.align.length > 0) {
          mergedBlock.align = block.align;
        }
        ScpNativeHtmlParser.attachAnchorsToBlock(mergedBlock, mergedAnchors);
        out.push(mergedBlock);
        index = cursor - 1;
        continue;
      }
      out.push(block);
    }
    return out;
  }

  private static hasReadableBlocks(blocks: NativeBlock[]): boolean {
    for (let index: number = 0; index < blocks.length; index++) {
      const block = blocks[index];
      if (block.k === 'embed' && (block.src ?? '').trim().length > 0) {
        return true;
      }
      if (block.k === 'image' && (block.src ?? '').trim().length > 0) {
        return true;
      }
      if (block.k === 'acs_header' && block.acs !== undefined &&
        (block.acs.itemNumber.trim().length > 0 || block.acs.containmentClass.trim().length > 0)) {
        return true;
      }
      const spans = block.spans ?? [];
      for (let spanIndex: number = 0; spanIndex < spans.length; spanIndex++) {
        if (spans[spanIndex].s !== 'footnote' && spans[spanIndex].t.trim().length > 0) {
          return true;
        }
      }
      if (ScpNativeHtmlParser.hasReadableBlocks(block.blocks ?? [])) {
        return true;
      }
    }
    return false;
  }

  private static hasReadableImages(images: NativeImage[]): boolean {
    for (let index: number = 0; index < images.length; index++) {
      if (images[index].src.trim().length > 0) {
        return true;
      }
    }
    return false;
  }
}
