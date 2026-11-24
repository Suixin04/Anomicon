import { ScpHtmlRequestPriority } from './ArticleHtmlRepository';

export const SERIES_TALES_PARSER_VERSION: number = 1;

const WIKI_BASE_URL: string = 'https://scp-wiki-cn.wikidot.com/';

/** 某篇 SCP 关联的故事条目（Wiki 系列故事版或标题匹配回退来源统一使用）。 */
export class SeriesRelatedTaleEntry {
  readonly id: string;
  readonly title: string;

  constructor(id: string, title: string) {
    this.id = id;
    this.title = title;
  }
}

export interface SeriesRelatedTalePayload {
  id: string;
  title: string;
}

export interface SeriesTalesBucketPayload {
  scpId: string;
  tales: SeriesRelatedTalePayload[];
}

export interface SeriesTalesEditionPayload {
  version: number;
  pageId: string;
  buckets: SeriesTalesBucketPayload[];
}

/** 从 Wiki 系列故事版按条目编号查询关联故事的领域端口。 */
export interface SeriesTalesRepository {
  listCuratedTalesForScp(scpId: string, priority?: ScpHtmlRequestPriority): Promise<SeriesRelatedTaleEntry[]>;
}

/**
 * 将 SCP 编号映射为中文 Wiki 系列故事版页面名（如 `SCP-173 -> scp-series-1-tales-edition`，
 * `SCP-CN-2000 -> scp-series-cn-3-tales-edition`）。搞笑条目 `-J` 与非系列编号返回 undefined。
 */
export function resolveSeriesTalesEditionPageId(scpId: string): string | undefined {
  const normalized = scpId.trim().toUpperCase();
  if (normalized.length === 0 || /-J$/i.test(normalized)) {
    return undefined;
  }

  const cnMatch = /^SCP-CN-(\d{3,4})(?:-[A-Z0-9-]+)?$/i.exec(normalized);
  if (cnMatch !== null) {
    const seriesNumber = Math.floor(Number(cnMatch[1]) / 1000) + 1;
    if (seriesNumber >= 1 && seriesNumber <= 5) {
      return `scp-series-cn-${seriesNumber}-tales-edition`;
    }
    return undefined;
  }

  const mainMatch = /^SCP-(\d{3,4})(?:-[A-Z0-9-]+)?$/i.exec(normalized);
  if (mainMatch !== null) {
    const seriesNumber = Math.floor(Number(mainMatch[1]) / 1000) + 1;
    if (seriesNumber >= 1 && seriesNumber <= 10) {
      return `scp-series-${seriesNumber}-tales-edition`;
    }
    return undefined;
  }

  return undefined;
}

export function seriesTalesEditionUrlOf(pageId: string): string {
  return `${WIKI_BASE_URL}${pageId.trim().toLowerCase()}`;
}

/**
 * 精确匹配文本/路径中的 SCP 编号引用，要求编号左右均不与字母数字粘连，
 * 且非搞笑/归档/已失效后缀的编号不会被 `-j`/`-ex`/`-arc`/`-d`/`-cu` 误匹配。
 */
export function matchesExactScpReference(text: string, scpId: string): boolean {
  const haystack = text.trim().toLowerCase();
  const needle = scpId.trim().toLowerCase();
  if (haystack.length === 0 || needle.length === 0) {
    return false;
  }

  const hasVariantSuffix = /-(?:j|ex|arc|d|cu)$/i.test(needle);
  let startIndex: number = 0;
  while (startIndex <= haystack.length - needle.length) {
    const matchIndex = haystack.indexOf(needle, startIndex);
    if (matchIndex < 0) {
      return false;
    }
    startIndex = matchIndex + 1;

    if (matchIndex > 0) {
      const prevChar = haystack.charAt(matchIndex - 1);
      if (/[a-z0-9]/i.test(prevChar)) {
        continue;
      }
    }

    const endIndex = matchIndex + needle.length;
    if (endIndex < haystack.length) {
      const nextChar = haystack.charAt(endIndex);
      if (/[a-z0-9]/i.test(nextChar)) {
        continue;
      }
      if (!hasVariantSuffix) {
        const after = haystack.substring(endIndex);
        if (/^-(?:j|ex|arc|d|cu)(?![a-z0-9])/i.test(after)) {
          continue;
        }
      }
    }

    return true;
  }
  return false;
}
