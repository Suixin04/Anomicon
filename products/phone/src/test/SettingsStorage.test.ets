import { describe, expect, it } from '@ohos/hypium';
import { SearchHistoryRepository } from 'catalog';
import { SettingsStorageAdapter } from '../main/ets/composition/SettingsStorageAdapter';

class PendingOfflineScan {
  scans: number = 0;
  finish: () => void = (): void => {};

  count(): Promise<number> {
    this.scans++;
    return new Promise<number>((resolve) => {
      this.finish = (): void => resolve(4);
    });
  }
}

class TestSearchHistory implements SearchHistoryRepository {
  private records: string[] = ['SCP-173'];

  list(): string[] {
    return this.records.slice();
  }

  add(query: string): void {
    this.records.unshift(query);
  }

  clear(): void {
    this.records = [];
  }
}

export default function settingsStorageTest(): void {
  describe('SettingsStorage', () => {
    it('reads and clears history while offline storage inspection is pending', 0, async () => {
      const offline = new PendingOfflineScan();
      const adapter = new SettingsStorageAdapter('', '', () => offline.count(), () => Promise.resolve(),
        new TestSearchHistory());
      const pending = adapter.inspect();
      await Promise.resolve();
      expect(offline.scans).assertEqual(1);
      expect(adapter.searchHistoryCount()).assertEqual(1);
      adapter.clearSearchHistory();
      expect(adapter.searchHistoryCount()).assertEqual(0);
      offline.finish();
      expect((await pending).offlineArticlesCount).assertEqual(4);
      expect(offline.scans).assertEqual(1);
      expect(adapter.searchHistoryCount()).assertEqual(0);
    });
  });
}
