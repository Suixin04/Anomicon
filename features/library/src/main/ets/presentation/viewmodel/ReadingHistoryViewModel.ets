import { LibraryContentRef } from '../../domain/LibraryContentRef';
import {
  READING_HISTORY_LIMIT,
  ReadingHistoryEntry
} from '../../domain/ReadingHistoryEntry';
import { ReadingHistoryRepository } from '../../domain/LibraryRepositories';

/** Lightweight state listener used by page-level projection ViewModels. */
export type ReadingHistoryViewModelListener = () => void;

/**
 * 阅读历史的应用级共享状态。
 *
 * 状态层与数据库服务各自串行化操作；写入成功并重新取得有序快照后，
 * 才整体替换 `items`，避免终端页观察到尚未落盘的进度。
 */
@ObservedV2
export class ReadingHistoryViewModel {
  @Trace items: ReadingHistoryEntry[] = [];
  @Trace loading: boolean = false;
  @Trace error: string = '';
  @Trace initialized: boolean = false;

  private readonly repository: ReadingHistoryRepository;
  private initialization: Promise<void> | undefined = undefined;
  private operationTail: Promise<void> = Promise.resolve();
  private readonly listeners: ReadingHistoryViewModelListener[] = [];

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

  constructor(repository: ReadingHistoryRepository) {
    this.repository = repository;
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
        this.items = await this.repository.list();
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

  async recordOpened(content: LibraryContentRef): Promise<void> {
    await this.initialize();
    await this.enqueue(async (): Promise<void> => {
      try {
        const updated = await this.repository.recordOpened(content);
        this.publishUpdated(updated);
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
        this.publishUpdated(updated);
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
        this.publishUpdated(updated);
        this.error = '';
        this.notifyListeners();
      } catch (error) {
        this.error = this.errorMessage(error);
        this.notifyListeners();
        throw new Error(this.error);
      }
    });
  }

  /** 发布名称补全快照，但保持最近浏览时间与进度完全不变。 */
  async updateMetadata(content: LibraryContentRef): Promise<void> {
    await this.initialize();
    await this.enqueue(async (): Promise<void> => {
      try {
        const updated = await this.repository.updateMetadata(content);
        if (updated !== undefined) {
          this.publishUpdated(updated);
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

  /** 等待先前写入发布后按稳定内容身份查找，供阅读页恢复唯一滚动进度。 */
  async find(contentKey: string): Promise<ReadingHistoryEntry | undefined> {
    await this.initialize();
    await this.operationTail;
    for (let index = 0; index < this.items.length; index++) {
      if (this.items[index].content.key === contentKey) {
        return this.items[index];
      }
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
        this.items = await this.repository.list();
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

  private enqueue(operation: () => Promise<void>): Promise<void> {
    const next = this.operationTail.then(operation, operation);
    this.operationTail = next.catch((): void => {
      // 保持队列可继续执行；原始 Promise 仍将错误交给调用方处理。
    });
    return next;
  }

  /** 单条写入后在内存中发布有序新数组，避免每次停止滚动都扫描整张历史表。 */
  private publishUpdated(updated: ReadingHistoryEntry): void {
    const next: ReadingHistoryEntry[] = [updated];
    for (let index = 0; index < this.items.length; index++) {
      if (this.items[index].content.key !== updated.content.key) {
        next.push(this.items[index]);
      }
    }
    next.sort((left: ReadingHistoryEntry, right: ReadingHistoryEntry): number => {
      if (left.lastReadAt !== right.lastReadAt) {
        return right.lastReadAt - left.lastReadAt;
      }
      return left.content.key.localeCompare(right.content.key);
    });
    this.items = next.slice(0, READING_HISTORY_LIMIT);
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
