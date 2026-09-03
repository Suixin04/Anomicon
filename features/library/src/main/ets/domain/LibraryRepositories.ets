import { LibraryContentRef, LibraryFavorite } from './LibraryContentRef';
import { ReadingHistoryEntry } from './ReadingHistoryEntry';

/** 收藏数据端口。展示层只依赖这一组业务动作。 */
export interface FavoriteRepository {
  list(): Promise<LibraryFavorite[]>;
  toggle(content: LibraryContentRef): Promise<boolean>;
  setFavorite(content: LibraryContentRef, favorite: boolean): Promise<boolean>;
}

/** 阅读历史数据端口。数据库表、迁移与查询细节均位于 data 层。 */
export interface ReadingHistoryRepository {
  list(): Promise<ReadingHistoryEntry[]>;
  recordOpened(content: LibraryContentRef): Promise<ReadingHistoryEntry>;
  updateProgress(content: LibraryContentRef, offset: number): Promise<ReadingHistoryEntry>;
  /** Toggle the reader's explicit completed annotation. */
  setCompleted?(content: LibraryContentRef, completed: boolean): Promise<ReadingHistoryEntry>;
  /** 只补全标题/类型，不改变最近阅读时间、排序或滚动位置。 */
  updateMetadata(content: LibraryContentRef): Promise<ReadingHistoryEntry | undefined>;
}
