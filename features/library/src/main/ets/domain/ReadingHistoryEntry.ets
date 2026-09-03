import { LibraryContentRef } from './LibraryContentRef';

/** 最近阅读是导航记录而非永久审计日志，限制体量以维持终端首帧稳定。 */
export const READING_HISTORY_LIMIT: number = 500;

/**
 * 一条阅读历史快照。
 *
 * `openedAt` 记录内容首次进入资料库的时间，`lastReadAt` 用于最近阅读排序；
 * 进度变化通过创建新快照并整体替换列表发布，不在原对象上原地修改。
 */
export class ReadingHistoryEntry {
  readonly content: LibraryContentRef;
  readonly openedAt: number;
  readonly lastReadAt: number;
  readonly scrollOffset: number;
  /** Explicit user annotation; independent from scroll progress. */
  readonly completed: boolean;

  constructor(
    content: LibraryContentRef,
    openedAt: number,
    lastReadAt: number,
    scrollOffset: number,
    completed: boolean = false
  ) {
    this.content = content;
    this.openedAt = openedAt;
    this.lastReadAt = lastReadAt;
    this.scrollOffset = normalizeReadingScrollOffset(scrollOffset);
    this.completed = completed === true;
  }
}

/** 数据库存储使用非负整数滚动位置，过滤布局切换时可能产生的无效值。 */
export function normalizeReadingScrollOffset(offset: number): number {
  if (!Number.isFinite(offset) || offset <= 0) {
    return 0;
  }
  return Math.floor(offset);
}
