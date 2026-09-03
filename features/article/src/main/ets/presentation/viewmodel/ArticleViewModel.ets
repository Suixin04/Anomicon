import {
  LibraryContentRef,
  createLibraryContentRef,
  isLibraryContentTitlePlaceholder
} from 'library';
import { ScpArticleDocument } from '../../domain/ScpDocument';
import {
  ViewModelLifecycle,
  ViewModelLoadState,
  ViewModelErrorInfo
} from 'anomiconbasic';
import {
  ArticleContentUseCase
} from '../../application/ArticleContentUseCase';
import {
  ArticleViewStatePort,
  ArticleFavoritePort,
  ArticleHistoryPort,
  ArticleHistorySnapshot,
  ArticleRelatedTale,
  PendingExtraction,
  ReadingSessionPort,
  ArticleExtractionRequest
} from '../../domain/ArticleContracts';

/** View subscription used by the staged page.  The callback
 * carries no platform object and is safe to invoke after an async boundary. */
export type ArticleViewModelListener = () => void;

/** Complete article screen state and commands. */
@ObservedV2
export class ArticleViewModel implements ViewModelLifecycle {
  @Trace state: ViewModelLoadState = ViewModelLoadState.IDLE;
  @Trace content: LibraryContentRef | undefined = undefined;
  @Trace document: ScpArticleDocument | undefined = undefined;
  @Trace pendingExtraction: ArticleExtractionRequest | undefined = undefined;
  @Trace error: ViewModelErrorInfo | undefined = undefined;
  @Trace stale: boolean = false;
  @Trace parsing: boolean = false;
  @Trace expandedKeys: string[] = [];
  @Trace readingPercent: number = 0;
  @Trace completed: boolean = false;
  /** Scroll position selected from reading history (or current reading history). */
  @Trace restoredScrollOffset: number = 0;
  /**
   * True only after the current route's authoritative scroll lookup has
   * completed.  This must stay separate from historyReady: recordOpened()
   * can make historyReady true before find() has returned the saved offset.
   */
  @Trace readingRestoreReady: boolean = false;
  @Trace historyPending: boolean = false;
  @Trace historyReady: boolean = false;
  @Trace historyError: ViewModelErrorInfo | undefined = undefined;
  @Trace favorite: boolean = false;
  @Trace favoriteReady: boolean = false;
  @Trace favoritePending: boolean = false;
  @Trace favoriteError: ViewModelErrorInfo | undefined = undefined;
  /** Bounded related-tale projection for the reader's navigation footer. */
  @Trace relatedTales: ArticleRelatedTale[] = [];

  private readonly useCase: ArticleContentUseCase;
  private readonly viewState: ArticleViewStatePort | undefined;
  private readonly readingSession: ReadingSessionPort | undefined;
  private readonly favoritePort: ArticleFavoritePort | undefined;
  private readonly history: ArticleHistoryPort | undefined;
  private readingSessionContent: LibraryContentRef | undefined = undefined;
  private readingSessionReleased: boolean = false;
  private pending: PendingExtraction | undefined = undefined;
  private generation: number = 0;
  /**
   * Fold-state reads belong to the current route content, not to an individual
   * network request.  A stale document may trigger a second generation for
   * background revalidation; that must not invalidate the first read.  This
   * epoch changes only when the route content identity changes or the VM is
   * disposed, so late reads from a previous article are still rejected.
   */
  private expandedStateEpoch: number = 0;
  /** Monotonic user mutation guard for asynchronous fold-state reads. */
  private expandedStateMutation: number = 0;
  private requestSequence: number = 0;
  private active: boolean = false;
  private disposed: boolean = false;
  private loadInFlight: boolean = false;
  private activeLoadRequestId: number = 0;
  /** Last renderer offset accepted by the reading-session port. */
  private readingOffset: number = 0;
  /** A real Scroll.onScrollStart has occurred for the current route. */
  private readingScrollInteracted: boolean = false;
  /**
   * A stale document can be revalidated in the background while the route is
   * hidden.  Deactivation invalidates that request; remember to resume it on
   * the next activation instead of leaving the VM stuck in REFRESHING/LOADING.
   */
  private refreshOnActivate: boolean = false;
  private favoriteGeneration: number = 0;
  private metadataToken: number = 0;
  private metadataIdentity: string = '';
  private metadataInFlight: boolean = false;
  private favoriteUnsubscribe: (() => void) | undefined = undefined;
  /** Route/lifecycle epoch for history reads and writes. */
  private historyEpoch: number = 0;
  private historyIdentity: string = '';
  private historyRecordTask: Promise<void> | undefined = undefined;
  private historyRestoreIdentity: string = '';
  private historyRestoreTask: Promise<number> | undefined = undefined;
  private historyOperationTail: Promise<void> = Promise.resolve();
  private readonly listeners: ArticleViewModelListener[] = [];

  constructor(
    useCase: ArticleContentUseCase,
    viewState: ArticleViewStatePort | undefined = undefined,
    readingSession: ReadingSessionPort | undefined = undefined,
    favoritePort: ArticleFavoritePort | undefined = undefined,
    history: ArticleHistoryPort | undefined = undefined
  ) {
    this.useCase = useCase;
    this.viewState = viewState;
    this.readingSession = readingSession;
    this.favoritePort = favoritePort;
    this.history = history;
  }

  subscribe(listener: ArticleViewModelListener): () => void {
    if (this.disposed) {
      return (): void => {
      };
    }
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

  activate(): void {
    if (this.disposed || this.active) {
      return;
    }
    this.active = true;
    this.bindFavoritePort();
    this.syncFavoriteState();
    if (this.content !== undefined) {
      this.recordOpened(this.content).catch((): void => {
      });
      if (this.document !== undefined) {
        // A restore interrupted by deactivate() is retried when the screen
        // becomes visible again; the epoch guard rejects the old callback.
        this.restoreReadingState(this.content).catch((): void => {
        });
      }
    }
    this.ensureMetadata();
    // Deactivation invalidates an in-flight request and clears a pending
    // extraction.  On re-entry, resume the load handshake instead of leaving
    // the View stuck in LOADING with no extractor mounted.
    if (this.content !== undefined && this.document === undefined &&
      (this.state === ViewModelLoadState.IDLE ||
        (this.state === ViewModelLoadState.LOADING && !this.loadInFlight))) {
      this.load(false);
    } else if (this.content !== undefined && this.document !== undefined &&
      this.refreshOnActivate) {
      this.refreshOnActivate = false;
      this.load(true);
    }
  }

  deactivate(): void {
    if (this.disposed || !this.active) {
      return;
    }
    this.active = false;
    // Invalidate history callbacks as soon as the route leaves the active
    // lifecycle.  The persistence operation may still finish, but it must not
    // publish a restore/error snapshot into a hidden screen.
    this.historyEpoch += 1;
    this.historyRestoreIdentity = '';
    this.historyRestoreTask = undefined;
    this.historyPending = false;
    const sessionContent = this.readingSessionContent ?? this.content;
    if (sessionContent !== undefined) {
      // Make the application-level reading session ineligible immediately;
      // the product View may deliver its own shown/active callbacks later.
      this.readingSession?.setActive(sessionContent, false, this.document !== undefined, this.readingOffset);
      this.readingSession?.setShown(sessionContent, false, this.document !== undefined, this.readingOffset);
    }
    this.favoriteGeneration++;
    this.metadataToken++;
    if (this.metadataInFlight) {
      this.metadataIdentity = '';
    }
    this.metadataInFlight = false;
    this.favoriteUnsubscribe?.();
    this.favoriteUnsubscribe = undefined;
    this.favoritePending = false;
    // `loadInFlight` is deliberately cleared below so a stale callback cannot
    // publish into the next activation.  Preserve only the fact that a
    // document-backed refresh/extraction was interrupted; a normal READY or
    // PARTIAL document should remain quiet until the user explicitly retries.
    this.refreshOnActivate = this.document !== undefined &&
      (this.state === ViewModelLoadState.REFRESHING ||
        this.state === ViewModelLoadState.LOADING);
    this.generation += 1;
    this.loadInFlight = false;
    this.activeLoadRequestId = 0;
    this.pending = undefined;
    this.pendingExtraction = undefined;
    this.parsing = false;
    this.notifyListeners();
  }

  dispose(): void {
    if (this.disposed) {
      return;
    }
    this.disposed = true;
    this.active = false;
    this.expandedStateEpoch += 1;
    this.historyEpoch += 1;
    this.historyRestoreIdentity = '';
    this.historyRestoreTask = undefined;
    this.generation += 1;
    this.loadInFlight = false;
    this.activeLoadRequestId = 0;
    this.refreshOnActivate = false;
    this.favoriteGeneration++;
    this.metadataToken++;
    this.metadataIdentity = '';
    this.metadataInFlight = false;
    this.favoriteUnsubscribe?.();
    this.favoriteUnsubscribe = undefined;
    this.favoritePending = false;
    this.historyPending = false;
    this.pending = undefined;
    this.pendingExtraction = undefined;
    this.parsing = false;
    this.releaseReadingSession(this.readingOffset);
    this.notifyListeners();
  }

  setRouteContent(content: LibraryContentRef): void {
    if (this.disposed) {
      return;
    }
    // LibraryContentRef.key intentionally collapses SCP/Tale entries that
    // point at the same site slug for persistence.  A screen VM must retain
    // the route kind as part of its identity, otherwise navigating from an
    // SCP to a same-slug Tale can reuse the old document and accept callbacks
    // from the wrong article.  A title-only update does not require a reload.
    const current = this.content;
    if (current !== undefined && current.kind === content.kind && current.id === content.id) {
      if (current.title !== content.title) {
        this.content = content;
        if (this.readingSessionContent !== undefined) {
          this.readingSessionContent = content;
        }
        this.notifyListeners();
      }
      this.syncFavoriteState();
      this.updateMetadata(content).catch((): void => {
      });
      return;
    }
    this.generation += 1;
    this.expandedStateEpoch += 1;
    this.expandedStateMutation += 1;
    this.requestSequence += 1;
    this.loadInFlight = false;
    this.activeLoadRequestId = 0;
    this.content = content;
    this.historyEpoch += 1;
    const sameSessionContent = this.readingSessionContent !== undefined &&
      this.readingSessionContent.kind === content.kind &&
      this.readingSessionContent.id === content.id;
    if (this.readingSessionContent !== undefined && !sameSessionContent && !this.readingSessionReleased) {
      this.readingSession?.release(this.readingSessionContent.key, this.readingOffset);
    }
    if (sameSessionContent) {
      // Route setup may attach the session before it publishes the route
      // content.  Preserve that lease instead of releasing it as a false
      // route replacement; only the title metadata changes here.
      this.readingSessionContent = content;
      this.readingSessionReleased = false;
    } else {
      this.readingSessionContent = undefined;
      this.readingSessionReleased = false;
      this.readingOffset = 0;
    }
    this.document = undefined;
    this.pending = undefined;
    this.pendingExtraction = undefined;
    this.expandedKeys = [];
    this.relatedTales = [];
    this.restoredScrollOffset = 0;
    this.readingPercent = 0;
    this.completed = false;
    this.readingRestoreReady = false;
    this.readingScrollInteracted = false;
    this.historyReady = false;
    this.historyError = undefined;
    this.historyIdentity = '';
    this.historyRecordTask = undefined;
    this.historyRestoreIdentity = '';
    this.historyRestoreTask = undefined;
    this.historyPending = false;
    this.metadataIdentity = '';
    this.metadataToken++;
    this.metadataInFlight = false;
    this.refreshOnActivate = false;
    this.favoriteGeneration++;
    this.favoritePending = false;
    this.favoriteError = undefined;
    this.syncFavoriteState(content);
    this.error = undefined;
    this.stale = false;
    this.parsing = false;
    this.state = ViewModelLoadState.IDLE;
    this.notifyListeners();
    // Route setup owns only the normalized content identity.  Opening the
    // history record is a VM concern and is safe before activate(); the epoch
    // guard below drops any late completion after a route replacement.
    this.recordOpened(content).catch((): void => {
    });
    if (this.active) {
      this.load(false);
      this.ensureMetadata();
    }
  }

  retry(): void {
    if (this.content !== undefined && !this.disposed) {
      this.load(true);
    }
  }

  /**
   * Record the current route in recent reading history.
   *
   * Calls are coalesced per route identity and serialized with progress and
   * metadata writes.  A route/lifecycle epoch is captured before crossing the
   * async boundary so a late completion can never publish state for a newer
   * article (the persistence adapter may still finish its already-started
   * write safely for the old identity).
   */
  async recordOpened(content: LibraryContentRef | undefined = this.content): Promise<void> {
    const history = this.history;
    if (history === undefined || content === undefined || this.disposed) {
      return;
    }
    if (!this.isContentCurrent(content)) {
      return;
    }
    const epoch = this.historyEpoch;
    const identity = this.historyContentIdentity(content);
    if (this.historyIdentity === identity && this.historyRecordTask !== undefined) {
      await this.historyRecordTask;
      return;
    }
    if (this.historyIdentity === identity && this.historyReady) {
      return;
    }
    this.historyIdentity = identity;
    this.historyPending = true;
    this.historyError = undefined;
    this.notifyListeners();
    const task = this.enqueueHistory((): Promise<void> => history.recordOpened(content));
    this.historyRecordTask = task;
    try {
      await task;
      if (this.isHistoryCurrent(epoch, content)) {
        this.historyReady = true;
        this.historyPending = false;
        this.historyError = undefined;
        this.notifyListeners();
      }
    } catch (error) {
      if (this.isHistoryCurrent(epoch, content)) {
        this.historyIdentity = '';
        this.historyPending = false;
        this.historyError = ViewModelErrorInfo.from(error, '记录阅读历史失败');
        this.notifyListeners();
      }
      throw new Error(error instanceof Error ? error.message : '记录阅读历史失败');
    } finally {
      if (this.historyRecordTask === task) {
        this.historyRecordTask = undefined;
      }
    }
  }

  /**
   * Resolve the scroll position for the current article.  Library history is
   * authoritative, including an explicit zero offset; the current article-state
   * table is consulted only when no history row exists.  The result is also
   * projected as `restoredScrollOffset` for a View to apply after layout.
   */
  async restoreReadingState(content: LibraryContentRef | undefined = this.content): Promise<number> {
    const history = this.history;
    if (content === undefined || this.disposed || !this.isContentCurrent(content)) {
      return 0;
    }
    const identity = this.historyContentIdentity(content);
    if (this.historyRestoreIdentity === identity && this.historyRestoreTask !== undefined) {
      return this.historyRestoreTask;
    }
    const epoch = this.historyEpoch;
    this.historyRestoreIdentity = identity;
    const task = this.readAndApplyRestoreOffset(content, epoch, history);
    this.historyRestoreTask = task;
    try {
      return await task;
    } finally {
      if (this.historyRestoreTask === task) {
        this.historyRestoreTask = undefined;
      }
    }
  }

  /** Persist the latest renderer offset through the injected history port. */
  async updateProgress(
    offset: number,
    content: LibraryContentRef | undefined = this.content
  ): Promise<void> {
    const history = this.history;
    if (history === undefined || content === undefined || this.disposed ||
      !this.isContentCurrent(content)) {
      return;
    }
    const normalized = this.normalizeReadingOffset(offset);
    // Until find() resolves, zero is only the renderer's provisional default.
    // Do not let an early lifecycle callback overwrite a saved positive
    // offset.  A positive offset is always real, while an explicit reader
    // scroll permits saving an intentional return to the top.
    if (normalized === 0 && !this.readingRestoreReady && !this.readingScrollInteracted) {
      return;
    }
    this.readingOffset = normalized;
    const epoch = this.historyEpoch;
    const task = this.enqueueHistory((): Promise<void> =>
      history.updateProgress(content, normalized)
    );
    try {
      await task;
      if (this.isHistoryCurrent(epoch, content)) {
        this.historyReady = true;
        this.historyError = undefined;
        this.notifyListeners();
      }
    } catch (error) {
      if (this.isHistoryCurrent(epoch, content)) {
        this.historyError = ViewModelErrorInfo.from(error, '保存阅读进度失败');
        this.notifyListeners();
      }
      throw new Error(error instanceof Error ? error.message : '保存阅读进度失败');
    }
  }

  /** Persist title/type enrichment without changing reading timestamps. */
  async updateMetadata(content: LibraryContentRef | undefined = this.content): Promise<void> {
    const history = this.history;
    if (history === undefined || content === undefined || this.disposed ||
      !this.isContentCurrent(content)) {
      return;
    }
    const epoch = this.historyEpoch;
    const task = this.enqueueHistory((): Promise<void> => history.updateMetadata(content));
    try {
      await task;
      if (this.isHistoryCurrent(epoch, content)) {
        this.historyReady = true;
        this.historyError = undefined;
        this.notifyListeners();
      }
    } catch (error) {
      if (this.isHistoryCurrent(epoch, content)) {
        this.historyError = ViewModelErrorInfo.from(error, '更新阅读元数据失败');
        this.notifyListeners();
      }
      throw new Error(error instanceof Error ? error.message : '更新阅读元数据失败');
    }
  }

  async setCompleted(completed: boolean = true,
    content: LibraryContentRef | undefined = this.content): Promise<void> {
    const history = this.history;
    if (history?.setCompleted === undefined || content === undefined || this.disposed ||
      !this.isContentCurrent(content)) {
      return;
    }
    const epoch = this.historyEpoch;
    const task = this.enqueueHistory(() => history.setCompleted!(content, completed === true));
    try {
      await task;
      if (this.isHistoryCurrent(epoch, content)) {
        this.completed = completed === true;
        this.historyReady = true;
        this.historyError = undefined;
        this.notifyListeners();
      }
    } catch (error) {
      if (this.isHistoryCurrent(epoch, content)) {
        this.historyError = ViewModelErrorInfo.from(error, '保存完成标记失败');
        this.notifyListeners();
      }
      throw new Error(error instanceof Error ? error.message : '保存完成标记失败');
    }
  }

  load(forceNetwork: boolean = false): void {
    const content = this.content;
    if (content === undefined || this.disposed || !this.active) {
      return;
    }
    if (this.loadInFlight) {
      return;
    }
    this.loadInFlight = true;
    const generation = ++this.generation;
    const requestId = ++this.requestSequence;
    this.activeLoadRequestId = requestId;
    this.state = this.document === undefined ? ViewModelLoadState.LOADING : ViewModelLoadState.REFRESHING;
    this.error = undefined;
    this.parsing = false;
    this.pending = undefined;
    this.pendingExtraction = undefined;
    this.notifyListeners();
    // Ports are Promise-typed, but a product adapter can still throw before
    // returning one.  Enter through a microtask so the catch path always
    // clears loadInFlight and exposes a recoverable error state.
    Promise.resolve().then(() => this.useCase.load(content, requestId, forceNetwork))
      .then((result): void => {
        if (this.activeLoadRequestId === requestId) {
          this.loadInFlight = false;
        }
        if (!this.isCurrent(content, generation)) {
          return;
        }
        this.stale = result.stale;
        if (result.document !== undefined) {
          this.publishDocument(result.document, result.stale);
          this.state = result.stale ? ViewModelLoadState.PARTIAL : ViewModelLoadState.READY;
          this.notifyListeners();
          if (result.stale && !forceNetwork) {
            // Keep the cached document visible while a conditional HTML
            // request revalidates it in the background.
            this.load(true);
          }
          return;
        }
        if (result.pendingExtraction !== undefined) {
          this.pending = result.pendingExtraction;
          this.pendingExtraction = {
            requestId: result.pendingExtraction.requestId,
            html: result.pendingExtraction.html,
            sourceUrl: result.pendingExtraction.sourceUrl,
            stale: result.pendingExtraction.stale
          };
          this.parsing = true;
          this.state = ViewModelLoadState.LOADING;
          this.notifyListeners();
          return;
        }
        if (this.document !== undefined) {
          // A stale-while-revalidate request may fail after a cached document
          // has already been published.  Keep that document readable and
          // expose a partial state; an empty error state would hide valid
          // offline content behind the full-screen failure view.
          this.stale = true;
          this.state = ViewModelLoadState.PARTIAL;
          this.error = new ViewModelErrorInfo(result.error || '正文更新失败，正在显示已缓存内容');
          this.parsing = false;
          this.notifyListeners();
          return;
        }
        this.state = ViewModelLoadState.ERROR;
        this.error = new ViewModelErrorInfo(result.error || '档案内容加载失败');
        this.notifyListeners();
      })
      .catch((error: Object): void => {
        if (this.activeLoadRequestId === requestId) {
          this.loadInFlight = false;
        }
        if (!this.isCurrent(content, generation)) {
          return;
        }
        if (this.document !== undefined) {
          // Gateways may reject instead of returning an error receipt.  Keep
          // an already rendered document readable on either failure shape.
          this.stale = true;
          this.state = ViewModelLoadState.PARTIAL;
          this.error = ViewModelErrorInfo.from(error, '正文更新失败，正在显示已缓存内容');
          this.parsing = false;
          this.notifyListeners();
          return;
        }
        this.state = ViewModelLoadState.ERROR;
        this.error = ViewModelErrorInfo.from(error, '档案内容加载失败');
        this.parsing = false;
        this.notifyListeners();
      });
  }

  /** Called by the View after ScpHtmlExtractor completes. */
  onExtractionResult(requestId: number, payload: string): void {
    const content = this.content;
    const pending = this.pending;
    if (content === undefined || pending === undefined || pending.requestId !== requestId || this.disposed) {
      return;
    }
    const generation = this.generation;
    // As with load(), normalize a synchronous adapter throw into rejection so
    // the pending extraction handshake cannot remain stuck forever.
    Promise.resolve().then(() => this.useCase.completeExtraction(content, pending, payload))
      .then((document): void => {
        if (!this.isCurrent(content, generation) || this.pending?.requestId !== requestId) {
          return;
        }
        this.publishDocument(document, pending.stale);
        this.pending = undefined;
        this.pendingExtraction = undefined;
        this.parsing = false;
        this.state = pending.stale ? ViewModelLoadState.PARTIAL : ViewModelLoadState.READY;
        this.notifyListeners();
      })
      .catch((error: Object): void => {
        if (!this.isCurrent(content, generation) || this.pending?.requestId !== requestId) {
          return;
        }
        this.pending = undefined;
        this.pendingExtraction = undefined;
        this.parsing = false;
        if (this.document !== undefined) {
          // A revalidation can reach ArkWeb after a readable document is
          // already on screen.  Keep that document visible and expose a
          // partial/stale state instead of replacing it with a full-screen
          // parse error.
          this.stale = true;
          this.state = ViewModelLoadState.PARTIAL;
          this.error = ViewModelErrorInfo.from(error, '正文解析更新失败，正在显示已缓存内容');
        } else {
          this.state = ViewModelLoadState.ERROR;
          this.error = ViewModelErrorInfo.from(error, '解析结果处理失败');
        }
        this.notifyListeners();
      });
  }

  onExtractionFailed(requestId: number, message: string): void {
    if (this.pending?.requestId !== requestId || this.disposed) {
      return;
    }
    this.pending = undefined;
    this.pendingExtraction = undefined;
    this.parsing = false;
    if (this.document === undefined) {
      this.state = ViewModelLoadState.ERROR;
      this.error = new ViewModelErrorInfo(message || '正文解析失败');
    } else {
      // Extraction failure during a background refresh must not hide the
      // existing document, even when the HTML response itself was fresh.
      this.stale = true;
      this.state = ViewModelLoadState.PARTIAL;
      this.error = new ViewModelErrorInfo(message || '正文解析更新失败，正在显示已缓存内容');
    }
    this.notifyListeners();
  }

  isExpanded(key: string): boolean {
    return this.expandedKeys.indexOf(key) >= 0;
  }

  toggleExpanded(key: string): void {
    if (this.disposed || !this.active) {
      return;
    }
    const next = this.expandedKeys.slice();
    const index = next.indexOf(key);
    if (index >= 0) {
      next.splice(index, 1);
    } else {
      next.push(key);
    }
    // A persisted read may still be in flight.  Mark this local interaction
    // before publishing so that the older snapshot cannot overwrite the
    // user's explicit fold choice when it eventually resolves.
    this.expandedStateMutation += 1;
    this.expandedKeys = next;
    this.notifyListeners();
    const itemId = this.content?.id;
    if (itemId !== undefined && this.viewState !== undefined) {
      this.viewState.save(itemId, next).catch((): void => {
      });
    }
  }

  setReadingPercent(percent: number): void {
    if (this.disposed || !this.active) {
      return;
    }
    // Math.min/Math.max propagate NaN.  Ignoring an invalid measurement keeps
    // the last known progress stable and avoids `NaN !== NaN` notification
    // loops when a layout callback races an unfinished measurement.
    if (!Number.isFinite(percent)) {
      return;
    }
    const normalized = Math.max(0, Math.min(100, Math.round(percent)));
    if (normalized !== this.readingPercent) {
      this.readingPercent = normalized;
      this.notifyListeners();
    }
  }

  /** Attach the screen-owned reading session to the current route content. */
  attachReadingSession(content: LibraryContentRef, offset: number = 0): void {
    if (this.disposed) {
      return;
    }
    if (this.readingSessionContent !== undefined &&
      (this.readingSessionContent.kind !== content.kind || this.readingSessionContent.id !== content.id) &&
      !this.readingSessionReleased) {
      this.readingSession?.release(this.readingSessionContent.key, this.readingOffset);
    }
    this.readingSessionContent = content;
    this.readingSessionReleased = false;
    this.readingOffset = this.normalizeReadingOffset(offset);
    this.readingSession?.attach(content, this.readingOffset);
  }

  /** Tell the reading-session use case that the parsed document is usable. */
  setContentReady(ready: boolean, offset: number = 0): void {
    if (this.disposed || !this.active || this.content === undefined) {
      return;
    }
    this.readingSessionContent = this.content;
    this.readingOffset = this.normalizeReadingOffset(offset);
    this.readingSession?.setContentReady(
      this.content,
      ready,
      this.readingOffset
    );
  }

  /** Forward NavDestination visibility without exposing the coordinator to the View. */
  setPageShown(shown: boolean, ready: boolean, offset: number = 0): void {
    if (this.disposed || !this.active || this.content === undefined) {
      return;
    }
    this.readingSessionContent = this.content;
    this.readingOffset = this.normalizeReadingOffset(offset);
    this.readingSession?.setShown(
      this.content,
      shown,
      ready,
      this.readingOffset
    );
  }

  /** Forward NavDestination active state through the injected session port. */
  setPageActive(active: boolean, ready: boolean, offset: number = 0): void {
    if (this.disposed || !this.active || this.content === undefined) {
      return;
    }
    this.readingSessionContent = this.content;
    this.readingOffset = this.normalizeReadingOffset(offset);
    this.readingSession?.setActive(
      this.content,
      active,
      ready,
      this.readingOffset
    );
  }

  noteInteraction(offset: number = 0): void {
    if (this.disposed || !this.active || this.content === undefined) {
      return;
    }
    this.readingOffset = this.normalizeReadingOffset(offset);
    this.readingSession?.noteInteraction(this.content, this.readingOffset);
  }

  setContinuousInteraction(active: boolean, offset: number = 0): void {
    if (this.disposed || !this.active || this.content === undefined) {
      return;
    }
    if (active) {
      this.readingScrollInteracted = true;
    }
    this.readingOffset = this.normalizeReadingOffset(offset);
    this.readingSession?.setContinuousInteraction(
      this.content,
      active,
      this.readingOffset
    );
  }

  /** Release the coordinator lease when a route is actually destroyed. */
  releaseReadingSession(offset: number = 0): void {
    if (this.readingSessionReleased) {
      return;
    }
    const sessionContent = this.readingSessionContent ?? this.content;
    if (sessionContent !== undefined) {
      this.readingOffset = this.normalizeReadingOffset(offset);
      this.readingSession?.release(sessionContent.key, this.readingOffset);
    }
    this.readingSessionReleased = true;
    this.readingSessionContent = undefined;
  }

  checkpoint(offset: number): void {
    const content = this.content;
    if (content !== undefined && !this.disposed && this.active) {
      this.readingOffset = this.normalizeReadingOffset(offset);
      this.readingSession?.checkpoint(content, this.readingOffset);
    }
  }

  /**
   * Toggle the current article's favorite state.  The command is intentionally
   * exposed by the screen VM so the View never reaches the shared Favorites VM.
   * `undefined` means that no favorite port/content has been mounted yet.
   */
  async toggleFavorite(): Promise<boolean | undefined> {
    const content = this.content;
    const port = this.favoritePort;
    if (content === undefined || port === undefined || this.disposed || !this.active ||
      this.favoritePending) {
      return undefined;
    }
    const generation = this.favoriteGeneration;
    this.favoritePending = true;
    this.favoriteError = undefined;
    this.notifyListeners();
    try {
      if (!port.initialized) {
        await port.initialize();
      }
      // Initialization may cross a route/lifecycle boundary.  Never mutate
      // the shared store for the article that the user has already left.
      if (!this.isFavoriteCurrent(generation, content)) {
        return undefined;
      }
      this.syncFavoriteState(content);
      this.notifyListeners();
      const next = await port.toggle(content);
      if (!this.isFavoriteCurrent(generation, content)) {
        return undefined;
      }
      this.favorite = next;
      this.favoriteReady = port.initialized;
      this.favoriteError = undefined;
      this.notifyListeners();
      return next;
    } catch (error) {
      if (!this.isFavoriteCurrent(generation, content)) {
        return undefined;
      }
      this.favoriteError = ViewModelErrorInfo.from(error, '收藏操作失败');
      this.favoriteReady = port.initialized;
      this.notifyListeners();
      throw new Error(error instanceof Error ? error.message : '收藏操作失败');
    } finally {
      if (this.isFavoriteCurrent(generation, content)) {
        this.favoritePending = false;
        this.notifyListeners();
      }
    }
  }

  private publishDocument(document: ScpArticleDocument, stale: boolean): void {
    this.document = document;
    this.stale = stale;
    // The mapper keeps the display id in the site's customary uppercase form,
    // whereas LibraryContentRef/persistence keys are canonical lowercase ids.
    // Always load fold state through the route identity so a freshly parsed
    // document cannot miss the row just written by toggleExpanded().
    this.loadExpanded(this.content?.id ?? document.itemId.toLowerCase());
    this.restoreReadingState().catch((): void => {
    });
    this.updateMetadata().catch((): void => {
    });
    if (this.content !== undefined) {
      this.readingSessionContent = this.content;
      this.readingSession?.setContentReady(this.content, true, this.readingOffset);
    }
  }

  /**
   * Start optional title/related-content work for the current route.  This is
   * deliberately independent from article loading: an unavailable catalog
   * snapshot must never turn a readable article into an error state.
   */
  private ensureMetadata(): void {
    const content = this.content;
    if (content === undefined || this.disposed || !this.active) {
      return;
    }
    const identity = `${content.kind}:${content.id}`;
    if (this.metadataInFlight || this.metadataIdentity === identity) {
      return;
    }
    this.metadataIdentity = identity;
    this.metadataInFlight = true;
    const token = ++this.metadataToken;
    let completed: number = 0;
    let resolvedTitle: string = '';
    let resolvedTales: ArticleRelatedTale[] = [];
    const complete = (): void => {
      completed += 1;
      if (completed < 2 || !this.isMetadataCurrent(token, content)) {
        return;
      }
      this.applyMetadataTitle(content, resolvedTitle);
      this.relatedTales = resolvedTales.slice();
      this.metadataInFlight = false;
      this.notifyListeners();
    };
    // A port is typed as Promise-returning, but an adapter can still throw
    // before constructing that Promise.  Enter both calls through a resolved
    // microtask so a synchronous throw is converted to rejection and `finally`
    // can always release metadataInFlight.
    // Keep optional metadata behind the use-case boundary.  This avoids a
    // second VM-owned dependency/state copy while retaining the no-op fallback
    // when the product does not mount a metadata adapter.
    Promise.resolve().then(() => this.useCase.resolveTitle(content)).then((title: string): void => {
      resolvedTitle = typeof title === 'string' ? title.trim() : '';
      // Title metadata is independent of the (potentially much larger) tale
      // index. Publish it as soon as it is available so the navigation bar
      // does not remain on a bare SCP id while related-content lookup runs.
      if (resolvedTitle.length > 0 && this.isMetadataCurrent(token, content)) {
        this.applyMetadataTitle(content, resolvedTitle);
      }
    }).catch((): void => {
      resolvedTitle = '';
    }).finally(complete);
    Promise.resolve().then(() => this.useCase.listRelatedTales(content, 6)).then((tales: ArticleRelatedTale[]): void => {
      resolvedTales = Array.isArray(tales) ? tales.slice() : [];
    }).catch((): void => {
      resolvedTales = [];
    }).finally(complete);
  }

  private applyMetadataTitle(content: LibraryContentRef, title: string): void {
    if (title.length === 0 || !isLibraryContentTitlePlaceholder(content.id, content.title) ||
      !isLibraryContentTitlePlaceholder(content.id, this.content?.title ?? '')) {
      return;
    }
    const enriched = createLibraryContentRef(content.kind, content.id, title);
    this.content = enriched;
    if (this.readingSessionContent !== undefined) {
      this.readingSessionContent = enriched;
    }
    this.syncFavoriteState(enriched);
    this.updateMetadata(enriched).catch((): void => {
    });
  }

  private isMetadataCurrent(token: number, content: LibraryContentRef): boolean {
    return !this.disposed && this.active && token === this.metadataToken &&
      this.content?.kind === content.kind && this.content?.id === content.id;
  }

  private historyContentIdentity(content: LibraryContentRef): string {
    // Persistence intentionally uses content.key so SCP/Tale aliases share a
    // history row.  The current route identity still includes kind/id through
    // isContentCurrent(), preventing a late callback from another article.
    return content.key;
  }

  private isContentCurrent(content: LibraryContentRef): boolean {
    return this.content !== undefined && this.content.kind === content.kind &&
      this.content.id === content.id;
  }

  private isHistoryCurrent(epoch: number, content: LibraryContentRef): boolean {
    return !this.disposed && epoch === this.historyEpoch && this.isContentCurrent(content);
  }

  private enqueueHistory(operation: () => Promise<void>): Promise<void> {
    const next = this.historyOperationTail.then(operation, operation);
    this.historyOperationTail = next.catch((): void => {
      // Keep the queue usable after one persistence failure; the original
      // rejected promise is still returned to the caller.
    });
    return next;
  }

  private async readAndApplyRestoreOffset(
    content: LibraryContentRef,
    epoch: number,
    history: ArticleHistoryPort | undefined
  ): Promise<number> {
    // setRouteContent starts recordOpened before the document arrives.  Await
    // that operation so find() observes the latest progress snapshot.  A
    // failed open should not prevent an offline current reading history from loading.
    const opened = this.historyRecordTask;
    if (opened !== undefined && this.historyIdentity === this.historyContentIdentity(content)) {
      await opened.catch((): void => {
      });
    }
    if (!this.isHistoryCurrent(epoch, content)) {
      return 0;
    }

    let snapshot: ArticleHistorySnapshot | undefined = undefined;
    let historyLookupSucceeded: boolean = false;
    if (history !== undefined) {
      try {
        snapshot = await history.find(content.key);
        historyLookupSucceeded = true;
        if (this.isHistoryCurrent(epoch, content)) {
          this.historyReady = true;
          this.historyError = undefined;
        }
      } catch (error) {
        if (this.isHistoryCurrent(epoch, content)) {
          this.historyError = ViewModelErrorInfo.from(error, '读取阅读历史失败');
        }
      }
    }
    if (!this.isHistoryCurrent(epoch, content)) {
      return 0;
    }

    let offset: number = 0;
    if (snapshot !== undefined) {
      offset = this.normalizeReadingOffset(snapshot.scrollOffset);
      this.completed = snapshot.completed === true;
    } else {
      this.completed = false;
    }
    if (!this.isHistoryCurrent(epoch, content)) {
      return 0;
    }
    this.restoredScrollOffset = offset;
    this.readingRestoreReady = historyLookupSucceeded;
    // Before the renderer applies the snapshot the VM normally still holds
    // the initial zero offset.  Seed that value for the reading-session port,
    // but never overwrite a renderer interaction that already advanced it.
    if (!this.readingScrollInteracted && this.readingOffset === 0 && offset > 0) {
      this.readingOffset = offset;
    }
    this.historyPending = false;
    // Publish both a positive offset and a resolved zero.  The View needs the
    // explicit readiness bit to distinguish the latter from the initial
    // value while the async query is still pending.
    this.notifyListeners();
    return offset;
  }

  private normalizeReadingOffset(offset: number): number {
    if (!Number.isFinite(offset) || offset <= 0) {
      return 0;
    }
    return Math.floor(offset);
  }

  private bindFavoritePort(): void {
    const port = this.favoritePort;
    if (port === undefined || this.favoriteUnsubscribe !== undefined) {
      return;
    }
    this.favoriteUnsubscribe = port.subscribe((): void => {
      if (!this.disposed && this.active) {
        this.syncFavoriteState();
        this.notifyListeners();
      }
    });
    // AppContainer normally initializes the shared VM at Ability startup, but
    // a route can be opened before that promise settles.  Initialize lazily as
    // a safety net and keep the failure local to the favorite command.
    if (!port.initialized && !port.loading) {
      port.initialize().then((): void => {
        if (!this.disposed && this.active) {
          this.syncFavoriteState();
        }
      }).catch((error: Object): void => {
        if (!this.disposed && this.active) {
          this.favoriteError = ViewModelErrorInfo.from(error, '收藏数据加载失败');
          this.notifyListeners();
        }
      });
    }
  }

  private syncFavoriteState(content: LibraryContentRef | undefined = this.content): void {
    const port = this.favoritePort;
    if (port === undefined || content === undefined) {
      this.favorite = false;
      this.favoriteReady = false;
      return;
    }
    this.favorite = port.isFavorite(content.key);
    this.favoriteReady = port.initialized;
  }

  private isFavoriteCurrent(generation: number, content: LibraryContentRef): boolean {
    return !this.disposed && this.active && generation === this.favoriteGeneration &&
      this.content?.kind === content.kind && this.content?.id === content.id;
  }

  private loadExpanded(itemId: string): void {
    if (this.viewState === undefined) {
      return;
    }
    // Do not capture `generation` here: publishing a stale cached document
    // immediately starts a background revalidation and increments generation.
    // The fold state is scoped to the route content epoch instead.
    const epoch = this.expandedStateEpoch;
    const mutation = this.expandedStateMutation;
    const content = this.content;
    this.viewState.read(itemId).then((keys): void => {
      if (!this.disposed && epoch === this.expandedStateEpoch &&
        mutation === this.expandedStateMutation &&
        content !== undefined && this.content !== undefined &&
        content.kind === this.content.kind && content.id === this.content.id) {
        this.expandedKeys = keys.slice();
        this.notifyListeners();
      }
    }).catch((): void => {
    });
  }

  private isCurrent(content: LibraryContentRef, generation: number): boolean {
    return !this.disposed && this.active && this.generation === generation &&
      this.content?.kind === content.kind && this.content?.id === content.id;
  }

  private notifyListeners(): void {
    const listeners = this.listeners.slice();
    for (let index = 0; index < listeners.length; index++) {
      try {
        listeners[index]();
      } catch (_error) {
        // A View listener is best effort; one disposed route must not affect VM state.
      }
    }
    if (this.disposed) {
      this.listeners.length = 0;
    }
  }
}
