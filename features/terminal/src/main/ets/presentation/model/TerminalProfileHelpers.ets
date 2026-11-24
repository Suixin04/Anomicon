import {
  RESEARCH_DAILY_CAP_MINUTES,
  ResearchDailyProgress,
  researchDayKeyAt
} from 'library';

const DAY_MS: number = 24 * 60 * 60 * 1000;
const MINUTE_MS: number = 60 * 1000;
const MIN_ACTIVITY_PEAK_MS: number = 20 * MINUTE_MS;
const WEEKDAY_LABELS: string[] = ['日', '一', '二', '三', '四', '五', '六'];

/** Compact presentation bar for one local civil day in the 7-day activity strip. */
export class DailyActivityBar {
  readonly key: string;
  readonly dayKey: number;
  readonly label: string;
  readonly activeMs: number;
  readonly minutes: number;
  readonly ratio: number;
  readonly isToday: boolean;

  constructor(
    dayKey: number,
    label: string,
    activeMs: number,
    minutes: number,
    ratio: number,
    isToday: boolean
  ) {
    // ForEach must update the bar when its height or today highlight changes.
    this.key = `day:${dayKey}:${ratio}:${isToday}`;
    this.dayKey = dayKey;
    this.label = label;
    this.activeMs = activeMs;
    this.minutes = minutes;
    this.ratio = ratio;
    this.isToday = isToday;
  }
}

function normalizePositiveDuration(value: number): number {
  if (!Number.isFinite(value) || value <= 0) {
    return 0;
  }
  return Math.floor(value);
}

function weekdayLabelForDayKey(dayKey: number): string {
  // 1970-01-01 (dayIndex = 0) was a Thursday (index 4 in Sunday-first labels).
  const dayIndex = Math.floor(dayKey / DAY_MS);
  const weekday = (((dayIndex % 7) + 7) + 4) % 7;
  return WEEKDAY_LABELS[weekday];
}

/** Builds the trailing seven civil days from the date-keyed ledger. */
export function buildRecentSevenDayActivity(
  daily: ResearchDailyProgress[],
  nowMs: number = Date.now(),
  timeZoneOffsetMinutes: number = -new Date(nowMs).getTimezoneOffset()
): DailyActivityBar[] {
  const todayKey = researchDayKeyAt(nowMs, timeZoneOffsetMinutes);
  const byDayKey: Map<number, number> = new Map<number, number>();
  for (let index: number = 0; index < daily.length; index++) {
    const entry = daily[index];
    const normalized = normalizePositiveDuration(entry.activeMs);
    if (normalized > 0) {
      byDayKey.set(entry.dayKey, Math.max(byDayKey.get(entry.dayKey) ?? 0, normalized));
    }
  }

  const windowDays: number[] = [];
  let maxMs: number = 0;
  for (let offset: number = 6; offset >= 0; offset--) {
    const dayKey = todayKey - offset * DAY_MS;
    const ms = byDayKey.get(dayKey) ?? 0;
    windowDays.push(ms);
    if (ms > maxMs) {
      maxMs = ms;
    }
  }

  const peakMs = Math.max(MIN_ACTIVITY_PEAK_MS, maxMs);
  const bars: DailyActivityBar[] = [];
  for (let index: number = 0; index < 7; index++) {
    const dayKey = todayKey - (6 - index) * DAY_MS;
    const activeMs = windowDays[index];
    const minutes = Math.floor(activeMs / MINUTE_MS);
    const ratio = activeMs <= 0 ? 0 : Math.max(0.22, Math.min(1, activeMs / peakMs));
    bars.push(new DailyActivityBar(
      dayKey,
      weekdayLabelForDayKey(dayKey),
      activeMs,
      minutes,
      ratio,
      index === 6
    ));
  }
  return bars;
}

/** Formats today's credited reading time against the daily XP quota. */
export function formatTodayQuotaLabel(
  todayActiveMs: number,
  dailyCapMinutes: number = RESEARCH_DAILY_CAP_MINUTES
): string {
  const normalizedMs = normalizePositiveDuration(todayActiveMs);
  const cap = Math.max(1, Math.floor(dailyCapMinutes));
  if (normalizedMs === 0) {
    return `0 / ${cap} 分钟`;
  }
  if (normalizedMs < MINUTE_MS) {
    return `< 1 / ${cap} 分钟`;
  }
  const minutes = Math.floor(normalizedMs / MINUTE_MS);
  return `${minutes} / ${cap} 分钟`;
}
