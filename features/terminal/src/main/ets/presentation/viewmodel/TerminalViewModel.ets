import {
  ViewModelLifecycle,
  ViewModelErrorInfo,
  ViewModelLoadState
} from 'anomiconbasic';
import {
  LibraryContentKind,
  LibraryContentRef,
  LibraryFavorite,
  isLibraryContentTitlePlaceholder,
  createLibraryContentRef
} from 'library';
import { ReadingHistoryEntry } from 'library';
import {
  ResearchActivitySnapshot,
  ResearchProgress,
  emptyResearchProgress
} from 'library';

/** 终端首页需要的标题补全端口；实现由 composition 注入。 */
export type TerminalTitleResolver = (ids: string[]) => Promise<Map<string, string>>;
export type TerminalViewModelListener = () => void;

/** Terminal 只读取收藏共享状态，不绑定 Library 的具体 ViewModel 实现。 */
export interface TerminalFavoritesPort {
  readonly items: LibraryFavorite[];
  readonly loading: boolean;
  readonly error: string;
  readonly initialized: boolean;
  subscribe(listener: TerminalViewModelListener): () => void;
  initialize(): Promise<void>;
  reload(): Promise<void>;
}

/** Terminal 只读取历史投影，并通过窄命令补全已有条目的标题。 */
export interface TerminalReadingHistoryPort {
  readonly items: ReadingHistoryEntry[];
  readonly resumableItems?: ReadingHistoryEntry[];
  readonly loading: boolean;
  readonly error: string;
  readonly initialized: boolean;
  subscribe(listener: TerminalViewModelListener): () => void;
  initialize(): Promise<void>;
  reload(): Promise<void>;
  updateMetadata(content: LibraryContentRef): Promise<void>;
}

/** Terminal 只消费研读画像快照，账本写入能力不会泄漏到页面级 VM。 */
export interface TerminalResearchProfilePort {
  readonly profile: ResearchProgress;
  readonly loading: boolean;
  readonly error: string;
  readonly initialized: boolean;
  subscribe(listener: TerminalViewModelListener): () => void;
  initialize(): Promise<void>;
  reload(): Promise<ResearchActivitySnapshot>;
}

/** 终端首页页面级投影 VM；不依赖 UI、导航或具体标题 service。 */
@ObservedV2
export class TerminalViewModel implements ViewModelLifecycle {
  @Trace favoriteEntries: LibraryFavorite[] = [];
  @Trace resumeEntries: ReadingHistoryEntry[] = [];
  @Trace recentEntries: ReadingHistoryEntry[] = [];
  @Trace recentCount: number = 0;
  @Trace favoriteCount: number = 0;
  /** Source-level readiness projected for the terminal View. */
  @Trace favoriteLoading: boolean = false;
  @Trace favoriteError: string = '';
  @Trace favoriteInitialized: boolean = false;
  @Trace historyCount: number = 0;
  @Trace historyLoading: boolean = false;
  @Trace historyError: string = '';
  @Trace historyInitialized: boolean = false;
  @Trace researchLoading: boolean = false;
  @Trace researchError: string = '';
  @Trace researchInitialized: boolean = false;
  @Trace profile: ResearchProgress = emptyResearchProgress();
  @Trace state: ViewModelLoadState = ViewModelLoadState.IDLE;
  @Trace loading: boolean = false;
  @Trace error: ViewModelErrorInfo | undefined = undefined;

  private readonly favorites: TerminalFavoritesPort;
  private readonly history: TerminalReadingHistoryPort;
  private readonly research: TerminalResearchProfilePort;
  private readonly titleResolver: TerminalTitleResolver | undefined;
  private active: boolean = false;
  private disposed: boolean = false;
  private generation: number = 0;
  /** Generation currently performing title enrichment; a newer lifecycle
   * generation must be allowed to start its own pass even if an older lookup
   * is still waiting on the resolver. */
  private enrichmentGeneration: number = -1;
  private favoritesUnsubscribe: (() => void) | undefined = undefined;
  private historyUnsubscribe: (() => void) | undefined = undefined;
  private researchUnsubscribe: (() => void) | undefined = undefined;
  /** Source retry owners; the generation prevents an old request from
   * clearing a marker belonging to the same source after re-entry. */
  private readonly sourceRefreshes: Map<string, number> = new Map<string, number>();
  constructor(
    favorites: TerminalFavoritesPort,
    history: TerminalReadingHistoryPort,
    research: TerminalResearchProfilePort,
    titleResolver?: TerminalTitleResolver
  ) {
    this.favorites = favorites;
    this.history = history;
    this.research = research;
    this.titleResolver = titleResolver;
  }

  activate(): void {
    if (this.disposed || this.active) {
      return;
    }
    this.active = true;
    this.observeSharedState();
    const generation = ++this.generation;
    this.loading = true;
    this.state = ViewModelLoadState.LOADING;
    // Publish source state before the asynchronous initializers settle so the
    // page can render a deterministic loading projection immediately.
    this.publishProjection();
    Promise.all([
      this.favorites.initialize(),
      this.history.initialize(),
      this.research.initialize()
    ]).then((): void => {
      if (!this.isCurrent(generation)) {
        return;
      }
      this.publishProjection();
      this.loading = false;
      this.state = this.sourceError().length > 0 ? ViewModelLoadState.PARTIAL : ViewModelLoadState.READY;
      this.enrichStoredHistoryTitles(generation);
    }).catch((error: Object): void => {
      if (!this.isCurrent(generation)) {
        return;
      }
      this.publishProjection();
      this.loading = false;
      this.error = ViewModelErrorInfo.from(error, '终端资料读取失败');
      this.state = this.sourceError().length > 0 ? ViewModelLoadState.PARTIAL :
        ViewModelLoadState.ERROR;
      this.enrichStoredHistoryTitles(generation);
    });
  }

  deactivate(): void {
    if (this.disposed || !this.active) {
      return;
    }
    this.active = false;
    this.generation++;
    // A section retry may still be running in a shared repository.  Its
    // result is invalidated by the generation above; clear the UI gate now so
    // the next activation can retry immediately instead of inheriting a stale
    // marker from the hidden page.
    this.sourceRefreshes.clear();
    this.stopObservingSharedState();
    this.loading = false;
  }

  dispose(): void {
    if (this.disposed) {
      return;
    }
    this.deactivate();
    this.stopObservingSharedState();
    this.sourceRefreshes.clear();
    this.disposed = true;
  }

  refresh(): void {
    if (this.disposed || !this.active) {
      return;
    }
    this.observeSharedState();
    const generation = ++this.generation;
    this.loading = true;
    this.state = ViewModelLoadState.REFRESHING;
    this.error = undefined;
    this.publishProjection();
    Promise.all([
      this.favorites.reload(),
      this.history.reload(),
      this.research.reload()
    ]).then((): void => {
      if (!this.isCurrent(generation)) {
        return;
      }
      this.publishProjection();
      this.loading = false;
      this.state = this.sourceError().length > 0 ? ViewModelLoadState.PARTIAL :
        ViewModelLoadState.READY;
      this.enrichStoredHistoryTitles(generation);
    }).catch((error: Object): void => {
      if (this.isCurrent(generation)) {
        this.loading = false;
        this.publishProjection();
        this.error = ViewModelErrorInfo.from(error, '终端资料刷新失败');
        this.state = ViewModelLoadState.PARTIAL;
      }
    });
  }

  /** Retry one source without disturbing the other sections' snapshots. */
  refreshFavorites(): void {
    this.refreshSource('favorites', (): Promise<void> => this.favorites.reload(), '收藏刷新失败');
  }

  refreshHistory(): void {
    this.refreshSource('history', (): Promise<void> => this.history.reload(), '阅读记录刷新失败');
  }

  refreshResearch(): void {
    this.refreshSource('research', async (): Promise<void> => {
      await this.research.reload();
    }, '档案阅历刷新失败');
  }

  private refreshSource(source: string, operation: () => Promise<void>, fallback: string): void {
    if (this.disposed || !this.active || this.sourceRefreshes.has(source)) {
      return;
    }
    this.observeSharedState();
    // Keep the page generation unchanged: a section retry must not invalidate
    // an unrelated global refresh that is already in progress.
    const generation = this.generation;
    this.sourceRefreshes.set(source, generation);
    this.loading = true;
    this.state = ViewModelLoadState.REFRESHING;
    this.error = undefined;
    this.publishProjection();
    Promise.resolve().then((): Promise<void> => operation()).then((): void => {
      this.clearSourceRefresh(source, generation);
      if (!this.isCurrent(generation)) {
        return;
      }
      this.publishProjection();
      const sourceError = this.sourceError();
      this.error = sourceError.length > 0 ? new ViewModelErrorInfo(sourceError) : undefined;
      this.loading = this.favorites.loading || this.history.loading || this.research.loading;
      this.state = sourceError.length > 0 ? ViewModelLoadState.PARTIAL :
        (this.loading ? ViewModelLoadState.REFRESHING : ViewModelLoadState.READY);
      this.enrichStoredHistoryTitles(generation);
    }).catch((error: Object): void => {
      this.clearSourceRefresh(source, generation);
      if (!this.isCurrent(generation)) {
        return;
      }
      this.publishProjection();
      const sourceError = this.sourceError();
      this.error = sourceError.length > 0 ? new ViewModelErrorInfo(sourceError) :
        ViewModelErrorInfo.from(error, fallback);
      this.loading = this.favorites.loading || this.history.loading || this.research.loading;
      this.state = ViewModelLoadState.PARTIAL;
    });
  }

  private clearSourceRefresh(source: string, generation: number): void {
    if (this.sourceRefreshes.get(source) === generation) {
      this.sourceRefreshes.delete(source);
    }
  }

  private publishProjection(): void {
    this.favoriteEntries = this.favorites.items.slice(0, 5);
    this.favoriteCount = this.favorites.items.length;
    this.favoriteLoading = this.favorites.loading;
    this.favoriteError = this.favorites.error;
    this.favoriteInitialized = this.favorites.initialized;
    this.historyCount = this.history.items.length;
    this.historyLoading = this.history.loading;
    this.historyError = this.history.error;
    this.historyInitialized = this.history.initialized;
    const resumable = this.history.resumableItems !== undefined ?
      this.history.resumableItems :
      this.history.items.filter((entry: ReadingHistoryEntry): boolean => entry.scrollOffset > 0);
    this.resumeEntries = resumable.slice(0, 1);
    const resumeKey = this.resumeEntries.length > 0 ? this.resumeEntries[0].content.key : '';
    this.recentEntries = this.history.items
      .filter((entry: ReadingHistoryEntry): boolean => entry.content.key !== resumeKey)
      .slice(0, 4);
    this.recentCount = this.history.items.filter((entry: ReadingHistoryEntry): boolean =>
      entry.content.key !== resumeKey).length;
    this.profile = this.research.profile;
    this.researchLoading = this.research.loading;
    this.researchError = this.research.error;
    this.researchInitialized = this.research.initialized;
    const sourceError = this.sourceError();
    this.error = sourceError.length > 0 ? new ViewModelErrorInfo(sourceError) : undefined;
  }

  private sourceError(): string {
    const errors: string[] = [];
    if (this.favorites.error.length > 0) {
      errors.push(`收藏：${this.favorites.error}`);
    }
    if (this.history.error.length > 0) {
      errors.push(`阅读记录：${this.history.error}`);
    }
    if (this.research.error.length > 0) {
      errors.push(`档案阅历：${this.research.error}`);
    }
    return errors.join('；');
  }

  private async enrichStoredHistoryTitles(generation: number): Promise<void> {
    if (this.titleResolver === undefined || this.enrichmentGeneration === generation ||
      !this.isCurrent(generation)) {
      return;
    }
    this.enrichmentGeneration = generation;
    try {
      const candidates: ReadingHistoryEntry[] = [];
      const seenKeys: Set<string> = new Set();
      const collectCandidates = (entries: ReadingHistoryEntry[]): void => {
        for (let index = 0; index < entries.length; index++) {
          const entry = entries[index];
          if (seenKeys.has(entry.content.key)) {
            continue;
          }
          if (entry.content.kind === LibraryContentKind.SCP &&
            isLibraryContentTitlePlaceholder(entry.content.id, entry.content.title)) {
            seenKeys.add(entry.content.key);
            candidates.push(entry);
          }
        }
      };
      collectCandidates(this.resumeEntries);
      collectCandidates(this.history.items);
      const ids: string[] = [];
      const seenIds: Set<string> = new Set();
      for (let index = 0; index < candidates.length; index++) {
        const id = candidates[index].content.id;
        if (!seenIds.has(id)) {
          seenIds.add(id);
          ids.push(id);
        }
      }
      if (ids.length === 0) {
        return;
      }
      const titles = await this.titleResolver(ids);
      if (!this.isCurrent(generation)) {
        return;
      }
      for (let index = 0; index < candidates.length; index++) {
        if (!this.isCurrent(generation)) {
          return;
        }
        const entry = candidates[index];
        const title = titles.get(entry.content.id) ?? '';
        if (title.length > 0) {
          await this.history.updateMetadata(createLibraryContentRef(
            entry.content.kind,
            entry.content.id,
            title
          ));
          if (!this.isCurrent(generation)) {
            return;
          }
        }
      }
      if (!this.isCurrent(generation)) {
        return;
      }
      this.publishProjection();
    } catch (_error) {
      // 标题补全是派生优化，失败不影响终端主内容。
    } finally {
      if (this.enrichmentGeneration === generation) {
        this.enrichmentGeneration = -1;
      }
    }
  }

  private observeSharedState(): void {
    if (this.favoritesUnsubscribe === undefined) {
      this.favoritesUnsubscribe = this.favorites.subscribe((): void => {
        if (this.active && !this.disposed) {
          this.publishProjection();
        }
      });
    }
    if (this.historyUnsubscribe === undefined) {
      this.historyUnsubscribe = this.history.subscribe((): void => {
        if (this.active && !this.disposed) {
          this.publishProjection();
          // History can be populated after activation (or after a catalog
          // cache refresh).  Re-run the derived title pass for newly arrived
          // placeholders instead of limiting enrichment to the first load.
          this.enrichStoredHistoryTitles(this.generation);
        }
      });
    }
    if (this.researchUnsubscribe === undefined) {
      this.researchUnsubscribe = this.research.subscribe((): void => {
        if (this.active && !this.disposed) {
          this.publishProjection();
        }
      });
    }
  }

  private stopObservingSharedState(): void {
    this.favoritesUnsubscribe?.();
    this.favoritesUnsubscribe = undefined;
    this.historyUnsubscribe?.();
    this.historyUnsubscribe = undefined;
    this.researchUnsubscribe?.();
    this.researchUnsubscribe = undefined;
  }

  private isCurrent(generation: number): boolean {
    return !this.disposed && this.active && generation === this.generation;
  }
}
