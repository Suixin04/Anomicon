import { LibraryContentRef } from '../../domain/LibraryContentRef';
import {
  READING_HISTORY_LIMIT,
  ReadingHistoryEntry,
  ReadingStateEntry,
  hasPermanentReadingState
} from '../../domain/ReadingHistoryEntry';
import { ReadingHistoryRepository } from '../../domain/LibraryRepositories';

/** Lightweight state listener used by page-level projection ViewModels. */
export type ReadingHistoryViewModelListener = () => void;

/**
 * 阅读历史与永久阅读状态的应用级共享状态。
 *
 * 状态层与数据库服务各自串行化操作；写入成功并重新取得有序快照后，
 * 才发布新的 `items` 与永久状态投影，避免终端页观察到尚未落盘的进度。
 */
@ObservedV2
export class ReadingHistoryViewModel {
  @Trace items: ReadingHistoryEntry[] = [];
  @Trace readingStates: ReadingStateEntry[] = [];
  @Trace resumableItems: ReadingHistoryEntry[] = [];
  @Trace completedCount: number = 0;
  @Trace stateRevision: number = 0;
  @Trace loading: boolean = false;
  @Trace error: string = '';
  @Trace initialized: boolean = false;

  private readonly repository: ReadingHistoryRepository;
  private readonly historyLimit: number;
  private initialization: Promise<void> | undefined = undefined;
  private operationTail: Promise<void> = Promise.resolve();
  private readonly listeners: ReadingHistoryViewModelListener[] = [];
  private readonly stateByKey: Map<string, ReadingStateEntry> =
    new Map<string, ReadingStateEntry>();
  private readonly completedKeys: Set<string> = new Set<string>();
  private readonly completedIds: Set<string> = new Set<string>();

  subscribe(listener: ReadingHistoryViewModelListener): () => void {
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

  constructor(
    repository: ReadingHistoryRepository,
    historyLimit: number = READING_HISTORY_LIMIT
  ) {
    this.repository = repository;
    this.historyLimit = Number.isFinite(historyLimit) && historyLimit >= 1 ?
      Math.floor(historyLimit) : READING_HISTORY_LIMIT;
  }

  initialize(): Promise<void> {
    if (this.initialized) {
      return Promise.resolve();
    }
    if (this.initialization !== undefined) {
      return this.initialization;
    }
    const task = this.enqueue(async (): Promise<void> => {
      this.loading = true;
      this.error = '';
      this.notifyListeners();
      try {
        await this.loadFromRepository();
        this.initialized = true;
      } catch (error) {
        this.error = this.errorMessage(error);
        this.notifyListeners();
        throw new Error(this.error);
      } finally {
        this.loading = false;
        this.notifyListeners();
      }
    });
    this.initialization = task;
    task.catch((): void => {
      if (this.initialization === task) {
        this.initialization = undefined;
      }
    });
    return task;
  }

  /** O(1) 查询内容是否被用户标为已读（兼容 `main:slug`、`/slug` 与 `SCP-173`）。 */
  isCompleted(contentKeyOrId: string): boolean {
    const revision = this.stateRevision;
    if (revision < 0) {
      return false;
    }
    let normalized = contentKeyOrId.trim().toLowerCase();
    if (normalized.length === 0) {
      return false;
    }
    if (this.completedKeys.has(normalized)) {
      return true;
    }
    if (normalized.startsWith('main:')) {
      normalized = normalized.substring(5);
    }
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    return normalized.length > 0 && this.completedIds.has(normalized);
  }

  async recordOpened(content: LibraryContentRef): Promise<void> {
    await this.initialize();
    await this.enqueue(async (): Promise<void> => {
      try {
        const updated = await this.repository.recordOpened(content);
        this.publishMutation(updated);
        this.error = '';
        this.notifyListeners();
      } catch (error) {
        this.error = this.errorMessage(error);
        this.notifyListeners();
        throw new Error(this.error);
      }
    });
  }

  async updateProgress(content: LibraryContentRef, offset: number): Promise<void> {
    await this.initialize();
    await this.enqueue(async (): Promise<void> => {
      try {
        const updated = await this.repository.updateProgress(content, offset);
        this.publishMutation(updated);
        this.error = '';
        this.notifyListeners();
      } catch (error) {
        this.error = this.errorMessage(error);
        this.notifyListeners();
        throw new Error(this.error);
      }
    });
  }

  async setCompleted(content: LibraryContentRef, completed: boolean = true): Promise<void> {
    await this.initialize();
    if (this.repository.setCompleted === undefined) {
      throw new Error('当前阅读历史存储不支持完成标记');
    }
    await this.enqueue(async (): Promise<void> => {
      try {
        const updated = await this.repository.setCompleted!(content, completed === true);
        this.publishMutation(updated);
        this.error = '';
        this.notifyListeners();
      } catch (error) {
        this.error = this.errorMessage(error);
        this.notifyListeners();
        throw new Error(this.error);
      }
    });
  }

  /** 发布名称补全快照，但保持最近浏览时间、排序与进度完全不变。 */
  async updateMetadata(content: LibraryContentRef): Promise<void> {
    await this.initialize();
    await this.enqueue(async (): Promise<void> => {
      try {
        const updated = await this.repository.updateMetadata(content);
        if (updated !== undefined) {
          this.publishMetadataUpdate(updated);
        }
        this.error = '';
        this.notifyListeners();
      } catch (error) {
        this.error = this.errorMessage(error);
        this.notifyListeners();
        throw new Error(this.error);
      }
    });
  }

  /** 等待先前写入发布后按稳定内容身份查找，供阅读页恢复唯一滚动进度与已读状态。 */
  async find(contentKey: string): Promise<ReadingHistoryEntry | undefined> {
    await this.initialize();
    await this.operationTail;
    for (let index = 0; index < this.items.length; index++) {
      if (this.items[index].content.key === contentKey) {
        return this.items[index];
      }
    }
    const permanent = this.stateByKey.get(contentKey);
    if (permanent !== undefined) {
      return new ReadingHistoryEntry(
        permanent.content,
        permanent.updatedAt,
        permanent.updatedAt,
        permanent.scrollOffset,
        permanent.completed
      );
    }
    if (this.repository.listStates === undefined && this.repository.find !== undefined) {
      return await this.repository.find(contentKey);
    }
    return undefined;
  }

  async reload(): Promise<void> {
    if (!this.initialized) {
      await this.initialize();
      return;
    }
    await this.enqueue(async (): Promise<void> => {
      this.loading = true;
      this.notifyListeners();
      try {
        await this.loadFromRepository();
        this.error = '';
      } catch (error) {
        this.error = this.errorMessage(error);
        throw new Error(this.error);
      } finally {
        this.loading = false;
        this.notifyListeners();
      }
    });
  }

  private async loadFromRepository(): Promise<void> {
    const historyItems = await this.repository.list();
    const permanentStates = this.repository.listStates !== undefined ?
      await this.repository.listStates() : this.deriveStatesFromHistory(historyItems);
    this.replaceSnapshots(historyItems, permanentStates);
  }

  private replaceSnapshots(
    historyItems: ReadingHistoryEntry[],
    permanentStates: ReadingStateEntry[]
  ): void {
    const nextItems = historyItems.slice();
    nextItems.sort(compareHistoryEntries);
    this.items = nextItems.slice(0, this.historyLimit);

    this.stateByKey.clear();
    for (let index = 0; index < permanentStates.length; index++) {
      const state = permanentStates[index];
      if (hasPermanentReadingState(state.scrollOffset, state.completed)) {
        this.stateByKey.set(state.content.key, state);
      }
    }
    this.rebuildStateProjections();
  }

  private deriveStatesFromHistory(historyItems: ReadingHistoryEntry[]): ReadingStateEntry[] {
    const derived: ReadingStateEntry[] = [];
    for (let index = 0; index < historyItems.length; index++) {
      const entry = historyItems[index];
      if (hasPermanentReadingState(entry.scrollOffset, entry.completed)) {
        derived.push(new ReadingStateEntry(
          entry.content,
          entry.scrollOffset,
          entry.completed,
          entry.completed ? entry.lastReadAt : 0,
          entry.lastReadAt
        ));
      }
    }
    return derived;
  }

  private enqueue(operation: () => Promise<void>): Promise<void> {
    const next = this.operationTail.then(operation, operation);
    this.operationTail = next.catch((): void => {
      // 保持队列可继续执行；原始 Promise 仍将错误交给调用方处理。
    });
    return next;
  }

  /** 单条写入后在内存中发布有序新数组与永久状态索引，避免每次停止滚动都扫库。 */
  private publishMutation(updated: ReadingHistoryEntry): void {
    const next: ReadingHistoryEntry[] = [updated];
    for (let index = 0; index < this.items.length; index++) {
      if (this.items[index].content.key !== updated.content.key) {
        next.push(this.items[index]);
      }
    }
    next.sort(compareHistoryEntries);
    this.items = next.slice(0, this.historyLimit);

    const existingState = this.stateByKey.get(updated.content.key);
    if (hasPermanentReadingState(updated.scrollOffset, updated.completed)) {
      const completedAt = updated.completed ?
        (existingState !== undefined && existingState.completed && existingState.completedAt > 0 ?
          existingState.completedAt : updated.lastReadAt) :
        0;
      this.stateByKey.set(
        updated.content.key,
        new ReadingStateEntry(
          updated.content,
          updated.scrollOffset,
          updated.completed,
          completedAt,
          updated.lastReadAt
        )
      );
    } else {
      this.stateByKey.delete(updated.content.key);
    }
    this.rebuildStateProjections();
  }

  /** 标题补全只更新各自已存在的数据集，绝不把已裁出的永久条目重新塞回最近队列。 */
  private publishMetadataUpdate(updated: ReadingHistoryEntry): void {
    let itemsChanged = false;
    const nextItems: ReadingHistoryEntry[] = [];
    for (let index = 0; index < this.items.length; index++) {
      const current = this.items[index];
      if (current.content.key === updated.content.key) {
        nextItems.push(new ReadingHistoryEntry(
          updated.content,
          current.openedAt,
          current.lastReadAt,
          updated.scrollOffset,
          updated.completed
        ));
        itemsChanged = true;
      } else {
        nextItems.push(current);
      }
    }
    if (itemsChanged) {
      nextItems.sort(compareHistoryEntries);
      this.items = nextItems;
    }

    const existingState = this.stateByKey.get(updated.content.key);
    if (existingState !== undefined) {
      this.stateByKey.set(
        updated.content.key,
        new ReadingStateEntry(
          updated.content,
          existingState.scrollOffset,
          existingState.completed,
          existingState.completedAt,
          existingState.updatedAt
        )
      );
    }
    if (itemsChanged || existingState !== undefined) {
      this.rebuildStateProjections();
    }
  }

  private rebuildStateProjections(): void {
    const states: ReadingStateEntry[] = [];
    this.stateByKey.forEach((state: ReadingStateEntry): void => {
      states.push(state);
    });
    states.sort(compareReadingStates);
    this.readingStates = states;

    this.completedKeys.clear();
    this.completedIds.clear();
    const historyByKey: Map<string, ReadingHistoryEntry> =
      new Map<string, ReadingHistoryEntry>();
    for (let index = 0; index < this.items.length; index++) {
      historyByKey.set(this.items[index].content.key, this.items[index]);
    }

    const resumable: ReadingHistoryEntry[] = [];
    let completedTotal = 0;
    for (let index = 0; index < states.length; index++) {
      const state = states[index];
      if (state.completed) {
        this.completedKeys.add(state.content.key);
        this.completedIds.add(state.content.id);
        completedTotal++;
      }
      if (state.scrollOffset > 0) {
        const recent = historyByKey.get(state.content.key);
        if (recent !== undefined) {
          resumable.push(recent);
        } else {
          resumable.push(new ReadingHistoryEntry(
            state.content,
            state.updatedAt,
            state.updatedAt,
            state.scrollOffset,
            state.completed
          ));
        }
      }
    }
    resumable.sort(compareHistoryEntries);
    this.resumableItems = resumable;
    this.completedCount = completedTotal;
    this.stateRevision += 1;
  }

  private notifyListeners(): void {
    const listeners = this.listeners.slice();
    for (let index = 0; index < listeners.length; index++) {
      try {
        listeners[index]();
      } catch (_error) {
        // A stale page listener must not interrupt persistence operations.
      }
    }
  }

  private errorMessage(error: Object): string {
    return error instanceof Error ? error.message : '阅读历史操作失败';
  }
}

function compareHistoryEntries(left: ReadingHistoryEntry, right: ReadingHistoryEntry): number {
  if (left.lastReadAt !== right.lastReadAt) {
    return right.lastReadAt - left.lastReadAt;
  }
  return left.content.key.localeCompare(right.content.key);
}

function compareReadingStates(left: ReadingStateEntry, right: ReadingStateEntry): number {
  if (left.updatedAt !== right.updatedAt) {
    return right.updatedAt - left.updatedAt;
  }
  return left.content.key.localeCompare(right.content.key);
}
