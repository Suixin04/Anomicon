import { cacheDownload } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'AnomiconImageWarm';
const MEMORY_CACHE_BYTES: number = 32 * 1024 * 1024;
const FILE_CACHE_BYTES: number = 192 * 1024 * 1024;
const MAX_ACTIVE_DOWNLOADS: number = 6;
const MAX_QUEUED_DOWNLOADS: number = 12;
const RECENT_SUCCESS_WINDOW_MS: number = 30 * 60 * 1000;
const RECENT_FAILURE_WINDOW_MS: number = 5 * 60 * 1000;
const HISTORY_PURGE_INTERVAL_MS: number = 60 * 1000;

export enum ScpImagePrefetchPriority {
  VISIBLE = 0,
  NEAR_VIEWPORT = 1,
  BACKGROUND = 2
}

class ScpImagePrefetchTask {
  readonly url: string;
  priority: ScpImagePrefetchPriority;
  readonly sequence: number;
  readonly owners: Set<string> = new Set<string>();

  constructor(
    url: string,
    priority: ScpImagePrefetchPriority,
    sequence: number,
    owner: string
  ) {
    this.url = url;
    this.priority = priority;
    this.sequence = sequence;
    this.owners.add(owner);
  }
}

/**
 * ArkUI 网络图片的官方缓存预热入口。
 *
 * cacheDownload 与支持该能力的 Image 组件共享 URL 缓存。服务只做有界预下载，
 * 不暴露缓存文件路径；最终渲染始终使用完全相同的规范化 URL。
 */
export class ScpImagePrefetchService {
  private initialized: boolean = false;
  private available: boolean = false;
  private maxActiveDownloads: number = MAX_ACTIVE_DOWNLOADS;
  private prefetchPaused: boolean = false;
  private nextSequence: number = 0;
  private lastHistoryPurgeAt: number = 0;
  private readonly queued: ScpImagePrefetchTask[] = [];
  private readonly active: Map<string, ScpImagePrefetchTask> = new Map<string, ScpImagePrefetchTask>();
  private readonly recentSuccesses: Map<string, number> = new Map<string, number>();
  private readonly recentFailures: Map<string, number> = new Map<string, number>();
  private readonly waiters: Map<string, Array<(success: boolean) => void>> =
    new Map<string, Array<(success: boolean) => void>>();

  initialize(): void {
    if (this.initialized) {
      return;
    }
    try {
      if (!canIUse('SystemCapability.Request.FileTransferAgent')) {
        // Capability absence is a stable device property; mark the service as
        // initialized so every card does not repeat the probe.
        this.initialized = true;
        this.available = false;
        hilog.warn(DOMAIN, TAG, 'cacheDownload unavailable on this device');
        return;
      }
      // 官方默认内存缓存为 0；显式给图片预热保留克制的 LRU 预算。
      cacheDownload.setMemoryCacheSize(MEMORY_CACHE_BYTES);
      cacheDownload.setFileCacheSize(FILE_CACHE_BYTES);
      this.available = true;
      this.initialized = true;
      hilog.info(DOMAIN, TAG, 'cacheDownload initialized: memory=%{public}d file=%{public}d',
        MEMORY_CACHE_BYTES, FILE_CACHE_BYTES);
    } catch (error) {
      // Leave initialized=false so a later visible request can retry after a
      // transient platform/configuration failure.
      this.available = false;
      const message = error instanceof Error ? error.message : 'unknown error';
      hilog.warn(DOMAIN, TAG, 'cacheDownload initialization failed: %{public}s', message);
    }
  }

  setNetworkPolicy(maxActive: number, pauseBackgroundPrefetch: boolean): void {
    this.maxActiveDownloads = Math.max(1, Math.min(MAX_ACTIVE_DOWNLOADS, Math.floor(maxActive)));
    this.prefetchPaused = pauseBackgroundPrefetch;
    if (pauseBackgroundPrefetch) {
      for (let index: number = this.queued.length - 1; index >= 0; index--) {
        if (this.queued[index].priority >= ScpImagePrefetchPriority.NEAR_VIEWPORT) {
          const dropped = this.queued.splice(index, 1)[0];
          this.resolveWaiters(dropped.url, false);
        }
      }
    }
    this.drain();
  }

  prefetch(
    url: string,
    priority: ScpImagePrefetchPriority = ScpImagePrefetchPriority.NEAR_VIEWPORT,
    owner: string = 'global'
  ): void {
    if (!this.initialized) {
      this.initialize();
    }
    if (!this.available || !url.startsWith('https://') || url.length > 8192) {
      return;
    }
    if (this.prefetchPaused && priority >= ScpImagePrefetchPriority.NEAR_VIEWPORT) {
      return;
    }
    const now = Date.now();
    this.purgeHistory(now);
    const successAt = this.recentSuccesses.get(url) ?? 0;
    const failureAt = this.recentFailures.get(url) ?? 0;
    if (now - successAt < RECENT_SUCCESS_WINDOW_MS ||
      now - failureAt < RECENT_FAILURE_WINDOW_MS) {
      return;
    }
    const activeTask = this.active.get(url);
    if (activeTask !== undefined) {
      activeTask.owners.add(owner);
      if (priority < activeTask.priority) {
        activeTask.priority = priority;
      }
      return;
    }
    const queuedTask = this.findQueued(url);
    if (queuedTask !== undefined) {
      queuedTask.owners.add(owner);
      if (priority < queuedTask.priority) {
        queuedTask.priority = priority;
      }
      this.drain();
      return;
    }
    this.queued.push(new ScpImagePrefetchTask(url, priority, this.nextSequence++, owner));
    this.trimQueue();
    this.drain();
  }

  /**
   * 受控预热并等待结果。调用方随后用同一 URL 创建 Image，系统会直接复用
   * cacheDownload 的缓存；失败时返回 false，调用方仍可交给 Image 自行兜底。
   */
  warm(
    url: string,
    priority: ScpImagePrefetchPriority = ScpImagePrefetchPriority.VISIBLE,
    owner: string = 'global'
  ): Promise<boolean> {
    if (!this.initialized) {
      this.initialize();
    }
    if (!this.available || !url.startsWith('https://') || url.length > 8192) {
      return Promise.resolve(false);
    }
    if (this.prefetchPaused && priority >= ScpImagePrefetchPriority.NEAR_VIEWPORT) {
      return Promise.resolve(false);
    }
    const now = Date.now();
    this.purgeHistory(now);
    const successAt = this.recentSuccesses.get(url) ?? 0;
    const failureAt = this.recentFailures.get(url) ?? 0;
    if (now - successAt < RECENT_SUCCESS_WINDOW_MS) {
      return Promise.resolve(true);
    }
    if (now - failureAt < RECENT_FAILURE_WINDOW_MS) {
      return Promise.resolve(false);
    }
    const result = new Promise<boolean>((resolve: (success: boolean) => void): void => {
      const current = this.waiters.get(url) ?? [];
      current.push(resolve);
      this.waiters.set(url, current);
    });
    this.prefetch(url, priority, owner);
    return result;
  }

  /** 只移除尚未开始且已无其他所有者的任务；活动 URL 不做全局 cancel。 */
  cancelOwner(owner: string): void {
    for (let index: number = this.queued.length - 1; index >= 0; index--) {
      const task = this.queued[index];
      task.owners.delete(owner);
      if (task.owners.size === 0) {
        this.queued.splice(index, 1);
        this.resolveWaiters(task.url, false);
      }
    }
    this.active.forEach((task: ScpImagePrefetchTask): void => {
      task.owners.delete(owner);
    });
  }

  private drain(): void {
    while (this.active.size < this.maxActiveDownloads && this.queued.length > 0) {
      const index = this.nextTaskIndex();
      if (index < 0) {
        return;
      }
      const task = this.queued.splice(index, 1)[0];
      this.start(task);
    }
  }

  private start(task: ScpImagePrefetchTask): void {
    this.active.set(task.url, task);
    let settled: boolean = false;
    const successCallback = (): void => {
      if (settled) {
        return;
      }
      settled = true;
      this.unregisterCallbacks(task.url, successCallback, errorCallback);
      this.active.delete(task.url);
      this.recentSuccesses.set(task.url, Date.now());
      this.recentFailures.delete(task.url);
      this.resolveWaiters(task.url, true);
      hilog.info(DOMAIN, TAG, 'image cache warmed: %{public}s', task.url);
      this.drain();
    };
    const errorCallback = (error: cacheDownload.DownloadError): void => {
      if (settled) {
        return;
      }
      settled = true;
      this.unregisterCallbacks(task.url, successCallback, errorCallback);
      this.active.delete(task.url);
      this.recentFailures.set(task.url, Date.now());
      this.resolveWaiters(task.url, false);
      hilog.warn(DOMAIN, TAG,
        'image cache warm failed: type=%{public}d message=%{public}s url=%{public}s',
        error.errorCode, error.message, task.url);
      this.drain();
    };
    try {
      cacheDownload.onDownloadSuccess(task.url, successCallback);
      cacheDownload.onDownloadError(task.url, errorCallback);
      hilog.info(DOMAIN, TAG, 'image cache warm started: %{public}s', task.url);
      cacheDownload.download(task.url, {
        headers: {
          'Accept': 'image/*',
          'User-Agent': 'Anomicon/0.8 HarmonyOS reader'
        },
        cacheStrategy: cacheDownload.CacheStrategy.LAZY,
        retry: { maxRetryCount: 1 },
        timeout: {
          networkCheckTimeout: 8,
          httpTotalTimeout: 60
        }
      });
    } catch (error) {
      if (settled) {
        return;
      }
      settled = true;
      this.unregisterCallbacks(task.url, successCallback, errorCallback);
      this.active.delete(task.url);
      this.recentFailures.set(task.url, Date.now());
      this.resolveWaiters(task.url, false);
      const message = error instanceof Error ? error.message : 'unknown error';
      hilog.warn(DOMAIN, TAG, 'image cache warm rejected: %{public}s url=%{public}s', message, task.url);
      this.drain();
    }
  }

  private unregisterCallbacks(
    url: string,
    successCallback: () => void,
    errorCallback: (error: cacheDownload.DownloadError) => void
  ): void {
    try {
      cacheDownload.offDownloadSuccess(url, successCallback);
    } catch (_error) {
    }
    try {
      cacheDownload.offDownloadError(url, errorCallback);
    } catch (_error) {
    }
  }

  private purgeHistory(now: number): void {
    if (now - this.lastHistoryPurgeAt < HISTORY_PURGE_INTERVAL_MS) {
      return;
    }
    this.lastHistoryPurgeAt = now;
    this.recentSuccesses.forEach((recordedAt: number, url: string): void => {
      if (now - recordedAt >= RECENT_SUCCESS_WINDOW_MS) {
        this.recentSuccesses.delete(url);
      }
    });
    this.recentFailures.forEach((recordedAt: number, url: string): void => {
      if (now - recordedAt >= RECENT_FAILURE_WINDOW_MS) {
        this.recentFailures.delete(url);
      }
    });
  }

  private findQueued(url: string): ScpImagePrefetchTask | undefined {
    for (let index: number = 0; index < this.queued.length; index++) {
      if (this.queued[index].url === url) {
        return this.queued[index];
      }
    }
    return undefined;
  }

  private resolveWaiters(url: string, success: boolean): void {
    const callbacks = this.waiters.get(url) ?? [];
    this.waiters.delete(url);
    for (let index: number = 0; index < callbacks.length; index++) {
      callbacks[index](success);
    }
  }

  private nextTaskIndex(): number {
    let selected: number = -1;
    for (let index: number = 0; index < this.queued.length; index++) {
      if (selected < 0 || this.queued[index].priority < this.queued[selected].priority ||
        (this.queued[index].priority === this.queued[selected].priority &&
          this.queued[index].sequence < this.queued[selected].sequence)) {
        selected = index;
      }
    }
    return selected;
  }

  private trimQueue(): void {
    while (this.queued.length > MAX_QUEUED_DOWNLOADS) {
      let dropIndex: number = -1;
      for (let index: number = 0; index < this.queued.length; index++) {
        if (dropIndex < 0 || this.queued[index].priority > this.queued[dropIndex].priority ||
          (this.queued[index].priority === this.queued[dropIndex].priority &&
            this.queued[index].sequence < this.queued[dropIndex].sequence)) {
          dropIndex = index;
        }
      }
      if (dropIndex < 0) {
        return;
      }
      const dropped = this.queued.splice(dropIndex, 1)[0];
      this.resolveWaiters(dropped.url, false);
    }
  }
}
