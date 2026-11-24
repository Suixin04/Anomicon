import {
  SERIES_TALES_PARSER_VERSION,
  SeriesRelatedTalePayload,
  SeriesTalesBucketPayload,
  SeriesTalesEditionPayload
} from '../domain/SeriesTalesContracts';
import { StaticCatalogHtmlParser } from './StaticCatalogHtmlParser';

const SCP_LINK_SLUG_REGEX: RegExp =
  /^scp-(?:(?:[a-z]{2,4}-)?\d+|[a-z0-9]*\d+[a-z0-9]*)(?:-[a-z0-9]+)*$/i;

const CN_WIKI_HTTPS_ORIGIN: string = 'https://scp-wiki-cn.wikidot.com';
const CN_WIKI_HTTP_ORIGIN: string = 'http://scp-wiki-cn.wikidot.com';

/**
 * 解析中文 Wiki `scp-series-*-tales-edition` 与 `scp-series-cn-*-tales-edition` 页面的静态 HTML：
 * 顶层 `<li>` 给出 SCP 编号，其内嵌 `<ul>` 中收编该条目对应的关联故事链接，同时过滤掉未翻译占位
 * （`class="newpage"`）及站务导航链接。
 */
export class SeriesTalesEditionParser {
  static parse(html: string, pageId: string): SeriesTalesEditionPayload {
    const content = StaticCatalogHtmlParser.pageContent(html);
    if (content.length === 0) {
      return {
        version: SERIES_TALES_PARSER_VERSION,
        pageId: pageId,
        buckets: []
      };
    }

    const topLis = SeriesTalesEditionParser.extractTopLevelListItems(content);
    const bucketByScpId: Map<string, SeriesTalesBucketPayload> = new Map();
    const seenByScpId: Map<string, Set<string>> = new Map();
    const orderedScpIds: string[] = [];

    for (let index: number = 0; index < topLis.length; index++) {
      const block = topLis[index];
      const nestedListMatch = /<(?:ul|ol)\b/i.exec(block);
      if (nestedListMatch === null || nestedListMatch.index === undefined) {
        continue;
      }
      const head = block.substring(0, nestedListMatch.index);
      const tail = block.substring(nestedListMatch.index);

      const headLinkMatch = /<a\b[^>]*\bhref\s*=\s*(["'])([^"']*)\1[^>]*>/i.exec(head);
      if (headLinkMatch === null) {
        continue;
      }
      const scpSlug = SeriesTalesEditionParser.extractInternalSlug(headLinkMatch[2] as string);
      if (scpSlug.length === 0 || !SCP_LINK_SLUG_REGEX.test(scpSlug)) {
        continue;
      }

      const scpId = scpSlug.toUpperCase();
      let bucket = bucketByScpId.get(scpId);
      let seen = seenByScpId.get(scpId);
      if (bucket === undefined || seen === undefined) {
        bucket = { scpId: scpId, tales: [] };
        seen = new Set<string>();
        bucketByScpId.set(scpId, bucket);
        seenByScpId.set(scpId, seen);
        orderedScpIds.push(scpId);
      }

      const taleLinkRe: RegExp = /<a\b([^>]*)\bhref\s*=\s*(["'])([^"']*)\2([^>]*)>([\s\S]*?)<\/a\s*>/gi;
      let taleMatch: RegExpExecArray | null = taleLinkRe.exec(tail);
      while (taleMatch !== null) {
        const beforeAttrs = taleMatch[1] as string;
        const href = taleMatch[3] as string;
        const afterAttrs = taleMatch[4] as string;
        const inner = taleMatch[5] as string;
        const fullAttrs = `${beforeAttrs} ${afterAttrs}`;

        if (!/\bnewpage\b/i.test(fullAttrs)) {
          const taleSlug = SeriesTalesEditionParser.extractInternalSlug(href);
          if (taleSlug.length > 0 && taleSlug !== scpSlug && !seen.has(taleSlug)) {
            const cleanTitle = StaticCatalogHtmlParser.cleanText(inner);
            if (cleanTitle.length > 0) {
              seen.add(taleSlug);
              const entry: SeriesRelatedTalePayload = {
                id: taleSlug,
                title: cleanTitle
              };
              bucket.tales.push(entry);
            }
          }
        }
        taleMatch = taleLinkRe.exec(tail);
      }
    }

    const buckets: SeriesTalesBucketPayload[] = [];
    for (let index: number = 0; index < orderedScpIds.length; index++) {
      const bucket = bucketByScpId.get(orderedScpIds[index]);
      if (bucket !== undefined && bucket.tales.length > 0) {
        buckets.push(bucket);
      }
    }

    return {
      version: SERIES_TALES_PARSER_VERSION,
      pageId: pageId,
      buckets: buckets
    };
  }

  private static extractTopLevelListItems(content: string): string[] {
    const tokenRe: RegExp = /<(\/?)(ul|ol|li)\b[^>]*>/gi;
    let ulDepth: number = 0;
    let liDepth: number = 0;
    let topLiStart: number = -1;
    const topLis: string[] = [];

    let match: RegExpExecArray | null = tokenRe.exec(content);
    while (match !== null) {
      const isClosing = match[1] === '/';
      const tag = (match[2] as string).toLowerCase();
      const matchStart = match.index ?? 0;
      const matchEnd = matchStart + match[0].length;

      if (tag === 'ul' || tag === 'ol') {
        if (!isClosing) {
          ulDepth += 1;
        } else {
          if (ulDepth > 0) {
            ulDepth -= 1;
          }
          if (ulDepth === 0 && topLiStart >= 0) {
            topLis.push(content.substring(topLiStart, matchStart));
            topLiStart = -1;
            liDepth = 0;
          }
        }
      } else if (tag === 'li') {
        if (!isClosing) {
          if (ulDepth === 1 && topLiStart < 0) {
            topLiStart = matchEnd;
            liDepth = 1;
          } else if (topLiStart >= 0) {
            liDepth += 1;
          }
        } else if (topLiStart >= 0) {
          liDepth -= 1;
          if (liDepth === 0) {
            topLis.push(content.substring(topLiStart, matchStart));
            topLiStart = -1;
          }
        }
      }

      match = tokenRe.exec(content);
    }

    return topLis;
  }

  private static extractInternalSlug(rawHref: string): string {
    let cleaned = StaticCatalogHtmlParser.normalizeHref(rawHref);
    if (cleaned.length === 0) {
      return '';
    }
    const lower = cleaned.toLowerCase();
    if (lower.startsWith(`${CN_WIKI_HTTPS_ORIGIN}/`)) {
      cleaned = cleaned.substring(CN_WIKI_HTTPS_ORIGIN.length);
    } else if (lower.startsWith(`${CN_WIKI_HTTP_ORIGIN}/`)) {
      cleaned = cleaned.substring(CN_WIKI_HTTP_ORIGIN.length);
    } else if (!cleaned.startsWith('/')) {
      return '';
    }

    const queryIndex = cleaned.indexOf('?');
    if (queryIndex >= 0) {
      cleaned = cleaned.substring(0, queryIndex);
    }
    const slug = cleaned.replace(/^\/+|\/+$/g, '').trim().toLowerCase();
    if (slug.length === 0 || slug.includes('/') || slug.includes(':') || slug.startsWith('_')) {
      return '';
    }
    return slug;
  }
}
