import {
  SCP_CATALOG_PARSER_VERSION,
  ScpCatalogPayload,
  ScpCatalogRawEntry
} from '../domain/StaticCatalogContracts';
import { ScpCatalogCacheService, ScpStoredCatalog } from './ScpCatalogCacheService';

/** Optional cold-start loader supplied by the composition root. */
export type CatalogSeriesTitleLoader =
  (seriesId: string) => Promise<ScpCatalogRawEntry[]>;

/** 从编号定位主站或原创 CN 系列目录缓存；每 1000 个编号对应一个系列。 */
function seriesIdOf(itemId: string): string {
  const match = /^scp-(cn-)?([0-9]{1,4})(?:-[a-z0-9]+)*$/i.exec(itemId.trim());
  if (match === null) {
    return '';
  }
  const value = Number(match[2]);
  if (!Number.isInteger(value) || value < 0 || value > 9999) {
    return '';
  }
  const seriesIndex = Math.floor(value / 1000);
  if (match[1] !== undefined && match[1].length > 0) {
    return seriesIndex === 0 ? 'scp-series-cn' : `scp-series-cn-${seriesIndex + 1}`;
  }
  return seriesIndex === 0 ? 'scp-series' : `scp-series-${seriesIndex + 1}`;
}

function isJokeScpId(itemId: string): boolean {
  return /^scp-(?:cn-)?[a-z0-9]+(?:-[a-z0-9]+)*-j(?:-|$)/i.test(itemId);
}

function jokeSeriesIdOf(itemId: string): string {
  return /^scp-cn-/i.test(itemId) ? 'scp-joke-cn' : 'scp-joke';
}

/**
 * SCP 单篇正文的 page-title 通常只有编号；项目名称以系列目录为准。
 * 默认消费本地派生缓存；冷启动时由组合根注入的系列加载器补齐缺失标题。
 */
export class ScpCatalogTitleResolver {
  private readonly catalogStore: ScpCatalogCacheService;
  private readonly seriesLoader: CatalogSeriesTitleLoader | undefined;
  /** Deduplicate cold-start title lookups when Explore resolves a whole page. */
  private readonly loadingSeries: Map<string, Promise<ScpCatalogRawEntry[]>> =
    new Map<string, Promise<ScpCatalogRawEntry[]>>();

  constructor(
    catalogStore: ScpCatalogCacheService,
    seriesLoader?: CatalogSeriesTitleLoader
  ) {
    this.catalogStore = catalogStore;
    this.seriesLoader = seriesLoader;
  }

  async resolve(itemId: string): Promise<string> {
    const normalizedId = itemId.trim().toLowerCase();
    const titles = await this.resolveMany([normalizedId]);
    return titles.get(normalizedId) ?? '';
  }

  async resolveMany(itemIds: string[]): Promise<Map<string, string>> {
    const requestedBySeries: Map<string, Set<string>> = new Map<string, Set<string>>();
    for (let index = 0; index < itemIds.length; index++) {
      const normalizedId = itemIds[index].trim().toLowerCase();
      const seriesId = isJokeScpId(normalizedId) ?
        jokeSeriesIdOf(normalizedId) : seriesIdOf(normalizedId);
      if (seriesId.length === 0) {
        continue;
      }
      const requested = requestedBySeries.get(seriesId) ?? new Set<string>();
      requested.add(normalizedId);
      requestedBySeries.set(seriesId, requested);
    }

    const result: Map<string, string> = new Map<string, string>();
    const seriesIds = Array.from(requestedBySeries.keys());
    for (let index = 0; index < seriesIds.length; index++) {
      const seriesId = seriesIds[index];
      let stored: ScpStoredCatalog | undefined = undefined;
      try {
        stored = await this.catalogStore.get(seriesId);
      } catch (_error) {
        // A cold article may race feature initialization. Treat an unavailable
        // cache as empty so the injected loader can still fetch the series.
        stored = undefined;
      }
      const requested = requestedBySeries.get(seriesId)!;
      const cachedEntries = stored === undefined ? [] : this.entriesOf(stored);
      this.collectTitles(cachedEntries, requested, result);
      // Explore and deep links can open an article before the catalog screen
      // has warmed its cache. Load just the missing series on demand, keeping
      // title enrichment independent from the article HTML parser.
      if (this.seriesLoader !== undefined && this.hasUnresolved(requested, result)) {
        try {
          const loadedEntries = await this.loadSeries(seriesId);
          this.collectTitles(loadedEntries, requested, result);
        } catch (_error) {
          // Title metadata is optional; the article remains readable when the
          // cold catalog request is unavailable.
        }
      }
    }
    return result;
  }

  private loadSeries(seriesId: string): Promise<ScpCatalogRawEntry[]> {
    const existing = this.loadingSeries.get(seriesId);
    if (existing !== undefined) {
      return existing;
    }
    if (this.seriesLoader === undefined) {
      return Promise.resolve([]);
    }
    const task = this.seriesLoader(seriesId).finally((): void => {
      this.loadingSeries.delete(seriesId);
    });
    this.loadingSeries.set(seriesId, task);
    return task;
  }

  private hasUnresolved(requested: Set<string>, result: Map<string, string>): boolean {
    const ids = Array.from(requested);
    for (let index = 0; index < ids.length; index++) {
      if (!result.has(ids[index])) {
        return true;
      }
    }
    return false;
  }

  private collectTitles(
    entries: ScpCatalogRawEntry[],
    requested: Set<string>,
    result: Map<string, string>
  ): void {
    for (let entryIndex = 0; entryIndex < entries.length; entryIndex++) {
      const entry = entries[entryIndex];
      const normalizedId = entry.itemId.trim().toLowerCase();
      const title = entry.title.trim();
      if (requested.has(normalizedId) && title.length > 0 && title.toLowerCase() !== normalizedId) {
        result.set(normalizedId, title);
      }
    }
  }

  private entriesOf(stored: ScpStoredCatalog): ScpCatalogRawEntry[] {
    try {
      const payload = JSON.parse(stored.json) as ScpCatalogPayload;
      return payload.parserVersion === SCP_CATALOG_PARSER_VERSION &&
        payload.ok && Array.isArray(payload.entries) ? payload.entries : [];
    } catch (error) {
      return [];
    }
  }
}
