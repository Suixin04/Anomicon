import { describe, expect, it } from '@ohos/hypium';
import {
  LibraryContentKind,
  LibraryContentRef,
  createLibraryContentRef
} from '../main/ets/domain/LibraryContentRef';
import {
  ReadingHistoryEntry,
  ReadingStateEntry
} from '../main/ets/domain/ReadingHistoryEntry';
import {
  ReadingHistoryMutation,
  ReadingHistoryStorageAdapter,
  ReadingHistoryStoreEngine
} from '../main/ets/data/ReadingHistoryEngine';
import { ReadingHistoryViewModel } from '../main/ets/presentation/viewmodel/ReadingHistoryViewModel';
import {
  ANTIMEMETICS_DIVISION_SERIES,
  ANTIMEMETICS_HUB_ID,
  ANTIMEMETICS_SERIES_ID,
  StorySeriesEnrollment,
  StorySeriesRepository,
  StorySeriesTier,
  buildStorySeriesArticleContext,
  parseStorySeriesGroupsFromHubHtml
} from '../main/ets/domain/StorySeriesContracts';
import { StorySeriesViewModel } from '../main/ets/presentation/viewmodel/StorySeriesViewModel';

class InMemoryHistoryStorageForSeries implements ReadingHistoryStorageAdapter {
  private readonly historyMap: Map<string, ReadingHistoryEntry> =
    new Map<string, ReadingHistoryEntry>();
  private readonly stateMap: Map<string, ReadingStateEntry> =
    new Map<string, ReadingStateEntry>();

  listHistory(limit: number): Promise<ReadingHistoryEntry[]> {
    const entries: ReadingHistoryEntry[] = [];
    this.historyMap.forEach((entry: ReadingHistoryEntry): void => {
      entries.push(entry);
    });
    entries.sort((left: ReadingHistoryEntry, right: ReadingHistoryEntry): number =>
      right.lastReadAt - left.lastReadAt);
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
    entries.sort((left: ReadingHistoryEntry, right: ReadingHistoryEntry): number =>
      right.lastReadAt - left.lastReadAt);
    const kept = entries.slice(0, limit);
    this.historyMap.clear();
    for (let index = 0; index < kept.length; index++) {
      this.historyMap.set(kept[index].content.key, kept[index]);
    }
    return Promise.resolve();
  }
}

class InMemoryStorySeriesRepo implements StorySeriesRepository {
  readonly saved: Map<string, StorySeriesEnrollment> = new Map<string, StorySeriesEnrollment>();

  listEnrollments(): Promise<StorySeriesEnrollment[]> {
    const rows: StorySeriesEnrollment[] = [];
    this.saved.forEach((row: StorySeriesEnrollment): void => {
      rows.push(row);
    });
    return Promise.resolve(rows);
  }

  saveEnrollment(enrollment: StorySeriesEnrollment): Promise<StorySeriesEnrollment> {
    this.saved.set(enrollment.seriesId, enrollment);
    return Promise.resolve(enrollment);
  }

  removeEnrollment(seriesId: string): Promise<void> {
    this.saved.delete(seriesId);
    return Promise.resolve();
  }
}

function createTestHistoryVm(): ReadingHistoryViewModel {
  let tick = 1000;
  const engine = new ReadingHistoryStoreEngine(
    new InMemoryHistoryStorageForSeries(),
    500,
    (): number => {
      tick += 10;
      return tick;
    }
  );
  return new ReadingHistoryViewModel(engine);
}

export default function storySeriesTest(): void {
  describe('StorySeriesContractsAndParser', () => {
    it('parses hub sections cleanly while skipping author, tag, and offset links', 0, () => {
      const sampleHtml = `
        <div id="page-content">
          <h2 id="toc0"><span>核心背景读物</span></h2>
          <ul>
            <li><a href="/scp-055">SCP-055</a> <a href="/qntm-s-author-page">qntm</a></li>
          </ul>
          <h2 id="toc1"><span>这里没有逆模因部 qntm著</span></h2>
          <ul>
            <li><a href="/we-need-to-talk-about-fifty-five">谈谈055</a></li>
            <li><a href="/introductory-antimemetics">逆模因学入门</a></li>
          </ul>
          <h2 id="toc2"><span>逝者所知 sirpudding著</span></h2>
          <ul>
            <li><a href="/scp-2111">SCP-2111</a></li>
          </ul>
          <h2 id="toc3"><span>以供参阅</span></h2>
          <ul>
            <li><a href="/antimemetics-division-timeline">逆模因部系列时间线</a></li>
            <li><a href="http://scp-wiki-cn.wikidot.com/antimemetics-division-hub/offset/1">Marion Wheeler</a></li>
          </ul>
          <h2 id="toc4"><span>进一步阅读</span></h2>
          <ul>
            <li><a href="/scp-3393">SCP-3393</a> <a href="/captain-kirby-s-personal-file">Captain Kirby</a></li>
            <li><a href="http://scp-wiki-cn.wikidot.com/system:page-tags/tag/marion-wheeler#pages">Tag</a></li>
          </ul>
          <h2 id="toc5"><span>中国分部原创的相关故事</span></h2>
          <ul>
            <li><a href="http://scp-wiki-cn.wikidot.com/train">失忆症</a></li>
          </ul>
        </div>
        <div class="page-tags"></div>
      `;

      const groups = parseStorySeriesGroupsFromHubHtml(sampleHtml);
      expect(groups.length).assertEqual(6);
      expect(groups[0].title).assertEqual('核心背景读物');
      expect(groups[0].tier).assertEqual(StorySeriesTier.MAINLINE);
      expect(groups[0].entries.length).assertEqual(1);
      expect(groups[0].entries[0].id).assertEqual('scp-055');

      expect(groups[1].title).assertEqual('这里没有逆模因部');
      expect(groups[1].entries.length).assertEqual(2);
      expect(groups[1].entries[0].id).assertEqual('we-need-to-talk-about-fifty-five');

      expect(groups[2].tier).assertEqual(StorySeriesTier.SIDE);
      expect(groups[3].tier).assertEqual(StorySeriesTier.EXTENDED);
      expect(groups[3].entries.length).assertEqual(1);
      expect(groups[4].entries.length).assertEqual(1);
      expect(groups[4].entries[0].id).assertEqual('scp-3393');
      expect(groups[5].entries.length).assertEqual(1);
      expect(groups[5].entries[0].id).assertEqual('train');
    });

    it('chains Antimemetics Division mainline chapters across Wiki groups in exact order', 0, () => {
      const ctx055 = buildStorySeriesArticleContext(
        ANTIMEMETICS_DIVISION_SERIES,
        'SCP-055',
        undefined,
        (): boolean => false
      );
      expect(ctx055.isHubPage).assertFalse();
      expect(ctx055.mainlineTotal).assertEqual(19);
      expect(ctx055.currentGroupTitle).assertEqual('核心背景读物');
      expect(ctx055.nextEntry?.id).assertEqual('we-need-to-talk-about-fifty-five');
      expect(ctx055.nextEntry?.title).assertEqual('谈谈055');
      expect(ctx055.previousEntry === undefined).assertTrue();

      const ctxLastFirstDay = buildStorySeriesArticleContext(
        ANTIMEMETICS_DIVISION_SERIES,
        'your-last-first-day',
        undefined,
        (): boolean => false
      );
      expect(ctxLastFirstDay.nextEntry?.id).assertEqual('scp-2256');

      const ctx2256 = buildStorySeriesArticleContext(
        ANTIMEMETICS_DIVISION_SERIES,
        'scp-2256',
        undefined,
        (): boolean => false
      );
      expect(ctx2256.nextEntry?.id).assertEqual('scp-3125');

      const ctx2111 = buildStorySeriesArticleContext(
        ANTIMEMETICS_DIVISION_SERIES,
        'scp-2111',
        undefined,
        (): boolean => false
      );
      expect(ctx2111.currentGroupTitle).assertEqual('逝者所知');
      expect(ctx2111.nextEntry?.id).assertEqual('in-the-trenches-with-the-dead');
    });
  });

  describe('StorySeriesViewModel', () => {
    it('enrolls series, syncs permanent completion, and preserves progress across detours', 0, async () => {
      const historyVm = createTestHistoryVm();
      const seriesRepo = new InMemoryStorySeriesRepo();
      const seriesVm = new StorySeriesViewModel(seriesRepo, historyVm);
      await seriesVm.initialize();

      const hubCtx = seriesVm.resolveArticleContext(ANTIMEMETICS_HUB_ID);
      expect(hubCtx !== undefined).assertTrue();
      expect(hubCtx!.isHubPage).assertTrue();
      expect(hubCtx!.enrolled).assertFalse();

      // Starting opens SCP-055 and persists enrollment.
      const firstTarget = await seriesVm.startSeries(ANTIMEMETICS_SERIES_ID);
      expect(firstTarget?.id).assertEqual('scp-055');
      expect(seriesVm.enrolledCount).assertEqual(1);

      // Completing SCP-055 and moving to 谈谈055 updates progress and next pointer.
      const scp055Ref: LibraryContentRef = createLibraryContentRef(
        LibraryContentKind.SCP,
        'scp-055',
        'SCP-055'
      );
      await historyVm.setCompleted(scp055Ref, true);
      await seriesVm.recordMemberOpened(
        ANTIMEMETICS_SERIES_ID,
        'we-need-to-talk-about-fifty-five',
        true
      );

      const snapshot = seriesVm.snapshotFor(ANTIMEMETICS_SERIES_ID);
      expect(snapshot?.mainlineCompleted).assertEqual(1);
      expect(snapshot?.resumeEntry?.id).assertEqual('we-need-to-talk-about-fifty-five');
      expect(snapshot?.resumeEntry?.title).assertEqual('谈谈055');

      // Detouring to an unrelated article (SCP-173) produces no series context and
      // never overwrites the saved Antimemetics Division cursor.
      const detourCtx = seriesVm.resolveArticleContext('scp-173');
      expect(detourCtx === undefined).assertTrue();
      await seriesVm.recordMemberOpened(ANTIMEMETICS_SERIES_ID, 'scp-173');

      const preserved = seriesVm.snapshotFor(ANTIMEMETICS_SERIES_ID);
      expect(preserved?.currentEntryId).assertEqual('we-need-to-talk-about-fifty-five');
      expect(preserved?.resumeEntry?.id).assertEqual('we-need-to-talk-about-fifty-five');
      seriesVm.dispose();
    });
  });
}
