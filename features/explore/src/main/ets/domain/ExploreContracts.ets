import { LibraryContentKind } from 'library';
import { CACHE_FRESH_DURATION_MS } from 'anomiconbasic';

/** Shared freshness window for every Explore cache adapter. */
export const EXPLORE_FRESH_CACHE_DURATION: number = CACHE_FRESH_DURATION_MS;

/** Explore collection route mode; owned by the feature rather than navigation. */
export enum ExploreCollectionMode {
  RECENT = 'recent',
  JOKE = 'joke'
}

/** Explore index sources. Values are persisted as part of the cache key. */
export enum ExploreSource {
  TOP_RATED = 'top-rated',
  RECENT_TRANSLATED = 'recent-translated',
  RECENT_ORIGINAL = 'recent-original',
  JOKE_SCPS = 'joke-scps',
  JOKE_SCPS_CN = 'joke-scps-cn',
  JOKE_TALES = 'joke-tales'
}

/** 原始静态解析条目；只在 data/application 边界流动。 */
export interface ExploreRawEntry {
  url: string;
  title: string;
  score: string;
  date?: string;
  comments?: string;
}

/** 原始索引解析结果。 */
export interface ExplorePayload {
  ok: boolean;
  error: string;
  entries: ExploreRawEntry[];
}

/** 官网页面的来源，用来区分网络新鲜副本和过期回退。 */
export enum ExploreDataOrigin {
  NETWORK = 'network',
  FRESH_CACHE = 'fresh_cache',
  STALE_CACHE = 'stale_cache'
}

/** 解析后的业务条目。id 为去掉前导斜杠的主站路径名。 */
export class ExploreEntry {
  readonly id: string;
  readonly title: string;
  readonly score: number;
  readonly date: string;
  readonly comments: string;

  constructor(id: string, title: string, score: number, date: string = '', comments: string = '') {
    // The parser normally removes the site's leading slash, but cached or
    // injected domain values can reach this constructor directly.  Keep the
    // value-object invariant here so display de-duplication is stable for
    // both paths.
    let normalizedId = id.trim();
    while (normalizedId.startsWith('/')) {
      normalizedId = normalizedId.substring(1);
    }
    this.id = normalizedId;
    this.title = title;
    this.score = score;
    this.date = date;
    this.comments = comments;
  }
}

/** 探索索引的派生缓存快照。parsedAt 继承原始 HTML 的抓取时间。 */
export class ExploreStoredSnapshot {
  readonly json: string;
  readonly parsedAt: number;

  constructor(json: string, parsedAt: number) {
    this.json = json;
    this.parsedAt = parsedAt;
  }
}

/** 已完成来源语义校验的页面响应。 */
export class ExploreLoadedPayload {
  readonly payload: ExplorePayload;
  readonly origin: ExploreDataOrigin;
  readonly fetchedAt: number;

  constructor(
    payload: ExplorePayload,
    origin: ExploreDataOrigin,
    fetchedAt: number
  ) {
    this.payload = payload;
    this.origin = origin;
    this.fetchedAt = fetchedAt;
  }
}

/** 探索列表中用于展示/去重的不可变条目。 */
export class ExploreContentItem {
  readonly key: string;
  readonly entry: ExploreEntry;
  readonly kind: LibraryContentKind;
  readonly sourceLabel: string;
  readonly timestamp: number;

  constructor(
    entry: ExploreEntry,
    kind: LibraryContentKind,
    sourceLabel: string,
    timestamp: number = 0
  ) {
    this.entry = entry;
    this.kind = kind;
    this.sourceLabel = sourceLabel;
    this.timestamp = timestamp;
    // 展示去重身份必须保留入口分类；持久化身份由 LibraryContentRef 另行负责。
    this.key = `${kind}:${entry.id}`;
  }
}

/** 卡片预览值对象；不携带 ArkUI/Image 对象。 */
export class ExplorePreview {
  readonly path: string;
  readonly aspect: number;
  readonly description: string;
  readonly url: string;
  readonly fetchedAt: number;
  readonly stale: boolean;
  /** Non-empty when preview HTML/network resolution failed. */
  readonly error: string;
  readonly failed: boolean;

  constructor(
    path: string = '',
    aspect: number = 1,
    description: string = '',
    url: string = '',
    fetchedAt: number = 0,
    stale: boolean = false,
    error: string = ''
  ) {
    this.path = path;
    this.aspect = Number.isFinite(aspect) && aspect > 0 ? aspect : 1;
    this.description = description;
    this.url = url;
    this.fetchedAt = fetchedAt;
    this.stale = stale;
    this.error = error;
    this.failed = error.trim().length > 0;
  }
}

/** 推荐卡的轻量条目模型。 */
export class ExploreRecommendationEntry {
  readonly itemId: string;
  readonly title: string;

  constructor(itemId: string, title: string) {
    this.itemId = itemId;
    this.title = title;
  }
}

/** 推荐卡快照；预览通过 withPreview 形成新的不可变值。 */
export class ExploreRecommendation {
  readonly entry: ExploreRecommendationEntry;
  readonly preview: ExplorePreview;

  constructor(entry: ExploreRecommendationEntry, preview: ExplorePreview = new ExplorePreview()) {
    this.entry = entry;
    this.preview = preview;
  }

  withPreview(preview: ExplorePreview): ExploreRecommendation {
    return new ExploreRecommendation(this.entry, preview);
  }
}

/** 单一来源的 UI 无关快照。 */
export class ExploreSourceSnapshot {
  readonly entries: ExploreEntry[];
  readonly error: string;
  readonly origin: ExploreDataOrigin;
  readonly fetchedAt: number;
  readonly stale: boolean;
  readonly partial: boolean;

  constructor(
    entries: ExploreEntry[] = [],
    error: string = '',
    origin: ExploreDataOrigin = ExploreDataOrigin.NETWORK,
    fetchedAt: number = 0
  ) {
    this.entries = entries.slice();
    this.error = error;
    this.origin = origin;
    this.fetchedAt = fetchedAt;
    this.stale = origin === ExploreDataOrigin.STALE_CACHE;
    this.partial = entries.length > 0 && error.length > 0;
  }
}

/** 多来源合并后的 UI 无关快照。 */
export class ExploreCombinedSnapshot {
  readonly items: ExploreContentItem[];
  readonly error: string;
  readonly origin: ExploreDataOrigin;
  readonly fetchedAt: number;
  readonly stale: boolean;
  readonly partial: boolean;

  constructor(
    items: ExploreContentItem[] = [],
    error: string = '',
    origin: ExploreDataOrigin = ExploreDataOrigin.NETWORK,
    fetchedAt: number = 0
  ) {
    this.items = items.slice();
    this.error = error;
    this.origin = origin;
    this.fetchedAt = fetchedAt;
    this.stale = origin === ExploreDataOrigin.STALE_CACHE;
    this.partial = items.length > 0 && error.length > 0;
  }
}

/** Parse the raw payload into business entries, including score and URL normalization. */
export function exploreEntriesFromPayload(payload: ExplorePayload): ExploreEntry[] {
  const entries: ExploreEntry[] = [];
  for (let index = 0; index < payload.entries.length; index++) {
    const raw = payload.entries[index];
    const id = raw.url.startsWith('/') ? raw.url.substring(1) : raw.url;
    const parsedScore = raw.score.length > 0 ? Number(raw.score) : -1;
    const score = Number.isNaN(parsedScore) ? -1 : parsedScore;
    entries.push(new ExploreEntry(id, raw.title, score, raw.date ?? '', raw.comments ?? ''));
  }
  return entries;
}

/** 稳定的本地自然日键；供 jokes/recommendations 选择策略使用。 */
export function exploreDayKey(timestamp: number = Date.now()): string {
  const date = new Date(timestamp);
  const month = date.getMonth() + 1;
  const day = date.getDate();
  const monthText = month < 10 ? `0${month}` : `${month}`;
  const dayText = day < 10 ? `0${day}` : `${day}`;
  return `${date.getFullYear()}-${monthText}-${dayText}`;
}

/** Deterministic, non-random index selection that stays stable for a local day. */
export function selectExploreIndexes(
  total: number,
  count: number,
  salt: string,
  dayKey: string
): number[] {
  const target = Math.min(Math.max(0, count), Math.max(0, total));
  if (target === 0) {
    return [];
  }
  const seed = exploreHash(`${dayKey}:${salt}`);
  const start = seed % total;
  const step = total <= 1 ? 1 : (exploreHash(`${salt}:${dayKey}:step`) % (total - 1)) + 1;
  const indexes: number[] = [];
  const selected: Set<number> = new Set();
  for (let offset = 0; offset < total && indexes.length < target; offset++) {
    const index = (start + offset * step) % total;
    if (!selected.has(index)) {
      selected.add(index);
      indexes.push(index);
    }
  }
  for (let offset = 0; offset < total && indexes.length < target; offset++) {
    const index = (start + offset) % total;
    if (!selected.has(index)) {
      selected.add(index);
      indexes.push(index);
    }
  }
  return indexes;
}

function exploreHash(value: string): number {
  let result: number = 5381;
  for (let index = 0; index < value.length; index++) {
    result = ((result * 33) ^ value.charCodeAt(index)) >>> 0;
  }
  return result;
}
