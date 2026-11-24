import type {
  ExplorePayload,
  ExploreRawEntry,
  ExploreSource
} from '../domain/ExploreContracts';

/**
 * SCP 中文主站探索索引的原生静态解析器。
 *
 * 这些页面的榜单、最近更新与搞笑索引均已包含在服务端返回的 HTML 中，
 * 不需要创建隐藏 ArkWeb。直接解析原始响应可以避免多个离屏 Web 组件连续
 * 销毁/创建时丢失回调，也让列表抓取与界面生命周期彻底解耦。
 */
export class ExploreHtmlParser {
  static parse(source: ExploreSource, html: string): ExplorePayload {
    const entries: ExploreRawEntry[] = [];
    try {
      const content = ExploreHtmlParser.pageContent(html);
      if (content.length === 0) {
        return ExploreHtmlParser.failure('page-content node not found');
      }
      if (source === 'top-rated' ||
        source === 'recent-translated' ||
        source === 'recent-original') {
        ExploreHtmlParser.parseTable(content, source, entries);
      } else {
        ExploreHtmlParser.parseJokes(content, source, entries);
      }
      if (entries.length === 0) {
        return ExploreHtmlParser.failure(`explore entries not found: ${source}`);
      }
      return { ok: true, error: '', entries: entries };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'unknown parse error';
      return ExploreHtmlParser.failure(message);
    }
  }

  private static failure(message: string): ExplorePayload {
    return { ok: false, error: message, entries: [] };
  }

  private static pageContent(html: string): string {
    const marker = /<div\b[^>]*id=["']page-content["'][^>]*>/i.exec(html);
    if (marker === null || marker.index === undefined) {
      return '';
    }
    const start = marker.index + marker[0].length;
    const endMarkers: string[] = [
      '<div class="page-tags">',
      '<div id="page-info-break">',
      '<div id="page-options-container">'
    ];
    let end = html.length;
    for (let index = 0; index < endMarkers.length; index++) {
      const candidate = html.indexOf(endMarkers[index], start);
      if (candidate >= 0 && candidate < end) {
        end = candidate;
      }
    }
    return html.substring(start, end);
  }

  private static parseTable(
    content: string,
    source: ExploreSource,
    entries: ExploreRawEntry[]
  ): void {
    const seen: Set<string> = new Set();
    const rowPattern: RegExp = /<tr\b[^>]*>([\s\S]*?)<\/tr>/gi;
    let rowMatch: RegExpExecArray | null = rowPattern.exec(content);
    while (rowMatch !== null && entries.length < 40) {
      const cells: string[] = ExploreHtmlParser.cellsOf(rowMatch[1] as string);
      if (cells.length >= 2) {
        const link = ExploreHtmlParser.firstLink(cells[0]);
        if (link !== undefined && !seen.has(link.url) &&
          !ExploreHtmlParser.isNavigation(link.url)) {
          seen.add(link.url);
          if (source === 'top-rated') {
            entries.push({
              url: link.url,
              title: link.title,
              score: ExploreHtmlParser.cleanText(cells[1]).replace(/^\+/, ''),
              date: '',
              comments: cells.length > 2 ? ExploreHtmlParser.cleanText(cells[2]) : ''
            });
          } else {
            entries.push({
              url: link.url,
              title: link.title,
              score: '',
              date: ExploreHtmlParser.cleanText(cells[1]),
              comments: cells.length > 2 ? ExploreHtmlParser.commentCount(cells[2]) : ''
            });
          }
        }
      }
      rowMatch = rowPattern.exec(content);
    }
  }

  private static cellsOf(row: string): string[] {
    const cells: string[] = [];
    const cellPattern: RegExp = /<td\b[^>]*>([\s\S]*?)<\/td>/gi;
    let match: RegExpExecArray | null = cellPattern.exec(row);
    while (match !== null) {
      cells.push(match[1] as string);
      match = cellPattern.exec(row);
    }
    return cells;
  }

  private static parseJokes(
    content: string,
    source: ExploreSource,
    entries: ExploreRawEntry[]
  ): void {
    // Wikidot puts explanatory/navigation links before the actual index.  The
    // old parser walked the entire page and consequently promoted links from
    // the instructions, table of contents and licensing footer as stories.
    // Narrow the input to the first content panel (joke SCPs) or to the list
    // introduced by the "就这样啦" marker (joke tales).  Fixtures and future
    // page variants without these markers still fall back to the full content.
    const listContent = ExploreHtmlParser.jokeListContent(content, source);
    const seen: Set<string> = new Set();
    const maxEntries = (source === 'joke-scps' || source === 'joke-scps-cn') ? 240 : 180;
    const linkPattern: RegExp = /<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
    let match: RegExpExecArray | null = linkPattern.exec(listContent);
    while (match !== null && entries.length < maxEntries) {
      const url = ExploreHtmlParser.normalizeHref(match[1] as string);
      const title = ExploreHtmlParser.cleanText(match[2] as string);
      if (ExploreHtmlParser.isJokeEntry(source, url, title) && !seen.has(url)) {
        seen.add(url);
        entries.push({ url: url, title: title, score: '', date: '', comments: '' });
      }
      match = linkPattern.exec(listContent);
    }
  }

  private static jokeListContent(content: string, source: ExploreSource): string {
    if (source === 'joke-tales') {
      const marker = /就这样啦[\s\S]*?<\/p>/i.exec(content);
      if (marker !== null && marker.index !== undefined) {
        return content.substring(marker.index + marker[0].length);
      }
      return content;
    }
    const panel = /<div\b[^>]*class=["'][^"']*\bcontent-panel\b[^"']*\bstandalone\b[^"']*\bseries\b[^"']*["'][^>]*>/i.exec(content);
    if (panel !== null && panel.index !== undefined) {
      return content.substring(panel.index + panel[0].length);
    }
    return content;
  }

  private static isJokeEntry(source: ExploreSource, url: string, title: string): boolean {
    if (url.length < 2 || title.length < 2 || ExploreHtmlParser.isNavigation(url)) {
      return false;
    }
    const slug = url.substring(1).toLowerCase();
    const isScpPage = slug.startsWith('scp-') || slug.startsWith('spc-');
    const isJokePage = isScpPage && (slug.indexOf('-j') >= 0 || title.toLowerCase().indexOf('-j') >= 0);
    if (source === 'joke-scps' || source === 'joke-scps-cn') {
      return isJokePage;
    }
    // 故事版页面的一级项目链接与二级故事链接混排。故事源排除 SCP/SPC
    // 页面，保留其余正文链接；导航、版权和跨站链接由统一策略过滤。
    return !isScpPage;
  }

  private static firstLink(html: string): ExploreRawEntry | undefined {
    const match = /<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/i.exec(html);
    if (match === null) {
      return undefined;
    }
    const url = ExploreHtmlParser.normalizeHref(match[1] as string);
    const title = ExploreHtmlParser.cleanText(match[2] as string);
    if (url.length === 0 || title.length === 0) {
      return undefined;
    }
    return { url: url, title: title, score: '', date: '', comments: '' };
  }

  private static normalizeHref(value: string): string {
    const trimmed = value.trim();
    const hash = trimmed.indexOf('#');
    const withoutFragment = hash >= 0 ? trimmed.substring(0, hash) : trimmed;
    const query = withoutFragment.indexOf('?');
    return (query >= 0 ? withoutFragment.substring(0, query) : withoutFragment).trim();
  }

  private static isNavigation(url: string): boolean {
    if (!url.startsWith('/') || url.startsWith('//')) {
      return true;
    }
    const normalized = url.toLowerCase();
    return normalized.startsWith('/system:') || normalized.startsWith('/_') ||
      normalized.indexOf('tales-by') >= 0 || normalized.indexOf('foundation-tales') >= 0 ||
      normalized.indexOf('most-recently') >= 0 || normalized.indexOf('top-rated') >= 0 ||
      normalized.indexOf('joke-scps') >= 0 || normalized.indexOf('explained-scps') >= 0 ||
      normalized.indexOf('random:') >= 0 || normalized.indexOf('scp-series') >= 0 ||
      normalized.startsWith('/forum') || normalized.startsWith('/help') ||
      normalized === '/main' || normalized === '/';
  }

  private static commentCount(html: string): string {
    const text = ExploreHtmlParser.cleanText(html);
    const match = /(?:评论数|comments?)\s*[：:]\s*(-?\d+)/i.exec(text);
    if (match !== null) {
      return match[1] as string;
    }
    // Some index templates render the comment cell as a bare number rather
    // than the labelled tooltip used by the current site.
    return /^-?\d+$/.test(text) ? text : '';
  }

  private static cleanText(value: string): string {
    return value
      .replace(/<(script|style)\b[\s\S]*?<\/\1>/gi, ' ')
      .replace(/<[^>]+>/g, ' ')
      .replace(/&nbsp;|&#160;/gi, ' ')
      .replace(/&amp;/gi, '&')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&quot;|&#34;/gi, '"')
      .replace(/&#39;|&apos;/gi, '\'')
      .replace(/&#x([0-9a-f]+);/gi, (_whole: string, hex: string): string =>
        ExploreHtmlParser.codePointText(parseInt(hex, 16)))
      .replace(/&#(\d+);/g, (_whole: string, decimal: string): string =>
        ExploreHtmlParser.codePointText(parseInt(decimal, 10)))
      .replace(/\s+/g, ' ')
      .trim();
  }

  private static codePointText(value: number): string {
    if (!Number.isFinite(value) || value <= 0 || value > 0x10FFFF) {
      return '';
    }
    return String.fromCodePoint(value);
  }
}
