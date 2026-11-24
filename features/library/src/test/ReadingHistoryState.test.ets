import { describe, expect, it } from '@ohos/hypium';
import {
  LibraryContentKind,
  LibraryContentRef,
  LibraryFavorite,
  createLibraryContentRef
} from '../main/ets/domain/LibraryContentRef';
import {
  FavoriteRepository
} from '../main/ets/domain/LibraryRepositories';
import { LibraryCollectionMode } from '../main/ets/domain/LibraryContracts';
import {
  READING_HISTORY_LIMIT,
  ReadingHistoryEntry,
  ReadingStateEntry
} from '../main/ets/domain/ReadingHistoryEntry';
import {
  ReadingHistoryMutation,
  ReadingHistoryStorageAdapter,
  ReadingHistoryStoreEngine
} from '../main/ets/data/ReadingHistoryEngine';
import { FavoritesViewModel } from '../main/ets/presentation/viewmodel/FavoritesViewModel';
import { LibraryCollectionVM } from '../main/ets/presentation/viewmodel/LibraryCollectionVM';
import { ReadingHistoryViewModel } from '../main/ets/presentation/viewmodel/ReadingHistoryViewModel';

class EmptyFavoritesRepo implements FavoriteRepository {
  list(): Promise<LibraryFavorite[]> {
    return Promise.resolve([]);
  }

  toggle(_content: LibraryContentRef): Promise<boolean> {
    return Promise.resolve(false);
  }

  setFavorite(_content: LibraryContentRef, favorite: boolean): Promise<boolean> {
    return Promise.resolve(favorite);
  }
}

class InMemoryReadingHistoryStorage implements ReadingHistoryStorageAdapter {
  private readonly historyMap: Map<string, ReadingHistoryEntry> =
    new Map<string, ReadingHistoryEntry>();
  private readonly stateMap: Map<string, ReadingStateEntry> =
    new Map<string, ReadingStateEntry>();

  listHistory(limit: number): Promise<ReadingHistoryEntry[]> {
    const entries: ReadingHistoryEntry[] = [];
    this.historyMap.forEach((entry: ReadingHistoryEntry): void => {
      entries.push(entry);
    });
    entries.sort((left: ReadingHistoryEntry, right: ReadingHistoryEntry): number => {
      if (left.lastReadAt !== right.lastReadAt) {
        return right.lastReadAt - left.lastReadAt;
      }
      return left.content.key.localeCompare(right.content.key);
    });
    return Promise.resolve(entries.slice(0, limit));
  }

  findHistory(contentKey: string): Promise<ReadingHistoryEntry | undefined> {
    return Promise.resolve(this.historyMap.get(contentKey));
  }

  listStates(): Promise<ReadingStateEntry[]> {
    const states: ReadingStateEntry[] = [];
    this.stateMap.forEach((state: ReadingStateEntry): void => {
      states.push(state);
    });
    states.sort((left: ReadingStateEntry, right: ReadingStateEntry): number => {
      if (left.updatedAt !== right.updatedAt) {
        return right.updatedAt - left.updatedAt;
      }
      return left.content.key.localeCompare(right.content.key);
    });
    return Promise.resolve(states);
  }

  findState(contentKey: string): Promise<ReadingStateEntry | undefined> {
    return Promise.resolve(this.stateMap.get(contentKey));
  }

  commitMutation(mutation: ReadingHistoryMutation): Promise<void> {
    if (mutation.historyEntry !== undefined) {
      this.historyMap.set(mutation.historyEntry.content.key, mutation.historyEntry);
    }
    if (mutation.stateEntry !== undefined) {
      this.stateMap.set(mutation.stateEntry.content.key, mutation.stateEntry);
    } else if (mutation.deleteStateKey !== undefined) {
      this.stateMap.delete(mutation.deleteStateKey);
    }
    return Promise.resolve();
  }

  pruneHistory(limit: number): Promise<void> {
    const entries: ReadingHistoryEntry[] = [];
    this.historyMap.forEach((entry: ReadingHistoryEntry): void => {
      entries.push(entry);
    });
    entries.sort((left: ReadingHistoryEntry, right: ReadingHistoryEntry): number => {
      if (left.lastReadAt !== right.lastReadAt) {
        return right.lastReadAt - left.lastReadAt;
      }
      return left.content.key.localeCompare(right.content.key);
    });
    const kept = entries.slice(0, limit);
    this.historyMap.clear();
    for (let index = 0; index < kept.length; index++) {
      this.historyMap.set(kept[index].content.key, kept[index]);
    }
    return Promise.resolve();
  }

  historySize(): number {
    return this.historyMap.size;
  }

  stateSize(): number {
    return this.stateMap.size;
  }
}

class MonotonicTestClock {
  private current: number = 1000;

  now(): number {
    this.current += 10;
    return this.current;
  }
}

function containsKey(entries: ReadingHistoryEntry[], contentKey: string): boolean {
  for (let index = 0; index < entries.length; index++) {
    if (entries[index].content.key === contentKey) {
      return true;
    }
  }
  return false;
}

function padThree(value: number): string {
  if (value < 10) {
    return `00${value}`;
  }
  if (value < 100) {
    return `0${value}`;
  }
  return `${value}`;
}

export default function readingHistoryStateTest(): void {
  describe('PermanentReadingStateDecoupling', () => {
    it('preserves completed status and scroll offset beyond 500 history pruning', 0, async () => {
      const storage = new InMemoryReadingHistoryStorage();
      const clock = new MonotonicTestClock();
      const engine = new ReadingHistoryStoreEngine(
        storage,
        READING_HISTORY_LIMIT,
        (): number => clock.now()
      );
      const viewModel = new ReadingHistoryViewModel(engine);

      const item1 = createLibraryContentRef(LibraryContentKind.SCP, 'SCP-001', '第一篇档案');
      const item2 = createLibraryContentRef(LibraryContentKind.SCP, 'SCP-002', '第二篇档案');
      const item3 = createLibraryContentRef(LibraryContentKind.SCP, 'SCP-003', '第三篇档案');

      await viewModel.recordOpened(item1);
      await viewModel.updateProgress(item1, 480);
      await viewModel.setCompleted(item1, true);

      await viewModel.recordOpened(item2);
      await viewModel.updateProgress(item2, 320);

      await viewModel.recordOpened(item3);

      for (let index = 4; index <= 505; index++) {
        const filler = createLibraryContentRef(
          LibraryContentKind.SCP,
          `SCP-${padThree(index)}`,
          `档案 ${index}`
        );
        await viewModel.recordOpened(filler);
      }

      expect(viewModel.items.length).assertEqual(READING_HISTORY_LIMIT);
      expect(storage.historySize()).assertEqual(READING_HISTORY_LIMIT);
      expect(containsKey(viewModel.items, 'main:scp-001')).assertFalse();
      expect(containsKey(viewModel.items, 'main:scp-002')).assertFalse();
      expect(containsKey(viewModel.items, 'main:scp-003')).assertFalse();

      expect(viewModel.isCompleted('SCP-001')).assertTrue();
      expect(viewModel.isCompleted('scp-001')).assertTrue();
      expect(viewModel.isCompleted('/scp-001')).assertTrue();
      expect(viewModel.isCompleted('main:scp-001')).assertTrue();
      expect(viewModel.isCompleted('SCP-002')).assertFalse();
      expect(viewModel.completedCount).assertEqual(1);

      const restored1 = await viewModel.find('main:scp-001');
      expect(restored1 !== undefined).assertTrue();
      expect(restored1!.scrollOffset).assertEqual(480);
      expect(restored1!.completed).assertTrue();

      const restored2 = await viewModel.find('main:scp-002');
      expect(restored2 !== undefined).assertTrue();
      expect(restored2!.scrollOffset).assertEqual(320);
      expect(restored2!.completed).assertFalse();

      const restored3 = await viewModel.find('main:scp-003');
      expect(restored3 === undefined).assertTrue();

      expect(containsKey(viewModel.resumableItems, 'main:scp-001')).assertTrue();
      expect(containsKey(viewModel.resumableItems, 'main:scp-002')).assertTrue();
      expect(containsKey(viewModel.resumableItems, 'main:scp-003')).assertFalse();
    });

    it('restores saved offset, completed flag and title when reopening a pruned entry', 0, async () => {
      const storage = new InMemoryReadingHistoryStorage();
      const clock = new MonotonicTestClock();
      const engine = new ReadingHistoryStoreEngine(
        storage,
        5,
        (): number => clock.now()
      );
      const viewModel = new ReadingHistoryViewModel(engine, 5);

      const item1 = createLibraryContentRef(LibraryContentKind.SCP, 'SCP-001', '第一篇档案');
      await viewModel.recordOpened(item1);
      await viewModel.updateProgress(item1, 480);
      await viewModel.setCompleted(item1, true);

      for (let index = 2; index <= 8; index++) {
        await viewModel.recordOpened(createLibraryContentRef(
          LibraryContentKind.SCP,
          `SCP-${padThree(index)}`,
          `档案 ${index}`
        ));
      }
      expect(viewModel.items.length).assertEqual(5);
      expect(containsKey(viewModel.items, 'main:scp-001')).assertFalse();

      // Reopen with a placeholder title (for example from an inline wiki link).
      await viewModel.recordOpened(createLibraryContentRef(
        LibraryContentKind.SCP,
        'scp-001',
        'scp-001'
      ));

      expect(viewModel.items.length).assertEqual(5);
      expect(viewModel.items[0].content.key).assertEqual('main:scp-001');
      expect(viewModel.items[0].content.title).assertEqual('第一篇档案');
      expect(viewModel.items[0].scrollOffset).assertEqual(480);
      expect(viewModel.items[0].completed).assertTrue();
    });

    it('clears permanent state entries cleanly when offset and completed both reset', 0, async () => {
      const storage = new InMemoryReadingHistoryStorage();
      const clock = new MonotonicTestClock();
      const engine = new ReadingHistoryStoreEngine(storage, 20, (): number => clock.now());
      const viewModel = new ReadingHistoryViewModel(engine);

      const item1 = createLibraryContentRef(LibraryContentKind.SCP, 'SCP-001', '第一篇');
      const item2 = createLibraryContentRef(LibraryContentKind.SCP, 'SCP-002', '第二篇');
      const itemZero = createLibraryContentRef(LibraryContentKind.TALE, 'tale-zero', '短篇故事');

      await viewModel.recordOpened(item1);
      await viewModel.updateProgress(item1, 480);
      await viewModel.setCompleted(item1, true);

      await viewModel.recordOpened(item2);
      await viewModel.updateProgress(item2, 320);

      await viewModel.updateProgress(item2, 0);
      expect(containsKey(viewModel.resumableItems, 'main:scp-002')).assertFalse();
      expect(storage.stateSize()).assertEqual(1);

      await viewModel.setCompleted(item1, false);
      expect(viewModel.isCompleted('scp-001')).assertFalse();
      expect(viewModel.completedCount).assertEqual(0);
      expect(containsKey(viewModel.resumableItems, 'main:scp-001')).assertTrue();
      expect(storage.stateSize()).assertEqual(1);
      expect(viewModel.readingStates[0].scrollOffset).assertEqual(480);

      await viewModel.recordOpened(itemZero);
      await viewModel.setCompleted(itemZero, true);
      expect(viewModel.completedCount).assertEqual(1);
      expect(viewModel.isCompleted('tale-zero')).assertTrue();
      expect(storage.stateSize()).assertEqual(2);

      await viewModel.setCompleted(itemZero, false);
      expect(viewModel.completedCount).assertEqual(0);
      expect(viewModel.isCompleted('tale-zero')).assertFalse();
      expect(storage.stateSize()).assertEqual(1);
    });

    it('enriches placeholder titles for both in-history and pruned permanent states without changing timestamps or re-adding pruned items', 0, async () => {
      const storage = new InMemoryReadingHistoryStorage();
      const clock = new MonotonicTestClock();
      const engine = new ReadingHistoryStoreEngine(storage, 4, (): number => clock.now());
      const viewModel = new ReadingHistoryViewModel(engine, 4);

      const prunedScrolled = createLibraryContentRef(LibraryContentKind.SCP, 'SCP-010', 'scp-010');
      await viewModel.recordOpened(prunedScrolled);
      await viewModel.updateProgress(prunedScrolled, 250);
      const prunedUpdatedAt = viewModel.readingStates[0].updatedAt;

      for (let index = 11; index <= 14; index++) {
        await viewModel.recordOpened(createLibraryContentRef(
          LibraryContentKind.SCP,
          `SCP-${padThree(index)}`,
          index === 14 ? 'scp-014' : `档案 ${index}`
        ));
      }
      expect(containsKey(viewModel.items, 'main:scp-010')).assertFalse();
      const recent14Before = viewModel.items[0];
      expect(recent14Before.content.key).assertEqual('main:scp-014');

      await viewModel.updateMetadata(createLibraryContentRef(
        LibraryContentKind.SCP,
        'SCP-010',
        '起司汉堡'
      ));
      expect(containsKey(viewModel.items, 'main:scp-010')).assertFalse();
      expect(viewModel.items.length).assertEqual(4);
      expect(viewModel.resumableItems[0].content.key).assertEqual('main:scp-010');
      expect(viewModel.resumableItems[0].content.title).assertEqual('起司汉堡');
      expect(viewModel.readingStates[0].updatedAt).assertEqual(prunedUpdatedAt);

      await viewModel.updateMetadata(createLibraryContentRef(
        LibraryContentKind.SCP,
        'SCP-014',
        '第十四号档案'
      ));
      expect(viewModel.items[0].content.title).assertEqual('第十四号档案');
      expect(viewModel.items[0].lastReadAt).assertEqual(recent14Before.lastReadAt);
      expect(viewModel.items[0].openedAt).assertEqual(recent14Before.openedAt);
    });

    it('exposes pruned resumable entries in LibraryCollectionVM CONTINUE_READING without expanding RECENT', 0, async () => {
      const storage = new InMemoryReadingHistoryStorage();
      const clock = new MonotonicTestClock();
      const engine = new ReadingHistoryStoreEngine(storage, 3, (): number => clock.now());
      const historyVm = new ReadingHistoryViewModel(engine, 3);

      const pruned = createLibraryContentRef(LibraryContentKind.SCP, 'SCP-055', '逆模因');
      await historyVm.recordOpened(pruned);
      await historyVm.updateProgress(pruned, 610);
      for (let index = 56; index <= 58; index++) {
        await historyVm.recordOpened(createLibraryContentRef(
          LibraryContentKind.SCP,
          `SCP-${padThree(index)}`,
          `档案 ${index}`
        ));
      }

      const collectionVm = new LibraryCollectionVM(
        new FavoritesViewModel(new EmptyFavoritesRepo()),
        historyVm
      );
      collectionVm.setRouteMode(LibraryCollectionMode.CONTINUE_READING);
      collectionVm.activate();
      await Promise.resolve();
      await Promise.resolve();
      expect(collectionVm.items.length).assertEqual(1);
      expect(collectionVm.items[0].content.key).assertEqual('main:scp-055');

      collectionVm.setMode(LibraryCollectionMode.RECENT);
      await Promise.resolve();
      await Promise.resolve();
      expect(collectionVm.items.length).assertEqual(3);
      for (let index = 0; index < collectionVm.items.length; index++) {
        expect(collectionVm.items[index].content.key === 'main:scp-055').assertFalse();
      }
      collectionVm.dispose();
    });

    it('restores permanent completed badges, offsets and counts after cold-reload from persistent storage', 0, async () => {
      const storage = new InMemoryReadingHistoryStorage();
      const clock = new MonotonicTestClock();
      const writerEngine = new ReadingHistoryStoreEngine(
        storage,
        READING_HISTORY_LIMIT,
        (): number => clock.now()
      );
      const writerVm = new ReadingHistoryViewModel(writerEngine);

      const item1 = createLibraryContentRef(LibraryContentKind.SCP, 'SCP-001', '第一篇档案');
      await writerVm.recordOpened(item1);
      await writerVm.updateProgress(item1, 777);
      await writerVm.setCompleted(item1, true);

      for (let index = 2; index <= 505; index++) {
        await writerVm.recordOpened(createLibraryContentRef(
          LibraryContentKind.SCP,
          `SCP-${padThree(index)}`,
          `档案 ${index}`
        ));
      }

      const coldEngine = new ReadingHistoryStoreEngine(
        storage,
        READING_HISTORY_LIMIT,
        (): number => clock.now()
      );
      const coldVm = new ReadingHistoryViewModel(coldEngine);
      await coldVm.initialize();

      expect(coldVm.items.length).assertEqual(READING_HISTORY_LIMIT);
      expect(coldVm.isCompleted('SCP-001')).assertTrue();
      expect(coldVm.completedCount).assertEqual(1);
      expect(containsKey(coldVm.resumableItems, 'main:scp-001')).assertTrue();
      const restored = await coldVm.find('main:scp-001');
      expect(restored !== undefined).assertTrue();
      expect(restored!.scrollOffset).assertEqual(777);
      expect(restored!.completed).assertTrue();
    });
  });
}
