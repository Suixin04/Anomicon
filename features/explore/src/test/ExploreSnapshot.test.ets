import { describe, expect, it } from '@ohos/hypium';
import { ViewModelLoadState } from 'anomiconbasic';
import {
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
  });
}
