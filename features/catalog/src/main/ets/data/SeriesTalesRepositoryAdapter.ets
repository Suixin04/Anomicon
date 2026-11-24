import {
  ArticleHtmlRepository,
  ScpHtmlRequestPriority
} from '../domain/ArticleHtmlRepository';
import { ScpCachePolicy } from '../domain/ScpCachePolicy';
import {
  resolveSeriesTalesEditionPageId,
  SERIES_TALES_PARSER_VERSION,
  SeriesRelatedTaleEntry,
  SeriesTalesBucketPayload,
  SeriesTalesEditionPayload,
  SeriesTalesRepository,
  seriesTalesEditionUrlOf
} from '../domain/SeriesTalesContracts';
import { SeriesTalesEditionParser } from './SeriesTalesEditionParser';

const CACHE_KEY_PREFIX: string = 'tales-edition:';

export interface SeriesTalesCacheRecord {
  readonly seriesId: string;
  readonly json: string;
  readonly parsedAt: number;
}

export interface SeriesTalesCacheStore {
  get(key: string): Promise<SeriesTalesCacheRecord | undefined>;
  put(record: SeriesTalesCacheRecord): Promise<void>;
}

class CachedSeriesTalesIndex {
  readonly fetchedAt: number;
  readonly byScpId: Map<string, SeriesRelatedTaleEntry[]>;

  constructor(fetchedAt: number, byScpId: Map<string, SeriesRelatedTaleEntry[]>) {
    this.fetchedAt = fetchedAt;
    this.byScpId = byScpId;
  }
}

function cloneEntries(entries: SeriesRelatedTaleEntry[]): SeriesRelatedTaleEntry[] {
  const result: SeriesRelatedTaleEntry[] = [];
  for (let index: number = 0; index < entries.length; index++) {
    const item = entries[index];
    result.push(new SeriesRelatedTaleEntry(item.id, item.title));
  }
  return result;
}

function indexFromPayload(payload: SeriesTalesEditionPayload): Map<string, SeriesRelatedTaleEntry[]> {
  const map: Map<string, SeriesRelatedTaleEntry[]> = new Map();
  for (let index: number = 0; index < payload.buckets.length; index++) {
    const bucket = payload.buckets[index];
    if (typeof bucket.scpId !== 'string' || !Array.isArray(bucket.tales)) {
      continue;
    }
    const scpKey = bucket.scpId.trim().toUpperCase();
    if (scpKey.length === 0) {
      continue;
    }
    const entries: SeriesRelatedTaleEntry[] = [];
    for (let taleIndex: number = 0; taleIndex < bucket.tales.length; taleIndex++) {
      const tale = bucket.tales[taleIndex];
      if (typeof tale.id === 'string' && typeof tale.title === 'string' &&
        tale.id.trim().length > 0 && tale.title.trim().length > 0) {
        entries.push(new SeriesRelatedTaleEntry(tale.id.trim(), tale.title.trim()));
      }
    }
    if (entries.length > 0) {
      map.set(scpKey, entries);
    }
  }
  return map;
}

function parseStoredPayload(
  rawJson: string,
  expectedPageId: string
): SeriesTalesEditionPayload | undefined {
  try {
    const parsed = JSON.parse(rawJson) as SeriesTalesEditionPayload;
    if (
      parsed === null ||
      typeof parsed !== 'object' ||
      parsed.version !== SERIES_TALES_PARSER_VERSION ||
      parsed.pageId !== expectedPageId ||
      !Array.isArray(parsed.buckets)
    ) {
      return undefined;
    }
    return parsed;
  } catch (_error) {
    return undefined;
  }
}

function isNotFoundError(error: Object): boolean {
  const message = error instanceof Error ? error.message : String(error);
  return /\b404\b/.test(message);
}

/**
 * Wiki 系列故事版（`scp-series-*-tales-edition` / `scp-series-cn-*-tales-edition`）仓储适配器：
 * 内存索引 -> 持久化派生缓存（6h 新鲜窗）-> `ArticleHtmlRepository` 抓取并解析 -> 失败回退旧缓存，
 * 并对暂未建页的 404 系列故事版做会话内负缓存。
 */
export class SeriesTalesRepositoryAdapter implements SeriesTalesRepository {
  private readonly articleHtmlRepository: ArticleHtmlRepository;
  private readonly cacheStore: SeriesTalesCacheStore;
  private readonly memoryCache: Map<string, CachedSeriesTalesIndex> = new Map();
  private readonly missingPages: Set<string> = new Set();
  private readonly inflight: Map<string, Promise<Map<string, SeriesRelatedTaleEntry[]>>> = new Map();

  constructor(
    articleHtmlRepository: ArticleHtmlRepository,
    cacheStore: SeriesTalesCacheStore
  ) {
    this.articleHtmlRepository = articleHtmlRepository;
    this.cacheStore = cacheStore;
  }

  async listCuratedTalesForScp(
    scpId: string,
    priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.BACKGROUND
  ): Promise<SeriesRelatedTaleEntry[]> {
    const pageId = resolveSeriesTalesEditionPageId(scpId);
    if (pageId === undefined || this.missingPages.has(pageId)) {
      return [];
    }

    const scpKey = scpId.trim().toUpperCase();
    const cached = this.memoryCache.get(pageId);
    if (cached !== undefined && ScpCachePolicy.isFresh(cached.fetchedAt)) {
      return cloneEntries(cached.byScpId.get(scpKey) ?? []);
    }

    let pending = this.inflight.get(pageId);
    if (pending === undefined) {
      pending = this.loadPageIndex(pageId, priority);
      this.inflight.set(pageId, pending);
      pending.then((): void => {
        this.inflight.delete(pageId);
      }).catch((): void => {
        this.inflight.delete(pageId);
      });
    }

    const indexMap = await pending;
    return cloneEntries(indexMap.get(scpKey) ?? []);
  }

  private async loadPageIndex(
    pageId: string,
    priority: ScpHtmlRequestPriority
  ): Promise<Map<string, SeriesRelatedTaleEntry[]>> {
    const cacheKey = `${CACHE_KEY_PREFIX}${pageId}`;
    let storedRecord: SeriesTalesCacheRecord | undefined = undefined;
    let storedIndex: Map<string, SeriesRelatedTaleEntry[]> | undefined = undefined;

    try {
      storedRecord = await this.cacheStore.get(cacheKey);
      if (storedRecord !== undefined) {
        const storedPayload = parseStoredPayload(storedRecord.json, pageId);
        if (storedPayload !== undefined) {
          storedIndex = indexFromPayload(storedPayload);
          if (ScpCachePolicy.isFresh(storedRecord.parsedAt)) {
            this.memoryCache.set(pageId, new CachedSeriesTalesIndex(storedRecord.parsedAt, storedIndex));
            return storedIndex;
          }
        }
      }
    } catch (error) {
      console.warn(
        `Read series tales cache failed (${pageId}): ${error instanceof Error ? error.message : 'unknown error'}`
      );
    }

    try {
      const htmlResult = await this.articleHtmlRepository.loadHtml(
        seriesTalesEditionUrlOf(pageId),
        false,
        priority
      );
      const payload = SeriesTalesEditionParser.parse(htmlResult.html, pageId);
      const parsedMap = indexFromPayload(payload);
      this.memoryCache.set(pageId, new CachedSeriesTalesIndex(htmlResult.fetchedAt, parsedMap));
      try {
        await this.cacheStore.put({
          seriesId: cacheKey,
          json: JSON.stringify(payload),
          parsedAt: htmlResult.fetchedAt
        });
      } catch (writeError) {
        console.warn(
          `Write series tales cache failed (${pageId}): ${writeError instanceof Error ? writeError.message : 'unknown error'}`
        );
      }
      return parsedMap;
    } catch (fetchError) {
      if (storedIndex !== undefined && storedRecord !== undefined) {
        return storedIndex;
      }
      if (fetchError !== undefined && isNotFoundError(fetchError as Object)) {
        this.missingPages.add(pageId);
      }
      return new Map();
    }
  }
}
