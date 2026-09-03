import {
  ScpHtmlRequestPriority,
  ScpHtmlLoadResult,
  ScpHtmlSource
} from '../domain/ArticleHtmlRepository';
import {
  CatalogParser,
  CatalogSnapshotSource,
  CatalogTaleEntry,
  TaleParseResult,
  TaleSnapshot
} from '../domain/CatalogContracts';
import { TaleRepository, TaleSnapshotListener } from '../domain/CatalogRepositories';
import { ScpCachePolicy } from '../domain/ScpCachePolicy';
import {
  TALE_LIST_PARSER_VERSION,
  TalePayload,
  TaleRawEntry
} from '../domain/StaticCatalogContracts';
import {
  ScpStoredTaleList,
  TaleListService
} from './TaleListService';

/** 故事列表 Data adapter；持久化与解析依赖由 feature composition 显式注入。 */
export class TaleRepositoryAdapter implements TaleRepository {
  private readonly service: TaleListService;
  private readonly parser: CatalogParser;
  private readonly listeners: Array<TaleSnapshotListener> = [];

  constructor(service: TaleListService, parser: CatalogParser) {
    this.service = service;
    this.parser = parser;
  }

  async getCached(): Promise<TaleSnapshot | undefined> {
    let stored: ScpStoredTaleList | undefined = undefined;
    try {
      stored = await this.service.read();
    } catch (error) {
      // The tale list is a rebuildable cache.  Continue to the network path
      // when RDB reads fail instead of turning a transient cache error into a
      // page-level failure.
      console.warn(`Read tale cache failed: ${error instanceof Error ? error.message : 'unknown error'}`);
      return undefined;
    }
    if (stored === undefined) {
      return undefined;
    }
    return this.decodeStored(stored);
  }

  async load(priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.USER_INITIATED): Promise<TaleSnapshot> {
    const cached = await this.getCached();
    if (cached !== undefined) {
      return cached;
    }
    return this.fetchAndParse(priority);
  }

  async refresh(priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.BACKGROUND): Promise<TaleSnapshot> {
    const cached = await this.getCached();
    const results = await this.loadSources(true, priority);
    if (results.length === 0 && cached !== undefined) {
      return cached;
    }
    const parsed = await this.parseSources(results);
    const tales = this.validatedTales(parsed);
    const rawTales: TaleRawEntry[] = [];
    for (let index = 0; index < tales.length; index++) {
      const tale = tales[index];
      const rawTale: TaleRawEntry = { id: tale.id, title: tale.title };
      rawTales.push(rawTale);
    }
    const payload: TalePayload = {
      parserVersion: parsed.parserVersion,
      ok: parsed.ok,
      error: typeof parsed.error === 'string' ? parsed.error : '',
      tales: rawTales
    };
    const fetchedAt = this.latestFetchedAt(results);
    await this.persist(payload, fetchedAt);
    const stale = this.hasStaleSource(results);
    const snapshot = new TaleSnapshot(
      tales,
      stale ? CatalogSnapshotSource.STALE_CACHE :
        (results.some((result: ScpHtmlLoadResult): boolean => result.source === ScpHtmlSource.NETWORK) ?
          CatalogSnapshotSource.NETWORK : CatalogSnapshotSource.CACHE),
      fetchedAt,
      stale,
      false,
      parsed.parserVersion
    );
    this.notify(snapshot);
    return snapshot;
  }

  subscribe(listener: TaleSnapshotListener): () => void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
    return (): void => {
      const index = this.listeners.indexOf(listener);
      if (index >= 0) {
        this.listeners.splice(index, 1);
      }
    };
  }

  private async fetchAndParse(priority: ScpHtmlRequestPriority): Promise<TaleSnapshot> {
    const results = await this.loadSources(false, priority);
    if (results.length === 0) {
      throw new Error('故事目录网络请求失败');
    }
    const parsed = await this.parseSources(results);
    const tales = this.validatedTales(parsed);
    const rawTales: TaleRawEntry[] = [];
    for (let index = 0; index < tales.length; index++) {
      const tale = tales[index];
      const rawTale: TaleRawEntry = { id: tale.id, title: tale.title };
      rawTales.push(rawTale);
    }
    const payload: TalePayload = {
      parserVersion: parsed.parserVersion,
      ok: parsed.ok,
      error: typeof parsed.error === 'string' ? parsed.error : '',
      tales: rawTales
    };
    const fetchedAt = this.latestFetchedAt(results);
    await this.persist(payload, fetchedAt);
    const stale = this.hasStaleSource(results);
    const snapshot = new TaleSnapshot(
      tales,
      stale ? CatalogSnapshotSource.STALE_CACHE :
        (results.some((result: ScpHtmlLoadResult): boolean => result.source === ScpHtmlSource.NETWORK) ?
          CatalogSnapshotSource.NETWORK : CatalogSnapshotSource.CACHE),
      fetchedAt,
      stale,
      false,
      parsed.parserVersion
    );
    this.notify(snapshot);
    return snapshot;
  }

  private decodeStored(stored: ScpStoredTaleList): TaleSnapshot | undefined {
    try {
      const payload = JSON.parse(stored.json) as TalePayload;
      if (payload === undefined || payload === null || typeof payload !== 'object' ||
        payload.parserVersion !== TALE_LIST_PARSER_VERSION ||
        payload.ok !== true || !Array.isArray(payload.tales)) {
        return undefined;
      }
      const tales = this.normalize(payload.tales.map((tale) =>
        new CatalogTaleEntry(tale.id, tale.title)));
      if (tales.length === 0) {
        return undefined;
      }
      return new TaleSnapshot(
        tales,
        CatalogSnapshotSource.CACHE,
        stored.parsedAt,
        !ScpCachePolicy.isFresh(stored.parsedAt),
        false,
        payload.parserVersion
      );
    } catch (error) {
      return undefined;
    }
  }

  private validatedTales(parsed: TaleParseResult): CatalogTaleEntry[] {
    if (parsed === undefined || parsed === null || typeof parsed !== 'object') {
      throw new Error('故事目录解析结果不是对象');
    }
    if (!Array.isArray(parsed.tales)) {
      throw new Error('故事目录解析结果字段不完整');
    }
    const tales = this.normalize(parsed.tales);
    if (parsed.parserVersion !== TALE_LIST_PARSER_VERSION || parsed.ok !== true || tales.length === 0) {
      throw new Error(parsed.parserVersion !== TALE_LIST_PARSER_VERSION ?
        `故事目录解析器版本不兼容：${parsed.parserVersion}` :
        (parsed.ok === true ? '故事目录解析结果为空' :
          `故事目录解析失败：${typeof parsed.error === 'string' ? parsed.error : '未知错误'}`));
    }
    return tales;
  }

  private async persist(payload: TalePayload, fetchedAt: number): Promise<void> {
    try {
      await this.service.put(payload, fetchedAt);
    } catch (error) {
      // Persistence is an acceleration layer; a valid network response is
      // still useful when the local database is read-only/full/unavailable.
      console.warn(`Write tale cache failed: ${error instanceof Error ? error.message : 'unknown error'}`);
    }
  }

  /** 主站翻译故事与中文分部原创故事分别请求，单一来源故障不遮蔽另一来源。 */
  private async loadSources(
    forceNetwork: boolean,
    priority: ScpHtmlRequestPriority
  ): Promise<ScpHtmlLoadResult[]> {
    const results: ScpHtmlLoadResult[] = [];
    const main = await this.service.loadHtmlForRequest(forceNetwork, priority).catch((error: Object): undefined => {
      console.warn(`Load translated tale index failed: ${error instanceof Error ? error.message : 'unknown error'}`);
      return undefined;
    });
    if (main !== undefined) {
      results.push(main);
    }
    const original = await this.service.loadOriginalHtmlForRequest(forceNetwork, priority)
      .catch((error: Object): undefined => {
        console.warn(`Load original tale index failed: ${error instanceof Error ? error.message : 'unknown error'}`);
        return undefined;
      });
    if (original !== undefined) {
      results.push(original);
    }
    return results;
  }

  private async parseSources(results: ScpHtmlLoadResult[]): Promise<TaleParseResult> {
    const all: CatalogTaleEntry[] = [];
    let parserVersion: number = TALE_LIST_PARSER_VERSION;
    const errors: string[] = [];
    for (let index = 0; index < results.length; index++) {
      const parsed = await this.parser.parseTales(results[index].html);
      parserVersion = Math.max(parserVersion, parsed.parserVersion);
      if (parsed.ok) {
        for (let taleIndex = 0; taleIndex < parsed.tales.length; taleIndex++) {
          all.push(parsed.tales[taleIndex]);
        }
      } else if (parsed.error.length > 0) {
        errors.push(parsed.error);
      }
    }
    return {
      parserVersion: parserVersion,
      ok: all.length > 0,
      error: all.length > 0 ? '' : errors.join('；'),
      tales: all
    };
  }

  private latestFetchedAt(results: ScpHtmlLoadResult[]): number {
    let latest: number = 0;
    for (let index = 0; index < results.length; index++) {
      latest = Math.max(latest, results[index].fetchedAt);
    }
    return latest;
  }

  private hasStaleSource(results: ScpHtmlLoadResult[]): boolean {
    return results.some((result: ScpHtmlLoadResult): boolean => result.source === ScpHtmlSource.STALE_CACHE);
  }

  private normalize(tales: CatalogTaleEntry[]): CatalogTaleEntry[] {
    const seen: Set<string> = new Set<string>();
    const result: CatalogTaleEntry[] = [];
    for (let index = 0; index < tales.length; index++) {
      const tale = tales[index];
      if (tale === undefined || tale === null || typeof tale !== 'object' ||
        typeof tale.id !== 'string' || typeof tale.title !== 'string') {
        continue;
      }
      const id = tale.id.trim();
      const title = tale.title.trim();
      if (id.length === 0 || title.length < 2 || seen.has(id)) {
        continue;
      }
      seen.add(id);
      result.push(new CatalogTaleEntry(id, title));
    }
    return result;
  }

  private notify(snapshot: TaleSnapshot): void {
    const listeners = this.listeners.slice();
    for (let index = 0; index < listeners.length; index++) {
      try {
        listeners[index](snapshot);
      } catch (error) {
        console.warn(`Notify tale snapshot failed: ${error instanceof Error ? error.message : 'unknown error'}`);
      }
    }
  }
}
