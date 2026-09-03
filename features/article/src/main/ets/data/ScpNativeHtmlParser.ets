import { ScpExtractPayload } from './ScpDocumentMapper';
import { ScpArticleDocument } from '../domain/ScpDocument';

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
}

interface NativeBlock {
  k: string;
  spans?: NativeSpan[];
  level?: number;
  title?: string;
  blocks?: NativeBlock[];
  src?: string;
  caption?: string;
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
}

const VOID_TAGS: string[] = [
  'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta',
  'param', 'source', 'track', 'wbr'
];

const NOISE_CLASSES: string[] = [
  'info-container', 'page-options', 'page-tags', 'footnotes-footer',
  'footer-wikiwalk-nav'
];

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
      warnings: [] as string[]
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

      ScpNativeHtmlParser.walkBlocks(pageContent, out.blocks, out.images, out.warnings);
      const footnotes = ScpNativeHtmlParser.byClass(pageContent, 'footnotes-footer');
      if (footnotes.length > 0) {
        const items = ScpNativeHtmlParser.byClass(footnotes[0], 'footnote-footer');
        for (let index: number = 0; index < items.length; index++) {
          const itemBlocks: NativeBlock[] = [];
          ScpNativeHtmlParser.walkBlocks(items[index], itemBlocks, out.images, out.warnings);
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
      stack[stack.length - 1].children.push(node);
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
    return value
      .replace(/&nbsp;?/gi, ' ')
      .replace(/&amp;/gi, '&')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&quot;/gi, '"')
      .replace(/&#39;|&apos;/gi, "'")
      .replace(/&#x([0-9a-f]+);/gi, (_match: string, code: string): string => {
        const value = Number.parseInt(code, 16);
        return Number.isFinite(value) ? String.fromCharCode(value) : '';
      })
      .replace(/&#(\d+);/g, (_match: string, code: string): string => {
        const value = Number.parseInt(code, 10);
        return Number.isFinite(value) ? String.fromCharCode(value) : '';
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

  private static textContent(node: HtmlNode): string {
    if (node.tag === '#text') {
      return node.text;
    }
    if (node.tag === 'img' || node.tag === 'rp' || node.tag === 'rt') {
      return '';
    }
    if (node.tag === 'ruby') {
      let base = '';
      const readings: string[] = [];
      for (let index: number = 0; index < node.children.length; index++) {
        const child = node.children[index];
        if (child.tag === 'rt') {
          const reading = ScpNativeHtmlParser.textContent(child).trim();
          if (reading.length > 0) {
            readings.push(reading);
          }
        } else if (child.tag !== 'rp') {
          base += ScpNativeHtmlParser.textContent(child);
        }
      }
      return readings.length === 0 ? base : `${base}（${readings.join(' / ')}）`;
    }
    let result = '';
    for (let index: number = 0; index < node.children.length; index++) {
      result += ScpNativeHtmlParser.textContent(node.children[index]);
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

  private static inlineSpans(
    node: HtmlNode,
    images: NativeImage[],
    warnings: string[],
    inherited: string = 'plain',
    skipLists: boolean = false
  ): NativeSpan[] {
    const result: NativeSpan[] = [];
    const append = (style: string, text: string, target: string = '', reference: string = ''): void => {
      if (text.length === 0) {
        return;
      }
      result.push({ s: style, t: text, u: target, r: reference });
    };
    const walk = (current: HtmlNode, style: string): void => {
      if (current.tag === '#text') {
        const text = current.text.replace(/\r\n?/g, '\n').replace(/[ \t\n]+/g, ' ');
        if (text.trim().length > 0) {
          append(style, text);
        } else if (result.length > 0) {
          append(style, ' ');
        }
        return;
      }
      if (current.tag === 'br') {
        append(style, '\n');
        return;
      }
      if (skipLists && (current.tag === 'ul' || current.tag === 'ol')) {
        return;
      }
      if (current.tag === 'img') {
        const alt = (ScpNativeHtmlParser.attr(current, 'alt') ||
          ScpNativeHtmlParser.attr(current, 'title')).trim();
        const src = ScpNativeHtmlParser.recordImage(images, current, alt);
        const label = alt.length > 0 ? `[图片：${alt}]` : '[图片]';
        append(src.length > 0 ? 'link' : style, label, src);
        ScpNativeHtmlParser.warning(warnings, 'degraded:inline-image-placement');
        return;
      }
      if (current.tag === 'ruby') {
        const ruby = ScpNativeHtmlParser.textContent(current);
        if (ruby.trim().length > 0) {
          append(style, ruby);
        }
        ScpNativeHtmlParser.warning(warnings, 'degraded:ruby-annotation');
        return;
      }
      const currentClass = ScpNativeHtmlParser.classes(current);
      if (current.tag === 'sup' && currentClass.indexOf(' footnoteref ') >= 0) {
        const link = ScpNativeHtmlParser.descendantsByTag(current, 'a');
        const footnote = link.length > 0 ? link[0] : current;
        const id = ScpNativeHtmlParser.attr(footnote, 'id').replace(/^footnoteref-/i, '');
        append('footnote', ScpNativeHtmlParser.textContent(footnote).trim(), '', id);
        return;
      }
      if (current.tag === 'a') {
        if (currentClass.indexOf(' footnoteref ') >= 0) {
          const id = ScpNativeHtmlParser.attr(current, 'id').replace(/^footnoteref-/i, '');
          append('footnote', ScpNativeHtmlParser.textContent(current).trim(), '', id);
          return;
        }
        const href = ScpNativeHtmlParser.attr(current, 'href');
        const linkText = ScpNativeHtmlParser.textContent(current).trim();
        if (linkText.length > 0) {
          append(href === 'javascript:;' ? style : 'link', linkText, href === 'javascript:;' ? '' : href);
        }
        const linkImages = ScpNativeHtmlParser.descendantsByTag(current, 'img');
        for (let index: number = 0; index < linkImages.length; index++) {
          const alt = (ScpNativeHtmlParser.attr(linkImages[index], 'alt') ||
            ScpNativeHtmlParser.attr(linkImages[index], 'title')).trim();
          const src = ScpNativeHtmlParser.recordImage(images, linkImages[index], alt);
          append(href.length > 0 && href !== 'javascript:;' ? 'link' : style,
            alt.length > 0 ? `[图片：${alt}]` : '[图片]', href.length > 0 ? href : src);
        }
        return;
      }
      let nextStyle = style;
      if (current.tag === 'strong' || current.tag === 'b') {
        nextStyle = 'strong';
      } else if (current.tag === 'em' || current.tag === 'i') {
        nextStyle = 'em';
      } else if (current.tag === 'del' || current.tag === 's' || current.tag === 'strike') {
        nextStyle = 'del';
      } else if (current.tag === 'code' || current.tag === 'tt') {
        nextStyle = 'code';
      }
      for (let index: number = 0; index < current.children.length; index++) {
        walk(current.children[index], nextStyle);
      }
    };
    walk(node, inherited);
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
        result.push({ s: span.s, t: text, u: span.u, r: span.r });
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

  private static walkNestedLists(node: HtmlNode, blocks: NativeBlock[], images: NativeImage[], warnings: string[], depth: number): void {
    for (let index: number = 0; index < node.children.length; index++) {
      const child = node.children[index];
      if (child.tag === 'ul' || child.tag === 'ol') {
        ScpNativeHtmlParser.walkList(child, blocks, images, warnings, depth);
      } else {
        ScpNativeHtmlParser.walkNestedLists(child, blocks, images, warnings, depth);
      }
    }
  }

  private static walkList(node: HtmlNode, blocks: NativeBlock[], images: NativeImage[], warnings: string[], depth: number): void {
    const ordered = node.tag === 'ol';
    const parsedStart = Number.parseInt(ScpNativeHtmlParser.attr(node, 'start') || '1', 10);
    const start = Number.isFinite(parsedStart) ? parsedStart : 1;
    const items = ScpNativeHtmlParser.directListItems(node);
    for (let index: number = 0; index < items.length; index++) {
      let prefix = '';
      for (let indent: number = 0; indent < depth; indent++) {
        prefix += '  ';
      }
      prefix += ordered ? `${start + index}. ` : '• ';
      const spans = ScpNativeHtmlParser.inlineSpans(items[index], images, warnings, 'plain', true);
      if (spans.length > 0) {
        spans.unshift({ s: 'plain', t: prefix });
        blocks.push({ k: 'paragraph', spans: spans });
      }
      ScpNativeHtmlParser.walkNestedLists(items[index], blocks, images, warnings, depth + 1);
    }
    ScpNativeHtmlParser.warning(warnings, 'degraded:list-layout');
  }

  private static unsupportedFallback(node: HtmlNode, blocks: NativeBlock[], images: NativeImage[], warnings: string[]): void {
    const labels = new Map<string, string>([
      ['audio', '音频'], ['video', '视频'], ['canvas', '画布'], ['svg', '矢量图'],
      ['object', '外部对象'], ['math', '数学公式']
    ]);
    const spans = ScpNativeHtmlParser.inlineSpans(node, images, warnings);
    if (spans.length === 0) {
      const source = ScpNativeHtmlParser.attr(node, 'src') || ScpNativeHtmlParser.attr(node, 'data');
      spans.push({
        s: source.length > 0 ? 'link' : 'plain',
        u: source,
        t: `[暂不支持的${labels.get(node.tag) ?? '内容'}]`
      });
    }
    blocks.push({ k: 'paragraph', spans: spans });
    ScpNativeHtmlParser.warning(warnings, `unsupported:${node.tag}`);
  }

  private static walkBlocks(node: HtmlNode, blocks: NativeBlock[], images: NativeImage[], warnings: string[]): void {
    for (let index: number = 0; index < node.children.length; index++) {
      const child = node.children[index];
      if (child.tag === '#text') {
        if (child.text.trim().length > 0) {
          blocks.push({ k: 'paragraph', spans: [{ s: 'plain', t: child.text }] });
        }
        continue;
      }
      const classNames = ScpNativeHtmlParser.classes(child);
      let skipped = false;
      for (let classIndex: number = 0; classIndex < NOISE_CLASSES.length; classIndex++) {
        if (classNames.indexOf(` ${NOISE_CLASSES[classIndex]} `) >= 0) {
          skipped = true;
          break;
        }
      }
      if (skipped || child.tag === 'style' || child.tag === 'script' || child.tag === 'noscript') {
        continue;
      }
      if (classNames.indexOf(' list-pages-box ') >= 0) {
        ScpNativeHtmlParser.walkBlocks(child, blocks, images, warnings);
        ScpNativeHtmlParser.warning(warnings, 'compat:list-pages-box-content');
        continue;
      }
      if (child.tag === 'ul' || child.tag === 'ol') {
        ScpNativeHtmlParser.walkList(child, blocks, images, warnings, 0);
      } else if (child.tag === 'pre') {
        const code = ScpNativeHtmlParser.textContent(child);
        if (code.length > 0) {
          blocks.push({ k: 'paragraph', spans: [{ s: 'code', t: code }] });
        }
        ScpNativeHtmlParser.warning(warnings, 'degraded:pre-layout');
      } else if (child.tag === 'p') {
        const spans = ScpNativeHtmlParser.inlineSpans(child, images, warnings);
        if (spans.length > 0) {
          blocks.push({ k: 'paragraph', spans: spans });
        }
      } else if (/^h[1-6]$/.test(child.tag)) {
        blocks.push({ k: 'heading', level: Number.parseInt(child.tag.charAt(1), 10),
          spans: ScpNativeHtmlParser.inlineSpans(child, images, warnings) });
      } else if (child.tag === 'blockquote') {
        const quote: NativeBlock[] = [];
        ScpNativeHtmlParser.walkBlocks(child, quote, images, warnings);
        blocks.push({ k: 'quote', blocks: quote });
      } else if (child.tag === 'hr') {
        blocks.push({ k: 'divider' });
      } else if (child.tag === 'table') {
        const rows: NativeBlock[] = [];
        const trs = ScpNativeHtmlParser.descendantsByTag(child, 'tr');
        for (let rowIndex: number = 0; rowIndex < trs.length; rowIndex++) {
          const cells: NativeBlock[] = [];
          for (let cellIndex: number = 0; cellIndex < trs[rowIndex].children.length; cellIndex++) {
            const cell = trs[rowIndex].children[cellIndex];
            if (cell.tag === 'th' || cell.tag === 'td') {
              cells.push({ k: 'cell', spans: ScpNativeHtmlParser.inlineSpans(cell, images, warnings) });
            }
          }
          rows.push({ k: 'row', blocks: cells });
        }
        blocks.push({ k: 'table', blocks: rows });
      } else if (child.tag === 'iframe') {
        const source = ScpNativeHtmlParser.attr(child, 'src');
        if (source.indexOf('interwikiFrame') < 0 && source.indexOf('styleFrame') < 0) {
          blocks.push({ k: 'embed', src: source });
        }
      } else if (child.tag === 'div' && classNames.indexOf(' scp-image-block ') >= 0) {
        const foundImages = ScpNativeHtmlParser.descendantsByTag(child, 'img');
        const captions = ScpNativeHtmlParser.byClass(child, 'scp-image-caption');
        const caption = captions.length > 0 ? ScpNativeHtmlParser.textContent(captions[0]).trim() : '';
        if (foundImages.length > 0) {
          ScpNativeHtmlParser.recordImage(images, foundImages[0], caption);
        }
      } else if (child.tag === 'div' && classNames.indexOf(' collapsible-block ') >= 0) {
        const links = ScpNativeHtmlParser.byClass(child, 'collapsible-block-link');
        const content = ScpNativeHtmlParser.byClass(child, 'collapsible-block-content');
        const unfolded = ScpNativeHtmlParser.byClass(child, 'collapsible-block-unfolded');
        const inner: NativeBlock[] = [];
        if (content.length > 0) {
          ScpNativeHtmlParser.walkBlocks(content[0], inner, images, warnings);
        } else if (unfolded.length > 0) {
          ScpNativeHtmlParser.walkBlocks(unfolded[0], inner, images, warnings);
        }
        blocks.push({ k: 'collapsible', title: links.length > 0 ? ScpNativeHtmlParser.textContent(links[0]).trim() : '', blocks: inner });
      } else if (child.tag === 'audio' || child.tag === 'video' || child.tag === 'canvas' ||
        child.tag === 'svg' || child.tag === 'object' || child.tag === 'math') {
        ScpNativeHtmlParser.unsupportedFallback(child, blocks, images, warnings);
      } else if (child.tag === 'div' || child.tag === 'section' || child.tag === 'article') {
        ScpNativeHtmlParser.walkBlocks(child, blocks, images, warnings);
      } else {
        const spans = ScpNativeHtmlParser.inlineSpans(child, images, warnings);
        if (spans.length > 0) {
          blocks.push({ k: 'paragraph', spans: spans });
        }
      }
    }
  }

  private static hasReadableBlocks(blocks: NativeBlock[]): boolean {
    for (let index: number = 0; index < blocks.length; index++) {
      const block = blocks[index];
      if (block.k === 'embed' && (block.src ?? '').trim().length > 0) {
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
