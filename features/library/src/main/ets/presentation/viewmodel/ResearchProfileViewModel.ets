import {
  ResearchActivityCheckpoint,
  ResearchActivityFinish,
  ResearchActivityStart,
  ResearchProgress,
  emptyResearchProgress
} from '../../domain/ResearchProgress';
import {
  ResearchActivityMutationResult,
  ResearchActivityRepo,
  ResearchActivitySnapshot,
  ResearchActivitySink
} from '../../domain/ResearchActivityRepo';

/** Lightweight state listener used by page-level projection ViewModels. */
export type ResearchProfileViewModelListener = () => void;

/**
 * 活动账本的应用级只读画像与写入门面。
 *
 * AppStorageV2 只共享本次 RDB 快照派生的摘要；进程重建后必须重新读取账本，
 * 不使用 PersistenceV2 保存经验或等级。
 */
@ObservedV2
export class ResearchProfileViewModel implements ResearchActivitySink {
  @Trace profile: ResearchProgress = emptyResearchProgress();
  @Trace loading: boolean = false;
  @Trace error: string = '';
  @Trace initialized: boolean = false;

  private readonly repository: ResearchActivityRepo;
  private initialization: Promise<void> | undefined = undefined;
  private operationTail: Promise<void> = Promise.resolve();
  private readonly listeners: ResearchProfileViewModelListener[] = [];

  constructor(repository: ResearchActivityRepo) {
    this.repository = repository;
  }

  subscribe(listener: ResearchProfileViewModelListener): () => void {
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
        this.applySnapshot(await this.repository.snapshot());
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

  async reload(): Promise<ResearchActivitySnapshot> {
    if (!this.initialized) {
      await this.initialize();
    }
    let loaded: ResearchActivitySnapshot | undefined = undefined;
    await this.enqueue(async (): Promise<void> => {
      this.loading = true;
      this.notifyListeners();
      try {
        loaded = await this.repository.snapshot();
        this.applySnapshot(loaded!);
        this.error = '';
      } catch (error) {
        this.error = this.errorMessage(error);
        this.notifyListeners();
        throw new Error(this.error);
      } finally {
        this.loading = false;
        this.notifyListeners();
      }
    });
    return loaded!;
  }

  async startSession(start: ResearchActivityStart): Promise<ResearchActivityMutationResult> {
    return this.mutate(async (): Promise<ResearchActivityMutationResult> =>
      this.repository.startSession(start)
    );
  }

  async checkpointSession(
    checkpoint: ResearchActivityCheckpoint
  ): Promise<ResearchActivityMutationResult> {
    return this.mutate(async (): Promise<ResearchActivityMutationResult> =>
      this.repository.checkpointSession(checkpoint)
    );
  }

  async finalizeSession(finish: ResearchActivityFinish): Promise<ResearchActivityMutationResult> {
    return this.mutate(async (): Promise<ResearchActivityMutationResult> =>
      this.repository.finalizeSession(finish)
    );
  }

  private async mutate(
    operation: () => Promise<ResearchActivityMutationResult>
  ): Promise<ResearchActivityMutationResult> {
    await this.initialize();
    let result: ResearchActivityMutationResult | undefined = undefined;
    await this.enqueue(async (): Promise<void> => {
      try {
        result = await operation();
        this.applyMutation(result!);
        this.error = '';
        this.notifyListeners();
      } catch (error) {
        this.error = this.errorMessage(error);
        this.notifyListeners();
        throw new Error(this.error);
      }
    });
    return result!;
  }

  private applySnapshot(snapshot: ResearchActivitySnapshot): void {
    this.profile = snapshot.profile;
  }

  private applyMutation(result: ResearchActivityMutationResult): void {
    this.profile = result.profile;
  }

  private notifyListeners(): void {
    const listeners = this.listeners.slice();
    for (let index = 0; index < listeners.length; index++) {
      try {
        listeners[index]();
      } catch (_error) {
        // A stale page listener must not interrupt ledger persistence.
      }
    }
  }

  private enqueue(operation: () => Promise<void>): Promise<void> {
    const next = this.operationTail.then(operation, operation);
    this.operationTail = next.catch((): void => {
      // 原始 Promise 继续向调用方抛错，队列尾恢复后仍可接收下一次生命周期写入。
    });
    return next;
  }

  private errorMessage(error: Object): string {
    return error instanceof Error ? error.message : '档案阅历读取失败';
  }
}
