import {
  ViewModelLifecycle,
  ViewModelErrorInfo,
  ViewModelLoadState,
  ViewModelSnapshot
} from 'anomiconbasic';
import {
  LibraryCollectionItem,
  LibraryCollectionMode,
  parseLibraryCollectionMode
} from '../../domain/LibraryContracts';
import { LibraryFavorite } from '../../domain/LibraryContentRef';
import { ReadingHistoryEntry } from '../../domain/ReadingHistoryEntry';
import { FavoritesViewModel } from './FavoritesViewModel';
import { ReadingHistoryViewModel } from './ReadingHistoryViewModel';

/** Immutable screen payload published through the common MVVM snapshot. */
export class LibraryCollectionScreenData {
  readonly mode: LibraryCollectionMode;
  readonly items: LibraryCollectionItem[];
  readonly routeError: ViewModelErrorInfo | undefined;

  constructor(
    mode: LibraryCollectionMode,
    items: LibraryCollectionItem[],
    routeError: ViewModelErrorInfo | undefined = undefined
  ) {
    this.mode = mode;
    this.items = items.slice();
    this.routeError = routeError;
  }
}

/**
 * 收藏/继续阅读/最近浏览全量页的页面级投影 VM。
 * 共享收藏与历史仍由应用级 VM 持久化；本类只负责模式、排序和生命周期。
 */
@ObservedV2
export class LibraryCollectionVM implements ViewModelLifecycle {
  mode: LibraryCollectionMode = LibraryCollectionMode.RECENT;
  items: LibraryCollectionItem[] = [];
  state: ViewModelLoadState = ViewModelLoadState.IDLE;
  // Loading/error are represented by `state` and the published snapshot. They
  // are kept as ordinary implementation data while a load is in flight so the
  // page has one reactive source instead of mirrored flags.
  private error: ViewModelErrorInfo | undefined = undefined;
  routeError: ViewModelErrorInfo | undefined = undefined;
  @Trace snapshot: ViewModelSnapshot<LibraryCollectionScreenData> =
    new ViewModelSnapshot<LibraryCollectionScreenData>(
      ViewModelLoadState.IDLE,
      new LibraryCollectionScreenData(LibraryCollectionMode.RECENT, [])
    );

  private readonly favorites: FavoritesViewModel;
  private readonly history: ReadingHistoryViewModel;
  private active: boolean = false;
  private disposed: boolean = false;
  private generation: number = 0;
  private favoritesUnsubscribe: (() => void) | undefined = undefined;
  private historyUnsubscribe: (() => void) | undefined = undefined;
  private snapshotRevision: number = 0;

  constructor(favorites: FavoritesViewModel, history: ReadingHistoryViewModel) {
    this.favorites = favorites;
    this.history = history;
  }

  activate(): void {
    if (this.disposed || this.active) {
      return;
    }
    this.active = true;
    this.observeSharedState();
    this.publishSnapshot();
    if (this.routeError !== undefined) {
      return;
    }
    const generation = ++this.generation;
    this.loadSources(generation);
  }

  deactivate(): void {
    // Route validation errors must not keep a hidden destination active.  A
    // malformed route still goes through the same teardown path so shared
    // subscriptions and in-flight projections are released promptly.
    if (this.disposed || !this.active) {
      return;
    }
    this.active = false;
    this.generation++;
    this.stopObservingSharedState();
    if (this.items.length === 0) {
      this.state = ViewModelLoadState.IDLE;
    }
    this.publishSnapshot();
  }

  dispose(): void {
    if (this.disposed) {
      return;
    }
    this.deactivate();
    this.stopObservingSharedState();
    this.disposed = true;
    this.publishSnapshot();
  }

  setRouteMode(value: string | undefined): void {
    if (this.disposed) {
      return;
    }
    const parsed = parseLibraryCollectionMode(value);
    if (parsed === undefined) {
      this.routeError = new ViewModelErrorInfo('资料列表参数无效', 'invalid_route', false);
      // onReady can report an invalid route after aboutToAppear has already
      // activated the VM.  Tear down shared subscriptions immediately so a
      // later favorites/history write cannot repopulate this error state.
      this.stopObservingSharedState();
      this.items = [];
      this.state = ViewModelLoadState.ERROR;
      this.generation++;
      this.publishSnapshot();
      return;
    }
    this.routeError = undefined;
    if (this.active) {
      this.observeSharedState();
    }
    this.setMode(parsed);
  }

  setMode(value: LibraryCollectionMode): void {
    if (this.disposed || this.routeError !== undefined) {
      return;
    }
    const changed = this.mode !== value;
    this.mode = value;
    this.publishProjection();
    this.publishSnapshot();
    if (this.active && (changed || this.items.length === 0 ||
      this.state === ViewModelLoadState.ERROR)) {
      const generation = ++this.generation;
      this.loadSources(generation, false);
    }
  }

  retry(): void {
    if (this.disposed || !this.active || this.routeError !== undefined) {
      return;
    }
    const generation = ++this.generation;
    this.loadSources(generation, true);
  }

  private loadSources(generation: number, forceReload: boolean = false): void {
    if (this.disposed || !this.active || this.routeError !== undefined) {
      return;
    }
    this.state = this.items.length > 0 ? ViewModelLoadState.REFRESHING : ViewModelLoadState.LOADING;
    this.error = undefined;
    this.publishSnapshot();
    const task = this.mode === LibraryCollectionMode.FAVORITES ?
      (forceReload ? this.favorites.reload() : this.favorites.initialize()) :
      (forceReload ? this.history.reload() : this.history.initialize());
    task.then((): void => {
      if (!this.isCurrent(generation)) {
        return;
      }
      this.publishProjection();
      this.state = ViewModelLoadState.READY;
      this.publishSnapshot();
    }).catch((error: Object): void => {
      if (!this.isCurrent(generation)) {
        return;
      }
      this.error = ViewModelErrorInfo.from(error, '资料列表读取失败');
      this.state = this.items.length > 0 ? ViewModelLoadState.PARTIAL : ViewModelLoadState.ERROR;
      this.publishSnapshot();
    });
  }

  private publishProjection(): void {
    const projected: LibraryCollectionItem[] = [];
    if (this.mode === LibraryCollectionMode.FAVORITES) {
      const favorites: LibraryFavorite[] = this.favorites.items;
      for (let index = 0; index < favorites.length; index++) {
        projected.push(new LibraryCollectionItem(favorites[index].content, favorites[index].favoritedAt));
      }
    } else if (this.mode === LibraryCollectionMode.CONTINUE_READING) {
      const resumable: ReadingHistoryEntry[] = this.history.resumableItems;
      for (let index = 0; index < resumable.length; index++) {
        const entry = resumable[index];
        projected.push(new LibraryCollectionItem(entry.content, entry.lastReadAt));
      }
    } else {
      const history: ReadingHistoryEntry[] = this.history.items;
      for (let index = 0; index < history.length; index++) {
        const entry = history[index];
        projected.push(new LibraryCollectionItem(entry.content, entry.lastReadAt));
      }
    }
    this.items = projected;
  }

  /** Keep the page projection current after an article toggles a favorite or
   * writes reading progress while this route remains mounted. */
  private observeSharedState(): void {
    if (this.favoritesUnsubscribe === undefined) {
      this.favoritesUnsubscribe = this.favorites.subscribe((): void => {
        if (this.active && !this.disposed) {
          this.publishProjection();
          this.publishSnapshot();
        }
      });
    }
    if (this.historyUnsubscribe === undefined) {
      this.historyUnsubscribe = this.history.subscribe((): void => {
        if (this.active && !this.disposed) {
          this.publishProjection();
          this.publishSnapshot();
        }
      });
    }
  }

  private stopObservingSharedState(): void {
    this.favoritesUnsubscribe?.();
    this.favoritesUnsubscribe = undefined;
    this.historyUnsubscribe?.();
    this.historyUnsubscribe = undefined;
  }

  private isCurrent(generation: number): boolean {
    return !this.disposed && this.active && generation === this.generation;
  }

  private publishSnapshot(): void {
    this.snapshotRevision += 1;
    this.snapshot = new ViewModelSnapshot<LibraryCollectionScreenData>(
      this.state,
      new LibraryCollectionScreenData(this.mode, this.items, this.routeError),
      this.routeError ?? this.error,
      undefined,
      false,
      this.state === ViewModelLoadState.PARTIAL,
      this.snapshotRevision
    );
  }
}
