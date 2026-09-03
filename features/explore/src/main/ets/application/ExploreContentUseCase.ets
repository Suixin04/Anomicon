import {
  ExploreCombinedSnapshot,
  ExploreContentItem,
  ExploreDataOrigin,
  ExploreEntry,
  ExplorePayload,
  ExploreSource,
  ExploreSourceSnapshot,
  ExploreStoredSnapshot,
  exploreEntriesFromPayload,
  selectExploreIndexes
} from '../domain/ExploreContracts';
import { ExploreListRepository, ExploreTitleResolver } from '../domain/ExploreRepositories';
import {
  isLibraryContentTitlePlaceholder,
  isLibraryScpId,
  LibraryContentKind
} from 'library';

/**
 * 探索索引应用用例。
 *
 * 这里集中处理缓存优先级、stale-while-revalidate、来源合并和每日选择；
 * ViewModel 只消费不可变快照，不再直接知道 RDB、RCP 或静态解析器。
 */
export class ExploreContentUseCase {
  private readonly repository: ExploreListRepository;
  private readonly titleResolver: ExploreTitleResolver | undefined;

  constructor(
    repository: ExploreListRepository,
    titleResolver?: ExploreTitleResolver
  ) {
    this.repository = repository;
    this.titleResolver = titleResolver;
  }

  async loadTopRated(force: boolean = false): Promise<ExploreSourceSnapshot> {
    const snapshot = await this.loadSource(ExploreSource.TOP_RATED, force);
    return this.withResolvedTitles(snapshot);
  }

  async loadRecent(force: boolean = false): Promise<ExploreCombinedSnapshot> {
    const results = await Promise.all([
      this.loadSource(ExploreSource.RECENT_TRANSLATED, force),
      this.loadSource(ExploreSource.RECENT_ORIGINAL, force)
    ]);
    const items: ExploreContentItem[] = [];
    const seen: Set<string> = new Set();
    this.appendRecent(items, seen, await this.resolveTitles(results[0].entries), '翻译主站');
    this.appendRecent(items, seen, await this.resolveTitles(results[1].entries), '原创');
    items.sort((left: ExploreContentItem, right: ExploreContentItem): number => {
      if (left.timestamp !== right.timestamp) {
        return right.timestamp - left.timestamp;
      }
      return left.key.localeCompare(right.key);
    });
    return new ExploreCombinedSnapshot(
      items,
      this.combinedError(results[0], results[1]),
      this.combinedOrigin(results[0], results[1]),
      this.latestFetchedAt(results[0], results[1])
    );
  }

  async loadJokes(dayKey: string, force: boolean = false): Promise<ExploreCombinedSnapshot> {
    const results = await Promise.all([
      this.loadSource(ExploreSource.JOKE_SCPS, force),
      this.loadSource(ExploreSource.JOKE_TALES, force)
    ]);
    const pool: ExploreContentItem[] = [];
    const seen: Set<string> = new Set();
    this.appendJokes(pool, seen, await this.resolveTitles(results[0].entries), LibraryContentKind.SCP, '搞笑 SCP');
    this.appendJokes(pool, seen, results[1].entries, LibraryContentKind.TALE, '搞笑故事');
    const indexes = selectExploreIndexes(pool.length, pool.length, 'combined-jokes', dayKey);
    const items: ExploreContentItem[] = [];
    for (let index = 0; index < indexes.length; index++) {
      items.push(pool[indexes[index]]);
    }
    return new ExploreCombinedSnapshot(
      items,
      this.combinedError(results[0], results[1]),
      this.combinedOrigin(results[0], results[1]),
      this.latestFetchedAt(results[0], results[1])
    );
  }

  /**
   * Explore indexes are allowed to publish a page id as their anchor text.
   * Resolve that placeholder at the application boundary so every Explore
   * surface (top-rated, recent and joke collections) shares the same title
   * semantics as the article and recommendation cards.
   */
  private async withResolvedTitles(snapshot: ExploreSourceSnapshot): Promise<ExploreSourceSnapshot> {
    if (snapshot.entries.length === 0) {
      return snapshot;
    }
    return new ExploreSourceSnapshot(
      await this.resolveTitles(snapshot.entries),
      snapshot.error,
      snapshot.origin,
      snapshot.fetchedAt
    );
  }

  private async resolveTitles(entries: ExploreEntry[]): Promise<ExploreEntry[]> {
    if (this.titleResolver === undefined || entries.length === 0) {
      return entries;
    }
    const tasks: Promise<ExploreEntry>[] = [];
    for (let index = 0; index < entries.length; index++) {
      tasks.push(this.resolveEntryTitle(entries[index]));
    }
    return Promise.all(tasks);
  }

  private async resolveEntryTitle(entry: ExploreEntry): Promise<ExploreEntry> {
    if (!isLibraryScpId(entry.id) ||
      !isLibraryContentTitlePlaceholder(entry.id, entry.title) ||
      this.titleResolver === undefined) {
      return entry;
    }
    try {
      const resolved = (await this.titleResolver(entry.id)).trim();
      if (resolved.length > 0 && !isLibraryContentTitlePlaceholder(entry.id, resolved)) {
        return new ExploreEntry(entry.id, resolved, entry.score, entry.date, entry.comments);
      }
    } catch (_error) {
      // A title is enrichment only; the stable page id remains readable when
      // the catalog index is unavailable or still warming its cache.
    }
    return entry;
  }

  private async loadSource(source: ExploreSource, force: boolean): Promise<ExploreSourceSnapshot> {
    let stored: ExploreStoredSnapshot | undefined = undefined;
    let cachedEntries: ExploreEntry[] = [];
    try {
      stored = await this.repository.read(source);
      if (stored !== undefined) {
        cachedEntries = this.entriesFromStored(stored);
        if (!force && cachedEntries.length > 0 && this.repository.isFresh(stored)) {
          return new ExploreSourceSnapshot(
            cachedEntries,
            '',
            ExploreDataOrigin.FRESH_CACHE,
            stored.parsedAt
          );
        }
      }
    } catch (error) {
      // 派生缓存故障不阻断官网请求；网络结果仍可正常发布。
      console.warn(`Read explore cache failed: ${error instanceof Error ? error.message : 'unknown error'}`);
    }

    try {
      const loaded = await this.repository.load(source, force);
      if (!loaded.payload.ok || loaded.payload.entries.length === 0) {
        const message = loaded.payload.error.length > 0 ? loaded.payload.error : '解析结果为空';
        return cachedEntries.length > 0 ?
          new ExploreSourceSnapshot(
            cachedEntries,
            '暂时无法更新，正在显示缓存内容',
            ExploreDataOrigin.STALE_CACHE,
            stored?.parsedAt ?? loaded.fetchedAt
          ) :
          new ExploreSourceSnapshot([], message, loaded.origin, loaded.fetchedAt);
      }
      const entries = exploreEntriesFromPayload(loaded.payload);
      if (loaded.origin !== ExploreDataOrigin.STALE_CACHE) {
        // Serialize the derived write with this load. A detached write could
        // finish after a newer force load and replace it with an older result.
        try {
          await this.repository.put(source, loaded.payload, loaded.fetchedAt);
        } catch (error) {
          // Persistence is an optimization; keep the valid network snapshot
          // visible while retaining a diagnostic for the next investigation.
          console.warn(`Write explore cache failed: ${error instanceof Error ? error.message : 'unknown error'}`);
        }
      }
      const staleMessage = loaded.origin === ExploreDataOrigin.STALE_CACHE ?
        '网络不可用，正在显示缓存内容' : '';
      return new ExploreSourceSnapshot(entries, staleMessage, loaded.origin, loaded.fetchedAt);
    } catch (error) {
      if (cachedEntries.length > 0) {
        return new ExploreSourceSnapshot(
          cachedEntries,
          '暂时无法更新，正在显示缓存内容',
          ExploreDataOrigin.STALE_CACHE,
          stored?.parsedAt ?? 0
        );
      }
      return new ExploreSourceSnapshot(
        [],
        error instanceof Error ? error.message : '官网内容加载失败',
        ExploreDataOrigin.NETWORK,
        0
      );
    }
  }

  private entriesFromStored(stored: ExploreStoredSnapshot): ExploreEntry[] {
    try {
      const payload = JSON.parse(stored.json) as ExplorePayload;
      if (!payload.ok || payload.entries.length === 0) {
        return [];
      }
      return exploreEntriesFromPayload(payload);
    } catch (_error) {
      return [];
    }
  }

  private combinedError(first: ExploreSourceSnapshot, second: ExploreSourceSnapshot): string {
    if (first.entries.length === 0 && second.entries.length === 0) {
      return first.error.length > 0 ? first.error : second.error;
    }
    if (first.error.length > 0 || second.error.length > 0) {
      return '正在显示已载入的部分内容';
    }
    return '';
  }

  private combinedOrigin(first: ExploreSourceSnapshot, second: ExploreSourceSnapshot): ExploreDataOrigin {
    // A mixed snapshot is only as fresh as its stalest source.  Giving NETWORK
    // precedence used to mark a network+stale pair as fresh, so the collection
    // VM skipped revalidation and the UI hid the partial warning.
    if (first.origin === ExploreDataOrigin.STALE_CACHE || second.origin === ExploreDataOrigin.STALE_CACHE) {
      return ExploreDataOrigin.STALE_CACHE;
    }
    if (first.origin === ExploreDataOrigin.NETWORK || second.origin === ExploreDataOrigin.NETWORK) {
      return ExploreDataOrigin.NETWORK;
    }
    return ExploreDataOrigin.FRESH_CACHE;
  }

  private latestFetchedAt(first: ExploreSourceSnapshot, second: ExploreSourceSnapshot): number {
    return Math.max(first.fetchedAt, second.fetchedAt);
  }

  private appendRecent(
    target: ExploreContentItem[],
    seen: Set<string>,
    entries: ExploreEntry[],
    sourceLabel: string
  ): void {
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index];
      if (!seen.has(entry.id)) {
        seen.add(entry.id);
        target.push(new ExploreContentItem(
          entry,
          isLibraryScpId(entry.id) ?
            LibraryContentKind.SCP : LibraryContentKind.WIKI,
          sourceLabel,
          this.parseSourceDate(entry.date)
        ));
      }
    }
  }

  private appendJokes(
    target: ExploreContentItem[],
    seen: Set<string>,
    entries: ExploreEntry[],
    kind: LibraryContentKind,
    sourceLabel: string
  ): void {
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index];
      const key = `${kind}:${entry.id}`;
      if (!seen.has(key)) {
        seen.add(key);
        target.push(new ExploreContentItem(entry, kind, sourceLabel));
      }
    }
  }

  private parseSourceDate(value: string): number {
    if (value.length === 0) {
      return 0;
    }
    if (/^\d{4}-\d{2}-\d{2}/.test(value)) {
      const parsed = new Date(value).getTime();
      return Number.isFinite(parsed) ? parsed : 0;
    }
    const parts = value.split(' ');
    if (parts.length < 4) {
      return 0;
    }
    const months: string[] = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const month = months.indexOf(parts[1]);
    const time = parts[3].split(':');
    if (month < 0 || time.length < 2) {
      return 0;
    }
    const result = new Date(
      Number(parts[2]),
      month,
      Number(parts[0]),
      Number(time[0]),
      Number(time[1])
    ).getTime();
    return Number.isFinite(result) ? result : 0;
  }
}
