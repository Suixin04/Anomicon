import { describe, expect, it } from '@ohos/hypium';
import {
  ANTIMEMETICS_DIVISION_SERIES,
  ANTIMEMETICS_HUB_ID,
  ANTIMEMETICS_SERIES_ID,
  ReadingHistoryEntry,
  ReadingHistoryRepository,
  ReadingHistoryViewModel,
  ReadingStateEntry,
  StorySeriesEnrollment,
  StorySeriesRepository,
  StorySeriesViewModel,
  listMainlineSeriesEntries
} from 'library';
import { TerminalStorySeriesAdapter } from '../main/ets/composition/TerminalLibraryAdapters';

class CompletedMainline implements ReadingHistoryRepository {
  states: ReadingStateEntry[] = listMainlineSeriesEntries(ANTIMEMETICS_DIVISION_SERIES)
    .map(entry => new ReadingStateEntry(entry.toContentRef(), 0, true, 1, 1));

  list(): Promise<ReadingHistoryEntry[]> {
    return Promise.resolve([]);
  }

  listStates(): Promise<ReadingStateEntry[]> {
    return Promise.resolve(this.states);
  }

  recordOpened(): Promise<ReadingHistoryEntry> { throw new Error('卡片写入了阅读记录'); }
  updateProgress(): Promise<ReadingHistoryEntry> { throw new Error('卡片更改了阅读进度'); }
  updateMetadata(): Promise<ReadingHistoryEntry> { throw new Error('卡片更新了标题'); }
}

class EnrolledAtFinale implements StorySeriesRepository {
  listEnrollments(): Promise<StorySeriesEnrollment[]> {
    return Promise.resolve([new StorySeriesEnrollment(ANTIMEMETICS_SERIES_ID, true, 'champions-of-nothing', 1, 1)]);
  }

  saveEnrollment(): Promise<StorySeriesEnrollment> { throw new Error('卡片更改了跟读位置'); }
  removeEnrollment(): Promise<void> { throw new Error('卡片移除了跟读'); }
}

export default function terminalStorySeriesTest(): void {
  describe('TerminalStorySeriesAdapter', () => {
    it('offers the directory at 19/19 and resumes an earlier unread chapter at 18/19', 0, async () => {
      const saved = new CompletedMainline();
      const history = new ReadingHistoryViewModel(saved);
      const series = new StorySeriesViewModel(new EnrolledAtFinale(), history);
      const adapter = new TerminalStorySeriesAdapter(series);
      await adapter.initialize();

      const complete = adapter.listEnrolled()[0];
      expect(complete.progressText).assertEqual('主线 19/19');
      expect(complete.nextEntryLabel).assertEqual('主线已全部读完 · 查看目录');
      expect(complete.nextEntry === undefined).assertTrue();
      expect(complete.hubId).assertEqual(ANTIMEMETICS_HUB_ID);
      expect(series.snapshotFor(ANTIMEMETICS_SERIES_ID)?.currentEntryId).assertEqual('champions-of-nothing');

      saved.states = saved.states.filter(state => state.content.id !== 'unforgettable-that-s-what-you-are');
      await history.reload();
      const unfinished = adapter.listEnrolled()[0];
      expect(unfinished.progressText).assertEqual('主线 18/19');
      expect(unfinished.nextEntryLabel).assertEqual('下一篇：难忘的你');
      expect(unfinished.nextEntry?.id).assertEqual('unforgettable-that-s-what-you-are');
      series.dispose();
    });
  });
}
