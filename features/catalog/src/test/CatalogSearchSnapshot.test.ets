import { describe, expect, it } from '@ohos/hypium';
import { ViewModelLoadState } from 'anomiconbasic';
import {
  ALL_CATALOG_SERIES,
  ALL_SERIES_ID,
  CatalogContentUseCase,
  CatalogEntry,
  CatalogRepository,
  CatalogSearchTargetKind,
  CatalogSearchUseCase,
  CatalogSearchViewModel,
  CatalogSnapshot,
  CatalogSnapshotSource,
  CatalogTaleEntry,
  DEFAULT_SERIES_ID,
  SCP_CN_SERIES,
  SCP_SERIES,
  ScpSeriesDescriptor,
  SearchHistoryRepository,
  SearchHistoryUseCase,
  TaleContentUseCase,
  TaleRepository,
  TaleSnapshot
} from '../main/ets/Index';

/** In-memory cold catalog used to verify the no-cache application path. */
class ColdCatalogRepository implements CatalogRepository {
  loadCalls: number = 0;

  getCached(_seriesId: string): Promise<CatalogSnapshot | undefined> {
    return Promise.resolve(undefined);
  }

  load(series: ScpSeriesDescriptor): Promise<CatalogSnapshot> {
    this.loadCalls += 1;
    return Promise.resolve(new CatalogSnapshot(
      series.id,
      [new CatalogEntry('SCP-173', '雕像')],
      CatalogSnapshotSource.NETWORK,
      321
    ));
  }

  refresh(series: ScpSeriesDescriptor): Promise<CatalogSnapshot> {
    return this.load(series);
  }

  subscribe(_seriesId: string, _listener: (snapshot: CatalogSnapshot) => void): () => void {
    return (): void => {
    };
  }
}

/** Cold catalog whose first network request fails. */
class FailingColdCatalogRepository implements CatalogRepository {
  getCached(_seriesId: string): Promise<CatalogSnapshot | undefined> {
    return Promise.resolve(undefined);
  }

  load(_series: ScpSeriesDescriptor): Promise<CatalogSnapshot> {
    return Promise.reject(new Error('catalog offline'));
  }

  refresh(series: ScpSeriesDescriptor): Promise<CatalogSnapshot> {
    return this.load(series);
  }

  subscribe(_seriesId: string, _listener: (snapshot: CatalogSnapshot) => void): () => void {
    return (): void => {
    };
  }
}

/** Minimal history adapter that still verifies immutable publication. */
class MemorySearchHistoryRepository implements SearchHistoryRepository {
  private values: string[] = ['SCP-049'];

  list(): string[] {
    return this.values.slice();
  }

  add(query: string): void {
    if (query.length > 0) {
      this.values = [query];
    }
  }

  clear(): void {
    this.values = [];
  }
}

async function drainMicrotasks(rounds: number = 20): Promise<void> {
  for (let index = 0; index < rounds; index++) {
    await Promise.resolve();
  }
}

class ManualCatalogSearchTimeout {
  private callback: (() => void) | undefined = undefined;

  schedule(callback: () => void): () => void {
    this.callback = callback;
    return (): void => {
      this.callback = undefined;
    };
  }

  fire(): void {
    const callback = this.callback;
    if (callback === undefined) {
      throw new Error('没有待触发的目录超时');
    }
    this.callback = undefined;
    callback();
  }
}

class DeferredCatalogSearchLoad {
  readonly promise: Promise<CatalogSnapshot>;
  private resolveLoad: ((snapshot: CatalogSnapshot) => void) | undefined = undefined;
  private rejectLoad: ((error: Error) => void) | undefined = undefined;

  constructor() {
    this.promise = new Promise<CatalogSnapshot>((resolve: (snapshot: CatalogSnapshot) => void,
      reject: (error: Error) => void): void => {
      this.resolveLoad = resolve;
      this.rejectLoad = reject;
    });
  }

  resolve(snapshot: CatalogSnapshot): void {
    this.resolveLoad?.(snapshot);
  }

  reject(): void {
    this.rejectLoad?.(new Error('catalog offline'));
  }
}

class DeferredCatalogSearchRepository implements CatalogRepository {
  readonly loads: DeferredCatalogSearchLoad[] = [];
  readonly refreshes: DeferredCatalogSearchLoad[] = [];
  readonly listeners: ((snapshot: CatalogSnapshot) => void)[] = [];

  getCached(_seriesId: string): Promise<CatalogSnapshot | undefined> {
    return Promise.resolve(undefined);
  }

  load(_series: ScpSeriesDescriptor): Promise<CatalogSnapshot> {
    const request = new DeferredCatalogSearchLoad();
    this.loads.push(request);
    return request.promise;
  }

  refresh(_series: ScpSeriesDescriptor): Promise<CatalogSnapshot> {
    const request = new DeferredCatalogSearchLoad();
    this.refreshes.push(request);
    return request.promise;
  }

  subscribe(_seriesId: string, listener: (snapshot: CatalogSnapshot) => void): () => void {
    this.listeners.push(listener);
    return (): void => {
      // 保留旧回调，模拟取消订阅前已排队的通知。
    };
  }
}

class MultiSeriesCatalogRepository implements CatalogRepository {
  private readonly cachedBySeries: Map<string, CatalogSnapshot> = new Map();
  private readonly networkBySeries: Map<string, CatalogSnapshot> = new Map();
  private readonly failingSeries: Set<string> = new Set();

  setCached(snapshot: CatalogSnapshot): void {
    this.cachedBySeries.set(snapshot.seriesId, snapshot);
  }

  setNetwork(snapshot: CatalogSnapshot): void {
    this.networkBySeries.set(snapshot.seriesId, snapshot);
  }

  setFailing(seriesId: string): void {
    this.failingSeries.add(seriesId);
  }

  getCached(seriesId: string): Promise<CatalogSnapshot | undefined> {
    return Promise.resolve(this.cachedBySeries.get(seriesId));
  }

  load(series: ScpSeriesDescriptor): Promise<CatalogSnapshot> {
    if (this.failingSeries.has(series.id)) {
      return Promise.reject(new Error(`offline:${series.id}`));
    }
    const configured = this.networkBySeries.get(series.id);
    if (configured !== undefined) {
      return Promise.resolve(configured);
    }
    return Promise.resolve(new CatalogSnapshot(series.id, [], CatalogSnapshotSource.NETWORK, 100));
  }

  refresh(series: ScpSeriesDescriptor): Promise<CatalogSnapshot> {
    return this.load(series);
  }

  subscribe(_seriesId: string, _listener: (snapshot: CatalogSnapshot) => void): () => void {
    return (): void => {
    };
  }
}

function searchCatalogSnapshot(
  fetchedAt: number,
  source: CatalogSnapshotSource = CatalogSnapshotSource.NETWORK
): CatalogSnapshot {
  return new CatalogSnapshot(DEFAULT_SERIES_ID, [new CatalogEntry('SCP-173', '雕像')], source, fetchedAt);
}

class FakeUnifiedTaleRepository implements TaleRepository {
  cachedSnapshot: TaleSnapshot | undefined = undefined;
  networkSnapshot: TaleSnapshot = new TaleSnapshot([], CatalogSnapshotSource.NETWORK, Date.now());
  private listeners: Array<(snapshot: TaleSnapshot) => void> = [];

  getCached(): Promise<TaleSnapshot | undefined> {
    return Promise.resolve(this.cachedSnapshot);
  }

  load(): Promise<TaleSnapshot> {
    return Promise.resolve(this.networkSnapshot);
  }

  refresh(): Promise<TaleSnapshot> {
    return Promise.resolve(this.networkSnapshot);
  }

  subscribe(listener: (snapshot: TaleSnapshot) => void): () => void {
    this.listeners.push(listener);
    return (): void => {};
  }
}

function createSearchViewModel(
  repository: CatalogRepository,
  timeout: ManualCatalogSearchTimeout = new ManualCatalogSearchTimeout(),
  initialSeriesId: string = DEFAULT_SERIES_ID,
  taleRepository?: TaleRepository
): CatalogSearchViewModel {
  return new CatalogSearchViewModel(
    new CatalogSearchUseCase(
      new CatalogContentUseCase(repository),
      new SearchHistoryUseCase(new MemorySearchHistoryRepository()),
      taleRepository !== undefined ? new TaleContentUseCase(taleRepository) : undefined
    ),
    1,
    (callback: () => void): () => void => timeout.schedule(callback),
    initialSeriesId
  );
}

export default function catalogSearchSnapshotTest(): void {
  describe('CatalogSearchSnapshotContract', () => {
    it('publishes a revisioned immutable snapshot after a cold load', 0, async () => {
      const repository = new ColdCatalogRepository();
      const viewModel = createSearchViewModel(repository);
      const initialRevision = viewModel.snapshot.revision;

      viewModel.activate();
      await drainMicrotasks();

      const loaded = viewModel.snapshot;
      expect(repository.loadCalls).assertEqual(1);
      expect(loaded.revision > initialRevision).assertTrue();
      expect(loaded.state).assertEqual(ViewModelLoadState.READY);
      expect(loaded.error === undefined).assertTrue();
      expect(loaded.fetchedAt).assertEqual(321);
      expect(loaded.data?.query).assertEqual('');
      expect(loaded.data?.seriesId).assertEqual(DEFAULT_SERIES_ID);
      expect(loaded.data?.entries.length).assertEqual(1);
      expect(loaded.data?.random.length).assertEqual(1);
      expect(loaded.data?.history.length).assertEqual(1);
      expect(loaded.data?.catalogPending).assertFalse();
      expect(loaded.data?.entries === viewModel.visibleEntries).assertFalse();
      expect(loaded.data?.random === viewModel.randomItems).assertFalse();
      expect(loaded.data?.history === viewModel.history).assertFalse();

      const loadedRevision = loaded.revision;
      viewModel.setQuery('173');
      expect(viewModel.snapshot.revision > loadedRevision).assertTrue();
      expect(viewModel.snapshot.data?.query).assertEqual('173');
      expect(viewModel.snapshot.data?.entries.length).assertEqual(1);
      expect(viewModel.snapshot.data?.entries[0].itemId).assertEqual('SCP-173');
      viewModel.dispose();
    });

    it('ends the pending state when a cold load fails', 0, async () => {
      const viewModel = createSearchViewModel(new FailingColdCatalogRepository());

      viewModel.activate();
      await drainMicrotasks();

      const failed = viewModel.snapshot;
      expect(failed.revision > 0).assertTrue();
      expect(failed.state).assertEqual(ViewModelLoadState.ERROR);
      expect(failed.error?.message).assertEqual('catalog offline');
      expect(failed.data?.catalogPending).assertFalse();
      expect(failed.data?.entries.length).assertEqual(0);
      viewModel.dispose();
    });

    it('recovers when the cold load returns after timeout without a cache notification', 0, async () => {
      const repository = new DeferredCatalogSearchRepository();
      const timeout = new ManualCatalogSearchTimeout();
      const viewModel = createSearchViewModel(repository, timeout);
      viewModel.activate();
      await drainMicrotasks();
      expect(viewModel.snapshot.data?.catalogPending).assertTrue();

      timeout.fire();
      expect(viewModel.snapshot.state).assertEqual(ViewModelLoadState.ERROR);
      expect(viewModel.snapshot.error?.message).assertEqual('目录加载超时，请重试');
      expect(viewModel.snapshot.data?.catalogPending).assertFalse();
      viewModel.setQuery('173');
      repository.loads[0].resolve(searchCatalogSnapshot(321));
      await drainMicrotasks();

      const recovered = viewModel.snapshot;
      expect(recovered.state).assertEqual(ViewModelLoadState.READY);
      expect(recovered.error === undefined).assertTrue();
      expect(recovered.data?.entries[0].itemId).assertEqual('SCP-173');
      expect(recovered.data?.catalogPending).assertFalse();
      repository.listeners[0](searchCatalogSnapshot(321, CatalogSnapshotSource.CACHE));
      expect(viewModel.snapshot.revision).assertEqual(recovered.revision);
      viewModel.dispose();
    });

    it('recovers from a retry timeout through observe and applies its returned duplicate only once', 0, async () => {
      const repository = new DeferredCatalogSearchRepository();
      const timeout = new ManualCatalogSearchTimeout();
      const viewModel = createSearchViewModel(repository, timeout);
      viewModel.activate();
      await drainMicrotasks();
      viewModel.retry();
      timeout.fire();
      expect(viewModel.snapshot.state).assertEqual(ViewModelLoadState.ERROR);

      repository.listeners[1](searchCatalogSnapshot(456, CatalogSnapshotSource.CACHE));
      const recovered = viewModel.snapshot;
      expect(recovered.state).assertEqual(ViewModelLoadState.READY);
      expect(recovered.error === undefined).assertTrue();
      expect(recovered.fetchedAt).assertEqual(456);
      repository.refreshes[0].resolve(searchCatalogSnapshot(456));
      await drainMicrotasks();
      expect(viewModel.snapshot.revision).assertEqual(recovered.revision);

      repository.listeners[1](searchCatalogSnapshot(789, CatalogSnapshotSource.CACHE));
      expect(viewModel.snapshot.fetchedAt).assertEqual(789);
      viewModel.dispose();
    });

    it('keeps the timeout message when the current load eventually fails', 0, async () => {
      const repository = new DeferredCatalogSearchRepository();
      const timeout = new ManualCatalogSearchTimeout();
      const viewModel = createSearchViewModel(repository, timeout);
      viewModel.activate();
      await drainMicrotasks();
      timeout.fire();
      const timedOut = viewModel.snapshot;
      repository.loads[0].reject();
      await drainMicrotasks();
      expect(viewModel.snapshot.revision).assertEqual(timedOut.revision);
      expect(viewModel.snapshot.error?.message).assertEqual('目录加载超时，请重试');
      viewModel.dispose();
    });

    it('keeps old returns and queued notifications out after retry, series switch and page exit', 0, async () => {
      const repository = new DeferredCatalogSearchRepository();
      const timeout = new ManualCatalogSearchTimeout();
      const viewModel = createSearchViewModel(repository, timeout);
      viewModel.activate();
      await drainMicrotasks();
      timeout.fire();
      viewModel.retry();
      const retry = viewModel.snapshot;
      repository.listeners[0](searchCatalogSnapshot(100));
      repository.loads[0].resolve(searchCatalogSnapshot(100));
      await drainMicrotasks();
      expect(viewModel.snapshot.revision).assertEqual(retry.revision);

      viewModel.selectSeries('scp-series-2');
      viewModel.selectSeries(DEFAULT_SERIES_ID);
      await drainMicrotasks();
      const switched = viewModel.snapshot;
      repository.listeners[1](searchCatalogSnapshot(200));
      repository.refreshes[0].resolve(searchCatalogSnapshot(200));
      await drainMicrotasks();
      expect(viewModel.snapshot.revision).assertEqual(switched.revision);

      viewModel.deactivate();
      viewModel.activate();
      await drainMicrotasks();
      const reopened = viewModel.snapshot;
      repository.listeners[3](searchCatalogSnapshot(300));
      repository.loads[1].resolve(searchCatalogSnapshot(300));
      await drainMicrotasks();
      expect(viewModel.snapshot.revision).assertEqual(reopened.revision);
      repository.loads[2].resolve(searchCatalogSnapshot(400));
      await drainMicrotasks();
      expect(viewModel.snapshot.state).assertEqual(ViewModelLoadState.READY);
      expect(viewModel.snapshot.fetchedAt).assertEqual(400);
      viewModel.dispose();
    });

    it('merges cached and progressive series snapshots and deduplicates items in ALL_SERIES_ID', 0, async () => {
      const repository = new MultiSeriesCatalogRepository();
      repository.setCached(new CatalogSnapshot(
        SCP_SERIES[0].id,
        [new CatalogEntry('SCP-173', '雕像'), new CatalogEntry('SCP-999', '痒痒怪')],
        CatalogSnapshotSource.CACHE,
        Date.now()
      ));
      repository.setNetwork(new CatalogSnapshot(
        SCP_SERIES[1].id,
        [new CatalogEntry('SCP-173', '重复雕像'), new CatalogEntry('SCP-1048', '泰迪熊建造者')],
        CatalogSnapshotSource.NETWORK,
        Date.now()
      ));
      repository.setNetwork(new CatalogSnapshot(
        SCP_SERIES[9].id,
        [new CatalogEntry('SCP-9000', '终点测试')],
        CatalogSnapshotSource.NETWORK,
        Date.now()
      ));

      const viewModel = createSearchViewModel(repository, new ManualCatalogSearchTimeout(), ALL_SERIES_ID);
      viewModel.activate();
      await drainMicrotasks(60);

      const loaded = viewModel.snapshot;
      expect(loaded.state).assertEqual(ViewModelLoadState.READY);
      expect(loaded.data?.seriesId).assertEqual(ALL_SERIES_ID);
      expect(loaded.data?.allSeriesLoading).assertFalse();
      expect(loaded.data?.loadedSeriesCount).assertEqual(ALL_CATALOG_SERIES.length);
      expect(loaded.data?.totalSeriesCount).assertEqual(ALL_CATALOG_SERIES.length);
      expect(loaded.data?.entries.length).assertEqual(4);
      expect(loaded.data?.entries[0].itemId).assertEqual('SCP-173');
      expect(loaded.data?.entries[2].itemId).assertEqual('SCP-1048');
      expect(loaded.data?.entries[3].itemId).assertEqual('SCP-9000');

      viewModel.setQuery('9000');
      expect(viewModel.snapshot.data?.entries.length).assertEqual(1);
      expect(viewModel.snapshot.data?.entries[0].itemId).assertEqual('SCP-9000');
      viewModel.dispose();
    });

    it('degrades partially failed ALL_SERIES_ID loads and preserves query across deactivate and activate', 0, async () => {
      const repository = new MultiSeriesCatalogRepository();
      repository.setCached(new CatalogSnapshot(
        SCP_SERIES[0].id,
        [new CatalogEntry('SCP-049', '疫医')],
        CatalogSnapshotSource.CACHE,
        Date.now()
      ));
      repository.setNetwork(new CatalogSnapshot(
        SCP_SERIES[2].id,
        [new CatalogEntry('SCP-2049', '跨系列示例')],
        CatalogSnapshotSource.NETWORK,
        Date.now()
      ));
      repository.setFailing(SCP_SERIES[1].id);

      const viewModel = createSearchViewModel(repository, new ManualCatalogSearchTimeout(), ALL_SERIES_ID);
      viewModel.activate();
      await drainMicrotasks(60);

      expect(viewModel.snapshot.state).assertEqual(ViewModelLoadState.PARTIAL);
      expect(viewModel.snapshot.data?.loadedSeriesCount).assertEqual(ALL_CATALOG_SERIES.length - 1);
      expect(viewModel.snapshot.error?.message.includes('部分系列目录加载失败')).assertTrue();
      const initialRandomId = viewModel.snapshot.data?.random[0]?.itemId;

      viewModel.setQuery('049');
      expect(viewModel.snapshot.data?.entries.length).assertEqual(2);

      viewModel.deactivate();
      viewModel.activate();
      await drainMicrotasks(60);

      expect(viewModel.snapshot.data?.query).assertEqual('049');
      expect(viewModel.snapshot.data?.seriesId).assertEqual(ALL_SERIES_ID);
      expect(viewModel.snapshot.data?.entries.length).assertEqual(2);
      expect(viewModel.snapshot.data?.random[0]?.itemId).assertEqual(initialRandomId);
      viewModel.dispose();
    });

    it('unifies CN archives, tales, and Wiki direct-open targets in ALL_SERIES_ID', 0, async () => {
      const repository = new MultiSeriesCatalogRepository();
      repository.setCached(new CatalogSnapshot(
        SCP_SERIES[0].id,
        [new CatalogEntry('SCP-055', '[未知]')],
        CatalogSnapshotSource.CACHE,
        Date.now()
      ));
      repository.setNetwork(new CatalogSnapshot(
        SCP_CN_SERIES[2].id,
        [
          new CatalogEntry('SCP-CN-2000', '混沌理论'),
          new CatalogEntry('SCP-CN-2111', '逆模因联动')
        ],
        CatalogSnapshotSource.NETWORK,
        Date.now()
      ));

      const taleRepository = new FakeUnifiedTaleRepository();
      taleRepository.cachedSnapshot = new TaleSnapshot(
        [
          new CatalogTaleEntry('antimemetics-division-hub', '逆模因部中心页'),
          new CatalogTaleEntry('we-need-to-talk-about-fifty-five', '谈谈055')
        ],
        CatalogSnapshotSource.CACHE,
        Date.now()
      );
      taleRepository.networkSnapshot = taleRepository.cachedSnapshot;

      const viewModel = createSearchViewModel(
        repository,
        new ManualCatalogSearchTimeout(),
        ALL_SERIES_ID,
        taleRepository
      );
      viewModel.activate();
      await drainMicrotasks(80);

      viewModel.setQuery('CN-2000');
      expect(viewModel.snapshot.data?.directTarget?.kind).assertEqual(CatalogSearchTargetKind.SCP);
      expect(viewModel.snapshot.data?.directTarget?.itemId).assertEqual('SCP-CN-2000');
      expect(viewModel.snapshot.data?.directTarget?.title).assertEqual('混沌理论');
      expect(viewModel.snapshot.data?.entries[0].itemId).assertEqual('SCP-CN-2000');
      expect(viewModel.snapshot.data?.tales.length).assertEqual(0);

      viewModel.setQuery('逆模因');
      expect(viewModel.snapshot.data?.directTarget === undefined).assertTrue();
      expect(viewModel.snapshot.data?.entries.length).assertEqual(1);
      expect(viewModel.snapshot.data?.entries[0].itemId).assertEqual('SCP-CN-2111');
      expect(viewModel.snapshot.data?.tales.length).assertEqual(1);
      expect(viewModel.snapshot.data?.tales[0].id).assertEqual('antimemetics-division-hub');

      viewModel.setQuery('https://scp-wiki-cn.wikidot.com/task-forces#alpha-1');
      expect(viewModel.snapshot.data?.directTarget?.kind).assertEqual(CatalogSearchTargetKind.TALE);
      expect(viewModel.snapshot.data?.directTarget?.itemId).assertEqual('task-forces');
      expect(viewModel.snapshot.data?.directTarget?.anchor).assertEqual('alpha-1');
      viewModel.dispose();
    });

    it('balances Main and CN entries in random discovery and refreshes when CN arrives', 0, async () => {
      const searchUseCase = new CatalogSearchUseCase(
        new CatalogContentUseCase(new ColdCatalogRepository()),
        new SearchHistoryUseCase(new MemorySearchHistoryRepository())
      );
      const mixedPool: CatalogEntry[] = [];
      for (let index = 1; index <= 20; index++) {
        mixedPool.push(new CatalogEntry(`SCP-${index}`, `主站档案 ${index}`));
      }
      mixedPool.push(new CatalogEntry('SCP-CN-100', '中文原创档案 A'));
      mixedPool.push(new CatalogEntry('SCP-CN-200', '中文原创档案 B'));
      const sampled = searchUseCase.pickRandom(mixedPool, 6);
      expect(sampled.length).assertEqual(6);
      const hasMain = sampled.some((item: CatalogEntry): boolean => !item.itemId.startsWith('SCP-CN-'));
      const hasCn = sampled.some((item: CatalogEntry): boolean => item.itemId.startsWith('SCP-CN-'));
      expect(hasMain).assertTrue();
      expect(hasCn).assertTrue();

      class DeferredCnCatalogRepository extends MultiSeriesCatalogRepository {
        private releaseCnFn: ((snapshot: CatalogSnapshot) => void) | undefined = undefined;

        load(series: ScpSeriesDescriptor): Promise<CatalogSnapshot> {
          if (series.id === SCP_CN_SERIES[0].id) {
            return new Promise<CatalogSnapshot>((resolve: (snapshot: CatalogSnapshot) => void): void => {
              this.releaseCnFn = resolve;
            });
          }
          return super.load(series);
        }

        resolveCn(snapshot: CatalogSnapshot): void {
          this.releaseCnFn?.(snapshot);
        }
      }
      const deferredRepo = new DeferredCnCatalogRepository();
      deferredRepo.setCached(new CatalogSnapshot(
        SCP_SERIES[0].id,
        [new CatalogEntry('SCP-173', '雕像'), new CatalogEntry('SCP-049', '疫医')],
        CatalogSnapshotSource.CACHE,
        100
      ));
      const timeout = new ManualCatalogSearchTimeout();
      const viewModel = new CatalogSearchViewModel(
        new CatalogSearchUseCase(
          new CatalogContentUseCase(deferredRepo),
          new SearchHistoryUseCase(new MemorySearchHistoryRepository())
        ),
        4,
        (callback: () => void): () => void => timeout.schedule(callback),
        ALL_SERIES_ID
      );
      viewModel.activate();
      await drainMicrotasks(40);
      const beforeCn = viewModel.snapshot.data?.random ?? [];
      expect(beforeCn.length).assertEqual(2);
      expect(beforeCn.some((item: CatalogEntry): boolean => item.itemId.startsWith('SCP-CN-'))).assertFalse();

      deferredRepo.resolveCn(new CatalogSnapshot(
        SCP_CN_SERIES[0].id,
        [new CatalogEntry('SCP-CN-100', '中文原创档案 A'), new CatalogEntry('SCP-CN-200', '中文原创档案 B')],
        CatalogSnapshotSource.NETWORK,
        200
      ));
      await drainMicrotasks(40);
      const afterCn = viewModel.snapshot.data?.random ?? [];
      expect(afterCn.length).assertEqual(4);
      expect(afterCn.some((item: CatalogEntry): boolean => !item.itemId.startsWith('SCP-CN-'))).assertTrue();
      expect(afterCn.some((item: CatalogEntry): boolean => item.itemId.startsWith('SCP-CN-'))).assertTrue();
      viewModel.dispose();
    });
  });
}
