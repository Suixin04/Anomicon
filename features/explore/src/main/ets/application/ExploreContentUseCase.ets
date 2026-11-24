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

  async loadTopRated(
    force: boolean = false,
    onProgress?: (snapshot: ExploreSourceSnapshot) => void
  ): Promise<ExploreSourceSnapshot> {
    const snapshot = await this.loadSource(ExploreSource.TOP_RATED, force);
    onProgress?.(snapshot);
    return this.withResolvedTitles(snapshot, onProgress);
  }

  async loadRecent(
    force: boolean = false,
    onProgress?: (snapshot: ExploreCombinedSnapshot) => void
  ): Promise<ExploreCombinedSnapshot> {
    return this.loadSources(
      [ExploreSource.RECENT_TRANSLATED, ExploreSource.RECENT_ORIGINAL],
      force,
      [true, true],
      (snapshots: ExploreSourceSnapshot[]): ExploreCombinedSnapshot =>
        this.mergeRecent(snapshots[0], snapshots[1]),
      onProgress
    );
  }

  private mergeRecent(first: ExploreSourceSnapshot, second: ExploreSourceSnapshot): ExploreCombinedSnapshot {
    const items: ExploreContentItem[] = [];
    const seen: Set<string> = new Set();
    this.appendRecent(items, seen, first.entries, '主站译文');
    this.appendRecent(items, seen, second.entries, '原创');
    items.sort((left: ExploreContentItem, right: ExploreContentItem): number => {
      if (left.timestamp !== right.timestamp) {
        return right.timestamp - left.timestamp;
      }
      return left.key.localeCompare(right.key);
    });
    const pair: ExploreSourceSnapshot[] = [first, second];
    return new ExploreCombinedSnapshot(
      items,
      this.combinedError(pair),
      this.combinedOrigin(pair),
      this.latestFetchedAt(pair)
    );
  }

  async loadJokes(
    dayKey: string,
    force: boolean = false,
    onProgress?: (snapshot: ExploreCombinedSnapshot) => void
  ): Promise<ExploreCombinedSnapshot> {
    return this.loadSources(
      [ExploreSource.JOKE_SCPS, ExploreSource.JOKE_SCPS_CN, ExploreSource.JOKE_TALES],
      force,
      [true, true, false],
      (snapshots: ExploreSourceSnapshot[]): ExploreCombinedSnapshot =>
        this.mergeJokes(dayKey, snapshots[0], snapshots[1], snapshots[2]),
      onProgress
    );
  }

  private mergeJokes(
    dayKey: string,
    mainJokes: ExploreSourceSnapshot,
    cnJokes: ExploreSourceSnapshot,
    jokeTales: ExploreSourceSnapshot
  ): ExploreCombinedSnapshot {
    const pool: ExploreContentItem[] = [];
    const seen: Set<string> = new Set();
    this.appendJokes(pool, seen, mainJokes.entries, LibraryContentKind.SCP, '搞笑 SCP');
    this.appendJokes(pool, seen, cnJokes.entries, LibraryContentKind.SCP, '原创搞笑 SCP');
    this.appendJokes(pool, seen, jokeTales.entries, LibraryContentKind.TALE, '搞笑故事');
    const indexes = selectExploreIndexes(pool.length, pool.length, 'combined-jokes', dayKey);
    const items: ExploreContentItem[] = [];
    for (let index = 0; index < indexes.length; index++) {
      items.push(pool[indexes[index]]);
    }
    const all: ExploreSourceSnapshot[] = [mainJokes, cnJokes, jokeTales];
    return new ExploreCombinedSnapshot(
      items,
      this.combinedError(all),
      this.combinedOrigin(all),
      this.latestFetchedAt(all)
    );
  }

  /** Publish parsed sources as they settle; optional title enrichment never gates initial items. */
  private async loadSources(
    sources: ExploreSource[],
    force: boolean,
    resolveFlags: boolean[],
    merge: (snapshots: ExploreSourceSnapshot[]) => ExploreCombinedSnapshot,
    onProgress?: (snapshot: ExploreCombinedSnapshot) => void
  ): Promise<ExploreCombinedSnapshot> {
    const snapshots: ExploreSourceSnapshot[] = sources.map((): ExploreSourceSnapshot => new ExploreSourceSnapshot([]));
    const publish = (): void => {
      if (onProgress === undefined) {
        return;
      }
      const hasAny = snapshots.some((item: ExploreSourceSnapshot): boolean => item.entries.length > 0);
      if (hasAny) {
        onProgress(merge(snapshots));
      }
    };
    const tasks: Promise<void>[] = sources.map((source: ExploreSource, index: number): Promise<void> =>
      this.loadSource(source, force).then(async (snapshot: ExploreSourceSnapshot): Promise<void> => {
        snapshots[index] = snapshot;
        publish();
        if (resolveFlags[index]) {
          snapshots[index] = await this.withResolvedTitles(snapshot);
        }
      })
    );
    await Promise.all(tasks);
    return merge(snapshots);
  }

  /**
   * Explore indexes are allowed to publish a page id as their anchor text.
   * Resolve that placeholder at the application boundary so every Explore
   * surface (top-rated, recent and joke collections) shares the same title
   * semantics as the article and recommendation cards.
   */
  private async withResolvedTitles(
    snapshot: ExploreSourceSnapshot,
    onProgress?: (snapshot: ExploreSourceSnapshot) => void
  ): Promise<ExploreSourceSnapshot> {
    if (this.titleResolver === undefined || snapshot.entries.length === 0) {
      return snapshot;
    }
    const entries = snapshot.entries.slice();
    const current = (): ExploreSourceSnapshot =>
      new ExploreSourceSnapshot(entries, snapshot.error, snapshot.origin, snapshot.fetchedAt);
    await Promise.all(entries.map(async (entry: ExploreEntry, index: number): Promise<void> => {
      const resolved = await this.resolveEntryTitle(entry);
      if (resolved !== entry) {
        entries[index] = resolved;
        onProgress?.(current());
      }
    }));
    return current();
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
        error instanceof Error ? error.message : '主站档案加载失败',
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

  private combinedError(snapshots: ExploreSourceSnapshot[]): string {
    let hasAnyEntries: boolean = false;
    let firstError: string = '';
    for (let index = 0; index < snapshots.length; index++) {
      const current = snapshots[index];
      if (current.entries.length > 0) {
        hasAnyEntries = true;
      }
      if (firstError.length === 0 && current.error.length > 0) {
        firstError = current.error;
      }
    }
    if (!hasAnyEntries) {
      return firstError;
    }
    return firstError.length > 0 ? '正在显示已载入的部分内容' : '';
  }

  private combinedOrigin(snapshots: ExploreSourceSnapshot[]): ExploreDataOrigin {
    // A mixed snapshot is only as fresh as its stalest source.  Giving NETWORK
    // precedence used to mark a stale pair/triple as fresh, so the collection
    // VM skipped revalidation and the UI hid the partial warning.
    let hasNetwork: boolean = false;
    for (let index = 0; index < snapshots.length; index++) {
      const origin = snapshots[index].origin;
      if (origin === ExploreDataOrigin.STALE_CACHE) {
        return ExploreDataOrigin.STALE_CACHE;
      }
      if (origin === ExploreDataOrigin.NETWORK) {
        hasNetwork = true;
      }
    }
    return hasNetwork ? ExploreDataOrigin.NETWORK : ExploreDataOrigin.FRESH_CACHE;
  }

  private latestFetchedAt(snapshots: ExploreSourceSnapshot[]): number {
    let latest: number = 0;
    for (let index = 0; index < snapshots.length; index++) {
      if (snapshots[index].fetchedAt > latest) {
        latest = snapshots[index].fetchedAt;
      }
    }
    return latest;
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
