import {
  ViewModelErrorInfo,
  ViewModelLifecycle,
  ViewModelLoadState,
  ViewModelSnapshot
} from 'anomiconbasic';
import {
  CatalogSearchUseCase
} from '../../application/CatalogUseCases';
import { ScpHtmlRequestPriority } from '../../domain/ArticleHtmlRepository';
import {
  CatalogEntry,
  CatalogSnapshot
} from '../../domain/CatalogContracts';
import { filterCatalogEntries } from '../../domain/CatalogRepositories';
import {
  ALL_SERIES_ID,
  DEFAULT_SERIES_ID,
  SCP_SERIES,
  ScpSeriesDescriptor
} from '../../domain/ScpSeriesItem';

const CATALOG_LOAD_TIMEOUT_MS: number = 40 * 1000;
type CatalogSearchTimeoutScheduler = (onTimeout: () => void) => () => void;

function scheduleCatalogSearchTimeout(onTimeout: () => void): () => void {
  const timeoutId = setTimeout(onTimeout, CATALOG_LOAD_TIMEOUT_MS);
  return (): void => clearTimeout(timeoutId);
}

/** Immutable screen projection consumed by the Catalog search View. */
export class CatalogSearchScreenData {
  readonly query: string;
  readonly seriesId: string;
  readonly entries: CatalogEntry[];
  readonly random: CatalogEntry[];
  readonly history: string[];
  readonly catalogPending: boolean;
  readonly loadedSeriesCount: number;
  readonly totalSeriesCount: number;
  readonly allSeriesLoading: boolean;

  constructor(
    query: string,
    seriesId: string,
    entries: CatalogEntry[],
    random: CatalogEntry[],
    history: string[],
    catalogPending: boolean,
    loadedSeriesCount: number = 0,
    totalSeriesCount: number = 0,
    allSeriesLoading: boolean = false
  ) {
    this.query = query;
    this.seriesId = seriesId;
    this.entries = entries.slice();
    this.random = random.slice();
    this.history = history.slice();
    this.catalogPending = catalogPending;
    this.loadedSeriesCount = loadedSeriesCount;
    this.totalSeriesCount = totalSeriesCount;
    this.allSeriesLoading = allSeriesLoading;
  }
}

/** 搜索页 ViewModel：管理目录观察、历史、随机发现和请求 token。 */
@ObservedV2
export class CatalogSearchViewModel implements ViewModelLifecycle {
  @Trace query: string = '';
  @Trace seriesId: string = DEFAULT_SERIES_ID;
  @Trace entries: CatalogEntry[] = [];
  @Trace visibleEntries: CatalogEntry[] = [];
  @Trace randomItems: CatalogEntry[] = [];
  @Trace history: string[] = [];
  @Trace catalogPending: boolean = false;
  @Trace loadedSeriesCount: number = 0;
  @Trace allSeriesLoading: boolean = false;
  @Trace status: ViewModelLoadState = ViewModelLoadState.IDLE;
  @Trace errorMessage: string = '';
  @Trace fetchedAt: number = 0;
  @Trace stale: boolean = false;
  @Trace snapshot: ViewModelSnapshot<CatalogSearchScreenData>;

  private readonly search: CatalogSearchUseCase;
  private readonly randomCount: number;
  private readonly scheduleTimeout: CatalogSearchTimeoutScheduler;
  private token: number = 0;
  private active: boolean = false;
  private disposed: boolean = false;
  private initialized: boolean = false;
  private unsubscribes: Array<() => void> = [];
  private cancelPendingTimeout: (() => void) | undefined = undefined;
  private loadTimedOut: boolean = false;
  private appliedCatalog: CatalogSnapshot | undefined = undefined;
  private readonly allSeriesSnapshots: Map<string, CatalogSnapshot> = new Map();
  private snapshotRevision: number = 0;

  constructor(
    search: CatalogSearchUseCase,
    randomCount: number = 10,
    scheduleTimeout?: CatalogSearchTimeoutScheduler,
    initialSeriesId: string = DEFAULT_SERIES_ID
  ) {
    this.search = search;
    this.randomCount = randomCount;
    this.scheduleTimeout = scheduleTimeout ?? scheduleCatalogSearchTimeout;
    this.seriesId = initialSeriesId === ALL_SERIES_ID ?
      ALL_SERIES_ID : this.descriptor(initialSeriesId).id;
    this.snapshot = new ViewModelSnapshot<CatalogSearchScreenData>(
      ViewModelLoadState.IDLE,
      new CatalogSearchScreenData(
        '',
        this.seriesId,
        [],
        [],
        [],
        false,
        0,
        this.seriesId === ALL_SERIES_ID ? SCP_SERIES.length : 1,
        false
      )
    );
  }

  activate(): void {
    if (this.disposed || this.active) {
      return;
    }
    this.active = true;
    this.publishSnapshot();
    if (!this.initialized) {
      this.initialized = true;
      try {
        this.history = this.search.listHistory();
      } catch (error) {
        // History is optional; a preferences failure must not prevent the
        // catalog itself from becoming usable.
        this.history = [];
        console.warn(`Read search history failed: ${error instanceof Error ? error.message : 'unknown error'}`);
      }
      this.observeCurrentScope();
    } else {
      this.observeCurrentScope();
    }
  }

  deactivate(): void {
    if (this.disposed || !this.active) {
      return;
    }
    this.active = false;
    this.token++;
    this.stopObservation();
    this.allSeriesLoading = false;
    this.publishSnapshot();
  }

  dispose(): void {
    if (this.disposed) {
      return;
    }
    this.deactivate();
    this.disposed = true;
    this.entries = [];
    this.visibleEntries = [];
    this.randomItems = [];
    this.allSeriesSnapshots.clear();
    this.loadedSeriesCount = 0;
    this.publishSnapshot();
  }

  setQuery(query: string): void {
    if (this.disposed) {
      return;
    }
    this.query = query;
    this.publishVisible();
    this.publishSnapshot();
  }

  selectSeries(seriesId: string): void {
    if (this.disposed) {
      return;
    }
    const normalizedId = seriesId === ALL_SERIES_ID ?
      ALL_SERIES_ID : this.descriptor(seriesId).id;
    if (this.seriesId === normalizedId) {
      return;
    }
    // Do not project the previous series while the new cache snapshot is
    // pending.  This also invalidates an old observer in the A→B→A route
    // sequence and keeps search results tied to the selected series.
    this.token++;
    this.stopObservation();
    this.allSeriesSnapshots.clear();
    this.seriesId = normalizedId;
    this.initialized = false;
    this.entries = [];
    this.visibleEntries = [];
    this.randomItems = [];
    this.catalogPending = false;
    this.loadedSeriesCount = 0;
    this.allSeriesLoading = false;
    this.fetchedAt = 0;
    this.stale = false;
    this.errorMessage = '';
    this.status = ViewModelLoadState.IDLE;
    this.publishSnapshot();
    if (this.active) {
      this.observeCurrentScope();
    }
  }

  addHistory(value: string): void {
    if (this.disposed) {
      return;
    }
    this.search.addHistory(value);
    this.history = this.search.listHistory();
    this.publishSnapshot();
  }

  clearHistory(): void {
    if (this.disposed) {
      return;
    }
    this.search.clearHistory();
    this.history = [];
    this.publishSnapshot();
  }

  retry(): void {
    if (this.active) {
      // A retry is an explicit user action.  Do not read the same stale or
      // corrupt cache again; go through the repository's force-refresh path.
      this.observeCurrentScope(true);
    }
  }

  private observeCurrentScope(forceRefresh: boolean = false): void {
    if (this.seriesId === ALL_SERIES_ID) {
      this.observeAllSeries(forceRefresh);
      return;
    }
    this.observeSeries(this.seriesId, forceRefresh);
  }

  private observeSeries(id: string, forceRefresh: boolean = false): void {
    const token = ++this.token;
    this.stopObservation();
    this.allSeriesLoading = false;
    const hasEntries = this.entries.length > 0;
    this.catalogPending = forceRefresh && !hasEntries;
    this.status = forceRefresh && hasEntries ?
      ViewModelLoadState.REFRESHING : ViewModelLoadState.LOADING;
    this.errorMessage = '';
    this.publishSnapshot();
    this.unsubscribes.push(this.search.observe(id, (snapshot: CatalogSnapshot): void => {
      this.applyCurrentSnapshot(id, token, snapshot);
    }));
    if (this.catalogPending) {
      this.armPendingTimeout(id, token);
    }
    this.loadCached(id, token, forceRefresh);
  }

  private async loadCached(id: string, token: number, forceRefresh: boolean = false): Promise<void> {
    try {
      if (!forceRefresh) {
        const cached = await this.search.cached(id);
        if (!this.isCurrent(token, id)) {
          return;
        }
        if (cached !== undefined) {
          // 图鉴页负责重验；搜索页只观察缓存更新。
          this.applyCurrentSnapshot(id, token, cached);
          return;
        }
        if (this.appliedCatalog !== undefined) {
          // 读缓存期间已经收到了更新，不再发起冷加载。
          return;
        }
        this.entries = [];
        this.randomItems = [];
        this.catalogPending = true;
        this.status = ViewModelLoadState.LOADING;
        this.armPendingTimeout(id, token);
        this.publishSnapshot();
      }
      const descriptor = this.descriptor(id);
      const loaded = forceRefresh ? await this.search.refresh(descriptor) : await this.search.load(descriptor);
      this.applyCurrentSnapshot(id, token, loaded);
    } catch (error) {
      if (!this.isCurrent(token, id) || this.loadTimedOut || this.appliedCatalog !== undefined) {
        return;
      }
      this.catalogPending = false;
      this.stopPendingTimeout();
      this.status = ViewModelLoadState.ERROR;
      this.errorMessage = error instanceof Error ? error.message : '搜索目录读取失败';
      this.publishSnapshot();
    }
  }

  private applyCurrentSnapshot(id: string, token: number, snapshot: CatalogSnapshot): void {
    if (!this.isCurrent(token, id) || snapshot.seriesId !== id) {
      return;
    }
    const applied = this.appliedCatalog;
    if (applied !== undefined &&
      (snapshot.fetchedAt < applied.fetchedAt || this.isSameProjection(applied, snapshot))) {
      return;
    }
    this.entries = snapshot.entries.slice();
    // Random discovery is an application concern; keep the ViewModel focused
    // on lifecycle/state projection and request-token guards.
    this.randomItems = this.search.pickRandom(this.entries, this.randomCount);
    this.catalogPending = false;
    this.loadedSeriesCount = 1;
    this.fetchedAt = snapshot.fetchedAt;
    this.stale = snapshot.stale;
    this.errorMessage = snapshot.error;
    this.status = snapshot.partial || snapshot.stale ?
      ViewModelLoadState.PARTIAL : ViewModelLoadState.READY;
    this.appliedCatalog = snapshot;
    this.loadTimedOut = false;
    this.stopPendingTimeout();
    this.publishVisible();
    this.publishSnapshot();
  }

  private observeAllSeries(forceRefresh: boolean = false): void {
    const token = ++this.token;
    this.stopObservation();
    if (forceRefresh) {
      this.allSeriesSnapshots.clear();
      this.loadedSeriesCount = 0;
    }
    this.allSeriesLoading = true;
    this.errorMessage = '';
    const hasEntries = this.entries.length > 0;
    this.catalogPending = !hasEntries;
    this.status = hasEntries ? ViewModelLoadState.REFRESHING : ViewModelLoadState.LOADING;
    this.publishSnapshot();
    for (let index: number = 0; index < SCP_SERIES.length; index++) {
      const descriptor = SCP_SERIES[index];
      this.unsubscribes.push(this.search.observe(descriptor.id, (snapshot: CatalogSnapshot): void => {
        this.applyAllSeriesSnapshot(descriptor.id, token, snapshot);
      }));
    }
    if (this.catalogPending) {
      this.armPendingTimeout(ALL_SERIES_ID, token);
    }
    this.loadAllSeries(token, forceRefresh);
  }

  private async loadAllSeries(token: number, forceRefresh: boolean): Promise<void> {
    if (!forceRefresh) {
      const cachedSnapshots = await Promise.all(
        SCP_SERIES.map((series: ScpSeriesDescriptor): Promise<CatalogSnapshot | undefined> =>
          this.search.cached(series.id))
      );
      if (!this.isCurrent(token, ALL_SERIES_ID)) {
        return;
      }
      for (let index: number = 0; index < SCP_SERIES.length; index++) {
        const snapshot = cachedSnapshots[index];
        if (snapshot !== undefined) {
          this.allSeriesSnapshots.set(SCP_SERIES[index].id, snapshot);
        }
      }
      if (this.allSeriesSnapshots.size > 0) {
        this.projectAllSeriesSnapshots(token, false, 0);
      }
    }

    const missing: ScpSeriesDescriptor[] = forceRefresh ?
      SCP_SERIES.slice() :
      SCP_SERIES.filter((series: ScpSeriesDescriptor): boolean => !this.allSeriesSnapshots.has(series.id));

    if (missing.length === 0) {
      this.allSeriesLoading = false;
      this.projectAllSeriesSnapshots(token, true, 0);
      return;
    }

    let failedCount: number = 0;
    let lastError: string = '';
    for (let index: number = 0; index < missing.length; index++) {
      if (!this.isCurrent(token, ALL_SERIES_ID)) {
        return;
      }
      const descriptor = missing[index];
      const priority = this.allSeriesSnapshots.size === 0 ?
        ScpHtmlRequestPriority.USER_INITIATED : ScpHtmlRequestPriority.BACKGROUND;
      try {
        const loaded = forceRefresh ?
          await this.search.refresh(descriptor) :
          await this.search.load(descriptor, priority);
        if (!this.isCurrent(token, ALL_SERIES_ID)) {
          return;
        }
        this.allSeriesSnapshots.set(descriptor.id, loaded);
        this.projectAllSeriesSnapshots(token, false, failedCount);
      } catch (error) {
        if (!this.isCurrent(token, ALL_SERIES_ID)) {
          return;
        }
        failedCount++;
        lastError = error instanceof Error ? error.message : '目录加载失败';
      }
    }

    if (!this.isCurrent(token, ALL_SERIES_ID)) {
      return;
    }
    this.allSeriesLoading = false;
    this.stopPendingTimeout();
    if (this.allSeriesSnapshots.size === 0) {
      if (!this.loadTimedOut) {
        this.catalogPending = false;
        this.status = ViewModelLoadState.ERROR;
        this.errorMessage = lastError.length > 0 ? lastError : '全部系列目录读取失败';
        this.publishSnapshot();
      }
      return;
    }
    this.projectAllSeriesSnapshots(token, true, failedCount);
  }

  private applyAllSeriesSnapshot(seriesId: string, token: number, snapshot: CatalogSnapshot): void {
    if (!this.isCurrent(token, ALL_SERIES_ID) || snapshot.seriesId !== seriesId) {
      return;
    }
    const existing = this.allSeriesSnapshots.get(seriesId);
    if (existing !== undefined &&
      (snapshot.fetchedAt < existing.fetchedAt || this.isSameProjection(existing, snapshot))) {
      return;
    }
    this.allSeriesSnapshots.set(seriesId, snapshot);
    this.projectAllSeriesSnapshots(token, !this.allSeriesLoading, 0);
  }

  private projectAllSeriesSnapshots(token: number, finished: boolean, failedCount: number): void {
    if (!this.isCurrent(token, ALL_SERIES_ID)) {
      return;
    }
    const merged: CatalogEntry[] = [];
    const seen: Set<string> = new Set<string>();
    let latestFetchedAt: number = 0;
    let anyStale: boolean = false;
    let loadedCount: number = 0;

    for (let seriesIndex: number = 0; seriesIndex < SCP_SERIES.length; seriesIndex++) {
      const snapshot = this.allSeriesSnapshots.get(SCP_SERIES[seriesIndex].id);
      if (snapshot === undefined) {
        continue;
      }
      loadedCount++;
      if (snapshot.fetchedAt > latestFetchedAt) {
        latestFetchedAt = snapshot.fetchedAt;
      }
      if (snapshot.stale || snapshot.partial) {
        anyStale = true;
      }
      for (let entryIndex: number = 0; entryIndex < snapshot.entries.length; entryIndex++) {
        const entry = snapshot.entries[entryIndex];
        if (!seen.has(entry.itemId)) {
          seen.add(entry.itemId);
          merged.push(entry);
        }
      }
    }

    this.entries = merged;
    if (this.randomItems.length === 0 && merged.length > 0) {
      this.randomItems = this.search.pickRandom(merged, this.randomCount);
    }
    this.loadedSeriesCount = loadedCount;
    this.catalogPending = false;
    this.loadTimedOut = false;
    this.stopPendingTimeout();
    this.fetchedAt = latestFetchedAt;
    this.stale = anyStale;
    if (finished && failedCount > 0) {
      this.status = ViewModelLoadState.PARTIAL;
      this.errorMessage = `部分系列目录加载失败，已检索 ${loadedCount}/${SCP_SERIES.length} 个系列`;
    } else {
      this.errorMessage = '';
      this.status = anyStale ? ViewModelLoadState.PARTIAL : ViewModelLoadState.READY;
    }
    this.publishVisible();
    this.publishSnapshot();
  }

  private isSameProjection(previous: CatalogSnapshot, next: CatalogSnapshot): boolean {
    // 缓存通知与请求返回的 source 可以不同，只比较影响界面投影的内容。
    if (previous.fetchedAt !== next.fetchedAt || previous.stale !== next.stale ||
      previous.partial !== next.partial || previous.error !== next.error ||
      previous.entries.length !== next.entries.length) {
      return false;
    }
    for (let index = 0; index < previous.entries.length; index++) {
      const before = previous.entries[index];
      const after = next.entries[index];
      if (before.itemId !== after.itemId || before.title !== after.title || before.description !== after.description) {
        return false;
      }
    }
    return true;
  }

  private publishVisible(): void {
    this.visibleEntries = filterCatalogEntries(this.entries, this.query);
  }

  private armPendingTimeout(id: string, token: number): void {
    this.cancelPendingTimeout = this.scheduleTimeout((): void => {
      if (!this.isCurrent(token, id) || !this.catalogPending) {
        return;
      }
      this.cancelPendingTimeout = undefined;
      // 超时只结束等待提示，不作废当前代次。
      this.loadTimedOut = true;
      this.catalogPending = false;
      this.status = ViewModelLoadState.ERROR;
      this.errorMessage = '目录加载超时，请重试';
      this.publishSnapshot();
    });
  }

  private stopPendingTimeout(): void {
    this.cancelPendingTimeout?.();
    this.cancelPendingTimeout = undefined;
  }

  private stopObservation(): void {
    this.stopPendingTimeout();
    this.loadTimedOut = false;
    this.appliedCatalog = undefined;
    const listeners = this.unsubscribes.splice(0, this.unsubscribes.length);
    for (let index: number = 0; index < listeners.length; index++) {
      listeners[index]();
    }
  }

  private isCurrent(token: number, id: string): boolean {
    return !this.disposed && this.active && token === this.token && id === this.seriesId;
  }

  private publishSnapshot(): void {
    const error = this.errorMessage.length > 0 &&
      (this.status === ViewModelLoadState.ERROR || this.status === ViewModelLoadState.PARTIAL) ?
      new ViewModelErrorInfo(this.errorMessage) : undefined;
    const totalCount = this.seriesId === ALL_SERIES_ID ? SCP_SERIES.length : 1;
    this.snapshotRevision += 1;
    this.snapshot = new ViewModelSnapshot<CatalogSearchScreenData>(
      this.status,
      new CatalogSearchScreenData(
        this.query,
        this.seriesId,
        this.visibleEntries,
        this.randomItems,
        this.history,
        this.catalogPending,
        this.loadedSeriesCount,
        totalCount,
        this.allSeriesLoading
      ),
      error,
      this.fetchedAt > 0 ? this.fetchedAt : undefined,
      this.stale,
      this.status === ViewModelLoadState.PARTIAL,
      this.snapshotRevision
    );
  }

  private descriptor(id: string): ScpSeriesDescriptor {
    for (let index = 0; index < SCP_SERIES.length; index++) {
      if (SCP_SERIES[index].id === id) {
        return SCP_SERIES[index];
      }
    }
    return SCP_SERIES[0];
  }
}
