import { describe, expect, it } from '@ohos/hypium';
import { ViewModelLoadState } from 'anomiconbasic';
import {
  LibraryContentKind,
  LibraryContentRef,
  LibraryFavorite,
  ReadingHistoryEntry,
  ResearchActivitySnapshot,
  ResearchDailyProgress,
  ResearchProgress,
  createLibraryContentRef,
  emptyResearchProgress,
  researchDayKeyAt
} from 'library';
import {
  FOUNDATION_FEATURED_KNOWLEDGE,
  FOUNDATION_KNOWLEDGE_SECTIONS,
  FOUNDATION_MANUAL_GRID_ITEMS,
  FoundationKnowledgeItem,
  TerminalEnrolledSeriesCard,
  TerminalFavoritesPort,
  TerminalReadingHistoryPort,
  TerminalResearchProfilePort,
  TerminalStorySeriesPort,
  TerminalViewModel,
  TerminalViewModelListener,
  buildRecentSevenDayActivity,
  formatTodayQuotaLabel
} from '../main/ets/Index';

class InMemoryStorySeriesPort implements TerminalStorySeriesPort {
  cards: TerminalEnrolledSeriesCard[];
  private readonly listeners: TerminalViewModelListener[];

  constructor(
    cards: TerminalEnrolledSeriesCard[],
    listeners: TerminalViewModelListener[]
  ) {
    this.cards = cards;
    this.listeners = listeners;
  }

  listEnrolled(): TerminalEnrolledSeriesCard[] {
    return this.cards;
  }

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  reload(): Promise<void> {
    return Promise.resolve();
  }

  subscribe(listener: TerminalViewModelListener): () => void {
    this.listeners.push(listener);
    return (): void => {
      const idx = this.listeners.indexOf(listener);
      if (idx >= 0) {
        this.listeners.splice(idx, 1);
      }
    };
  }
}

class InMemoryFavorites implements TerminalFavoritesPort {
  items: LibraryFavorite[];
  loading: boolean = false;
  error: string = '';
  initialized: boolean = true;
  private readonly listeners: TerminalViewModelListener[] = [];

  constructor(items: LibraryFavorite[]) {
    this.items = items;
  }

  subscribe(listener: TerminalViewModelListener): () => void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
    return (): void => {
      const index = this.listeners.indexOf(listener);
      if (index >= 0) {
        this.listeners.splice(index, 1);
      }
    };
  }

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  reload(): Promise<void> {
    return Promise.resolve();
  }

  emit(): void {
    const listeners = this.listeners.slice();
    for (let index = 0; index < listeners.length; index++) {
      listeners[index]();
    }
  }

  subscriberCount(): number {
    return this.listeners.length;
  }
}

class InMemoryReadingHistory implements TerminalReadingHistoryPort {
  items: ReadingHistoryEntry[];
  resumableItems: ReadingHistoryEntry[] | undefined;
  loading: boolean = false;
  error: string = '';
  initialized: boolean = true;
  readonly metadataWrites: LibraryContentRef[] = [];
  private readonly listeners: TerminalViewModelListener[] = [];

  constructor(
    items: ReadingHistoryEntry[],
    resumableItems: ReadingHistoryEntry[] | undefined = undefined
  ) {
    this.items = items;
    this.resumableItems = resumableItems;
  }

  subscribe(listener: TerminalViewModelListener): () => void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
    return (): void => {
      const index = this.listeners.indexOf(listener);
      if (index >= 0) {
        this.listeners.splice(index, 1);
      }
    };
  }

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  reload(): Promise<void> {
    return Promise.resolve();
  }

  updateMetadata(content: LibraryContentRef): Promise<void> {
    this.metadataWrites.push(content);
    const updated: ReadingHistoryEntry[] = [];
    for (let index = 0; index < this.items.length; index++) {
      const entry = this.items[index];
      updated.push(entry.content.key === content.key ? new ReadingHistoryEntry(
        content,
        entry.openedAt,
        entry.lastReadAt,
        entry.scrollOffset,
        entry.completed
      ) : entry);
    }
    this.items = updated;
    if (this.resumableItems !== undefined) {
      const updatedResumable: ReadingHistoryEntry[] = [];
      for (let index = 0; index < this.resumableItems.length; index++) {
        const entry = this.resumableItems[index];
        updatedResumable.push(entry.content.key === content.key ? new ReadingHistoryEntry(
          content,
          entry.openedAt,
          entry.lastReadAt,
          entry.scrollOffset,
          entry.completed
        ) : entry);
      }
      this.resumableItems = updatedResumable;
    }
    this.emit();
    return Promise.resolve();
  }

  emit(): void {
    const listeners = this.listeners.slice();
    for (let index = 0; index < listeners.length; index++) {
      listeners[index]();
    }
  }

  subscriberCount(): number {
    return this.listeners.length;
  }
}

class InMemoryResearchProfile implements TerminalResearchProfilePort {
  profile: ResearchProgress;
  loading: boolean = false;
  error: string = '';
  initialized: boolean = true;
  private readonly listeners: TerminalViewModelListener[] = [];

  constructor(profile: ResearchProgress) {
    this.profile = profile;
  }

  subscribe(listener: TerminalViewModelListener): () => void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
    return (): void => {
      const index = this.listeners.indexOf(listener);
      if (index >= 0) {
        this.listeners.splice(index, 1);
      }
    };
  }

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  reload(): Promise<ResearchActivitySnapshot> {
    return Promise.resolve(new ResearchActivitySnapshot(this.profile, undefined));
  }

  emit(): void {
    const listeners = this.listeners.slice();
    for (let index = 0; index < listeners.length; index++) {
      listeners[index]();
    }
  }

  subscriberCount(): number {
    return this.listeners.length;
  }
}

class ControlledTitleResolver {
  readonly requests: string[][] = [];
  private resolvePending: ((titles: Map<string, string>) => void) | undefined = undefined;

  resolve(ids: string[]): Promise<Map<string, string>> {
    this.requests.push(ids.slice());
    return new Promise<Map<string, string>>((resolve: (titles: Map<string, string>) => void): void => {
      this.resolvePending = resolve;
    });
  }

  succeed(id: string, title: string): void {
    const titles = new Map<string, string>();
    titles.set(id, title);
    const resolve = this.resolvePending;
    this.resolvePending = undefined;
    resolve?.(titles);
  }
}

class TerminalFixture {
  readonly placeholderContent: LibraryContentRef = createLibraryContentRef(
    LibraryContentKind.SCP,
    'SCP-173',
    'scp-173'
  );
  readonly recentContent: LibraryContentRef = createLibraryContentRef(
    LibraryContentKind.SCP,
    'SCP-049',
    '疫医'
  );
  readonly favorites: InMemoryFavorites = new InMemoryFavorites([
    new LibraryFavorite(this.recentContent, 300)
  ]);
  readonly history: InMemoryReadingHistory = new InMemoryReadingHistory([
    new ReadingHistoryEntry(this.placeholderContent, 100, 300, 48),
    new ReadingHistoryEntry(this.recentContent, 110, 200, 0)
  ]);
  readonly research: InMemoryResearchProfile = new InMemoryResearchProfile(emptyResearchProgress());
  readonly resolver: ControlledTitleResolver = new ControlledTitleResolver();
  readonly viewModel: TerminalViewModel = new TerminalViewModel(
    this.favorites,
    this.history,
    this.research,
    (ids: string[]): Promise<Map<string, string>> => this.resolver.resolve(ids)
  );
}

async function drainMicrotasks(rounds: number = 16): Promise<void> {
  for (let index = 0; index < rounds; index++) {
    await Promise.resolve();
  }
}

export default function terminalViewModelTest(): void {
  describe('TerminalViewModelLifecycle', () => {
    it('projects the current shared state immediately when activated', 0, async () => {
      const fixture = new TerminalFixture();

      fixture.viewModel.activate();

      expect(fixture.viewModel.state).assertEqual(ViewModelLoadState.LOADING);
      expect(fixture.viewModel.favoriteCount).assertEqual(1);
      expect(fixture.viewModel.favoriteEntries[0].content.key).assertEqual('main:scp-049');
      expect(fixture.viewModel.historyCount).assertEqual(2);
      expect(fixture.viewModel.resumeEntries.length).assertEqual(1);
      expect(fixture.viewModel.resumeEntries[0].content.key).assertEqual('main:scp-173');
      expect(fixture.viewModel.recentEntries.length).assertEqual(1);
      expect(fixture.viewModel.recentEntries[0].content.key).assertEqual('main:scp-049');
      expect(fixture.viewModel.profile === fixture.research.profile).assertTrue();

      await drainMicrotasks();
      expect(fixture.viewModel.state).assertEqual(ViewModelLoadState.READY);
      fixture.viewModel.dispose();
    });

    it('drops title enrichment that resolves after deactivation', 0, async () => {
      const fixture = new TerminalFixture();
      fixture.viewModel.activate();
      await drainMicrotasks();
      expect(fixture.resolver.requests.length).assertEqual(1);
      expect(fixture.resolver.requests[0][0]).assertEqual('scp-173');

      fixture.viewModel.deactivate();
      fixture.resolver.succeed('scp-173', '雕像');
      await drainMicrotasks();

      expect(fixture.history.metadataWrites.length).assertEqual(0);
      expect(fixture.viewModel.resumeEntries[0].content.title).assertEqual('scp-173');
      fixture.viewModel.dispose();
    });

    it('disposes idempotently and ignores later source or title results', 0, async () => {
      const fixture = new TerminalFixture();
      fixture.viewModel.activate();
      await drainMicrotasks();
      expect(fixture.resolver.requests.length).assertEqual(1);

      fixture.viewModel.dispose();
      expect(fixture.favorites.subscriberCount()).assertEqual(0);
      expect(fixture.history.subscriberCount()).assertEqual(0);
      expect(fixture.research.subscriberCount()).assertEqual(0);
      fixture.viewModel.dispose();
      fixture.favorites.emit();
      fixture.history.emit();
      fixture.research.emit();
      fixture.viewModel.refresh();
      fixture.viewModel.activate();
      fixture.resolver.succeed('scp-173', '雕像');
      await drainMicrotasks();

      expect(fixture.history.metadataWrites.length).assertEqual(0);
      expect(fixture.favorites.subscriberCount()).assertEqual(0);
      expect(fixture.history.subscriberCount()).assertEqual(0);
      expect(fixture.research.subscriberCount()).assertEqual(0);
    });

    it('surfaces pruned permanent resumable entries and enriches their placeholder titles', 0, async () => {
      const prunedResumeContent = createLibraryContentRef(
        LibraryContentKind.SCP,
        'SCP-173',
        'scp-173'
      );
      const recentContent = createLibraryContentRef(
        LibraryContentKind.SCP,
        'SCP-049',
        '疫医'
      );
      const history = new InMemoryReadingHistory(
        [new ReadingHistoryEntry(recentContent, 200, 400, 0, false)],
        [new ReadingHistoryEntry(prunedResumeContent, 100, 300, 420, true)]
      );
      const resolver = new ControlledTitleResolver();
      const viewModel = new TerminalViewModel(
        new InMemoryFavorites([]),
        history,
        new InMemoryResearchProfile(emptyResearchProgress()),
        (ids: string[]): Promise<Map<string, string>> => resolver.resolve(ids)
      );

      viewModel.activate();
      await drainMicrotasks();

      expect(viewModel.resumeEntries.length).assertEqual(1);
      expect(viewModel.resumeEntries[0].content.key).assertEqual('main:scp-173');
      expect(viewModel.resumeEntries[0].scrollOffset).assertEqual(420);
      expect(viewModel.resumeEntries[0].completed).assertTrue();
      expect(viewModel.recentEntries.length).assertEqual(1);
      expect(resolver.requests.length).assertEqual(1);
      expect(resolver.requests[0][0]).assertEqual('scp-173');

      resolver.succeed('scp-173', '雕像');
      await drainMicrotasks();

      expect(viewModel.resumeEntries[0].content.title).assertEqual('雕像');
      viewModel.dispose();
    });

    it('projects and reactively updates enrolled story series cards', 0, async () => {
      const seriesListeners: TerminalViewModelListener[] = [];
      let seriesCards: TerminalEnrolledSeriesCard[] = [{
        seriesId: 'antimemetics-division',
        hubId: 'antimemetics-division-hub',
        title: '逆模因部',
        subtitle: '从 SCP-055 起步',
        nextEntry: createLibraryContentRef(LibraryContentKind.SCP, 'scp-055', 'SCP-055'),
        nextEntryLabel: '下一篇：SCP-055',
        progressText: '主线 0/19',
        mainlineCompleted: 0,
        mainlineTotal: 19,
        updatedAt: 100
      }];
      const seriesPort = new InMemoryStorySeriesPort(seriesCards, seriesListeners);

      const viewModel = new TerminalViewModel(
        new InMemoryFavorites([]),
        new InMemoryReadingHistory([]),
        new InMemoryResearchProfile(emptyResearchProgress()),
        undefined,
        undefined,
        seriesPort
      );

      viewModel.activate();
      await drainMicrotasks();

      expect(viewModel.enrolledSeries.length).assertEqual(1);
      expect(viewModel.enrolledSeries[0].nextEntryLabel).assertEqual('下一篇：SCP-055');
      expect(seriesListeners.length).assertEqual(1);

      seriesPort.cards = [{
        seriesId: 'antimemetics-division',
        hubId: 'antimemetics-division-hub',
        title: '逆模因部',
        subtitle: '从 SCP-055 起步',
        nextEntry: createLibraryContentRef(
          LibraryContentKind.TALE,
          'we-need-to-talk-about-fifty-five',
          '谈谈055'
        ),
        nextEntryLabel: '下一篇：谈谈055',
        progressText: '主线 1/19',
        mainlineCompleted: 1,
        mainlineTotal: 19,
        updatedAt: 200
      }];
      seriesListeners[0]();
      expect(viewModel.enrolledSeries[0].nextEntryLabel).assertEqual('下一篇：谈谈055');
      expect(viewModel.enrolledSeries[0].mainlineCompleted).assertEqual(1);
      viewModel.dispose();
    });
  });

  describe('TerminalProfileHelpersAndManual', () => {
    it('builds 7 ordered daily bars and merges live today active ms', 0, () => {
      const nowMs = Date.UTC(2026, 10, 24, 12, 0, 0);
      const tzOffsetMinutes = 480;
      const dayMs = 24 * 60 * 60 * 1000;
      const todayKey = researchDayKeyAt(nowMs, tzOffsetMinutes);
      const daily: ResearchDailyProgress[] = [
        new ResearchDailyProgress(todayKey - 3 * dayMs, 40 * 60 * 1000),
        new ResearchDailyProgress(todayKey - 1 * dayMs, 2 * 60 * 1000)
      ];

      const bars = buildRecentSevenDayActivity(daily, 15 * 60 * 1000, nowMs, tzOffsetMinutes);

      expect(bars.length).assertEqual(7);
      expect(bars[6].isToday).assertTrue();
      expect(bars[6].dayKey).assertEqual(todayKey);
      expect(bars[6].label).assertEqual('二');
      expect(bars[6].minutes).assertEqual(15);
      expect(bars[0].ratio).assertEqual(0);
      expect(bars[3].minutes).assertEqual(40);
      expect(bars[3].ratio).assertEqual(1);
      // Small non-zero days remain visibly lifted above the baseline (0.22 minimum).
      expect(bars[5].minutes).assertEqual(2);
      expect(bars[5].ratio >= 0.22).assertTrue();
    });

    it('formats today quota labels across zero, sub-minute, and minute states', 0, () => {
      expect(formatTodayQuotaLabel(0)).assertEqual('0 / 180 分钟');
      expect(formatTodayQuotaLabel(45 * 1000)).assertEqual('< 1 / 180 分钟');
      expect(formatTodayQuotaLabel(12 * 60 * 1000)).assertEqual('12 / 180 分钟');
    });

    it('keeps featured overview plus 8 unique grid topics aligned with manual sections', 0, () => {
      const sectionKeys: Set<string> = new Set();
      for (let i = 0; i < FOUNDATION_KNOWLEDGE_SECTIONS.length; i++) {
        const items: FoundationKnowledgeItem[] = FOUNDATION_KNOWLEDGE_SECTIONS[i].items;
        for (let j = 0; j < items.length; j++) {
          sectionKeys.add(items[j].key);
        }
      }

      const gridKeys: Set<string> = new Set();
      gridKeys.add(FOUNDATION_FEATURED_KNOWLEDGE.key);
      for (let i = 0; i < FOUNDATION_MANUAL_GRID_ITEMS.length; i++) {
        gridKeys.add(FOUNDATION_MANUAL_GRID_ITEMS[i].key);
      }

      expect(FOUNDATION_MANUAL_GRID_ITEMS.length).assertEqual(8);
      expect(gridKeys.size).assertEqual(9);
      expect(gridKeys.size).assertEqual(sectionKeys.size);
      sectionKeys.forEach((key: string): void => {
        expect(gridKeys.has(key)).assertTrue();
      });
    });
  });
}
