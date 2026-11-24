import { LibraryContentRef } from './LibraryContentRef';

export const RESEARCH_MINUTE_MS: number = 60 * 1000;
export const RESEARCH_DAILY_CAP_MINUTES: number = 180;
export const RESEARCH_DAILY_CAP_MS: number = RESEARCH_DAILY_CAP_MINUTES * RESEARCH_MINUTE_MS;
export const RESEARCHED_CONTENT_MIN_MS: number = RESEARCH_MINUTE_MS;
export const RESEARCHED_CONTENT_REWARD: number = 8;
export const RESEARCH_MAX_LEVEL: number = 50;
/** 旧账本未记录起始时区；值刻意放在合法 UTC 偏移范围之外。 */
export const RESEARCH_TIME_ZONE_OFFSET_UNSET: number = 1441;

const RESEARCH_DAY_MS: number = 24 * 60 * RESEARCH_MINUTE_MS;
const MAX_SAFE_INTEGER_VALUE: number = 9007199254740991;
const MAX_TIME_ZONE_OFFSET_MINUTES: number = 14 * 60;

export enum ResearchSessionState {
  OPEN = 'open',
  FINALIZED = 'finalized',
  INTERRUPTED = 'interrupted'
}

export enum ResearchRankTitle {
  VISITOR = '见习档案员',
  RETRIEVER = '档案助理',
  READER = '档案员',
  CATALOGER = '高级档案员',
  RESEARCHER = '档案编审',
  ARCHIVIST = '首席档案编审'
}

/** 开始一次 provisional 阅读段所需的稳定值。 */
export class ResearchActivityStart {
  readonly segmentId: string;
  readonly content: LibraryContentRef;
  readonly startedAt: number;
  readonly lastOffset: number;
  readonly updatedAt: number;
  readonly checkpointSequence: number;
  readonly startTimeZoneOffsetMinutes: number;

  constructor(
    segmentId: string,
    content: LibraryContentRef,
    startedAt: number,
    lastOffset: number = 0,
    updatedAt: number = startedAt,
    checkpointSequence: number = 0,
    startTimeZoneOffsetMinutes: number = RESEARCH_TIME_ZONE_OFFSET_UNSET
  ) {
    this.segmentId = normalizeResearchSegmentId(segmentId);
    this.content = content;
    this.startedAt = normalizeResearchTimestamp(startedAt);
    this.lastOffset = normalizeResearchOffset(lastOffset);
    this.updatedAt = Math.max(this.startedAt, normalizeResearchTimestamp(updatedAt));
    this.checkpointSequence = normalizeResearchCheckpointSequence(checkpointSequence);
    this.startTimeZoneOffsetMinutes = normalizeResearchStartTimeZoneOffset(
      startTimeZoneOffsetMinutes
    );
  }
}

/** checkpoint 中的 activeMs 是单调时钟累计总值，而不是本次增量。 */
export class ResearchActivityCheckpoint {
  readonly segmentId: string;
  readonly activeMs: number;
  readonly lastOffset: number;
  readonly updatedAt: number;
  readonly checkpointSequence: number;

  constructor(
    segmentId: string,
    activeMs: number,
    lastOffset: number,
    updatedAt: number,
    checkpointSequence: number = 0
  ) {
    this.segmentId = normalizeResearchSegmentId(segmentId);
    this.activeMs = normalizeResearchDuration(activeMs);
    this.lastOffset = normalizeResearchOffset(lastOffset);
    this.updatedAt = normalizeResearchTimestamp(updatedAt);
    this.checkpointSequence = normalizeResearchCheckpointSequence(checkpointSequence);
  }
}

/** 正常结束阅读段；异常进程退出由数据库恢复流程标记为 interrupted。 */
export class ResearchActivityFinish {
  readonly segmentId: string;
  readonly endedAt: number;
  readonly activeMs: number;
  readonly lastOffset: number;
  readonly endReason: string;
  readonly updatedAt: number;
  readonly checkpointSequence: number;

  constructor(
    segmentId: string,
    endedAt: number,
    activeMs: number,
    lastOffset: number,
    endReason: string,
    updatedAt: number = endedAt,
    checkpointSequence: number = 0
  ) {
    this.segmentId = normalizeResearchSegmentId(segmentId);
    this.endedAt = normalizeResearchTimestamp(endedAt);
    this.activeMs = normalizeResearchDuration(activeMs);
    this.lastOffset = normalizeResearchOffset(lastOffset);
    this.endReason = normalizeResearchEndReason(endReason, 'completed');
    this.updatedAt = normalizeResearchTimestamp(updatedAt);
    this.checkpointSequence = normalizeResearchCheckpointSequence(checkpointSequence);
  }
}

/** RDB 中一条活动账本记录；经验和等级永不写回此记录。 */
export class ResearchActivitySegment {
  readonly segmentId: string;
  readonly content: LibraryContentRef;
  readonly startedAt: number;
  readonly endedAt: number;
  readonly activeMs: number;
  readonly lastOffset: number;
  readonly state: ResearchSessionState;
  readonly endReason: string;
  readonly updatedAt: number;
  readonly checkpointSequence: number;
  readonly startTimeZoneOffsetMinutes: number;

  constructor(
    segmentId: string,
    content: LibraryContentRef,
    startedAt: number,
    endedAt: number,
    activeMs: number,
    lastOffset: number,
    state: ResearchSessionState,
    endReason: string,
    updatedAt: number,
    checkpointSequence: number = 0,
    startTimeZoneOffsetMinutes: number = RESEARCH_TIME_ZONE_OFFSET_UNSET
  ) {
    const normalizedStartedAt = normalizeResearchTimestamp(startedAt);
    const normalizedUpdatedAt = Math.max(
      normalizedStartedAt,
      normalizeResearchTimestamp(updatedAt)
    );
    this.segmentId = normalizeResearchSegmentId(segmentId);
    this.content = content;
    this.startedAt = normalizedStartedAt;
    this.activeMs = normalizeResearchDuration(activeMs);
    this.lastOffset = normalizeResearchOffset(lastOffset);
    this.state = state;
    this.checkpointSequence = normalizeResearchCheckpointSequence(checkpointSequence);
    this.startTimeZoneOffsetMinutes = normalizeResearchStartTimeZoneOffset(
      startTimeZoneOffsetMinutes
    );
    if (state === ResearchSessionState.OPEN) {
      this.endedAt = 0;
      this.endReason = '';
      this.updatedAt = normalizedUpdatedAt;
    } else {
      this.endedAt = Math.max(normalizedStartedAt, normalizeResearchTimestamp(endedAt));
      this.endReason = normalizeResearchEndReason(
        endReason,
        state === ResearchSessionState.INTERRUPTED ? 'interrupted' : 'completed'
      );
      this.updatedAt = Math.max(normalizedUpdatedAt, this.endedAt);
    }
  }
}

/** 一条账本记录跨本地自然日切分后的原始片段。 */
export class ResearchDaySlice {
  readonly segmentId: string;
  readonly content: LibraryContentRef;
  /** 与时区无关的民用日期键：localDayIndex * 24h。 */
  readonly dayKey: number;
  readonly startedAt: number;
  readonly endedAt: number;
  readonly activeMs: number;

  constructor(
    segmentId: string,
    content: LibraryContentRef,
    dayKey: number,
    startedAt: number,
    endedAt: number,
    activeMs: number
  ) {
    this.segmentId = segmentId;
    this.content = content;
    this.dayKey = dayKey;
    this.startedAt = startedAt;
    this.endedAt = endedAt;
    this.activeMs = normalizeResearchDuration(activeMs);
  }
}

/** 应用每日额度后真正可用于经验与研读判定的片段。 */
export class CreditedResearchSlice {
  readonly segmentId: string;
  readonly content: LibraryContentRef;
  readonly dayKey: number;
  readonly startedAt: number;
  readonly endedAt: number;
  readonly activeMs: number;

  constructor(slice: ResearchDaySlice, activeMs: number) {
    this.segmentId = slice.segmentId;
    this.content = slice.content;
    this.dayKey = slice.dayKey;
    this.startedAt = slice.startedAt;
    this.endedAt = slice.endedAt;
    this.activeMs = normalizeResearchDuration(activeMs);
  }
}

export class ResearchDailyProgress {
  readonly dayKey: number;
  readonly activeMs: number;

  constructor(dayKey: number, activeMs: number) {
    this.dayKey = dayKey;
    this.activeMs = normalizeResearchDuration(activeMs);
  }
}

export class ResearchContentProgress {
  readonly content: LibraryContentRef;
  readonly activeMs: number;
  readonly researched: boolean;

  constructor(content: LibraryContentRef, activeMs: number) {
    this.content = content;
    this.activeMs = normalizeResearchDuration(activeMs);
    this.researched = this.activeMs >= RESEARCHED_CONTENT_MIN_MS;
  }
}

/** 完全由活动账本派生的资料员画像；它不是第二份持久化真相。 */
export class ResearchProgress {
  readonly rawActiveMs: number;
  readonly creditedActiveMs: number;
  readonly todayActiveMs: number;
  readonly researchedContentCount: number;
  readonly experience: number;
  readonly level: number;
  readonly rankTitle: ResearchRankTitle;
  readonly levelThreshold: number;
  readonly nextLevelThreshold: number;
  readonly levelExperience: number;
  readonly levelExperienceTarget: number;
  readonly daily: ResearchDailyProgress[];
  readonly contents: ResearchContentProgress[];

  constructor(
    rawActiveMs: number,
    creditedActiveMs: number,
    todayActiveMs: number,
    researchedContentCount: number,
    experience: number,
    daily: ResearchDailyProgress[],
    contents: ResearchContentProgress[]
  ) {
    this.rawActiveMs = normalizeResearchDuration(rawActiveMs);
    this.creditedActiveMs = normalizeResearchDuration(creditedActiveMs);
    this.todayActiveMs = normalizeResearchDuration(todayActiveMs);
    this.researchedContentCount = normalizeResearchDuration(researchedContentCount);
    this.experience = normalizeResearchDuration(experience);
    this.level = researchLevelForExperience(this.experience);
    this.rankTitle = researchRankTitleForLevel(this.level);
    this.levelThreshold = researchExperienceThreshold(this.level);
    this.nextLevelThreshold = this.level >= RESEARCH_MAX_LEVEL ?
      this.levelThreshold : researchExperienceThreshold(this.level + 1);
    this.levelExperience = this.experience - this.levelThreshold;
    this.levelExperienceTarget = this.level >= RESEARCH_MAX_LEVEL ?
      0 : this.nextLevelThreshold - this.levelThreshold;
    this.daily = daily;
    this.contents = contents;
  }
}

class ResearchContentAccumulator {
  readonly content: LibraryContentRef;
  activeMs: number;

  constructor(content: LibraryContentRef, activeMs: number) {
    this.content = content;
    this.activeMs = activeMs;
  }
}

export function normalizeResearchDuration(value: number): number {
  if (!Number.isFinite(value) || value <= 0) {
    return 0;
  }
  return Math.min(MAX_SAFE_INTEGER_VALUE, Math.floor(value));
}

export function normalizeResearchOffset(value: number): number {
  return normalizeResearchDuration(value);
}

export function normalizeResearchTimestamp(value: number): number {
  return normalizeResearchDuration(value);
}

export function normalizeResearchCheckpointSequence(value: number): number {
  return normalizeResearchDuration(value);
}

/** offset 约定为“本地时间减 UTC”的分钟数，例如中国标准时间为 +480。 */
export function normalizeResearchTimeZoneOffset(value: number): number {
  if (!Number.isFinite(value)) {
    return 0;
  }
  const integer = value < 0 ? Math.ceil(value) : Math.floor(value);
  return Math.max(-MAX_TIME_ZONE_OFFSET_MINUTES, Math.min(MAX_TIME_ZONE_OFFSET_MINUTES, integer));
}

/** 起始时区允许保留“旧数据未记录”哨兵，其余值归一化到合法 UTC 偏移。 */
export function normalizeResearchStartTimeZoneOffset(value: number): number {
  if (!Number.isFinite(value) || value === RESEARCH_TIME_ZONE_OFFSET_UNSET) {
    return RESEARCH_TIME_ZONE_OFFSET_UNSET;
  }
  return normalizeResearchTimeZoneOffset(value);
}

export function normalizeResearchSegmentId(value: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new Error('研读片段标识不能为空');
  }
  return normalized;
}

export function normalizeResearchEndReason(value: string, fallback: string): string {
  const normalized = value.trim();
  return (normalized.length > 0 ? normalized : fallback).slice(0, 128);
}

export function parseResearchSessionState(value: string): ResearchSessionState | undefined {
  switch (value) {
    case ResearchSessionState.OPEN:
      return ResearchSessionState.OPEN;
    case ResearchSessionState.FINALIZED:
      return ResearchSessionState.FINALIZED;
    case ResearchSessionState.INTERRUPTED:
      return ResearchSessionState.INTERRUPTED;
    default:
      return undefined;
  }
}

/** open 行只承认最后一次 checkpoint 的 updatedAt，不根据当前墙钟补算。 */
export function effectiveResearchSegmentEndAt(segment: ResearchActivitySegment): number {
  if (segment.state === ResearchSessionState.OPEN) {
    return Math.max(segment.startedAt, segment.updatedAt);
  }
  return Math.max(segment.startedAt, segment.endedAt);
}

/**
 * checkpoint 合并保持单调：activeMs 永不回退；只有严格递增的持久化序列
 * 才能替换滚动位置和 checkpoint 墙钟元数据，墙钟回拨不参与新旧判定。
 */
export function checkpointResearchSegment(
  existing: ResearchActivitySegment,
  checkpoint: ResearchActivityCheckpoint
): ResearchActivitySegment {
  assertMatchingResearchSegment(existing.segmentId, checkpoint.segmentId);
  if (existing.state !== ResearchSessionState.OPEN) {
    return existing;
  }
  const acceptsCheckpoint = checkpoint.checkpointSequence > existing.checkpointSequence;
  return new ResearchActivitySegment(
    existing.segmentId,
    existing.content,
    existing.startedAt,
    0,
    Math.max(existing.activeMs, checkpoint.activeMs),
    acceptsCheckpoint ? checkpoint.lastOffset : existing.lastOffset,
    ResearchSessionState.OPEN,
    '',
    acceptsCheckpoint ? checkpoint.updatedAt : existing.updatedAt,
    Math.max(existing.checkpointSequence, checkpoint.checkpointSequence),
    existing.startTimeZoneOffsetMinutes
  );
}

export function finalizeResearchSegment(
  existing: ResearchActivitySegment,
  finish: ResearchActivityFinish
): ResearchActivitySegment {
  assertMatchingResearchSegment(existing.segmentId, finish.segmentId);
  if (existing.state !== ResearchSessionState.OPEN) {
    return existing;
  }
  const acceptsCheckpoint = finish.checkpointSequence > existing.checkpointSequence;
  const endedAt = acceptsCheckpoint ?
    Math.max(existing.startedAt, finish.endedAt) :
    Math.max(existing.startedAt, existing.updatedAt, finish.endedAt);
  return new ResearchActivitySegment(
    existing.segmentId,
    existing.content,
    existing.startedAt,
    endedAt,
    Math.max(existing.activeMs, finish.activeMs),
    acceptsCheckpoint ? finish.lastOffset : existing.lastOffset,
    ResearchSessionState.FINALIZED,
    finish.endReason,
    acceptsCheckpoint ? finish.updatedAt : existing.updatedAt,
    Math.max(existing.checkpointSequence, finish.checkpointSequence),
    existing.startTimeZoneOffsetMinutes
  );
}

/** interrupted 仅封存最后 checkpoint，不增加一毫秒。 */
export function interruptResearchSegment(
  existing: ResearchActivitySegment,
  endReason: string
): ResearchActivitySegment {
  if (existing.state !== ResearchSessionState.OPEN) {
    return existing;
  }
  return new ResearchActivitySegment(
    existing.segmentId,
    existing.content,
    existing.startedAt,
    existing.updatedAt,
    existing.activeMs,
    existing.lastOffset,
    ResearchSessionState.INTERRUPTED,
    endReason,
    existing.updatedAt,
    existing.checkpointSequence,
    existing.startTimeZoneOffsetMinutes
  );
}

export function researchDayStartAt(timestamp: number, timeZoneOffsetMinutes: number): number {
  const offsetMs = normalizeResearchTimeZoneOffset(timeZoneOffsetMinutes) * RESEARCH_MINUTE_MS;
  return researchDayKeyAt(timestamp, timeZoneOffsetMinutes) - offsetMs;
}

/**
 * 将时间映射到 YYYY-MM-DD 等价的稳定键。相同民用日期即使 UTC 偏移不同，
 * 也会得到相同的键；该键只用于额度、daily 与 today 聚合，不是绝对时间戳。
 */
export function researchDayKeyAt(timestamp: number, timeZoneOffsetMinutes: number): number {
  const normalizedTimestamp = normalizeResearchTimestamp(timestamp);
  const offsetMs = normalizeResearchTimeZoneOffset(timeZoneOffsetMinutes) * RESEARCH_MINUTE_MS;
  const localDayIndex = Math.floor((normalizedTimestamp + offsetMs) / RESEARCH_DAY_MS);
  return localDayIndex * RESEARCH_DAY_MS;
}

/**
 * 按墙钟跨度把已经由单调时钟确认的 activeMs 比例切到各自然日。
 * 墙钟回拨或零跨度时不猜测，将全部可信时长归到开始日。
 */
export function splitResearchSegmentByDay(
  segment: ResearchActivitySegment,
  timeZoneOffsetMinutes: number
): ResearchDaySlice[] {
  const activeMs = normalizeResearchDuration(segment.activeMs);
  if (activeMs === 0) {
    return [];
  }
  const startedAt = segment.startedAt;
  const endedAt = effectiveResearchSegmentEndAt(segment);
  const segmentTimeZoneOffset = segment.startTimeZoneOffsetMinutes ===
    RESEARCH_TIME_ZONE_OFFSET_UNSET ?
    normalizeResearchTimeZoneOffset(timeZoneOffsetMinutes) :
    segment.startTimeZoneOffsetMinutes;
  const startDayKey = researchDayKeyAt(startedAt, segmentTimeZoneOffset);
  if (endedAt <= startedAt) {
    return [new ResearchDaySlice(
      segment.segmentId,
      segment.content,
      startDayKey,
      startedAt,
      endedAt,
      activeMs
    )];
  }

  const wallSpan = endedAt - startedAt;
  const slices: ResearchDaySlice[] = [];
  let cursor = startedAt;
  let allocated = 0;
  while (cursor < endedAt) {
    const dayKey = researchDayKeyAt(cursor, segmentTimeZoneOffset);
    const localDayStartAt = researchDayStartAt(cursor, segmentTimeZoneOffset);
    const nextDayStartAt = localDayStartAt + RESEARCH_DAY_MS;
    const sliceEndAt = Math.min(endedAt, nextDayStartAt);
    const isLast = sliceEndAt >= endedAt;
    const sliceActiveMs = isLast ? activeMs - allocated : Math.floor(
      activeMs * ((sliceEndAt - cursor) / wallSpan)
    );
    if (sliceActiveMs > 0) {
      slices.push(new ResearchDaySlice(
        segment.segmentId,
        segment.content,
        dayKey,
        cursor,
        sliceEndAt,
        sliceActiveMs
      ));
      allocated += sliceActiveMs;
    }
    cursor = sliceEndAt;
  }
  return slices;
}

/** 每日额度按片段发生顺序消耗；超出额度的时长不再产生分钟或内容奖励。 */
export function creditResearchSegments(
  segments: ResearchActivitySegment[],
  timeZoneOffsetMinutes: number,
  dailyCapMs: number = RESEARCH_DAILY_CAP_MS
): CreditedResearchSlice[] {
  const cap = normalizeResearchDuration(dailyCapMs);
  if (cap === 0) {
    return [];
  }
  const slices: ResearchDaySlice[] = [];
  for (let index = 0; index < segments.length; index++) {
    const segmentSlices = splitResearchSegmentByDay(segments[index], timeZoneOffsetMinutes);
    for (let sliceIndex = 0; sliceIndex < segmentSlices.length; sliceIndex++) {
      slices.push(segmentSlices[sliceIndex]);
    }
  }
  slices.sort((left: ResearchDaySlice, right: ResearchDaySlice): number => {
    if (left.dayKey !== right.dayKey) {
      return left.dayKey - right.dayKey;
    }
    if (left.startedAt !== right.startedAt) {
      return left.startedAt - right.startedAt;
    }
    return left.segmentId.localeCompare(right.segmentId);
  });

  const usedByDay: Map<number, number> = new Map<number, number>();
  const credited: CreditedResearchSlice[] = [];
  for (let index = 0; index < slices.length; index++) {
    const slice = slices[index];
    const used = usedByDay.get(slice.dayKey) ?? 0;
    const remaining = Math.max(0, cap - used);
    const activeMs = Math.min(slice.activeMs, remaining);
    if (activeMs > 0) {
      credited.push(new CreditedResearchSlice(slice, activeMs));
      usedByDay.set(slice.dayKey, used + activeMs);
    }
  }
  return credited;
}

export function researchExperienceThreshold(level: number): number {
  const normalizedLevel = normalizeResearchLevel(level);
  return 8 * (normalizedLevel - 1) * (normalizedLevel - 1);
}

export function researchLevelForExperience(experience: number): number {
  const normalizedExperience = normalizeResearchDuration(experience);
  let level = 1;
  for (let candidate = 2; candidate <= RESEARCH_MAX_LEVEL; candidate++) {
    if (normalizedExperience < researchExperienceThreshold(candidate)) {
      break;
    }
    level = candidate;
  }
  return level;
}

export function researchRankTitleForLevel(level: number): ResearchRankTitle {
  const normalizedLevel = normalizeResearchLevel(level);
  if (normalizedLevel >= 50) {
    return ResearchRankTitle.ARCHIVIST;
  }
  if (normalizedLevel >= 35) {
    return ResearchRankTitle.RESEARCHER;
  }
  if (normalizedLevel >= 20) {
    return ResearchRankTitle.CATALOGER;
  }
  if (normalizedLevel >= 10) {
    return ResearchRankTitle.READER;
  }
  if (normalizedLevel >= 5) {
    return ResearchRankTitle.RETRIEVER;
  }
  return ResearchRankTitle.VISITOR;
}

export function deriveResearchProgress(
  segments: ResearchActivitySegment[],
  now: number,
  timeZoneOffsetMinutes: number
): ResearchProgress {
  let rawActiveMs = 0;
  for (let index = 0; index < segments.length; index++) {
    rawActiveMs += normalizeResearchDuration(segments[index].activeMs);
  }
  const credited = creditResearchSegments(segments, timeZoneOffsetMinutes);
  const dailyMap: Map<number, number> = new Map<number, number>();
  const contentMap: Map<string, ResearchContentAccumulator> =
    new Map<string, ResearchContentAccumulator>();
  let creditedActiveMs = 0;
  for (let index = 0; index < credited.length; index++) {
    const slice = credited[index];
    creditedActiveMs += slice.activeMs;
    dailyMap.set(slice.dayKey, (dailyMap.get(slice.dayKey) ?? 0) + slice.activeMs);
    const existing = contentMap.get(slice.content.key);
    if (existing === undefined) {
      contentMap.set(
        slice.content.key,
        new ResearchContentAccumulator(slice.content, slice.activeMs)
      );
    } else {
      existing.activeMs += slice.activeMs;
    }
  }

  const daily: ResearchDailyProgress[] = [];
  dailyMap.forEach((activeMs: number, dayKey: number): void => {
    daily.push(new ResearchDailyProgress(dayKey, activeMs));
  });
  daily.sort((left: ResearchDailyProgress, right: ResearchDailyProgress): number =>
    right.dayKey - left.dayKey
  );

  const contents: ResearchContentProgress[] = [];
  contentMap.forEach((accumulator: ResearchContentAccumulator): void => {
    contents.push(new ResearchContentProgress(accumulator.content, accumulator.activeMs));
  });
  contents.sort((left: ResearchContentProgress, right: ResearchContentProgress): number => {
    if (left.activeMs !== right.activeMs) {
      return right.activeMs - left.activeMs;
    }
    return left.content.key.localeCompare(right.content.key);
  });

  let researchedContentCount = 0;
  for (let index = 0; index < contents.length; index++) {
    if (contents[index].researched) {
      researchedContentCount++;
    }
  }
  const experience = Math.floor(creditedActiveMs / RESEARCH_MINUTE_MS) +
    researchedContentCount * RESEARCHED_CONTENT_REWARD;
  const todayKey = researchDayKeyAt(now, timeZoneOffsetMinutes);
  const todayActiveMs = dailyMap.get(todayKey) ?? 0;
  return new ResearchProgress(
    rawActiveMs,
    creditedActiveMs,
    todayActiveMs,
    researchedContentCount,
    experience,
    daily,
    contents
  );
}

export function emptyResearchProgress(
  now: number = 0,
  timeZoneOffsetMinutes: number = 0
): ResearchProgress {
  return deriveResearchProgress([], now, timeZoneOffsetMinutes);
}

function normalizeResearchLevel(level: number): number {
  if (!Number.isFinite(level)) {
    return 1;
  }
  const integer = Math.floor(level);
  return Math.max(1, Math.min(RESEARCH_MAX_LEVEL, integer));
}

function assertMatchingResearchSegment(existingId: string, requestedId: string): void {
  if (existingId !== requestedId) {
    throw new Error('研读片段标识不匹配');
  }
}
