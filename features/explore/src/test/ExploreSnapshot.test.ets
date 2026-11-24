import { describe, expect, it } from '@ohos/hypium';
import { ViewModelLoadState } from 'anomiconbasic';
import {
  ExploreCombinedSnapshot,
  ExploreCollectionMode,
  ExploreCollectionVM,
  ExploreContentUseCase,
  ExploreDataOrigin,
  ExploreListRepository,
  ExploreLoadedPayload,
  ExplorePayload,
  ExploreSource,
  ExploreStoredSnapshot
} from '../main/ets/Index';

/** One source succeeds and one fails, producing a deterministic partial list. */
class PartialExploreRepository implements ExploreListRepository {
  read(_source: ExploreSource): Promise<ExploreStoredSnapshot | undefined> {
    return Promise.resolve(undefined);
  }

  isFresh(_snapshot: ExploreStoredSnapshot, _now?: number): boolean {
    return false;
  }

  load(source: ExploreSource, _forceNetwork?: boolean): Promise<ExploreLoadedPayload> {
    if (source === ExploreSource.RECENT_TRANSLATED) {
      const payload: ExplorePayload = {
        ok: true,
        error: '',
        entries: [{
          url: '/scp-cn-001',
          title: '已载入条目',
          score: '+10',
          date: '2026-08-27 12:30'
        }]
      };
      return Promise.resolve(new ExploreLoadedPayload(
        payload,
        ExploreDataOrigin.NETWORK,
        123
      ));
    }
    return Promise.reject(new Error('second source unavailable'));
  }

  put(_source: ExploreSource, _payload: ExplorePayload, _fetchedAt?: number): Promise<void> {
    return Promise.resolve();
  }
}

class DelayedExploreSecondSource extends PartialExploreRepository {
  private finishSecond: (() => void) | undefined = undefined;
  private readonly secondGate: Promise<void> = new Promise<void>((resolve: () => void): void => {
    this.finishSecond = resolve;
  });

  async load(source: ExploreSource, forceNetwork?: boolean): Promise<ExploreLoadedPayload> {
    if (source === ExploreSource.RECENT_ORIGINAL) {
      await this.secondGate;
    }
    return super.load(source, forceNetwork);
  }

  releaseSecond(): void {
    this.finishSecond?.();
  }
}

class PlaceholderExploreRepository implements ExploreListRepository {
  read(_source: ExploreSource): Promise<ExploreStoredSnapshot | undefined> {
    return Promise.resolve(undefined);
  }

  isFresh(_snapshot: ExploreStoredSnapshot, _now?: number): boolean {
    return false;
  }

  load(_source: ExploreSource, _forceNetwork?: boolean): Promise<ExploreLoadedPayload> {
    return Promise.resolve(new ExploreLoadedPayload({
      ok: true,
      error: '',
      entries: [{ url: '/scp-cn-963-j', title: 'SCP-CN-963-J', score: '+4508' }]
    }, ExploreDataOrigin.NETWORK, 456));
  }

  put(_source: ExploreSource, _payload: ExplorePayload, _fetchedAt?: number): Promise<void> {
    return Promise.resolve();
  }
}

class MixedJokesRepository implements ExploreListRepository {
  read(_source: ExploreSource): Promise<ExploreStoredSnapshot | undefined> {
    return Promise.resolve(undefined);
  }

  isFresh(_snapshot: ExploreStoredSnapshot, _now?: number): boolean {
    return false;
  }

  load(source: ExploreSource, _forceNetwork?: boolean): Promise<ExploreLoadedPayload> {
    if (source === ExploreSource.JOKE_SCPS) {
      return Promise.resolve(new ExploreLoadedPayload({
        ok: true,
        error: '',
        entries: [{ url: '/scp-173-j', title: 'SCP-173-J 派对雕塑', score: '' }]
      }, ExploreDataOrigin.NETWORK, 100));
    }
    if (source === ExploreSource.JOKE_SCPS_CN) {
      return Promise.resolve(new ExploreLoadedPayload({
        ok: true,
        error: '',
        entries: [{ url: '/scp-cn-963-j', title: 'SCP-CN-963-J', score: '' }]
      }, ExploreDataOrigin.NETWORK, 200));
    }
    return Promise.resolve(new ExploreLoadedPayload({
      ok: true,
      error: '',
      entries: [{ url: '/why-not-joke', title: '搞笑故事示例', score: '' }]
    }, ExploreDataOrigin.NETWORK, 300));
  }

  put(_source: ExploreSource, _payload: ExplorePayload, _fetchedAt?: number): Promise<void> {
    return Promise.resolve();
  }
}

export default function exploreCollectionSnapshotTest(): void {
  describe('ExploreCollectionSnapshotContract', () => {
    it('publishes revisioned partial and route-error snapshots', 0, async () => {
      const viewModel = new ExploreCollectionVM(
        new ExploreContentUseCase(new PartialExploreRepository()),
        ExploreCollectionMode.RECENT,
        (): string => '2026-08-27'
      );
      const initialRevision = viewModel.snapshot.revision;

      await viewModel.activate();
      const partialSnapshot = viewModel.snapshot;
      expect(partialSnapshot.revision > initialRevision).assertTrue();
      expect(partialSnapshot.state).assertEqual(ViewModelLoadState.PARTIAL);
      expect(partialSnapshot.partial).assertTrue();
      expect(partialSnapshot.error?.message).assertEqual('正在显示已载入的部分内容');
      expect(partialSnapshot.fetchedAt).assertEqual(123);
      expect(partialSnapshot.data?.mode).assertEqual(ExploreCollectionMode.RECENT);
      expect(partialSnapshot.data?.items.length).assertEqual(1);
      expect(partialSnapshot.data?.items === viewModel.items).assertFalse();

      const partialRevision = partialSnapshot.revision;
      await viewModel.setRouteMode(undefined);
      const routeErrorSnapshot = viewModel.snapshot;
      expect(routeErrorSnapshot.revision > partialRevision).assertTrue();
      expect(routeErrorSnapshot.state).assertEqual(ViewModelLoadState.ERROR);
      expect(routeErrorSnapshot.partial).assertFalse();
      expect(routeErrorSnapshot.data?.items.length).assertEqual(0);
      expect(routeErrorSnapshot.data?.routeError?.code).assertEqual('invalid_route');
      expect(routeErrorSnapshot.error?.recoverable).assertFalse();
      expect(routeErrorSnapshot.error?.message).assertEqual('探索列表参数无效');
      viewModel.dispose();
    });

    it('publishes the first source while the other is still waiting', 0, async () => {
      const repository = new DelayedExploreSecondSource();
      const useCase = new ExploreContentUseCase(repository);
      let releaseProgress: ((snapshot: ExploreCombinedSnapshot) => void) | undefined = undefined;
      const progressArrived = new Promise<ExploreCombinedSnapshot>(
        (resolve: (snapshot: ExploreCombinedSnapshot) => void): void => {
          releaseProgress = resolve;
        });
      const result = useCase.loadRecent(false, (snapshot: ExploreCombinedSnapshot): void => {
        releaseProgress?.(snapshot);
      });
      const first = await progressArrived;
      repository.releaseSecond();
      const complete = await result;
      expect(first.items.length).assertEqual(1);
      expect(first.error).assertEqual('');
      expect(complete.items.length).assertEqual(1);
      expect(complete.error).assertEqual('正在显示已载入的部分内容');
    });

    it('enriches id-only original SCP index rows through the shared title port', 0, async () => {
      const useCase = new ExploreContentUseCase(
        new PlaceholderExploreRepository(),
        (itemId: string): Promise<string> => Promise.resolve(
          itemId.toLowerCase() === 'scp-cn-963-j' ? '神烦代码' : ''
        )
      );
      const snapshot = await useCase.loadTopRated();
      expect(snapshot.entries.length).assertEqual(1);
      expect(snapshot.entries[0].title).assertEqual('神烦代码');
    });

    it('combines Main jokes, CN original jokes, and joke tales with title enrichment', 0, async () => {
      const useCase = new ExploreContentUseCase(
        new MixedJokesRepository(),
        (itemId: string): Promise<string> => Promise.resolve(
          itemId.toLowerCase() === 'scp-cn-963-j' ? '神烦代码' : ''
        )
      );
      const snapshot = await useCase.loadJokes('2026-11-24');
      expect(snapshot.error).assertEqual('');
      expect(snapshot.items.length).assertEqual(3);
      const labels = snapshot.items.map((item) => item.sourceLabel);
      expect(labels.indexOf('搞笑 SCP') >= 0).assertTrue();
      expect(labels.indexOf('原创搞笑 SCP') >= 0).assertTrue();
      expect(labels.indexOf('搞笑故事') >= 0).assertTrue();
      const cnItem = snapshot.items.find((item) => item.entry.id === 'scp-cn-963-j');
      expect(cnItem?.entry.title).assertEqual('神烦代码');
    });
  });
}
