import {
  LibraryContentKind,
  LibraryContentRef,
  createLibraryContentRef,
  isLibraryScpId
} from './LibraryContentRef';

/** Story series section tiers matching Wiki hub structure without reordering chapters. */
export enum StorySeriesTier {
  MAINLINE = 'mainline',
  SIDE = 'side',
  EXTENDED = 'extended'
}

/** One readable work entry inside an author/Wiki-curated story series group. */
export class StorySeriesEntry {
  readonly id: string;
  readonly kind: LibraryContentKind;
  readonly title: string;
  readonly author: string;
  readonly note: string;
  readonly groupId: string;
  readonly groupTitle: string;
  readonly tier: StorySeriesTier;
  readonly orderIndex: number;

  constructor(
    id: string,
    title: string,
    groupId: string,
    groupTitle: string,
    tier: StorySeriesTier,
    orderIndex: number,
    author: string = '',
    note: string = ''
  ) {
    const normalizedId = normalizeSeriesPageId(id);
    this.id = normalizedId;
    this.kind = isLibraryScpId(normalizedId) ? LibraryContentKind.SCP : LibraryContentKind.TALE;
    this.title = title.trim().length > 0 ? title.trim() : normalizedId;
    this.author = author.trim();
    this.note = note.trim();
    this.groupId = groupId;
    this.groupTitle = groupTitle;
    this.tier = tier;
    this.orderIndex = orderIndex;
  }

  toContentRef(): LibraryContentRef {
    return createLibraryContentRef(this.kind, this.id, this.title);
  }
}

/** One section group from the series hub (preserves exact Wiki grouping). */
export class StorySeriesGroup {
  readonly id: string;
  readonly title: string;
  readonly subtitle: string;
  readonly tier: StorySeriesTier;
  readonly entries: StorySeriesEntry[];

  constructor(
    id: string,
    title: string,
    subtitle: string,
    tier: StorySeriesTier,
    entries: StorySeriesEntry[]
  ) {
    this.id = id;
    this.title = title;
    this.subtitle = subtitle;
    this.tier = tier;
    this.entries = entries;
  }
}

/** Complete story series definition anchored to its Wiki hub page. */
export class StorySeriesDefinition {
  readonly id: string;
  readonly hubId: string;
  readonly title: string;
  readonly subtitle: string;
  readonly description: string;
  readonly groups: StorySeriesGroup[];

  constructor(
    id: string,
    hubId: string,
    title: string,
    subtitle: string,
    description: string,
    groups: StorySeriesGroup[]
  ) {
    this.id = id;
    this.hubId = normalizeSeriesPageId(hubId);
    this.title = title;
    this.subtitle = subtitle;
    this.description = description;
    this.groups = groups;
  }
}

/** Persisted per-series enrollment and last active chapter pointer. */
export class StorySeriesEnrollment {
  readonly seriesId: string;
  readonly enrolled: boolean;
  readonly currentEntryId: string;
  readonly enrolledAt: number;
  readonly updatedAt: number;

  constructor(
    seriesId: string,
    enrolled: boolean,
    currentEntryId: string,
    enrolledAt: number,
    updatedAt: number
  ) {
    this.seriesId = seriesId;
    this.enrolled = enrolled;
    this.currentEntryId = normalizeSeriesPageId(currentEntryId);
    this.enrolledAt = enrolledAt;
    this.updatedAt = updatedAt;
  }
}

/** Narrow persistence port for story series enrollment; SQLite lives in data/. */
export interface StorySeriesRepository {
  listEnrollments(): Promise<StorySeriesEnrollment[]>;
  saveEnrollment(enrollment: StorySeriesEnrollment): Promise<StorySeriesEnrollment>;
  removeEnrollment(seriesId: string): Promise<void>;
}

/** Derived series summary combined with permanent reading completion state. */
export class StorySeriesProgressSnapshot {
  readonly series: StorySeriesDefinition;
  readonly enrolled: boolean;
  readonly currentEntryId: string;
  readonly mainlineTotal: number;
  readonly mainlineCompleted: number;
  readonly totalEntries: number;
  readonly totalCompleted: number;
  readonly resumeEntry: StorySeriesEntry | undefined;
  readonly updatedAt: number;

  constructor(
    series: StorySeriesDefinition,
    enrolled: boolean,
    currentEntryId: string,
    mainlineTotal: number,
    mainlineCompleted: number,
    totalEntries: number,
    totalCompleted: number,
    resumeEntry: StorySeriesEntry | undefined,
    updatedAt: number
  ) {
    this.series = series;
    this.enrolled = enrolled;
    this.currentEntryId = currentEntryId;
    this.mainlineTotal = mainlineTotal;
    this.mainlineCompleted = mainlineCompleted;
    this.totalEntries = totalEntries;
    this.totalCompleted = totalCompleted;
    this.resumeEntry = resumeEntry;
    this.updatedAt = updatedAt;
  }
}

/** Article-level series context used on the hub page and member chapters. */
export class StorySeriesArticleContext {
  readonly seriesId: string;
  readonly hubId: string;
  readonly seriesTitle: string;
  readonly seriesSubtitle: string;
  readonly isHubPage: boolean;
  readonly enrolled: boolean;
  readonly currentEntry: StorySeriesEntry | undefined;
  readonly previousEntry: StorySeriesEntry | undefined;
  readonly nextEntry: StorySeriesEntry | undefined;
  readonly resumeEntry: StorySeriesEntry | undefined;
  readonly currentGroupTitle: string;
  readonly currentGroupIndex: number;
  readonly currentGroupTotal: number;
  readonly mainlineCompleted: number;
  readonly mainlineTotal: number;
  readonly totalCompleted: number;
  readonly totalEntries: number;
  readonly groups: StorySeriesGroup[];

  constructor(
    seriesId: string,
    hubId: string,
    seriesTitle: string,
    seriesSubtitle: string,
    isHubPage: boolean,
    enrolled: boolean,
    currentEntry: StorySeriesEntry | undefined,
    previousEntry: StorySeriesEntry | undefined,
    nextEntry: StorySeriesEntry | undefined,
    resumeEntry: StorySeriesEntry | undefined,
    currentGroupTitle: string,
    currentGroupIndex: number,
    currentGroupTotal: number,
    mainlineCompleted: number,
    mainlineTotal: number,
    totalCompleted: number,
    totalEntries: number,
    groups: StorySeriesGroup[]
  ) {
    this.seriesId = seriesId;
    this.hubId = hubId;
    this.seriesTitle = seriesTitle;
    this.seriesSubtitle = seriesSubtitle;
    this.isHubPage = isHubPage;
    this.enrolled = enrolled;
    this.currentEntry = currentEntry;
    this.previousEntry = previousEntry;
    this.nextEntry = nextEntry;
    this.resumeEntry = resumeEntry;
    this.currentGroupTitle = currentGroupTitle;
    this.currentGroupIndex = currentGroupIndex;
    this.currentGroupTotal = currentGroupTotal;
    this.mainlineCompleted = mainlineCompleted;
    this.mainlineTotal = mainlineTotal;
    this.totalCompleted = totalCompleted;
    this.totalEntries = totalEntries;
    this.groups = groups;
  }
}

interface RawSeriesEntrySeed {
  id: string;
  title: string;
  author?: string;
  note?: string;
}

interface RawSeriesGroupSeed {
  id: string;
  title: string;
  subtitle: string;
  tier: StorySeriesTier;
  entries: RawSeriesEntrySeed[];
}

export const ANTIMEMETICS_SERIES_ID: string = 'antimemetics-division';
export const ANTIMEMETICS_HUB_ID: string = 'antimemetics-division-hub';

function buildGroup(seed: RawSeriesGroupSeed, startOrder: number): StorySeriesGroup {
  const entries: StorySeriesEntry[] = [];
  for (let index = 0; index < seed.entries.length; index++) {
    const item = seed.entries[index];
    entries.push(new StorySeriesEntry(
      item.id,
      item.title,
      seed.id,
      seed.title,
      seed.tier,
      startOrder + index,
      item.author ?? '',
      item.note ?? ''
    ));
  }
  return new StorySeriesGroup(seed.id, seed.title, seed.subtitle, seed.tier, entries);
}

function buildGroups(seeds: RawSeriesGroupSeed[]): StorySeriesGroup[] {
  const groups: StorySeriesGroup[] = [];
  let order = 0;
  for (let index = 0; index < seeds.length; index++) {
    const group = buildGroup(seeds[index], order);
    order += group.entries.length;
    groups.push(group);
  }
  return groups;
}

const ANTIMEMETICS_GROUPS: StorySeriesGroup[] = buildGroups([
  {
    id: 'core-background',
    title: '核心背景读物',
    subtitle: '推荐阅读顺序从上到下，从 055 起步',
    tier: StorySeriesTier.MAINLINE,
    entries: [
      { id: 'scp-055', title: 'SCP-055', author: 'qntm & CptBellman' }
    ]
  },
  {
    id: 'there-is-no-antimemetics-division',
    title: '这里没有逆模因部',
    subtitle: '主线第一部 · qntm 著',
    tier: StorySeriesTier.MAINLINE,
    entries: [
      { id: 'we-need-to-talk-about-fifty-five', title: '谈谈055', author: 'qntm' },
      { id: 'introductory-antimemetics', title: '逆模因学入门', author: 'qntm' },
      { id: 'unforgettable-that-s-what-you-are', title: '难忘的你', author: 'qntm' },
      { id: 'case-colourless-green', title: '无色之绿事件', author: 'qntm' },
      { id: 'your-last-first-day', title: '你最后一个第一天', author: 'qntm' }
    ]
  },
  {
    id: 'intermission',
    title: '幕间休息',
    subtitle: '在阅读《五-五-五-五-五》前观看',
    tier: StorySeriesTier.MAINLINE,
    entries: [
      { id: 'scp-2256', title: 'SCP-2256', author: 'qntm' }
    ]
  },
  {
    id: 'five-five-five-five-five',
    title: '五-五-五-五-五',
    subtitle: '主线第二部 · qntm 著',
    tier: StorySeriesTier.MAINLINE,
    entries: [
      { id: 'scp-3125', title: 'SCP-3125', author: 'qntm', note: '含交互密码锁，可切换原版网页体验' },
      { id: 'where-have-you-been-all-my-life', title: '我一生里，你在何处', author: 'qntm' },
      { id: 'fresh-hell', title: '活地狱', author: 'qntm' },
      { id: 'ojai', title: '奥哈伊', author: 'qntm' },
      { id: 'immemorial', title: '忘念碑', author: 'qntm' },
      { id: 'case-hate-red', title: '憎恨之红事件', author: 'qntm' },
      { id: 'ara-orun', title: 'Ará Orún', author: 'qntm' },
      { id: 'unthreaded', title: '了无牵挂', author: 'qntm' },
      { id: 'the-wild-light', title: '狂光', author: 'qntm' },
      { id: 'blood-brain', title: '血/脑', author: 'qntm' },
      { id: 'tombstone', title: '墓碑', author: 'qntm' },
      { id: 'champions-of-nothing', title: '尾声：胜冠徒然', author: 'qntm' }
    ]
  },
  {
    id: 'what-the-dead-know',
    title: '逝者所知',
    subtitle: '支线故事 · 发生于《这里没有逆模因部》期间及之后 · sirpudding 著',
    tier: StorySeriesTier.SIDE,
    entries: [
      { id: 'scp-2111', title: 'SCP-2111', author: 'sirpudding' },
      { id: 'in-the-trenches-with-the-dead', title: '与亡者共战', author: 'sirpudding' },
      { id: 'a-thin-dangerous-line', title: '生死一息间', author: 'sirpudding' }
    ]
  },
  {
    id: 'for-reference',
    title: '以供参阅',
    subtitle: '时间线与人物参考',
    tier: StorySeriesTier.EXTENDED,
    entries: [
      { id: 'antimemetics-division-timeline', title: '逆模因部系列时间线' }
    ]
  },
  {
    id: 'precursors',
    title: '先驱创作',
    subtitle: '早期逆模因概念代表作品',
    tier: StorySeriesTier.EXTENDED,
    entries: [
      { id: 'scp-033', title: 'SCP-033', author: 'Mulciber' },
      { id: 'revenants', title: '归来者', author: 'Photosynthetic' },
      { id: 'scp-1425', title: 'SCP-1425', author: 'Silberescher' },
      { id: 'scp-2828', title: 'SCP-2828', author: 'ooblex' },
      { id: 'scp-2358', title: 'SCP-2358', author: 'HotCocoaNerd' }
    ]
  },
  {
    id: 'further-reading',
    title: '进一步阅读',
    subtitle: '主站延伸阅读与跨系列关联',
    tier: StorySeriesTier.EXTENDED,
    entries: [
      { id: 'scp-scp-033', title: 'SCP-SCP-033', author: 'HotCocoaNerd' },
      { id: 'numbers-lie', title: '数字会说谎', author: 'CityToast' },
      { id: 'scp-3393', title: 'SCP-3393', author: 'Captain Kirby' },
      { id: 'scp-3211', title: 'SCP-3211', author: 'Croquembouche' },
      { id: 'scp-4773', title: 'SCP-4773', author: 'MaliceAforethought & Henzoid' },
      { id: 'note-your-name-is-nobody', title: '速记：你的名字是“Nobody”', author: 'Iapetus The Acausal' }
    ]
  },
  {
    id: 'cn-related',
    title: '中国分部原创的相关故事',
    subtitle: '中文分部逆模因部相关原创',
    tier: StorySeriesTier.EXTENDED,
    entries: [
      { id: 'memory-maze', title: '记忆迷宫', author: 'Holy_Darklight' },
      { id: 'tell-you-tales', title: '说个故事吧', author: 'MScarlet' },
      { id: 'diary', title: '不，这不是你第一天上班。还有：记得写日记', author: 'ONXY' },
      { id: 'rainy-stars-with-the-thunderstorm', title: '霆霓飘霖，星陨如雨', author: 'Simon Arran' },
      { id: 'antimeme-guide', title: '简单易懂的逆模因识别指南（节选）', author: 'UnnaHuz' },
      { id: 'antimemetic-speech', title: 'ONXY的逆模因讲座：认识，假设与对抗', author: 'ONXY' },
      { id: 'who-is-the-knife-who-is-the-fish', title: '谁为刀俎，谁为鱼肉？', author: 'ONXY' },
      { id: 'black-hairs-black-eyes', title: '黑发，黑眸', author: 'ONXY' },
      { id: 'through-calamity', title: '跨越末日', author: 'UnnaHuz' },
      { id: 'train', title: '失忆症', author: 'bye jack' },
      { id: 'going-downward-and-pasting-through-translation', title: '螺旋而下，迭代前行', author: 'ONXY' },
      { id: 'the-spirit-is-shining-among-us', title: '有黄金从裂缝中渗出', author: 'ONXY' },
      { id: 'wandering-ghost', title: '游魂', author: 'honghuanglan' },
      { id: 'arememnber', title: '也许你能铭记一切，但你仍不能战胜遗忘', author: 'R_Yukikaze' },
      { id: 'endro-reversi', title: '勇者与魔王', author: 'UnnaHuz' },
      { id: 'for-forgotten-memories', title: '东方忘却碑 ～ For Forgotten Memories.', author: 'ForJD' },
      { id: 'the-self-help-guide-of-antimemetics-division', title: '逆模因部自救指南', author: 'TRhine' },
      { id: 'therefore-the-red-flood-arose', title: '熄梦之网', author: 'highlightingman' },
      { id: 'nimoyinburenzhenshicanhhh', title: '于逆模因囹圄之下', author: 'TRhine' },
      { id: 'anon-unknown-nobody', title: '无人知晓千早爱音', author: 'highlightingman' },
      { id: 'scp-cn-3215', title: 'SCP-CN-3215 - 虚构扩大器', author: 'ZIMIAO' },
      { id: 'locked-room-mystery', title: '个人梦盒站点：「无隙困室」事件（23.1.17留档）', author: 'TRhine' },
      { id: 'unknown-and-rana', title: '乐奈救赎乌有之人', author: 'highlightingman' },
      { id: 'the-wind-up-bird-chihaya-anon-i', title: '深红色的拧发条鸟', author: 'highlightingman' },
      { id: 'gharfa-ruh', title: '如是点燃千早爱音', author: 'highlightingman' },
      { id: 'welcome-to-vanguard-threshold-must-die', title: '惊天秘密！为什么你应该成为现实扭曲者或逆模因', author: 'SisterTan_Greasy' }
    ]
  }
]);

export const ANTIMEMETICS_DIVISION_SERIES: StorySeriesDefinition = new StorySeriesDefinition(
  ANTIMEMETICS_SERIES_ID,
  ANTIMEMETICS_HUB_ID,
  '逆模因部',
  '从 SCP-055 起步 · 按中心页顺序',
  '围绕未知与被抹除记忆展开的经典系列：先从核心档案 SCP-055 起步，经《这里没有逆模因部》与 SCP-2256，直面《五-五-五-五-五》主线与《逝者所知》支线。',
  ANTIMEMETICS_GROUPS
);

const BUILT_IN_SERIES: StorySeriesDefinition[] = [
  ANTIMEMETICS_DIVISION_SERIES
];

export function normalizeSeriesPageId(raw: string): string {
  let cleaned = raw.trim().toLowerCase();
  const hashIndex = cleaned.indexOf('#');
  if (hashIndex >= 0) {
    cleaned = cleaned.substring(0, hashIndex);
  }
  const queryIndex = cleaned.indexOf('?');
  if (queryIndex >= 0) {
    cleaned = cleaned.substring(0, queryIndex);
  }
  cleaned = cleaned.replace(/^https?:\/\/scp-wiki(?:-cn)?\.wikidot\.com/i, '');
  while (cleaned.startsWith('/')) {
    cleaned = cleaned.substring(1);
  }
  while (cleaned.endsWith('/')) {
    cleaned = cleaned.substring(0, cleaned.length - 1);
  }
  return cleaned;
}

export function listBuiltInStorySeries(): StorySeriesDefinition[] {
  return BUILT_IN_SERIES;
}

export function findStorySeriesById(seriesId: string): StorySeriesDefinition | undefined {
  const normalized = normalizeSeriesPageId(seriesId);
  for (let index = 0; index < BUILT_IN_SERIES.length; index++) {
    if (BUILT_IN_SERIES[index].id === normalized) {
      return BUILT_IN_SERIES[index];
    }
  }
  return undefined;
}

export function findStorySeriesByHubId(hubId: string): StorySeriesDefinition | undefined {
  const normalized = normalizeSeriesPageId(hubId);
  for (let index = 0; index < BUILT_IN_SERIES.length; index++) {
    if (BUILT_IN_SERIES[index].hubId === normalized) {
      return BUILT_IN_SERIES[index];
    }
  }
  return undefined;
}

export function findStorySeriesByMemberId(entryId: string): StorySeriesDefinition[] {
  const normalized = normalizeSeriesPageId(entryId);
  if (normalized.length === 0) {
    return [];
  }
  const matched: StorySeriesDefinition[] = [];
  for (let index = 0; index < BUILT_IN_SERIES.length; index++) {
    const series = BUILT_IN_SERIES[index];
    if (containsSeriesEntry(series, normalized)) {
      matched.push(series);
    }
  }
  return matched;
}

export function flattenSeriesEntries(series: StorySeriesDefinition): StorySeriesEntry[] {
  const all: StorySeriesEntry[] = [];
  for (let g = 0; g < series.groups.length; g++) {
    const entries = series.groups[g].entries;
    for (let e = 0; e < entries.length; e++) {
      all.push(entries[e]);
    }
  }
  return all;
}

export function containsSeriesEntry(series: StorySeriesDefinition, entryId: string): boolean {
  const normalized = normalizeSeriesPageId(entryId);
  if (normalized.length === 0) {
    return false;
  }
  for (let g = 0; g < series.groups.length; g++) {
    const entries = series.groups[g].entries;
    for (let e = 0; e < entries.length; e++) {
      if (entries[e].id === normalized) {
        return true;
      }
    }
  }
  return false;
}

export function listMainlineSeriesEntries(series: StorySeriesDefinition): StorySeriesEntry[] {
  const mainline: StorySeriesEntry[] = [];
  for (let g = 0; g < series.groups.length; g++) {
    const group = series.groups[g];
    if (group.tier !== StorySeriesTier.MAINLINE) {
      continue;
    }
    for (let e = 0; e < group.entries.length; e++) {
      mainline.push(group.entries[e]);
    }
  }
  return mainline;
}

export function countSeriesProgress(
  series: StorySeriesDefinition,
  isCompleted: (entryId: string) => boolean
): [number, number, number, number] {
  let mainlineTotal = 0;
  let mainlineCompleted = 0;
  let totalEntries = 0;
  let totalCompleted = 0;
  for (let g = 0; g < series.groups.length; g++) {
    const group = series.groups[g];
    for (let e = 0; e < group.entries.length; e++) {
      const entry = group.entries[e];
      const done = isCompleted(entry.id);
      totalEntries++;
      if (done) {
        totalCompleted++;
      }
      if (group.tier === StorySeriesTier.MAINLINE) {
        mainlineTotal++;
        if (done) {
          mainlineCompleted++;
        }
      }
    }
  }
  return [mainlineCompleted, mainlineTotal, totalCompleted, totalEntries];
}

/**
 * Determine which entry the reader should open next for a series.
 * Respects enrolled `currentEntryId` if still unread; if completed, advances
 * smoothly to the next unread chapter along Wiki reading order.
 */
export function resolveSeriesResumeEntry(
  series: StorySeriesDefinition,
  enrollment: StorySeriesEnrollment | undefined,
  isCompleted: (entryId: string) => boolean
): StorySeriesEntry | undefined {
  const all = flattenSeriesEntries(series);
  if (all.length === 0) {
    return undefined;
  }
  const mainline = listMainlineSeriesEntries(series);
  const currentId = enrollment !== undefined ? normalizeSeriesPageId(enrollment.currentEntryId) : '';
  if (currentId.length > 0) {
    const currentIndex = indexOfEntryId(all, currentId);
    if (currentIndex >= 0) {
      const currentEntry = all[currentIndex];
      if (!isCompleted(currentEntry.id)) {
        return currentEntry;
      }
      if (currentEntry.tier === StorySeriesTier.MAINLINE) {
        const mainlineIdx = indexOfEntryId(mainline, currentEntry.id);
        for (let i = mainlineIdx + 1; i < mainline.length; i++) {
          if (!isCompleted(mainline[i].id)) {
            return mainline[i];
          }
        }
      } else {
        const group = findGroupById(series, currentEntry.groupId);
        if (group !== undefined) {
          const inGroupIdx = indexOfEntryId(group.entries, currentEntry.id);
          for (let i = inGroupIdx + 1; i < group.entries.length; i++) {
            if (!isCompleted(group.entries[i].id)) {
              return group.entries[i];
            }
          }
        }
      }
      for (let i = 0; i < mainline.length; i++) {
        if (!isCompleted(mainline[i].id)) {
          return mainline[i];
        }
      }
      return currentEntry;
    }
  }
  for (let i = 0; i < mainline.length; i++) {
    if (!isCompleted(mainline[i].id)) {
      return mainline[i];
    }
  }
  return mainline.length > 0 ? mainline[0] : all[0];
}

export function buildStorySeriesArticleContext(
  series: StorySeriesDefinition,
  articleId: string,
  enrollment: StorySeriesEnrollment | undefined,
  isCompleted: (entryId: string) => boolean
): StorySeriesArticleContext {
  const normalizedId = normalizeSeriesPageId(articleId);
  const counts = countSeriesProgress(series, isCompleted);
  const resumeEntry = resolveSeriesResumeEntry(series, enrollment, isCompleted);
  const enrolled = enrollment !== undefined && enrollment.enrolled;
  if (normalizedId === series.hubId) {
    return new StorySeriesArticleContext(
      series.id,
      series.hubId,
      series.title,
      series.subtitle,
      true,
      enrolled,
      undefined,
      undefined,
      resumeEntry,
      resumeEntry,
      '',
      0,
      0,
      counts[0],
      counts[1],
      counts[2],
      counts[3],
      series.groups
    );
  }

  let matchedGroup: StorySeriesGroup | undefined = undefined;
  let matchedEntry: StorySeriesEntry | undefined = undefined;
  let groupIndex = 0;
  for (let g = 0; g < series.groups.length; g++) {
    const group = series.groups[g];
    for (let e = 0; e < group.entries.length; e++) {
      if (group.entries[e].id === normalizedId) {
        matchedGroup = group;
        matchedEntry = group.entries[e];
        groupIndex = e + 1;
        break;
      }
    }
    if (matchedEntry !== undefined) {
      break;
    }
  }

  let previousEntry: StorySeriesEntry | undefined = undefined;
  let nextEntry: StorySeriesEntry | undefined = undefined;
  if (matchedEntry !== undefined && matchedGroup !== undefined) {
    const sequence = matchedEntry.tier === StorySeriesTier.MAINLINE ?
      listMainlineSeriesEntries(series) : matchedGroup.entries;
    const seqIdx = indexOfEntryId(sequence, matchedEntry.id);
    if (seqIdx > 0) {
      previousEntry = sequence[seqIdx - 1];
    }
    if (seqIdx >= 0 && seqIdx + 1 < sequence.length) {
      nextEntry = sequence[seqIdx + 1];
    }
  }

  return new StorySeriesArticleContext(
    series.id,
    series.hubId,
    series.title,
    series.subtitle,
    false,
    enrolled,
    matchedEntry,
    previousEntry,
    nextEntry,
    resumeEntry,
    matchedGroup !== undefined ? matchedGroup.title : '',
    groupIndex,
    matchedGroup !== undefined ? matchedGroup.entries.length : 0,
    counts[0],
    counts[1],
    counts[2],
    counts[3],
    series.groups
  );
}

/**
 * Pure parser for Wiki hub HTML pages (`<h2>` headings + `<ul><li>` chapter links).
 * Picks only the primary work link per list item and excludes author, tag, and offset links.
 */
export function parseStorySeriesGroupsFromHubHtml(html: string): StorySeriesGroup[] {
  const contentMatch = /<div\s+id=["']page-content["'][^>]*>([\s\S]*?)<div\s+class=["']page-tags["']/i.exec(html);
  const body = contentMatch !== null ? contentMatch[1] : html;
  const headingMatches: RegExpExecArray[] = [];
  const headingRegex = /<h2[^>]*>([\s\S]*?)<\/h2>/gi;
  let hMatch: RegExpExecArray | null = headingRegex.exec(body);
  while (hMatch !== null) {
    headingMatches.push(hMatch);
    hMatch = headingRegex.exec(body);
  }
  if (headingMatches.length === 0) {
    return [];
  }

  const parsedGroups: StorySeriesGroup[] = [];
  let runningOrder = 0;
  for (let index = 0; index < headingMatches.length; index++) {
    const current = headingMatches[index];
    const startOffset = current.index + current[0].length;
    const endOffset = index + 1 < headingMatches.length ?
      headingMatches[index + 1].index : body.length;
    const rawHeading = decodeBasicHtmlEntities(stripHtmlTags(current[1])).trim();
    const cleanedTitle = cleanHubHeadingTitle(rawHeading);
    if (cleanedTitle.length === 0) {
      continue;
    }
    const segment = body.substring(startOffset, endOffset);
    const tier = classifyHubHeadingTier(cleanedTitle);
    const groupId = `group-${index}`;
    const entries: StorySeriesEntry[] = [];
    const seenIds: Set<string> = new Set<string>();
    const liRegex = /<li[^>]*>([\s\S]*?)<\/li>/gi;
    let liMatch: RegExpExecArray | null = liRegex.exec(segment);
    while (liMatch !== null) {
      const parsedEntry = extractPrimaryEntryFromListItem(
        liMatch[1],
        groupId,
        cleanedTitle,
        tier,
        runningOrder + entries.length
      );
      if (parsedEntry !== undefined && !seenIds.has(parsedEntry.id)) {
        seenIds.add(parsedEntry.id);
        entries.push(parsedEntry);
      }
      liMatch = liRegex.exec(segment);
    }
    if (entries.length > 0) {
      runningOrder += entries.length;
      parsedGroups.push(new StorySeriesGroup(groupId, cleanedTitle, '', tier, entries));
    }
  }
  return parsedGroups;
}

function extractPrimaryEntryFromListItem(
  liHtml: string,
  groupId: string,
  groupTitle: string,
  tier: StorySeriesTier,
  orderIndex: number
): StorySeriesEntry | undefined {
  const linkRegex = /<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
  let linkMatch: RegExpExecArray | null = linkRegex.exec(liHtml);
  while (linkMatch !== null) {
    const rawHref = linkMatch[1].trim();
    const workId = normalizeInternalHubWorkHref(rawHref);
    if (workId.length > 0 && !isNonWorkSeriesSlug(workId)) {
      const linkTitle = decodeBasicHtmlEntities(stripHtmlTags(linkMatch[2])).trim();
      return new StorySeriesEntry(
        workId,
        linkTitle.length > 0 ? linkTitle : workId,
        groupId,
        groupTitle,
        tier,
        orderIndex
      );
    }
    linkMatch = linkRegex.exec(liHtml);
  }
  return undefined;
}

function normalizeInternalHubWorkHref(rawHref: string): string {
  const lower = rawHref.trim().toLowerCase();
  if (lower.length === 0 || lower.startsWith('#') || lower.startsWith('javascript:')) {
    return '';
  }
  if (/^https?:\/\//i.test(lower) &&
    !/^https?:\/\/scp-wiki(?:-cn)?\.wikidot\.com\//i.test(lower)) {
    return '';
  }
  const normalized = normalizeSeriesPageId(lower);
  if (normalized.length === 0 || normalized.indexOf('/') >= 0 || normalized.indexOf(':') >= 0) {
    return '';
  }
  return normalized;
}

function isNonWorkSeriesSlug(slug: string): boolean {
  return slug.endsWith('-author-page') ||
    slug.endsWith('-personnel-file') ||
    slug.endsWith('-personal-file') ||
    slug.endsWith('-author-ght');
}

function classifyHubHeadingTier(title: string): StorySeriesTier {
  if (title.indexOf('逝者所知') >= 0 || title.indexOf('支线') >= 0) {
    return StorySeriesTier.SIDE;
  }
  if (title.indexOf('参阅') >= 0 || title.indexOf('先驱') >= 0 ||
    title.indexOf('进一步') >= 0 || title.indexOf('延伸') >= 0 ||
    title.indexOf('中国分部') >= 0 || title.indexOf('原创') >= 0) {
    return StorySeriesTier.EXTENDED;
  }
  return StorySeriesTier.MAINLINE;
}

function cleanHubHeadingTitle(raw: string): string {
  return raw
    .replace(/\s+(?:qntm|sirpudding)\s*著$/i, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function stripHtmlTags(html: string): string {
  return html.replace(/<[^>]+>/g, '');
}

function decodeBasicHtmlEntities(text: string): string {
  return text
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, '\'')
    .replace(/&nbsp;/g, ' ')
    .replace(/&#8211;|&ndash;/g, '–')
    .replace(/&#8212;|&mdash;/g, '—');
}

function indexOfEntryId(entries: StorySeriesEntry[], entryId: string): number {
  for (let index = 0; index < entries.length; index++) {
    if (entries[index].id === entryId) {
      return index;
    }
  }
  return -1;
}

function findGroupById(series: StorySeriesDefinition, groupId: string): StorySeriesGroup | undefined {
  for (let index = 0; index < series.groups.length; index++) {
    if (series.groups[index].id === groupId) {
      return series.groups[index];
    }
  }
  return undefined;
}
