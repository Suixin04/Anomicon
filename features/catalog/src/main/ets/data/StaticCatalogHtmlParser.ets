import {
  SCP_CATALOG_PARSER_VERSION,
  ScpCatalogPayload,
  ScpCatalogRawEntry,
  TALE_LIST_PARSER_VERSION,
  TalePayload,
  TaleRawEntry
} from '../domain/StaticCatalogContracts';

// Wikidot pages are published by several mirrors, so the catalog can mix
// Traditional and Simplified Chinese even when the app language is Simplified
// Chinese. Keep this small, dependency-free projection at the HTML boundary so
// titles are normalized before search, sorting, and rendering consume them.
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
  ['務', '务'], ['門', '门'], ['間', '间'], ['隊', '队'], ['號', '号'], ['線', '线'],
  ['從', '从'], ['種', '种'], ['這', '这'], ['麼', '么'], ['樣', '样'], ['還', '还'],
  ['處', '处'], ['應', '应'], ['極', '极'], ['標', '标'], ['準', '准'], ['廣', '广'],
  ['義', '义'], ['則', '则'], ['單', '单'], ['據', '据'], ['無', '无'], ['論', '论'],
  ['論', '论'], ['邊', '边'], ['導', '导'], ['覽', '览'], ['製', '制'], ['術', '术'],
  ['術', '术'], ['異', '异'], ['常', '常'], ['種', '种'], ['變', '变'], ['化', '化'],
  ['現', '现'], ['場', '场'], ['圖', '图'], ['說', '说'], ['明', '明'], ['問', '问'],
  ['題', '题'], ['標', '标'], ['識', '识'], ['類', '类'], ['別', '别'], ['體', '体'],
  ['驗', '验'], ['證', '证'], ['實', '实'], ['際', '际'], ['狀', '状'], ['態', '态'],
  ['輔', '辅'], ['創', '创'], ['藝', '艺'], ['攝', '摄'], ['權', '权'], ['產', '产'],
  ['護', '护'], ['敵', '敌'], ['殺', '杀'], ['傷', '伤'], ['釋', '释'], ['針', '针']
]);

function toSimplifiedChinese(value: string): string {
  let result: string = '';
  for (let index: number = 0; index < value.length; index++) {
    const character = value.charAt(index);
    result += TRADITIONAL_TO_SIMPLIFIED.get(character) ?? character;
  }
  return result;
}

/**
 * 目录类页面的原生静态 HTML 解析器。
 *
 * 系列目录与故事索引均已包含在服务端 HTML 的 page-content 内，无需创建
 * 隐藏 ArkWeb。公开入口通过 TaskPool 执行，避免数千条链接的扫描与文本清理
 * 阻塞 UI 线程。
 */
export class StaticCatalogHtmlParser {
  static parseCatalog(html: string): ScpCatalogPayload {
    const entries: ScpCatalogRawEntry[] = [];
    try {
      const pageContent = StaticCatalogHtmlParser.pageContent(html);
      if (pageContent.length === 0) {
        return StaticCatalogHtmlParser.catalogFailure('page-content node not found');
      }
      const content = StaticCatalogHtmlParser.catalogPanel(pageContent);
      const lowerContent = content.toLowerCase();
      const seen: Set<string> = new Set();
      const linkPattern: RegExp = /<a\b[^>]*\bhref\s*=\s*(["'])([^"']*)\1[^>]*>([\s\S]*?)<\/a\s*>/gi;
      let match: RegExpExecArray | null = linkPattern.exec(content);
      while (match !== null) {
        const href = StaticCatalogHtmlParser.normalizeHref(match[2] as string);
        const id = href.startsWith('/') ? href.substring(1).toUpperCase() : '';
        if (/^SCP-\d{3,4}$/.test(id) && !seen.has(id)) {
          seen.add(id);
          const linkText = StaticCatalogHtmlParser.cleanText(match[3] as string);
          let title = StaticCatalogHtmlParser.stripIdPrefix(linkText, id);
          if (title.length === 0 && match.index !== undefined) {
            const linkEnd = match.index + match[0].length;
            const parentText = StaticCatalogHtmlParser.nearestParentText(
              content,
              lowerContent,
              match.index,
              linkEnd
            );
            title = StaticCatalogHtmlParser.stripIdPrefix(parentText, id);
          }
          entries.push({
            itemId: id,
            title: StaticCatalogHtmlParser.cleanCatalogTitle(title),
            description: ''
          });
        }
        match = linkPattern.exec(content);
      }
      if (entries.length === 0) {
        return StaticCatalogHtmlParser.catalogFailure('series entries not found');
      }
      return {
        parserVersion: SCP_CATALOG_PARSER_VERSION,
        ok: true,
        error: '',
        entries: entries
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'unknown catalog parse error';
      return StaticCatalogHtmlParser.catalogFailure(message);
    }
  }

  static parseTales(html: string): TalePayload {
    const tales: TaleRawEntry[] = [];
    try {
      const content = StaticCatalogHtmlParser.pageContent(html);
      if (content.length === 0) {
        return StaticCatalogHtmlParser.taleFailure('page-content node not found');
      }
      const seen: Set<string> = new Set();
      const linkPattern: RegExp = /<a\b[^>]*\bhref\s*=\s*(["'])([^"']*)\1[^>]*>([\s\S]*?)<\/a\s*>/gi;
      let match: RegExpExecArray | null = linkPattern.exec(content);
      while (match !== null) {
        const href = StaticCatalogHtmlParser.normalizeHref(match[2] as string);
        const title = StaticCatalogHtmlParser.cleanText(match[3] as string);
        if (StaticCatalogHtmlParser.isTaleLink(href, title)) {
          const id = href.substring(1);
          if (!seen.has(id)) {
            seen.add(id);
            tales.push({ id: id, title: title });
          }
        }
        match = linkPattern.exec(content);
      }
      if (tales.length === 0) {
        return StaticCatalogHtmlParser.taleFailure('no tale links found');
      }
      // 保留旧列表按页面名排序的展示语义，同时把大列表排序留在线程池。
      tales.sort((left: TaleRawEntry, right: TaleRawEntry) => left.id.localeCompare(right.id));
      return {
        parserVersion: TALE_LIST_PARSER_VERSION,
        ok: true,
        error: '',
        tales: tales
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'unknown tale parse error';
      return StaticCatalogHtmlParser.taleFailure(message);
    }
  }

  private static catalogFailure(message: string): ScpCatalogPayload {
    return {
      parserVersion: SCP_CATALOG_PARSER_VERSION,
      ok: false,
      error: message,
      entries: []
    };
  }

  private static taleFailure(message: string): TalePayload {
    return {
      parserVersion: TALE_LIST_PARSER_VERSION,
      ok: false,
      error: message,
      tales: []
    };
  }

  /** 只保留 page-content 正文，避免侧栏与页脚导航链接混入结果。 */
  private static pageContent(html: string): string {
    const marker = /<div\b[^>]*\bid\s*=\s*(["'])page-content\1[^>]*>/i.exec(html);
    if (marker === null || marker.index === undefined) {
      return '';
    }
    const start = marker.index + marker[0].length;
    const tail = html.substring(start);
    const endPatterns: RegExp[] = [
      /<div\b[^>]*\bclass\s*=\s*(["'])[^"']*\bpage-tags\b[^"']*\1[^>]*>/i,
      /<div\b[^>]*\bid\s*=\s*(["'])page-info-break\1[^>]*>/i,
      /<div\b[^>]*\bid\s*=\s*(["'])page-options-container\1[^>]*>/i
    ];
    let end = tail.length;
    for (let index: number = 0; index < endPatterns.length; index++) {
      const candidate = endPatterns[index].exec(tail);
      if (candidate !== null && candidate.index !== undefined && candidate.index < end) {
        end = candidate.index;
      }
    }
    return tail.substring(0, end);
  }

  /** 对齐旧 DOM 提取器：优先 .content-panel.series，再回退 .content-panel。 */
  private static catalogPanel(pageContent: string): string {
    const divPattern: RegExp = /<div\b[^>]*>/gi;
    let firstPanelStart = -1;
    let firstPanelEnd = -1;
    let match: RegExpExecArray | null = divPattern.exec(pageContent);
    while (match !== null) {
      const classMatch = /\bclass\s*=\s*(["'])([^"']*)\1/i.exec(match[0]);
      if (classMatch !== null) {
        const classNames = ` ${StaticCatalogHtmlParser.collapseSpace(classMatch[2] as string).toLowerCase()} `;
        if (classNames.indexOf(' content-panel ') >= 0) {
          const start = match.index === undefined ? 0 : match.index + match[0].length;
          if (classNames.indexOf(' series ') >= 0) {
            return StaticCatalogHtmlParser.balancedDivContent(pageContent, start);
          }
          if (firstPanelStart < 0) {
            firstPanelStart = start;
            firstPanelEnd = match.index === undefined ? 0 : match.index;
          }
        }
      }
      match = divPattern.exec(pageContent);
    }
    if (firstPanelStart >= 0) {
      const panel = StaticCatalogHtmlParser.balancedDivContent(pageContent, firstPanelStart);
      if (panel.length > 0) {
        return panel;
      }
      return pageContent.substring(firstPanelEnd);
    }
    return pageContent;
  }

  private static balancedDivContent(source: string, start: number): string {
    const tagPattern: RegExp = /<\/?div\b[^>]*>/gi;
    tagPattern.lastIndex = start;
    let depth = 1;
    let match: RegExpExecArray | null = tagPattern.exec(source);
    while (match !== null) {
      if (/^<\s*\/div/i.test(match[0])) {
        depth--;
        if (depth === 0) {
          return source.substring(start, match.index);
        }
      } else {
        depth++;
      }
      match = tagPattern.exec(source);
    }
    return source.substring(start);
  }

  /** 取链接最近的父元素文本，覆盖「链接只有编号、标题在相邻文本」的系列页结构。 */
  private static nearestParentText(
    source: string,
    lowerSource: string,
    linkStart: number,
    linkEnd: number
  ): string {
    const tags: string[] = ['span', 'li', 'p', 'td', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'];
    let bestStart = -1;
    let bestEnd = -1;
    for (let index: number = 0; index < tags.length; index++) {
      const tag = tags[index];
      const open = lowerSource.lastIndexOf(`<${tag}`, linkStart);
      if (open < 0 || open < bestStart ||
        !StaticCatalogHtmlParser.isTagBoundary(lowerSource, open + tag.length + 1)) {
        continue;
      }
      const closedBeforeLink = lowerSource.lastIndexOf(`</${tag}`, linkStart);
      if (closedBeforeLink > open) {
        continue;
      }
      const close = lowerSource.indexOf(`</${tag}`, linkEnd);
      if (close < linkEnd || close - open > 4096) {
        continue;
      }
      bestStart = open;
      bestEnd = close;
    }
    if (bestStart < 0 || bestEnd <= bestStart) {
      const end = Math.min(source.length, linkEnd + 512);
      return StaticCatalogHtmlParser.cleanText(source.substring(linkStart, end));
    }
    return StaticCatalogHtmlParser.cleanText(source.substring(bestStart, bestEnd));
  }

  private static isTagBoundary(source: string, index: number): boolean {
    if (index >= source.length) {
      return true;
    }
    const value = source.charAt(index);
    return value === '>' || value === '/' || /\s/.test(value);
  }

  private static stripIdPrefix(value: string, id: string): string {
    const index = value.toUpperCase().indexOf(id);
    return index < 0 ? value : value.substring(index + id.length);
  }

  private static cleanCatalogTitle(value: string): string {
    return value
      .replace(/^[\s\-–—:：'"‘’“”\[（(]+/, '')
      .replace(/\[[^\]]*\]\s*$/g, '')
      .replace(/[\s\-–—:：'"‘’“”\]）)]+$/, '')
      .trim();
  }

  /** 保留既有故事索引的导航过滤语义。 */
  private static isTaleLink(href: string, title: string): boolean {
    if (title.length < 2 || href.length < 2 || !href.startsWith('/')) {
      return false;
    }
    const lowerHref = href.toLowerCase();
    if (lowerHref.startsWith('/system:') || lowerHref.startsWith('/_')) {
      return false;
    }
    return lowerHref.indexOf('tales-by') < 0 &&
      !lowerHref.startsWith('/tale') &&
      lowerHref.indexOf('foundation-tales') < 0 &&
      lowerHref.indexOf('canon') < 0 &&
      !lowerHref.startsWith('/user:');
  }

  private static normalizeHref(value: string): string {
    const decoded = StaticCatalogHtmlParser.decodeEntities(value).trim();
    const hash = decoded.indexOf('#');
    return (hash >= 0 ? decoded.substring(0, hash) : decoded).trim();
  }

  private static cleanText(value: string): string {
    const withoutMarkup = value
      .replace(/<(script|style)\b[\s\S]*?<\/\1>/gi, ' ')
      .replace(/<!--[\s\S]*?-->/g, ' ')
      .replace(/<[^>]+>/g, ' ');
    return toSimplifiedChinese(StaticCatalogHtmlParser.collapseSpace(
      StaticCatalogHtmlParser.decodeEntities(withoutMarkup)
    )).trim();
  }

  private static decodeEntities(value: string): string {
    return value
      .replace(/&amp;/gi, '&')
      .replace(/&nbsp;|&#160;|&ensp;|&emsp;|&thinsp;/gi, ' ')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&quot;|&#34;/gi, '"')
      .replace(/&#39;|&apos;/gi, '\'')
      .replace(/&ndash;/gi, '–')
      .replace(/&mdash;/gi, '—')
      .replace(/&minus;/gi, '−')
      .replace(/&lsquo;/gi, '‘')
      .replace(/&rsquo;/gi, '’')
      .replace(/&ldquo;/gi, '“')
      .replace(/&rdquo;/gi, '”')
      .replace(/&hellip;/gi, '…')
      .replace(/&middot;/gi, '·')
      .replace(/&bull;/gi, '•')
      .replace(/&laquo;/gi, '«')
      .replace(/&raquo;/gi, '»')
      .replace(/&#x([0-9a-f]+);/gi, (_whole: string, hex: string): string =>
        StaticCatalogHtmlParser.codePointText(parseInt(hex, 16)))
      .replace(/&#(\d+);/g, (_whole: string, decimal: string): string =>
        StaticCatalogHtmlParser.codePointText(parseInt(decimal, 10)));
  }

  private static collapseSpace(value: string): string {
    return value.replace(/\s+/g, ' ');
  }

  private static codePointText(value: number): string {
    if (!Number.isFinite(value) || value <= 0 || value > 0x10FFFF) {
      return '';
    }
    return String.fromCodePoint(value);
  }
}
