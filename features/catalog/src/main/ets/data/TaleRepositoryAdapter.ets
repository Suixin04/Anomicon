import { ScpHtmlRequestPriority, ScpHtmlSource } from '../domain/ArticleHtmlRepository';
import { CatalogParser, CatalogSnapshotSource, CatalogTaleEntry, TaleSnapshot } from '../domain/CatalogContracts';
import { TaleRepository, TaleSnapshotListener } from '../domain/CatalogRepositories';
import { ScpCachePolicy } from '../domain/ScpCachePolicy';
import { TALE_LIST_PARSER_VERSION, TaleRawEntry } from '../domain/StaticCatalogContracts';
import { TaleDirectoryCache, TaleIndexPart, TaleListService } from './TaleListService';

interface IndexRead {
  part?: TaleIndexPart;
  network: boolean;
}

function unavailable(part?: TaleIndexPart): boolean {
  return part === undefined || part.needsRetry;
}

function validPart(part?: TaleIndexPart): boolean {
  return part === undefined || (part !== null && Array.isArray(part.tales) &&
    part.tales.length > 0 && Number.isFinite(part.fetchedAt) && typeof part.needsRetry === 'boolean');
}

function mergeEntries(translated: TaleRawEntry[], original: TaleRawEntry[], legacy: TaleRawEntry[]): CatalogTaleEntry[] {
  const seen = new Set<string>();
  const result: CatalogTaleEntry[] = [];
  for (const tale of translated.concat(original, legacy)) {
    if (tale === null || typeof tale !== 'object' || typeof tale.id !== 'string' || typeof tale.title !== 'string') {
      continue;
    }
    const id = tale.id.trim();
    const title = tale.title.trim();
    if (id.length > 0 && title.length >= 2 && !seen.has(id)) {
      seen.add(id);
      result.push(new CatalogTaleEntry(id, title));
    }
  }
  return result;
}

/** A refresh publishes the independently validated indexes together in one cache row. */
export class TaleRepositoryAdapter implements TaleRepository {
  private readonly service: TaleListService;
  private readonly parser: CatalogParser;
  private readonly listeners: TaleSnapshotListener[] = [];
  private generation: number = 0;
  private writing: Promise<void> = Promise.resolve();

  constructor(service: TaleListService, parser: CatalogParser) {
    this.service = service;
    this.parser = parser;
  }

  async getCached(): Promise<TaleSnapshot | undefined> {
    const cache = await this.readCache();
    return cache === undefined ? undefined : this.snapshot(cache, false);
  }

  async load(priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.USER_INITIATED): Promise<TaleSnapshot> {
    const cached = await this.getCached();
    return cached ?? await this.update(false, priority);
  }

  refresh(priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.BACKGROUND): Promise<TaleSnapshot> {
    return this.update(true, priority);
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

  private async readCache(): Promise<TaleDirectoryCache | undefined> {
    await this.writing;
    try {
      const stored = await this.service.read();
      if (stored === undefined) {
        return undefined;
      }
      const cache = JSON.parse(stored.json) as TaleDirectoryCache;
      if (cache === null || cache.parserVersion !== TALE_LIST_PARSER_VERSION || cache.ok !== true ||
        !validPart(cache.translated) || !validPart(cache.original) ||
        (cache.tales !== undefined && !Array.isArray(cache.tales))) {
        return undefined;
      }
      return cache;
    } catch (error) {
      console.warn(`Read tale cache failed: ${error instanceof Error ? error.message : 'invalid cache'}`);
      return undefined;
    }
  }

  private async readSource(original: boolean, force: boolean, priority: ScpHtmlRequestPriority,
    previous?: TaleIndexPart): Promise<IndexRead> {
    try {
      const html = original ? await this.service.loadOriginalHtmlForRequest(force, priority) :
        await this.service.loadHtmlForRequest(force, priority);
      const parsed = await this.parser.parseTales(html.html);
      if (!parsed.ok || parsed.parserVersion !== TALE_LIST_PARSER_VERSION || parsed.tales.length === 0) {
        throw new Error(parsed.error || '故事索引没有有效条目');
      }
      const tales = mergeEntries(parsed.tales, [], []);
      if (tales.length === 0) {
        throw new Error('故事索引没有有效条目');
      }
      const stale = html.source === ScpHtmlSource.STALE_CACHE;
      if (!stale || previous === undefined || html.fetchedAt > previous.fetchedAt) {
        const part: TaleIndexPart = { tales: tales, fetchedAt: html.fetchedAt, needsRetry: stale };
        return { part: part, network: html.source === ScpHtmlSource.NETWORK };
      }
    } catch (error) {
      console.warn(`Load ${original ? 'original' : 'translated'} tale index failed: ${error instanceof Error ? error.message : 'unknown error'}`);
    }
    if (previous === undefined) {
      return { network: false };
    }
    const retained: TaleIndexPart = { tales: previous.tales, fetchedAt: previous.fetchedAt, needsRetry: true };
    return { part: retained, network: false };
  }

  private async update(force: boolean, priority: ScpHtmlRequestPriority): Promise<TaleSnapshot> {
    const generation = ++this.generation;
    const old = await this.readCache();
    const parts = await Promise.all([
      this.readSource(false, force, priority, old?.translated),
      this.readSource(true, force, priority, old?.original)
    ]);
    const cache: TaleDirectoryCache = {
      parserVersion: TALE_LIST_PARSER_VERSION,
      ok: true,
      translated: parts[0].part,
      original: parts[1].part,
      tales: parts[0].part === undefined || parts[1].part === undefined ? old?.tales : undefined
    };
    const next = this.snapshot(cache, parts[0].network || parts[1].network);
    if (next === undefined) {
      throw new Error('翻译和原创故事目录均未加载成功');
    }
    if (generation === this.generation) {
      // Queue complete records so an older in-flight database write cannot replace the latest one.
      this.writing = this.writing.then(() => this.service.put(cache, next.fetchedAt)).catch((error: Object): void => {
        console.warn(`Write tale cache failed: ${error instanceof Error ? error.message : 'unknown error'}`);
      });
      await this.writing;
      if (generation === this.generation) {
        this.notify(next);
      }
    }
    return next;
  }

  private snapshot(cache: TaleDirectoryCache, network: boolean): TaleSnapshot | undefined {
    const translated = cache.translated;
    const original = cache.original;
    const entries = mergeEntries(translated?.tales ?? [], original?.tales ?? [], cache.tales ?? []);
    if (entries.length === 0) {
      return undefined;
    }
    const missing: string[] = [];
    if (unavailable(translated)) {
      missing.push('翻译');
    }
    if (unavailable(original)) {
      missing.push('原创');
    }
    const partial = missing.length > 0;
    const fetchedAt = translated && original ? Math.min(translated.fetchedAt, original.fetchedAt) :
      (translated?.fetchedAt ?? original?.fetchedAt ?? 0);
    const stale = partial || !ScpCachePolicy.isFresh(fetchedAt);
    const source = stale ? CatalogSnapshotSource.STALE_CACHE :
      (network ? CatalogSnapshotSource.NETWORK : CatalogSnapshotSource.CACHE);
    return new TaleSnapshot(entries, source, fetchedAt, stale, partial, TALE_LIST_PARSER_VERSION,
      partial ? `${missing.join('、')}故事目录待更新，可重试` : '');
  }

  private notify(snapshot: TaleSnapshot): void {
    for (const listener of this.listeners.slice()) {
      try {
        listener(snapshot);
      } catch (error) {
        console.warn(`Notify tale snapshot failed: ${error instanceof Error ? error.message : 'unknown error'}`);
      }
    }
  }
}
