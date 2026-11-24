import { describe, expect, it } from '@ohos/hypium';
import { ViewModelLoadState } from 'anomiconbasic';
import {
  ExploreDataOrigin,
  ExploreHomeViewModel,
  ExploreLoadedPayload,
  ExploreListRepository,
  ExploreRecommendation,
  ExploreRecommendationEntry,
  ExploreRecommendationProgress,
  ExploreContentUseCase,
  ExploreStoredSnapshot,
  RecommendationRepository,
  RecommendationUseCase,
  ExploreSource,
  ExplorePayload
} from '../main/ets/Index';

/** Content adapter that resolves every index request from memory. */
class ImmediateExploreRepository implements ExploreListRepository {
  read(_source: ExploreSource): Promise<ExploreStoredSnapshot | undefined> {
    return Promise.resolve(undefined);
  }

  isFresh(_snapshot: ExploreStoredSnapshot, _now?: number): boolean {
    return false;
  }

  load(_source: ExploreSource, _forceNetwork?: boolean): Promise<ExploreLoadedPayload> {
    const payload: ExplorePayload = {
      ok: true,
      error: '',
      entries: [{
        url: '/scp-cn-001',
        title: '内存测试条目',
        score: '+1',
        date: '2026-08-30 12:00'
      }]
    };
    return Promise.resolve(new ExploreLoadedPayload(payload, ExploreDataOrigin.NETWORK, 1));
  }

  put(
    _source: ExploreSource,
    _payload: ExplorePayload,
    _fetchedAt?: number
  ): Promise<void> {
    return Promise.resolve();
  }
}

class CachedRankingRepository extends ImmediateExploreRepository {
  rankingLoads: number = 0;

  private ranking(score: string): ExplorePayload {
    return {
      ok: true,
      error: '',
      entries: [
        { url: '/scp-cn-001', title: '已有标题', score: '+4510' },
        { url: '/scp-cn-963-j', title: 'SCP-CN-963-J', score: score }
      ]
    };
  }

  read(source: ExploreSource): Promise<ExploreStoredSnapshot | undefined> {
    if (source === ExploreSource.TOP_RATED) {
      return Promise.resolve(new ExploreStoredSnapshot(JSON.stringify(this.ranking('+4508')), 10));
    }
    return super.read(source);
  }

  isFresh(_snapshot: ExploreStoredSnapshot): boolean { return true; }

  load(source: ExploreSource, forceNetwork?: boolean): Promise<ExploreLoadedPayload> {
    if (source === ExploreSource.TOP_RATED) {
      this.rankingLoads++;
      return Promise.resolve(new ExploreLoadedPayload(this.ranking('+4509'), ExploreDataOrigin.NETWORK, 20));
    }
    return super.load(source, forceNetwork);
  }
}

class SlowTopRatedRepository extends ImmediateExploreRepository {
  private finish: (() => void) | undefined;

  async load(source: ExploreSource, forceNetwork?: boolean): Promise<ExploreLoadedPayload> {
    if (source === ExploreSource.TOP_RATED) {
      await new Promise<void>((resolve: () => void): void => {
        this.finish = resolve;
      });
    }
    return super.load(source, forceNetwork);
  }

  release(): void {
    this.finish?.();
  }
}

/** 手动发牌和结束批次，便于断言中间状态。 */
class PendingRecommendationRequest {
  readonly progress: ExploreRecommendationProgress | undefined;
  readonly items: ExploreRecommendation[] = [];
  readonly dayKey: string;
  readonly batchIndex: number;
  private finish: (items: ExploreRecommendation[]) => void = (): void => {};
  private fail: (error: Error) => void = (): void => {};
  readonly result: Promise<ExploreRecommendation[]> = new Promise<ExploreRecommendation[]>(
    (resolve: (items: ExploreRecommendation[]) => void, reject: (error: Error) => void): void => {
      this.finish = resolve;
      this.fail = reject;
    }
  );

  constructor(batchIndex: number, dayKey: string, progress?: ExploreRecommendationProgress) {
    this.batchIndex = batchIndex;
    this.dayKey = dayKey;
    this.progress = progress;
  }

  publish(item: ExploreRecommendation): void {
    this.items.push(item);
    this.progress?.onCandidate(item);
  }

  complete(): void {
    this.finish(this.items);
  }

  reject(): void {
    this.fail(new Error('连接中断'));
  }
}

class PendingRecommendationRepository implements RecommendationRepository {
  readonly requests: PendingRecommendationRequest[] = [];

  loadDaily(
    batchIndex: number,
    dayKey?: string,
    progress?: ExploreRecommendationProgress
  ): Promise<ExploreRecommendation[]> {
    const request = new PendingRecommendationRequest(batchIndex, dayKey ?? '', progress);
    this.requests.push(request);
    return request.result;
  }
}

async function drainMicrotasks(count: number = 24): Promise<void> {
  for (let index: number = 0; index < count; index++) {
    await Promise.resolve();
  }
}

function recommendation(id: string): ExploreRecommendation {
  return new ExploreRecommendation(new ExploreRecommendationEntry(id, id));
}

export default function exploreHomeViewModelTest(): void {
  describe('ExploreHomeViewModelLoadingContract', () => {
    it('keeps an empty recommendation resume in initial loading state', 0, async () => {
      const recommendationRepository = new PendingRecommendationRepository();
      const viewModel = new ExploreHomeViewModel(
        new ExploreContentUseCase(new ImmediateExploreRepository()),
        new RecommendationUseCase(recommendationRepository),
        (): string => '2026-08-30'
      );

      // Before activate() publishes its first request, IDLE is still an
      // initialization surface and is consumed by the Deck skeleton.
      expect(viewModel.recommendationStatus).assertEqual(ViewModelLoadState.IDLE);
      expect(viewModel.recommendationLoading).assertFalse();

      const firstActivation = viewModel.activate();
      await drainMicrotasks();
      expect(recommendationRepository.requests.length).assertEqual(1);
      expect(viewModel.recommendationLoading).assertTrue();
      expect(viewModel.recommendationRefreshing).assertFalse();
      expect(viewModel.recommendationStatus).assertEqual(ViewModelLoadState.LOADING);

      viewModel.deactivate();
      expect(viewModel.recommendationLoading).assertFalse();
      expect(viewModel.recommendationRefreshing).assertFalse();
      // No cards exist, so deactivation must leave a resumable initialization
      // state instead of publishing an empty READY/retry surface.
      expect(viewModel.recommendationStatus).assertEqual(ViewModelLoadState.IDLE);

      const secondActivation = viewModel.activate();
      await drainMicrotasks();
      expect(recommendationRepository.requests.length).assertEqual(2);
      expect(viewModel.recommendationLoading).assertTrue();
      expect(viewModel.recommendationRefreshing).assertFalse();
      expect(viewModel.recommendationStatus).assertEqual(ViewModelLoadState.LOADING);

      // Resolve the stale request first and the current request second. Epoch
      // and token checks must discard the first result without clearing state.
      const stale = recommendationRepository.requests[0];
      expect(stale.progress?.isCurrent()).assertFalse();
      stale.publish(recommendation('SCP-001'));
      stale.complete();
      await firstActivation;
      expect(viewModel.recommendations.length).assertEqual(0);
      expect(viewModel.recommendationLoading).assertTrue();
      const current = recommendationRepository.requests[1];
      current.publish(recommendation('SCP-002'));
      current.complete();
      await secondActivation;
      expect(viewModel.recommendationLoading).assertFalse();
      expect(viewModel.recommendationStatus).assertEqual(ViewModelLoadState.READY);
      expect(viewModel.recommendations[0].entry.itemId).assertEqual('SCP-002');
      viewModel.dispose();
      current.progress?.onTitle('SCP-002', '迟到的标题');
      expect(viewModel.recommendations[0].entry.title).assertEqual('SCP-002');
    });

    it('publishes cached ranked rows before lookup and fills in only the current request’s title', 0, async () => {
      const content = new CachedRankingRepository();
      const recommendations = new PendingRecommendationRepository();
      const titles: Array<(value: string) => void> = [];
      const vm = new ExploreHomeViewModel(new ExploreContentUseCase(content,
        (_id: string): Promise<string> => new Promise<string>((resolve: (value: string) => void): void => {
          titles.push(resolve);
        })), new RecommendationUseCase(recommendations));
      try {
        const activation = vm.activate();
        recommendations.requests[0].complete();
        await drainMicrotasks();
        const rows = vm.topRatedEntries;
        expect(titles.length).assertEqual(1);
        expect(content.rankingLoads).assertEqual(0);
        expect(vm.topRatedStatus).assertEqual(ViewModelLoadState.READY);
        expect(vm.topRatedLoading).assertFalse();
        expect(rows.length).assertEqual(2);
        expect(rows[0].id).assertEqual('scp-cn-001');
        expect(rows[0].title).assertEqual('已有标题');
        expect(rows[1].id).assertEqual('scp-cn-963-j');
        expect(rows[1].title).assertEqual('SCP-CN-963-J');
        expect(rows[1].score).assertEqual(4508);

        const refresh = vm.loadTopRated(true);
        await drainMicrotasks();
        expect(titles.length).assertEqual(2);
        expect(content.rankingLoads).assertEqual(1);
        titles[0]('上一次请求的标题');
        await activation;
        expect(vm.topRatedEntries[1].score).assertEqual(4509);
        expect(vm.topRatedEntries[1].title).assertEqual('SCP-CN-963-J');
        titles[1]('神烦代码');
        await refresh;
        expect(vm.topRatedEntries[1].id).assertEqual('scp-cn-963-j');
        expect(vm.topRatedEntries[1].title).assertEqual('神烦代码');
        expect(vm.topRatedEntries[1].score).assertEqual(4509);
        expect(rows[1].title).assertEqual('SCP-CN-963-J');
      } finally {
        vm.dispose();
      }
    });

    it('publishes the first card while the home index is still pending', 0, async () => {
      const content = new SlowTopRatedRepository();
      const repository = new PendingRecommendationRepository();
      const vm = new ExploreHomeViewModel(new ExploreContentUseCase(content),
        new RecommendationUseCase(repository), (): string => '2026-08-30');
      try {
        const activation = vm.activate();
        await drainMicrotasks();
        expect(vm.topRatedLoading).assertTrue();
        expect(repository.requests.length).assertEqual(1);
        repository.requests[0].publish(recommendation('SCP-001'));
        expect(vm.recommendations.length).assertEqual(1);
        expect(vm.recommendationLoading).assertFalse();
        expect(vm.topRatedLoading).assertTrue();
        repository.requests[0].complete();
        content.release();
        await activation;
      } finally {
        vm.dispose();
      }
    });

    it('retains the old deck until the first card and preserves index on append or title update', 0, async () => {
      const repository = new PendingRecommendationRepository();
      const vm = new ExploreHomeViewModel(new ExploreContentUseCase(new ImmediateExploreRepository()),
        new RecommendationUseCase(repository), (): string => '2026-08-30');
      try {
        const activation = vm.activate();
        repository.requests[0].publish(recommendation('SCP-001'));
        repository.requests[0].publish(recommendation('SCP-002'));
        repository.requests[0].complete();
        await activation;
        vm.nextRecommendation();
        const priorVersion = vm.recommendationDeckVersion;
        const refresh = vm.refreshRecommendations();
        await vm.refreshRecommendations();
        expect(repository.requests.length).assertEqual(2);
        expect(vm.recommendationIndex).assertEqual(1);
        expect(vm.recommendations[1].entry.itemId).assertEqual('SCP-002');
        const request = repository.requests[1];
        expect(request.batchIndex).assertEqual(1);
        request.publish(recommendation('SCP-003'));
        expect(vm.recommendations.length).assertEqual(1);
        expect(vm.recommendationIndex).assertEqual(0);
        expect(vm.recommendationDeckVersion).assertEqual(priorVersion + 1);
        expect(vm.recommendationRefreshing).assertTrue();
        vm.nextRecommendation();
        expect(vm.recommendationIndex).assertEqual(0);
        request.publish(recommendation('SCP-004'));
        vm.nextRecommendation();
        request.publish(recommendation('SCP-005'));
        request.progress?.onTitle('SCP-004', '补齐的标题');
        expect(vm.recommendationIndex).assertEqual(1);
        expect(vm.recommendations[1].entry.title).assertEqual('补齐的标题');
        expect(vm.recommendationDeckVersion).assertEqual(priorVersion + 1);
        request.reject();
        await refresh;
        expect(vm.recommendations.length).assertEqual(3);
        expect(vm.recommendationIndex).assertEqual(1);
        expect(vm.recommendationStatus).assertEqual(ViewModelLoadState.PARTIAL);
        expect(vm.recommendationRefreshing).assertFalse();

        const empty = vm.refreshRecommendations();
        repository.requests[2].complete();
        await empty;
        expect(vm.recommendations.length).assertEqual(3);
        expect(vm.recommendationIndex).assertEqual(1);
        expect(vm.recommendationDeckVersion).assertEqual(priorVersion + 1);
      } finally {
        vm.dispose();
      }
    });

    it('ignores stale candidates, titles and completion on day rollover', 0, async () => {
      const repository = new PendingRecommendationRepository();
      let today: string = '2026-08-30';
      const vm = new ExploreHomeViewModel(new ExploreContentUseCase(new ImmediateExploreRepository()),
        new RecommendationUseCase(repository), (): string => today);
      try {
        const activation = vm.activate();
        const old = repository.requests[0];
        old.publish(recommendation('SCP-001'));
        today = '2026-08-31';
        const rollover = vm.refreshDay();
        await vm.refreshDay();
        expect(repository.requests.length).assertEqual(2);
        expect(repository.requests[1].dayKey).assertEqual(today);
        expect(old.progress?.isCurrent()).assertFalse();
        old.publish(recommendation('SCP-002'));
        old.progress?.onTitle('SCP-001', '旧标题');
        old.complete();
        await activation;
        expect(vm.recommendations.length).assertEqual(1);
        expect(vm.recommendations[0].entry.title).assertEqual('SCP-001');
        expect(vm.recommendationRefreshing).assertTrue();
        repository.requests[1].publish(recommendation('SCP-003'));
        repository.requests[1].complete();
        await rollover;
        expect(vm.recommendations[0].entry.itemId).assertEqual('SCP-003');
        expect(vm.recommendationRefreshing).assertFalse();
      } finally {
        vm.dispose();
      }
    });
  });
}

