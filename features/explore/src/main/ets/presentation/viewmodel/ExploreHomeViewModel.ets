import {
  ExploreCombinedSnapshot,
  ExploreContentItem,
  ExploreEntry,
  ExploreRecommendation,
  ExploreRecommendationEntry,
  ExploreSourceSnapshot,
  exploreDayKey
} from '../../domain/ExploreContracts';
import {
  ExploreContentUseCase
} from '../../application/ExploreContentUseCase';
import { RecommendationUseCase } from '../../application/RecommendationUseCase';
import { ExploreRecommendationProgress } from '../../domain/ExploreRepositories';
import { ViewModelLifecycle, ViewModelLoadState } from 'anomiconbasic';
import {
  ExploreHomeEvent,
  ExploreHomeEventType
} from './ExploreViewModelContracts';

/**
 * Explore 首页的屏幕级 ViewModel。
 *
 * ViewModel 只依赖 application use case；页面生命周期通过
 * activate/deactivate/dispose 明确传入，所有异步回调都带 epoch + request token，
 * 因而页面离开或重新激活时不会把迟到结果写回旧状态。
 */
@ObservedV2
export class ExploreHomeViewModel implements ViewModelLifecycle {
  @Trace topRatedEntries: ExploreEntry[] = [];
  @Trace topRatedLoading: boolean = false;
  @Trace topRatedError: string = '';
  @Trace topRatedStatus: ViewModelLoadState = ViewModelLoadState.IDLE;
  @Trace topRatedStale: boolean = false;
  @Trace topRatedPartial: boolean = false;

  @Trace recentItems: ExploreContentItem[] = [];
  @Trace recentLoading: boolean = false;
  @Trace recentError: string = '';
  @Trace recentStatus: ViewModelLoadState = ViewModelLoadState.IDLE;
  @Trace recentStale: boolean = false;
  @Trace recentPartial: boolean = false;

  @Trace jokeItems: ExploreContentItem[] = [];
  @Trace jokeLoading: boolean = false;
  @Trace jokeError: string = '';
  @Trace jokeStatus: ViewModelLoadState = ViewModelLoadState.IDLE;
  @Trace jokeStale: boolean = false;
  @Trace jokePartial: boolean = false;

  @Trace recommendations: ExploreRecommendation[] = [];
  @Trace recommendationIndex: number = 0;
  @Trace recommendationBatch: number = 0;
  @Trace recommendationDeckVersion: number = 0;
  @Trace recommendationLoading: boolean = false;
  @Trace recommendationRefreshing: boolean = false;
  @Trace recommendationError: string = '';
  @Trace recommendationStatus: ViewModelLoadState = ViewModelLoadState.IDLE;

  @Trace activeDayKey: string;

  private readonly contentUseCase: ExploreContentUseCase;
  private readonly recommendationUseCase: RecommendationUseCase;
  private readonly dayKeyProvider: () => string;
  private lifecycleEpoch: number = 0;
  private topRatedRequestToken: number = 0;
  private recentRequestToken: number = 0;
  private jokeRequestToken: number = 0;
  private recommendationRequestToken: number = 0;
  private dayRolloverTimer: number = -1;
  private active: boolean = false;
  private disposed: boolean = false;
  private recommendationRequestBatch: number = 0;
  private recommendationRequestDayKey: string = '';
  /** The day for which the last successful jokes/recommendations request ran. */
  private topRatedLoaded: boolean = false;
  private recentLoaded: boolean = false;
  private jokeLoadedDayKey: string = '';
  private recommendationLoadedDayKey: string = '';
  /** Requests invalidated by deactivation are resumed on the next activation. */
  private retryTopRatedOnActivate: boolean = false;
  private retryRecentOnActivate: boolean = false;
  private retryJokesOnActivate: boolean = false;
  private retryRecommendationsOnActivate: boolean = false;

  constructor(
    contentUseCase: ExploreContentUseCase,
    recommendationUseCase: RecommendationUseCase,
    dayKeyProvider: () => string = exploreDayKey
  ) {
    this.contentUseCase = contentUseCase;
    this.recommendationUseCase = recommendationUseCase;
    this.dayKeyProvider = dayKeyProvider;
    this.activeDayKey = dayKeyProvider();
  }

  /** 激活时各区块独立启动；推荐优先发起，不等索引或索引的标题补齐。 */
  async activate(): Promise<void> {
    if (this.disposed || this.active) {
      return;
    }
    this.active = true;
    this.scheduleDayRollover();
    const today = this.dayKeyProvider();
    this.activeDayKey = today;
    const epoch = this.lifecycleEpoch;
    const tasks: Promise<void>[] = [];
    if (this.recommendationLoadedDayKey !== today || this.retryRecommendationsOnActivate) {
      const batch = this.recommendationRequestDayKey === today && this.retryRecommendationsOnActivate ?
        this.recommendationRequestBatch : 0;
      tasks.push(this.loadRecommendations(batch, epoch, today));
    }
    if (!this.recentLoaded || this.retryRecentOnActivate) {
      tasks.push(this.loadRecentInternal(this.retryRecentOnActivate, epoch));
      this.retryRecentOnActivate = false;
    }
    if (this.jokeLoadedDayKey !== today || this.retryJokesOnActivate) {
      tasks.push(this.loadJokesInternal(this.retryJokesOnActivate, epoch, today));
      this.retryJokesOnActivate = false;
    }
    if (!this.topRatedLoaded || this.retryTopRatedOnActivate) {
      tasks.push(this.loadTopRatedInternal(this.retryTopRatedOnActivate, epoch));
      this.retryTopRatedOnActivate = false;
    }
    await Promise.all(tasks);
  }

  /** 暂停屏幕并使所有在途请求失效；可稍后再次 activate。 */
  deactivate(): void {
    // Lifecycle callbacks can arrive from more than one page hook (for
    // example onHidden + onInactive).  Once the VM is inactive, keep the
    // retry markers captured by the first transition instead of recomputing
    // them from the already-reset loading flags.
    if (this.disposed || !this.active) {
      return;
    }
    this.active = false;
    this.lifecycleEpoch++;
    this.topRatedRequestToken++;
    this.recentRequestToken++;
    this.jokeRequestToken++;
    this.recommendationRequestToken++;
    this.retryTopRatedOnActivate = this.topRatedLoading ||
      this.topRatedStatus === ViewModelLoadState.LOADING ||
      this.topRatedStatus === ViewModelLoadState.REFRESHING;
    this.retryRecentOnActivate = this.recentLoading ||
      this.recentStatus === ViewModelLoadState.LOADING ||
      this.recentStatus === ViewModelLoadState.REFRESHING;
    this.retryJokesOnActivate = this.jokeLoading ||
      this.jokeStatus === ViewModelLoadState.LOADING ||
      this.jokeStatus === ViewModelLoadState.REFRESHING;
    this.retryRecommendationsOnActivate = this.recommendationLoading ||
      this.recommendationRefreshing ||
      this.recommendationStatus === ViewModelLoadState.LOADING ||
      this.recommendationStatus === ViewModelLoadState.REFRESHING;
    this.clearDayRolloverTimer();
    this.resetInFlightFlags();
  }

  /** 永久释放屏幕状态；释放后任何异步结果都会被丢弃。 */
  dispose(): void {
    if (this.disposed) {
      return;
    }
    this.deactivate();
    this.disposed = true;
  }

  dispatch(event: ExploreHomeEvent): Promise<void> {
    switch (event.type) {
      case ExploreHomeEventType.RETRY_TOP_RATED:
        return this.loadTopRated(true);
      case ExploreHomeEventType.RETRY_RECENT:
        return this.loadRecent(true);
      case ExploreHomeEventType.RETRY_JOKES:
        return this.loadJokes(true);
      case ExploreHomeEventType.REFRESH_RECOMMENDATIONS:
        return this.refreshRecommendations();
      case ExploreHomeEventType.DISMISS_RECOMMENDATION:
        this.nextRecommendation();
        return Promise.resolve();
      case ExploreHomeEventType.REFRESH_DAY:
        return this.refreshDay();
    }
    return Promise.resolve();
  }

  loadTopRated(force: boolean = false): Promise<void> {
    return this.loadTopRatedInternal(force, this.lifecycleEpoch);
  }

  loadRecent(force: boolean = false): Promise<void> {
    return this.loadRecentInternal(force, this.lifecycleEpoch);
  }

  loadJokes(force: boolean = false): Promise<void> {
    return this.loadJokesInternal(force, this.lifecycleEpoch);
  }

  /** 重新生成下一批推荐；正在请求时保持幂等。 */
  refreshRecommendations(): Promise<void> {
    if (this.recommendationLoading || this.recommendationRefreshing || !this.active || this.disposed) {
      return Promise.resolve();
    }
    return this.loadRecommendations(this.recommendationBatch + 1, this.lifecycleEpoch);
  }

  /** 丢弃当前顶牌并显示下一层；卡牌数量不足时保持原索引。 */
  nextRecommendation(): void {
    if (this.disposed || !this.active || this.recommendations.length <= 1) {
      return;
    }
    this.recommendationIndex = (this.recommendationIndex + 1) % this.recommendations.length;
  }

  /** 检查自然日；joke 与推荐在午夜各刷新一次。 */
  async refreshDay(): Promise<void> {
    if (this.disposed) {
      return;
    }
    const today = this.dayKeyProvider();
    if (!this.active) {
      return;
    }
    const dayChanged = today !== this.activeDayKey;
    this.activeDayKey = today;
    const epoch = this.lifecycleEpoch;
    const tasks: Promise<void>[] = [];
    if (dayChanged || (this.recommendationLoadedDayKey !== today &&
      !this.recommendationLoading && !this.recommendationRefreshing)) {
      tasks.push(this.loadRecommendations(0, epoch, today));
    }
    if (dayChanged || (this.jokeLoadedDayKey !== today && !this.jokeLoading)) {
      tasks.push(this.loadJokesInternal(false, epoch, today));
    }
    await Promise.all(tasks);
  }

  private async loadTopRatedInternal(force: boolean, epoch: number): Promise<void> {
    if (this.disposed || !this.active) {
      return;
    }
    const token = ++this.topRatedRequestToken;
    this.topRatedLoading = true;
    this.topRatedError = '';
    this.topRatedStatus = this.topRatedEntries.length > 0 ?
      ViewModelLoadState.REFRESHING : ViewModelLoadState.LOADING;
    try {
      const snapshot: ExploreSourceSnapshot = await this.contentUseCase.loadTopRated(force);
      if (!this.isSourceCurrent(epoch, token, this.topRatedRequestToken)) {
        return;
      }
      this.topRatedEntries = snapshot.entries;
      this.topRatedError = snapshot.error;
      this.topRatedStale = snapshot.stale;
      this.topRatedPartial = snapshot.partial;
      this.topRatedStatus = this.statusOf(snapshot.entries.length, snapshot.error, snapshot.stale);
      // A successful empty payload is still an attempted load and must not be
      // re-requested on every tab activation.  Semantic/network errors remain
      // retryable when no usable entries were returned.
      this.topRatedLoaded = snapshot.error.length === 0 || snapshot.entries.length > 0;
    } catch (error) {
      if (this.isSourceCurrent(epoch, token, this.topRatedRequestToken)) {
        this.topRatedError = this.messageOf(error, '热门内容加载失败');
        this.topRatedStatus = this.topRatedEntries.length > 0 ?
          ViewModelLoadState.PARTIAL : ViewModelLoadState.ERROR;
        this.topRatedPartial = this.topRatedEntries.length > 0;
      }
    } finally {
      if (this.isSourceCurrent(epoch, token, this.topRatedRequestToken)) {
        this.topRatedLoading = false;
      }
    }
  }

  private async loadRecentInternal(force: boolean, epoch: number): Promise<void> {
    if (this.disposed || !this.active) {
      return;
    }
    const token = ++this.recentRequestToken;
    this.recentLoading = true;
    this.recentError = '';
    this.recentStatus = this.recentItems.length > 0 ?
      ViewModelLoadState.REFRESHING : ViewModelLoadState.LOADING;
    try {
      const snapshot: ExploreCombinedSnapshot = await this.contentUseCase.loadRecent(force,
        (progress: ExploreCombinedSnapshot): void => {
          if (this.isSourceCurrent(epoch, token, this.recentRequestToken)) {
            this.recentItems = progress.items;
            this.recentStatus = ViewModelLoadState.REFRESHING;
          }
        });
      if (!this.isSourceCurrent(epoch, token, this.recentRequestToken)) {
        return;
      }
      this.recentItems = snapshot.items;
      this.recentError = snapshot.error;
      this.recentStale = snapshot.stale;
      this.recentPartial = snapshot.partial;
      this.recentStatus = this.statusOf(snapshot.items.length, snapshot.error, snapshot.stale);
      this.recentLoaded = snapshot.error.length === 0 || snapshot.items.length > 0;
    } catch (error) {
      if (this.isSourceCurrent(epoch, token, this.recentRequestToken)) {
        this.recentError = this.messageOf(error, '最近更新加载失败');
        this.recentStatus = this.recentItems.length > 0 ?
          ViewModelLoadState.PARTIAL : ViewModelLoadState.ERROR;
        this.recentPartial = this.recentItems.length > 0;
      }
    } finally {
      if (this.isSourceCurrent(epoch, token, this.recentRequestToken)) {
        this.recentLoading = false;
      }
    }
  }

  private async loadJokesInternal(
    force: boolean,
    epoch: number,
    dayKey: string = this.activeDayKey
  ): Promise<void> {
    if (this.disposed || !this.active) {
      return;
    }
    const token = ++this.jokeRequestToken;
    this.jokeLoading = true;
    this.jokeError = '';
    this.jokeStatus = this.jokeItems.length > 0 ?
      ViewModelLoadState.REFRESHING : ViewModelLoadState.LOADING;
    try {
      const snapshot: ExploreCombinedSnapshot = await this.contentUseCase.loadJokes(dayKey, force,
        (progress: ExploreCombinedSnapshot): void => {
          if (this.isDaySourceCurrent(epoch, token, this.jokeRequestToken, dayKey)) {
            this.jokeItems = progress.items;
            this.jokeStatus = ViewModelLoadState.REFRESHING;
          }
        });
      if (!this.isDaySourceCurrent(epoch, token, this.jokeRequestToken, dayKey)) {
        return;
      }
      this.jokeItems = snapshot.items;
      this.jokeError = snapshot.error;
      this.jokeStale = snapshot.stale;
      this.jokePartial = snapshot.partial;
      this.jokeStatus = this.statusOf(snapshot.items.length, snapshot.error, snapshot.stale);
      if (snapshot.error.length === 0 || snapshot.items.length > 0) {
        this.jokeLoadedDayKey = dayKey;
      }
      this.retryJokesOnActivate = false;
    } catch (error) {
      if (this.isDaySourceCurrent(epoch, token, this.jokeRequestToken, dayKey)) {
        this.jokeError = this.messageOf(error, '轻松内容加载失败');
        this.jokeStatus = this.jokeItems.length > 0 ?
          ViewModelLoadState.PARTIAL : ViewModelLoadState.ERROR;
        this.jokePartial = this.jokeItems.length > 0;
      }
    } finally {
      if (this.isDaySourceCurrent(epoch, token, this.jokeRequestToken, dayKey)) {
        this.jokeLoading = false;
      }
    }
  }

  private async loadRecommendations(
    batch: number,
    epoch: number,
    dayKey: string = this.activeDayKey
  ): Promise<void> {
    if (!this.isEpochCurrent(epoch)) {
      return;
    }
    const token = ++this.recommendationRequestToken;
    this.recommendationRequestBatch = batch;
    this.recommendationRequestDayKey = dayKey;
    this.retryRecommendationsOnActivate = false;
    this.recommendationLoading = this.recommendations.length === 0;
    this.recommendationRefreshing = !this.recommendationLoading;
    this.recommendationStatus = this.recommendationLoading ?
      ViewModelLoadState.LOADING : ViewModelLoadState.REFRESHING;
    this.recommendationError = '';

    let published: boolean = false;
    const isCurrent = (): boolean =>
      this.isDaySourceCurrent(epoch, token, this.recommendationRequestToken, dayKey);
    const progress: ExploreRecommendationProgress = {
      isCurrent: isCurrent,
      onCandidate: (item: ExploreRecommendation): void => {
        if (!isCurrent()) {
          return;
        }
        if (!published) {
          published = true;
          this.recommendationBatch = batch;
          this.recommendationIndex = 0;
          this.recommendationDeckVersion++;
          this.recommendations = [item];
          this.recommendationLoading = false;
          this.recommendationRefreshing = true;
          this.recommendationStatus = ViewModelLoadState.REFRESHING;
          return;
        }
        this.recommendations = this.recommendations.concat([item]);
      },
      onTitle: (itemId: string, title: string): void => {
        if (!isCurrent() || !published) {
          return;
        }
        const items = this.recommendations.slice();
        for (let index = 0; index < items.length; index++) {
          if (items[index].entry.itemId === itemId) {
            items[index] = new ExploreRecommendation(
              new ExploreRecommendationEntry(itemId, title), items[index].preview);
            this.recommendations = items;
            return;
          }
        }
      }
    };
    try {
      const items = await this.recommendationUseCase.loadDaily(batch, dayKey, progress);
      if (!isCurrent()) {
        return;
      }
      if (!published) {
        for (let index = 0; index < items.length; index++) {
          progress.onCandidate(items[index]);
        }
      }
      this.recommendationBatch = batch;
      if (!published && this.recommendations.length > 0) {
        this.recommendationError = '今天没有新的推荐，正在显示上一批推荐';
        this.recommendationStatus = ViewModelLoadState.PARTIAL;
      } else {
        this.recommendationStatus = ViewModelLoadState.READY;
      }
      this.recommendationLoadedDayKey = dayKey;
    } catch (error) {
      if (isCurrent()) {
        this.recommendationError = !published && this.recommendations.length > 0 ?
          '更新失败，正在显示上一批推荐' : this.messageOf(error, '今日推荐加载失败');
        this.recommendationStatus = this.recommendations.length > 0 ?
          ViewModelLoadState.PARTIAL : ViewModelLoadState.ERROR;
      }
    } finally {
      if (isCurrent()) {
        this.recommendationLoading = false;
        this.recommendationRefreshing = false;
      }
    }
  }

  private statusOf(itemCount: number, error: string, stale: boolean): ViewModelLoadState {
    if (itemCount === 0 && error.length > 0) {
      return ViewModelLoadState.ERROR;
    }
    if (error.length > 0 || stale) {
      return ViewModelLoadState.PARTIAL;
    }
    return ViewModelLoadState.READY;
  }

  private messageOf(error: Object, fallback: string): string {
    return error instanceof Error ? error.message : fallback;
  }

  private isEpochCurrent(epoch: number): boolean {
    return !this.disposed && this.active && epoch === this.lifecycleEpoch;
  }

  private isSourceCurrent(epoch: number, token: number, currentToken: number): boolean {
    return this.isEpochCurrent(epoch) && token === currentToken;
  }

  private isDaySourceCurrent(
    epoch: number,
    token: number,
    currentToken: number,
    dayKey: string
  ): boolean {
    return this.isSourceCurrent(epoch, token, currentToken) && dayKey === this.activeDayKey;
  }

  private scheduleDayRollover(): void {
    this.clearDayRolloverTimer();
    const now = new Date();
    const nextDay = new Date(now.getTime());
    nextDay.setHours(24, 0, 0, 250);
    const delay = Math.max(1000, nextDay.getTime() - now.getTime());
    const epoch = this.lifecycleEpoch;
    this.dayRolloverTimer = setTimeout((): void => {
      if (!this.isEpochCurrent(epoch)) {
        return;
      }
      this.dayRolloverTimer = -1;
      this.refreshDay();
      if (this.active && !this.disposed) {
        this.scheduleDayRollover();
      }
    }, delay);
  }

  private clearDayRolloverTimer(): void {
    if (this.dayRolloverTimer >= 0) {
      clearTimeout(this.dayRolloverTimer);
      this.dayRolloverTimer = -1;
    }
  }

  private resetInFlightFlags(): void {
    this.topRatedLoading = false;
    this.recentLoading = false;
    this.jokeLoading = false;
    this.recommendationLoading = false;
    this.recommendationRefreshing = false;
    if (this.topRatedStatus === ViewModelLoadState.LOADING ||
      this.topRatedStatus === ViewModelLoadState.REFRESHING) {
      this.topRatedStatus = this.topRatedEntries.length === 0 && this.topRatedError.length > 0 ?
        ViewModelLoadState.ERROR : (this.topRatedError.length > 0 || this.topRatedStale ||
          this.topRatedPartial ? ViewModelLoadState.PARTIAL : ViewModelLoadState.READY);
    }
    if (this.recentStatus === ViewModelLoadState.LOADING ||
      this.recentStatus === ViewModelLoadState.REFRESHING) {
      this.recentStatus = this.recentItems.length === 0 && this.recentError.length > 0 ?
        ViewModelLoadState.ERROR : (this.recentError.length > 0 || this.recentStale ||
          this.recentPartial ? ViewModelLoadState.PARTIAL : ViewModelLoadState.READY);
    }
    if (this.jokeStatus === ViewModelLoadState.LOADING ||
      this.jokeStatus === ViewModelLoadState.REFRESHING) {
      this.jokeStatus = this.jokeItems.length === 0 && this.jokeError.length > 0 ?
        ViewModelLoadState.ERROR : (this.jokeError.length > 0 || this.jokeStale ||
          this.jokePartial ? ViewModelLoadState.PARTIAL : ViewModelLoadState.READY);
    }
    if (this.recommendationStatus === ViewModelLoadState.LOADING ||
      this.recommendationStatus === ViewModelLoadState.REFRESHING) {
      // A request interrupted with no cards is pending recovery. Keep the
      // empty surface in initialization/idle rather than publishing READY,
      // which would render the unavailable/retry branch before reactivation
      // starts the next request.
      if (this.recommendations.length === 0 && this.retryRecommendationsOnActivate) {
        this.recommendationStatus = ViewModelLoadState.IDLE;
      } else {
        this.recommendationStatus = this.recommendations.length === 0 &&
          this.recommendationError.length > 0 ? ViewModelLoadState.ERROR :
          (this.recommendationError.length > 0 ? ViewModelLoadState.PARTIAL :
            ViewModelLoadState.READY);
      }
    }
  }
}
