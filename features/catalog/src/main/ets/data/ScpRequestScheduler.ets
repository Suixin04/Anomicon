import { ScpHtmlRequestPriority } from '../domain/ArticleHtmlRepository';

const DEFAULT_MAX_CONCURRENT_PAGE_REQUESTS: number = 4;
const DEFAULT_MAX_LOW_PRIORITY_REQUESTS: number = 2;

export interface ScpConcurrencyPolicy {
  readonly maxConcurrent: number;
  readonly maxLowPriority: number;
}

class ScpScheduledRequest {
  readonly key: string;
  priority: ScpHtmlRequestPriority;
  readonly sequence: number;
  readonly resolve: (priority: ScpHtmlRequestPriority) => void;

  constructor(
    key: string,
    priority: ScpHtmlRequestPriority,
    sequence: number,
    resolve: (priority: ScpHtmlRequestPriority) => void
  ) {
    this.key = key;
    this.priority = priority;
    this.sequence = sequence;
    this.resolve = resolve;
  }
}

/**
 * 中文主站页面请求的应用级优先级闸门。
 *
 * 并发上限可根据网络质量动态调整，始终为正文和可见卡片保留至少一个高优先级槽。
 * 等待任务按「优先级 → 入队顺序」选择，且同一 URL 的排队任务可以在用户真正打开时晋升。
 */
export class ScpRequestScheduler {
  private maxConcurrentRequests: number = DEFAULT_MAX_CONCURRENT_PAGE_REQUESTS;
  private maxLowPriorityRequests: number = DEFAULT_MAX_LOW_PRIORITY_REQUESTS;
  private activeRequests: number = 0;
  private activeLowPriorityRequests: number = 0;
  private nextSequence: number = 0;
  private readonly waiting: ScpScheduledRequest[] = [];

  constructor(
    maxConcurrent: number = DEFAULT_MAX_CONCURRENT_PAGE_REQUESTS,
    maxLowPriority: number = DEFAULT_MAX_LOW_PRIORITY_REQUESTS
  ) {
    this.setConcurrencyPolicy(maxConcurrent, maxLowPriority);
  }

  setConcurrencyPolicy(maxConcurrent: number, maxLowPriority: number): void {
    const nextMax = Math.max(1, Math.floor(maxConcurrent));
    const nextLow = nextMax <= 1 ?
      0 : Math.max(0, Math.min(nextMax - 1, Math.floor(maxLowPriority)));
    this.maxConcurrentRequests = nextMax;
    this.maxLowPriorityRequests = nextLow;
    this.drain();
  }

  getConcurrencyPolicy(): ScpConcurrencyPolicy {
    return {
      maxConcurrent: this.maxConcurrentRequests,
      maxLowPriority: this.maxLowPriorityRequests
    };
  }

  async run<T>(
    task: () => Promise<T>,
    priority: ScpHtmlRequestPriority = ScpHtmlRequestPriority.USER_INITIATED,
    key: string = ''
  ): Promise<T> {
    const grantedPriority = await this.acquire(key, priority);
    try {
      return await task();
    } finally {
      this.release(grantedPriority);
    }
  }

  /** 已排队的预取在变为可见/正文请求时原地晋升，不创建第二个网络任务。 */
  promote(key: string, priority: ScpHtmlRequestPriority): void {
    if (key.length === 0) {
      return;
    }
    let changed: boolean = false;
    for (let index: number = 0; index < this.waiting.length; index++) {
      const request = this.waiting[index];
      if (request.key === key && priority < request.priority) {
        request.priority = priority;
        changed = true;
      }
    }
    if (changed) {
      this.drain();
    }
  }

  private acquire(
    key: string,
    priority: ScpHtmlRequestPriority
  ): Promise<ScpHtmlRequestPriority> {
    if (this.canStart(priority) && this.waiting.length === 0) {
      this.markStarted(priority);
      return Promise.resolve(priority);
    }
    return new Promise<ScpHtmlRequestPriority>(
      (resolve: (grantedPriority: ScpHtmlRequestPriority) => void): void => {
        this.waiting.push(new ScpScheduledRequest(key, priority, this.nextSequence++, resolve));
        this.drain();
      }
    );
  }

  private release(priority: ScpHtmlRequestPriority): void {
    this.activeRequests = Math.max(0, this.activeRequests - 1);
    if (this.isLowPriority(priority)) {
      this.activeLowPriorityRequests = Math.max(0, this.activeLowPriorityRequests - 1);
    }
    this.drain();
  }

  private drain(): void {
    while (this.activeRequests < this.maxConcurrentRequests) {
      const index = this.nextEligibleIndex();
      if (index < 0) {
        return;
      }
      const request = this.waiting.splice(index, 1)[0];
      // 在唤醒 Promise continuation 前原子占用槽位，避免短暂超发。
      this.markStarted(request.priority);
      request.resolve(request.priority);
    }
  }

  private nextEligibleIndex(): number {
    let selectedIndex: number = -1;
    for (let index: number = 0; index < this.waiting.length; index++) {
      const candidate = this.waiting[index];
      if (!this.canStart(candidate.priority)) {
        continue;
      }
      if (selectedIndex < 0) {
        selectedIndex = index;
        continue;
      }
      const selected = this.waiting[selectedIndex];
      if (candidate.priority < selected.priority ||
        (candidate.priority === selected.priority && candidate.sequence < selected.sequence)) {
        selectedIndex = index;
      }
    }
    return selectedIndex;
  }

  private canStart(priority: ScpHtmlRequestPriority): boolean {
    if (this.activeRequests >= this.maxConcurrentRequests) {
      return false;
    }
    return !this.isLowPriority(priority) ||
      this.activeLowPriorityRequests < this.maxLowPriorityRequests;
  }

  private markStarted(priority: ScpHtmlRequestPriority): void {
    this.activeRequests++;
    if (this.isLowPriority(priority)) {
      this.activeLowPriorityRequests++;
    }
  }

  private isLowPriority(priority: ScpHtmlRequestPriority): boolean {
    return priority >= ScpHtmlRequestPriority.PREFETCH;
  }
}
