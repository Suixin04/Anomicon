import {
  ScpHtmlLoadResult,
  ScpHtmlRequestPriority,
  ScpHtmlSource
} from '../domain/ArticleHtmlRepository';
import {
  CatalogEntry,
  CatalogParser,
  CatalogSnapshot,
  CatalogSnapshotSource,
  normalizeCatalogItemId
} from '../domain/CatalogContracts';
import { CatalogRepository, CatalogSnapshotListener } from '../domain/CatalogRepositories';
import { ScpCachePolicy } from '../domain/ScpCachePolicy';
import { ScpSeriesDescriptor } from '../domain/ScpSeriesItem';
import {
  SCP_CATALOG_PARSER_VERSION,
  ScpCatalogPayload,
  ScpCatalogRawEntry
} from '../domain/StaticCatalogContracts';
import { CachedArticleRepo } from './CachedArticleRepo';
import {
  ScpCatalogCacheService,
  ScpStoredCatalog
} from './ScpCatalogCacheService';

/**
 * 目录 Data adapter。缓存、HTML 仓储和解析器均由 feature composition 显式注入，
 * 向上层只暴露窄化的 CatalogRepository 端口。
 */
export class CatalogRepoAdapter implements CatalogRepository {
  private readonly cache: ScpCatalogCacheService;
  private readonly html: CachedArticleRepo;
  private readonly parser: CatalogParser;

  constructor(
    cache: ScpCatalogCacheService,
    html: CachedArticleRepo,
    parser: CatalogParser
  ) {
    this.cache = cache;
    this.html = html;
    this.parser = parser;
  }

  async getCached(seriesId: string): Promise<CatalogSnapshot | undefined> {
    let stored: ScpStoredCatalog | undefined = undefined;
    try {
      stored = await this.cache.get(seriesId);
    } catch (error) {
      // The catalog cache is a rebuildable acceleration layer.  A corrupt or
      // temporarily unavailable RDB must not prevent the network path from
      // loading a usable snapshot.
      console.warn(`Read catalog cache failed: ${error instanceof Error ? error.message : 'unknown error'}`);
      return undefined;
    }
    if (stored === undefined) {
      return undefined;
    }
    return this.decodeStored(seriesId, stored);
  }

  async load(
    series: ScpSeriesDescriptor,
    priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.USER_INITIATED
  ): Promise<CatalogSnapshot> {
    const cached = await this.getCached(series.id);
    // application/VM 会在拿到 stale 快照后另行调 refresh，保证首屏不等待网络。
    if (cached !== undefined) {
      return cached;
    }
    return this.fetchAndParse(series, false, priority);
  }

  async refresh(
    series: ScpSeriesDescriptor,
    priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.BACKGROUND
  ): Promise<CatalogSnapshot> {
    const cached = await this.getCached(series.id);
    // An explicit refresh is a user request and must bypass the fresh HTML
    // cache.  The repository still falls back to stale data on network error.
    const htmlResult = await this.html.loadHtml(series.url, true, priority);
    // 条件请求失败时保留旧派生快照，不把旧 HTML 的解析时间当作新鲜时间。
    if (htmlResult.source === ScpHtmlSource.STALE_CACHE && cached !== undefined) {
      // Keep the cache timestamp so a failed request cannot make the snapshot
      // look fresh.  Retain the cache source rank, however: this is the same
      // durable snapshot already projected by the VM, and a lower
      // STALE_CACHE rank would be rejected as an out-of-order update.  The
      // stale/partial/error fields carry the failed refresh provenance to the
      // UI without replacing the usable entries.
      return new CatalogSnapshot(
        cached.seriesId,
        cached.entries,
        cached.source,
        cached.fetchedAt,
        true,
        true,
        cached.parserVersion,
        '目录更新失败，正在显示缓存内容'
      );
    }
    return this.parseResult(series.id, htmlResult);
  }

  subscribe(seriesId: string, listener: CatalogSnapshotListener): () => void {
    return this.cache.subscribe(seriesId, (stored: ScpStoredCatalog): void => {
      const snapshot = this.decodeStored(seriesId, stored);
      if (snapshot !== undefined) {
        listener(snapshot);
      }
    });
  }

  private async fetchAndParse(
    series: ScpSeriesDescriptor,
    forceNetwork: boolean,
    priority: ScpHtmlRequestPriority
  ): Promise<CatalogSnapshot> {
    const htmlResult = await this.html.loadHtml(series.url, forceNetwork, priority);
    return this.parseResult(series.id, htmlResult);
  }

  private async parseResult(seriesId: string, result: ScpHtmlLoadResult): Promise<CatalogSnapshot> {
    const parsed = await this.parser.parseCatalog(result.html);
    if (parsed === undefined || parsed === null || typeof parsed !== 'object') {
      throw new Error('目录解析结果不是对象');
    }
    if (!Array.isArray(parsed.entries)) {
      throw new Error('目录解析结果字段不完整');
    }
    const validEntries = this.normalizeEntries(parsed.entries);
    const stale = result.source === ScpHtmlSource.STALE_CACHE;
    if (parsed.parserVersion !== SCP_CATALOG_PARSER_VERSION ||
      parsed.ok !== true || validEntries.length === 0) {
      const message = parsed.parserVersion !== SCP_CATALOG_PARSER_VERSION ?
        `目录解析器版本不兼容：${parsed.parserVersion}` :
        (parsed.ok === true ? '目录解析结果为空' :
          `目录解析失败：${typeof parsed.error === 'string' ? parsed.error : '未知错误'}`);
      throw new Error(message);
    }
    const staleMessage = stale ? '目录更新失败，正在显示缓存内容' : '';
    const snapshot = new CatalogSnapshot(
      seriesId,
      validEntries,
      this.sourceOf(result),
      result.fetchedAt,
      stale,
      stale,
      parsed.parserVersion,
      staleMessage
    );
    // parsed_at 绑定原始 HTML fetchedAt；STALE_CACHE 不会因此获得新的新鲜度。
    try {
      const rawEntries: ScpCatalogRawEntry[] = [];
      for (let index = 0; index < validEntries.length; index++) {
        const entry = validEntries[index];
        const rawEntry: ScpCatalogRawEntry = {
          itemId: entry.itemId,
          title: entry.title,
          description: entry.description
        };
        rawEntries.push(rawEntry);
      }
      const payload: ScpCatalogPayload = {
        parserVersion: parsed.parserVersion,
        ok: parsed.ok,
        error: stale ? staleMessage : (typeof parsed.error === 'string' ? parsed.error : ''),
        entries: rawEntries
      };
      await this.cache.put(new ScpStoredCatalog(
        seriesId,
        JSON.stringify(payload),
        result.fetchedAt
      ));
    } catch (error) {
      // 派生目录是加速层，写入失败不应阻断已取得的网络结果。
      console.warn(`Store catalog snapshot failed: ${error instanceof Error ? error.message : 'unknown error'}`);
    }
    return snapshot;
  }

  private decodeStored(seriesId: string, stored: ScpStoredCatalog): CatalogSnapshot | undefined {
    try {
      const payload = JSON.parse(stored.json) as ScpCatalogPayload;
      if (payload === undefined || payload === null || typeof payload !== 'object' ||
        payload.parserVersion !== SCP_CATALOG_PARSER_VERSION ||
        payload.ok !== true || !Array.isArray(payload.entries)) {
        return undefined;
      }
      const entries = this.normalizeEntries(payload.entries.map((entry) =>
        new CatalogEntry(entry.itemId, entry.title, entry.description ?? '')));
      if (entries.length === 0) {
        return undefined;
      }
      return new CatalogSnapshot(
        seriesId,
        entries,
        CatalogSnapshotSource.CACHE,
        stored.parsedAt,
        !ScpCachePolicy.isFresh(stored.parsedAt),
        typeof payload.error === 'string' && payload.error.trim().length > 0,
        payload.parserVersion,
        typeof payload.error === 'string' ? payload.error : ''
      );
    } catch (error) {
      return undefined;
    }
  }

  private normalizeEntries(entries: CatalogEntry[]): CatalogEntry[] {
    const seen: Set<string> = new Set<string>();
    const normalized: CatalogEntry[] = [];
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index];
      if (entry === undefined || entry === null || typeof entry !== 'object' ||
        typeof entry.itemId !== 'string' || typeof entry.title !== 'string') {
        continue;
      }
      const itemId = normalizeCatalogItemId(entry.itemId);
      const title = entry.title.trim();
      const description = typeof entry.description === 'string' ? entry.description.trim() : '';
      if (!/^SCP-(?:(?:[A-Z]{2,4}-)?\d+|[A-Z0-9]*\d+[A-Z0-9]*)(?:-[A-Z0-9]+)*$/i.test(itemId) ||
        title.length === 0 || seen.has(itemId)) {
        continue;
      }
      seen.add(itemId);
      normalized.push(new CatalogEntry(itemId, title, description));
    }
    return normalized;
  }

  private sourceOf(result: ScpHtmlLoadResult): CatalogSnapshotSource {
    if (result.source === ScpHtmlSource.STALE_CACHE) {
      return CatalogSnapshotSource.STALE_CACHE;
    }
    if (result.source === ScpHtmlSource.FRESH_CACHE) {
      return CatalogSnapshotSource.CACHE;
    }
    return CatalogSnapshotSource.NETWORK;
  }
}
