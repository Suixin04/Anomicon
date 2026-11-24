import { describe, expect, it } from '@ohos/hypium';
import { ScpSearchHistoryService, SearchHistoryStorage } from '../main/ets/data/ScpSearchHistoryService';

class TestHistoryStorage implements SearchHistoryStorage {
  saved: string[] = ['SCP-055'];
  private cached: string[] = this.saved.slice();
  failWrites: boolean = false;

  discardCache(): void {
    this.cached = this.saved.slice();
  }

  read(): string[] {
    return this.cached.slice();
  }

  write(items: string[]): void {
    // The SDK skips unchanged cached values even if the previous flush failed.
    if (this.cached.join(',') === items.join(',')) {
      return;
    }
    this.cached = items.slice();
    if (this.failWrites) {
      throw new Error('模拟落盘失败');
    }
    this.saved = items.slice();
  }
}

export default function searchHistoryPersistenceTest(): void {
  describe('SearchHistoryPersistence', () => {
    it('keeps the record available for retry until deletion is durable', 0, () => {
      const disk = new TestHistoryStorage();
      const history = new ScpSearchHistoryService(disk);
      expect(history.list()[0]).assertEqual('SCP-055');
      disk.failWrites = true;
      for (let attempt = 0; attempt < 2; attempt++) {
        let failure = '';
        try {
          history.clear();
        } catch (error) {
          failure = error instanceof Error ? error.message : '';
        }
        expect(failure).assertEqual('模拟落盘失败');
        expect(history.list()[0]).assertEqual('SCP-055');
        expect(disk.saved[0]).assertEqual('SCP-055');
      }
      expect(new ScpSearchHistoryService(disk).list()[0]).assertEqual('SCP-055');
      disk.failWrites = false;
      history.clear();
      expect(history.list().length).assertEqual(0);
      expect(new ScpSearchHistoryService(disk).list().length).assertEqual(0);
    });

    it('retries a failed query addition and persists the newest query first', 0, () => {
      const disk = new TestHistoryStorage();
      const history = new ScpSearchHistoryService(disk);
      disk.failWrites = true;
      history.add('SCP-173');
      expect(disk.saved.length).assertEqual(1);
      disk.failWrites = false;
      expect(history.list().join(',')).assertEqual('SCP-173,SCP-055');
      expect(new ScpSearchHistoryService(disk).list().join(',')).assertEqual('SCP-173,SCP-055');
    });
  });
}
