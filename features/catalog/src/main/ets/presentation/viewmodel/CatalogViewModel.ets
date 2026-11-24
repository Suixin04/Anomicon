import { ScpHtmlRequestPriority } from '../../domain/ArticleHtmlRepository';
import { ViewModelLifecycle, ViewModelLoadState } from 'anomiconbasic';
import {
  CatalogContentUseCase,
  CatalogPreviewUseCase
} from '../../application/CatalogUseCases';
import {
  CatalogEntry,
  CatalogPreview,
  CatalogSnapshot,
  CatalogSnapshotSource
} from '../../domain/CatalogContracts';
import {
  filterCatalogEntries
} from '../../domain/CatalogRepositories';
import {
  DEFAULT_SERIES_ID,
  findCatalogSeriesById,
  SCP_SERIES,
  ScpSeriesDescriptor
} from '../../domain/ScpSeriesItem';

/** 图鉴页面的只读状态投影，供 View 观察。 */
@ObservedV2
export class CatalogViewModel implements ViewModelLifecycle {
  @Trace seriesId: string = DEFAULT_SERIES_ID;
  @Trace query: string = '';
  @Trace entries: CatalogEntry[] = [];
  @Trace visibleEntries: CatalogEntry[] = [];
  @Trace status: ViewModelLoadState = ViewModelLoadState.IDLE;
  @Trace loading: boolean = false;
  @Trace refreshing: boolean = false;
  @Trace errorMessage: string = '';
  @Trace stale: boolean = false;
  @Trace partial: boolean = false;

  private readonly content: CatalogContentUseCase;
  private readonly preview: CatalogPreviewUseCase;
  private generation: number = 0;
  private active: boolean = false;
  private disposed: boolean = false;
  private initialized: boolean = false;
  /** Re-run a stale/refresh request that was invalidated while hidden. */
  private refreshOnActivate: boolean = false;
  private unsubscribe: (() => void) | undefined = undefined;
  /** Only one request generation may own the screen loading flags at a time. */
  private activeLoadTask: Promise<void> | undefined = undefined;
  private activeLoadGeneration: number = 0;
  private activeLoadSeriesId: string = '';
  /** Notifications emitted by cache writes while the owning request is pending. */
  private observedSnapshot: CatalogSnapshot | undefined = undefined;
  private observerGeneration: number = 0;
  /** Monotonic acceptance watermark for cache/network snapshots. */
  private appliedFetchedAt: number = 0;
  private appliedSourceRank: number = 0;
  /** Owner epoch for card preview callbacks; incremented on every page exit. */
  private previewOwnerEpoch: number = 0;

  constructor(content: CatalogContentUseCase, preview: CatalogPreviewUseCase) {
    this.content = content;
    this.preview = preview;
  }

  activate(): void {
    if (this.disposed || this.active) {
      return;
    }
    this.active = true;
    this.subscribeSeries(this.seriesId);
    if (this.refreshOnActivate) {
      this.refreshOnActivate = false;
      this.loadInternal(true).catch((): void => {
        // The failure is already represented by the VM state.
      });
    } else if (!this.initialized) {
      this.initialized = true;
      this.load().catch((): void => {
        // 错误已经发布到状态，View 可通过 retry 再次触发。
      });
    }
  }

  deactivate(): void {
    if (this.disposed) {
      return;
    }
    // ArkUI can deliver both destination and component lifecycle callbacks.
    // Invalidate preview owners even when the VM was already inactive so a
    // late card callback can never publish into a hidden/reused page.
    this.previewOwnerEpoch++;
    if (!this.active) {
      return;
    }
    const interruptedStatus = this.status;
    const interruptedRequest = this.loading || this.refreshing ||
      interruptedStatus === ViewModelLoadState.LOADING ||
      interruptedStatus === ViewModelLoadState.REFRESHING;
    this.active = false;
    this.generation++;
    this.stopObservation();
    this.loading = false;
    this.refreshing = false;
    if (this.entries.length === 0) {
      this.status = ViewModelLoadState.IDLE;
      // If the first request was invalidated while the page was hidden, allow
      // the next activation to start it again instead of keeping an empty VM
      // marked as initialized.
      this.initialized = false;
    } else if (interruptedStatus === ViewModelLoadState.LOADING ||
      interruptedStatus === ViewModelLoadState.REFRESHING) {
      // If a request was invalidated while hidden, retain the snapshot but
      // preserve its stale/partial provenance for the next projection.
      this.status = this.partial || this.stale ?
        ViewModelLoadState.PARTIAL : ViewModelLoadState.READY;
      this.initialized = false;
    }
    // A stale snapshot may already have changed the visible status to
    // PARTIAL while its background revalidation is still in flight.  Capture
    // that case explicitly so activation cannot strand the VM on old data.
    // Preserve an explicitly interrupted request even when the previous
    // snapshot was still considered fresh.  Otherwise a force-refresh started
    // just before a navigation transition would be silently lost on re-entry.
    this.refreshOnActivate = interruptedRequest || (this.entries.length > 0 && this.stale);
  }

  dispose(): void {
    if (this.disposed) {
      return;
    }
    this.deactivate();
    this.disposed = true;
    this.previewOwnerEpoch++;
    this.observedSnapshot = undefined;
    this.entries = [];
    this.visibleEntries = [];
  }

  selectSeries(seriesId: string): void {
    if (this.disposed || this.seriesId === seriesId) {
      return;
    }
    // A series can be selected while the Tab is hidden.  Retaining the old
    // entries/initialized flag would make the next activation skip loading
    // and briefly render data belonging to the previous series.
    this.stopObservation();
    this.generation++;
    this.previewOwnerEpoch++;
    this.observedSnapshot = undefined;
    this.appliedFetchedAt = 0;
    this.appliedSourceRank = 0;
    this.seriesId = this.descriptor(seriesId).id;
    this.initialized = false;
    this.refreshOnActivate = false;
    this.entries = [];
    this.visibleEntries = [];
    this.loading = false;
    this.refreshing = false;
    this.errorMessage = '';
    this.stale = false;
    this.partial = false;
    this.status = ViewModelLoadState.IDLE;
    if (this.active) {
      this.subscribeSeries(this.seriesId);
      this.load().catch((): void => {
        // 状态已经包含错误信息。
      });
    }
  }

  setQuery(query: string): void {
    if (this.disposed) {
      return;
    }
    this.query = query;
    this.publishVisible();
  }

  load(): Promise<void> {
    return this.loadInternal(false);
  }

  refresh(): Promise<void> {
    return this.loadInternal(true);
  }

  retry(): Promise<void> {
    return this.loadInternal(true);
  }

  /** 视图在卡片出现时调用；预览仍由独立端口提供。 */
  loadPreview(
    itemId: string,
    onRefreshed?: (preview: CatalogPreview) => void,
    forceRefresh: boolean = false
  ): Promise<CatalogPreview> {
    const ownerEpoch = this.previewOwnerEpoch;
    if (this.disposed || !this.active) {
      return Promise.reject(new Error('目录页面已离开'));
    }
    const guardedRefresh = onRefreshed === undefined ? undefined : (preview: CatalogPreview): void => {
      if (this.isPreviewOwnerCurrent(ownerEpoch)) {
        onRefreshed(preview);
      }
    };
    // Normalize a synchronous adapter throw and reject a result that belongs
    // to a card which disappeared while the shared preview task was running.
    return Promise.resolve()
      .then(() => this.preview.execute(
        itemId, guardedRefresh, ScpHtmlRequestPriority.VISIBLE, forceRefresh))
      .then((preview: CatalogPreview): CatalogPreview => {
        if (!this.isPreviewOwnerCurrent(ownerEpoch)) {
          throw new Error('目录页面已离开');
        }
        return preview;
      });
  }

  prefetchPreviews(itemIds: string[]): void {
    if (!this.disposed && this.active) {
      this.preview.prefetch(itemIds);
    }
  }

  cancelPreviewPrefetch(itemIds: string[]): void {
    this.preview.cancelPrefetch(itemIds);
  }

  private loadInternal(
    forceRefresh: boolean,
    priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.USER_INITIATED
  ): Promise<void> {
    // A View event can remain queued after its Tab becomes inactive.  Do not
    // start work in that window: deactivate() invalidates the generation and
    // a request started afterwards would otherwise leave loading=true forever
    // because its completion is (correctly) discarded by isCurrent().
    if (this.disposed || !this.active) {
      return Promise.resolve();
    }
    const descriptor = this.descriptor(this.seriesId);
    // Repeated lifecycle/retry events share the current generation.  A force
    // request arriving while a normal request is pending is intentionally
    // coalesced; the normal result will schedule the single background
    // revalidation path if it is stale.
    if (this.activeLoadTask !== undefined &&
      this.activeLoadGeneration === this.generation &&
      this.activeLoadSeriesId === descriptor.id) {
      return this.activeLoadTask;
    }
    const generation = ++this.generation;
    this.refreshOnActivate = false;
    this.observedSnapshot = undefined;
    this.loading = !forceRefresh || this.entries.length === 0;
    this.refreshing = forceRefresh && this.entries.length > 0;
    this.errorMessage = '';
    this.status = this.refreshing ? ViewModelLoadState.REFRESHING : ViewModelLoadState.LOADING;
    // Register the owner before entering the repository.  Some adapters can
    // publish a cache notification synchronously; without this deferred turn
    // that callback would see no active task and clear the loading state before
    // the request had even been recorded.
    const task = Promise.resolve().then((): Promise<void> =>
      this.performLoad(descriptor, generation, forceRefresh, priority));
    this.activeLoadTask = task;
    this.activeLoadGeneration = generation;
    this.activeLoadSeriesId = descriptor.id;
    const clear = (): void => {
      if (this.activeLoadTask === task) {
        this.activeLoadTask = undefined;
        this.activeLoadGeneration = 0;
        this.activeLoadSeriesId = '';
        // A cache write can notify just after performLoad has resolved but
        // before this reaction runs.  Consume that last newer notification
        // while the generation is still valid; otherwise it would remain
        // stranded in observedSnapshot until a later manual load.
        if (this.isCurrent(generation, descriptor.id)) {
          const observed = this.takeObservedSnapshot();
          if (observed !== undefined) {
            this.applySnapshot(observed);
          }
        }
      }
    };
    task.then(clear, clear);
    return task;
  }

  private async performLoad(
    descriptor: ScpSeriesDescriptor,
    generation: number,
    forceRefresh: boolean,
    priority: ScpHtmlRequestPriority
  ): Promise<void> {
    if (!this.isCurrent(generation, descriptor.id)) {
      return;
    }
    try {
      const snapshot = forceRefresh ?
        await this.content.refresh(descriptor, priority) :
        await this.content.load(descriptor, priority);
      if (!this.isCurrent(generation, descriptor.id)) {
        return;
      }
      this.refreshOnActivate = false;
      // A late cache notification may have advanced the screen watermark
      // while this request was in flight.  Even when that makes the returned
      // snapshot ineligible, the request still has to settle its loading
      // flags; otherwise the page can remain stuck in REFRESHING forever.
      const applied = this.applySnapshot(snapshot, true);
      const observed = this.takeObservedSnapshot();
      let observedApplied: boolean = false;
      if (observed !== undefined) {
        observedApplied = this.applySnapshot(observed);
      }
      if (!applied && !observedApplied) {
        this.loading = false;
        this.refreshing = false;
        if (this.entries.length === 0) {
          this.status = ViewModelLoadState.ERROR;
          this.errorMessage = snapshot.error.length > 0 ? snapshot.error :
            '目录加载结果已过期，请重试';
        } else {
          this.status = this.partial || this.stale ?
            ViewModelLoadState.PARTIAL : ViewModelLoadState.READY;
          if (snapshot.error.length > 0) {
            this.errorMessage = snapshot.error;
          }
        }
      }
      // stale 快照先可见，再由同一状态机启动唯一的后台重验；不再让
      // 一个脱离 generation 的 Promise 直接改写 loading/refreshing。
      if (snapshot.stale && !forceRefresh && this.isCurrent(generation, descriptor.id)) {
        this.clearActiveLoad(generation);
        this.loadInternal(true, ScpHtmlRequestPriority.BACKGROUND).catch((): void => {
          // 后台重验失败已经由同一 VM 代际发布为 PARTIAL/ERROR。
        });
      }
    } catch (error) {
      if (!this.isCurrent(generation, descriptor.id)) {
        return;
      }
      const observed = this.takeObservedSnapshot();
      const recovered = observed !== undefined && this.applySnapshot(observed);
      if (!recovered) {
        this.loading = false;
        this.refreshing = false;
        this.status = this.entries.length > 0 ? ViewModelLoadState.PARTIAL : ViewModelLoadState.ERROR;
        this.errorMessage = error instanceof Error ? error.message : '目录加载失败';
      }
      throw new Error(error instanceof Error ? error.message : '目录加载失败');
    }
  }

  private applySnapshot(snapshot: CatalogSnapshot, allowEqual: boolean = false): boolean {
    if (!this.acceptSnapshot(snapshot, allowEqual)) {
      return false;
    }
    this.entries = snapshot.entries.slice();
    this.stale = snapshot.stale;
    this.partial = snapshot.partial;
    this.loading = false;
    this.refreshing = false;
    this.errorMessage = snapshot.error;
    this.status = snapshot.partial || snapshot.stale ?
      ViewModelLoadState.PARTIAL : ViewModelLoadState.READY;
    this.publishVisible();
    this.appliedFetchedAt = snapshot.fetchedAt;
    this.appliedSourceRank = this.snapshotSourceRank(snapshot.source);
    return true;
  }

  private publishVisible(): void {
    this.visibleEntries = filterCatalogEntries(this.entries, this.query);
  }

  private subscribeSeries(seriesId: string): void {
    this.stopObservation();
    const observerToken = this.observerGeneration;
    this.unsubscribe = this.content.observe(seriesId, (snapshot: CatalogSnapshot): void => {
      if (!this.isObserverCurrent(observerToken, seriesId) || snapshot.seriesId !== this.seriesId) {
        return;
      }
      if (this.hasCurrentLoad(seriesId)) {
        if (this.isSnapshotNewer(snapshot, this.observedSnapshot)) {
          this.observedSnapshot = snapshot;
        }
        return;
      }
      this.applySnapshot(snapshot);
    });
  }

  private stopObservation(): void {
    // Invalidate before invoking user/repository code: an unsubscribe callback
    // is allowed to synchronously flush its last notification.
    this.observerGeneration++;
    this.observedSnapshot = undefined;
    const unsubscribe = this.unsubscribe;
    this.unsubscribe = undefined;
    unsubscribe?.();
  }

  private takeObservedSnapshot(): CatalogSnapshot | undefined {
    const snapshot = this.observedSnapshot;
    this.observedSnapshot = undefined;
    return snapshot;
  }

  private clearActiveLoad(generation: number): void {
    if (this.activeLoadGeneration !== generation) {
      return;
    }
    this.activeLoadTask = undefined;
    this.activeLoadGeneration = 0;
    this.activeLoadSeriesId = '';
  }

  private hasCurrentLoad(seriesId: string): boolean {
    return this.activeLoadTask !== undefined && this.activeLoadGeneration === this.generation &&
      this.activeLoadSeriesId === seriesId;
  }

  private isObserverCurrent(observerToken: number, seriesId: string): boolean {
    return !this.disposed && this.active && observerToken === this.observerGeneration &&
      seriesId === this.seriesId;
  }

  private acceptSnapshot(snapshot: CatalogSnapshot, allowEqual: boolean): boolean {
    if (snapshot.seriesId !== this.seriesId || snapshot.fetchedAt < this.appliedFetchedAt) {
      return false;
    }
    if (snapshot.fetchedAt > this.appliedFetchedAt) {
      return true;
    }
    const sourceRank = this.snapshotSourceRank(snapshot.source);
    if (sourceRank < this.appliedSourceRank) {
      return false;
    }
    return allowEqual || sourceRank > this.appliedSourceRank;
  }

  private isSnapshotNewer(
    snapshot: CatalogSnapshot,
    previous: CatalogSnapshot | undefined
  ): boolean {
    if (previous === undefined) {
      return this.acceptSnapshot(snapshot, false);
    }
    if (snapshot.fetchedAt !== previous.fetchedAt) {
      return snapshot.fetchedAt > previous.fetchedAt;
    }
    return this.snapshotSourceRank(snapshot.source) > this.snapshotSourceRank(previous.source);
  }

  private snapshotSourceRank(source: CatalogSnapshotSource): number {
    switch (source) {
      case CatalogSnapshotSource.NETWORK:
        return 3;
      case CatalogSnapshotSource.CACHE:
        return 2;
      case CatalogSnapshotSource.STALE_CACHE:
        return 1;
    }
    return 0;
  }

  private isPreviewOwnerCurrent(ownerEpoch: number): boolean {
    return !this.disposed && this.active && ownerEpoch === this.previewOwnerEpoch;
  }

  private isCurrent(generation: number, seriesId: string): boolean {
    return !this.disposed && this.active && generation === this.generation && seriesId === this.seriesId;
  }

  private descriptor(id: string): ScpSeriesDescriptor {
    return findCatalogSeriesById(id) ?? SCP_SERIES[0];
  }

}
