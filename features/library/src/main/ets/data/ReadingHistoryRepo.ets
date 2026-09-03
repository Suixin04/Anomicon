import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { ArkTSUtils } from '@kit.ArkTS';
import { ANOMICON_DATABASE_NAME } from 'anomiconbasic';
import {
  LibraryContentKind,
  LibraryContentRef,
  parseLibraryContentKind,
  preferLibraryContentMetadata
} from '../domain/LibraryContentRef';
import {
  READING_HISTORY_LIMIT,
  ReadingHistoryEntry,
  normalizeReadingScrollOffset
} from '../domain/ReadingHistoryEntry';
import { ReadingHistoryRepository } from '../domain/LibraryRepositories';

const TABLE_NAME: string = 'library_reading_history';
const CREATE_TABLE: string =
  'CREATE TABLE IF NOT EXISTS library_reading_history (' +
  'content_key TEXT PRIMARY KEY, content_id TEXT NOT NULL, title TEXT NOT NULL, ' +
  'content_kind TEXT NOT NULL, opened_at INTEGER NOT NULL, ' +
  'last_read_at INTEGER NOT NULL, scroll_offset INTEGER NOT NULL, ' +
  'completed INTEGER NOT NULL DEFAULT 0)';
const ADD_COMPLETED_COLUMN: string =
  'ALTER TABLE library_reading_history ADD COLUMN completed INTEGER NOT NULL DEFAULT 0';
const CREATE_TIME_INDEX: string =
  'CREATE INDEX IF NOT EXISTS idx_library_reading_history_time ' +
  'ON library_reading_history(last_read_at DESC, content_key ASC)';
const PRUNE_HISTORY: string =
  'DELETE FROM library_reading_history WHERE content_key NOT IN (' +
  'SELECT content_key FROM library_reading_history ' +
  `ORDER BY last_read_at DESC, content_key ASC LIMIT ${READING_HISTORY_LIMIT})`;

/** 初始化迁移使用的数据库原始行；storedKey 可能仍是旧版 kind:id。 */
class StoredHistoryMigrationRow {
  readonly storedKey: string;
  readonly entry: ReadingHistoryEntry;

  constructor(storedKey: string, entry: ReadingHistoryEntry) {
    this.storedKey = storedKey;
    this.entry = entry;
  }
}

/**
 * 阅读历史持久化。
 *
 * 写操作由同一原生锁串行；再次打开内容时保留首次打开时间和已有滚动位置，
 * 只刷新内容元数据与最后阅读时间。
 */
export class ReadingHistoryRepo implements ReadingHistoryRepository {
  private readonly context: common.UIAbilityContext;
  private store: relationalStore.RdbStore | undefined = undefined;
  private initialization: Promise<void> | undefined = undefined;
  private readonly operationLock: ArkTSUtils.locks.AsyncLock =
    new ArkTSUtils.locks.AsyncLock();

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  /** Opens the feature-owned store; repeated calls share one task. */
  public initialize(): Promise<void> {
    if (this.initialization !== undefined) {
      return this.initialization;
    }
    this.initialization = this.open(this.context);
    return this.initialization;
  }

  /** 按最后阅读时间倒序读取稳定快照。 */
  async list(): Promise<ReadingHistoryEntry[]> {
    return this.operationLock.lockAsync<ReadingHistoryEntry[]>(
      (): Promise<ReadingHistoryEntry[]> => this.listNow(),
      ArkTSUtils.locks.AsyncLockMode.SHARED
    );
  }

  /**
   * 记录一次进入文章：新内容从零进度开始，已有内容绝不覆盖其阅读进度。
   */
  async recordOpened(content: LibraryContentRef): Promise<ReadingHistoryEntry> {
    let updated: ReadingHistoryEntry | undefined = undefined;
    await this.enqueueMutation(async (): Promise<void> => {
      const existing = await this.findNow(content.key);
      const now = Date.now();
      const openedAt = existing === undefined ? now : existing.openedAt;
      const scrollOffset = existing === undefined ? 0 : existing.scrollOffset;
      const resolvedContent = preferLibraryContentMetadata(content, existing?.content);
      const entry = new ReadingHistoryEntry(
        resolvedContent, openedAt, now, scrollOffset, existing?.completed ?? false
      );
      await this.putNow(entry);
      if (existing === undefined) {
        await this.pruneNow();
      }
      updated = entry;
    });
    return updated!;
  }

  /** 更新进度；尚无历史时同时创建记录。 */
  async updateProgress(content: LibraryContentRef, offset: number): Promise<ReadingHistoryEntry> {
    let updated: ReadingHistoryEntry | undefined = undefined;
    await this.enqueueMutation(async (): Promise<void> => {
      const existing = await this.findNow(content.key);
      const now = Date.now();
      const openedAt = existing === undefined ? now : existing.openedAt;
      const resolvedContent = preferLibraryContentMetadata(content, existing?.content);
      const entry = new ReadingHistoryEntry(
        resolvedContent,
        openedAt,
        now,
        normalizeReadingScrollOffset(offset),
        existing?.completed ?? false
      );
      await this.putNow(entry);
      if (existing === undefined) {
        await this.pruneNow();
      }
      updated = entry;
    });
    return updated!;
  }

  async setCompleted(content: LibraryContentRef, completed: boolean): Promise<ReadingHistoryEntry> {
    let updated: ReadingHistoryEntry | undefined = undefined;
    await this.enqueueMutation(async (): Promise<void> => {
      const existing = await this.findNow(content.key);
      const now = Date.now();
      const openedAt = existing === undefined ? now : existing.openedAt;
      const resolvedContent = preferLibraryContentMetadata(content, existing?.content);
      const entry = new ReadingHistoryEntry(
        resolvedContent,
        openedAt,
        now,
        existing?.scrollOffset ?? 0,
        completed === true
      );
      await this.putNow(entry);
      if (existing === undefined) {
        await this.pruneNow();
      }
      updated = entry;
    });
    return updated!;
  }

  /** 旧记录名称补全不能伪造一次新的浏览，因此完整保留三个时间/进度字段。 */
  async updateMetadata(content: LibraryContentRef): Promise<ReadingHistoryEntry | undefined> {
    let updated: ReadingHistoryEntry | undefined = undefined;
    await this.enqueueMutation(async (): Promise<void> => {
      const existing = await this.findNow(content.key);
      if (existing === undefined) {
        return;
      }
      const resolvedContent = preferLibraryContentMetadata(content, existing.content);
      if (resolvedContent.title === existing.content.title &&
        resolvedContent.kind === existing.content.kind) {
        updated = existing;
        return;
      }
      const entry = new ReadingHistoryEntry(
        resolvedContent,
        existing.openedAt,
        existing.lastReadAt,
        existing.scrollOffset,
        existing.completed
      );
      await this.putNow(entry);
      updated = entry;
    });
    return updated;
  }

  private async listNow(): Promise<ReadingHistoryEntry[]> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.orderByDesc('last_read_at');
    predicates.orderByAsc('content_key');
    predicates.limitAs(READING_HISTORY_LIMIT);
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    const entries: ReadingHistoryEntry[] = [];
    try {
      resultSet = await store.query(predicates, [
        'content_id',
        'title',
        'content_kind',
        'opened_at',
        'last_read_at',
        'scroll_offset',
        'completed'
      ]);
      while (resultSet.goToNextRow()) {
        const entry = this.entryFromResultSet(resultSet);
        if (entry !== undefined) {
          entries.push(entry);
        }
      }
      return entries;
    } catch (error) {
      throw this.historyError('读取', error);
    } finally {
      this.closeResultSet(resultSet, 'list');
    }
  }

  private async findNow(contentKey: string): Promise<ReadingHistoryEntry | undefined> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('content_key', contentKey);
    predicates.limitAs(1);
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await store.query(predicates, [
        'content_id',
        'title',
        'content_kind',
        'opened_at',
        'last_read_at',
        'scroll_offset',
        'completed'
      ]);
      if (!resultSet.goToFirstRow()) {
        return undefined;
      }
      return this.entryFromResultSet(resultSet);
    } catch (error) {
      throw this.historyError('查询', error);
    } finally {
      this.closeResultSet(resultSet, 'lookup');
    }
  }

  private entryFromResultSet(resultSet: relationalStore.ResultSet): ReadingHistoryEntry | undefined {
    try {
      const kindValue = resultSet.getString(resultSet.getColumnIndex('content_kind'));
      const kind = parseLibraryContentKind(kindValue);
      if (kind === undefined) {
        return undefined;
      }
      const content = new LibraryContentRef(
        kind,
        resultSet.getString(resultSet.getColumnIndex('content_id')),
        resultSet.getString(resultSet.getColumnIndex('title'))
      );
      return new ReadingHistoryEntry(
        content,
        resultSet.getLong(resultSet.getColumnIndex('opened_at')),
        resultSet.getLong(resultSet.getColumnIndex('last_read_at')),
        resultSet.getLong(resultSet.getColumnIndex('scroll_offset')),
        resultSet.getLong(resultSet.getColumnIndex('completed')) > 0
      );
    } catch (error) {
      // 单条历史脏数据不应阻断其他记录展示；再次打开时会重建该条记录。
      return undefined;
    }
  }

  private async putNow(entry: ReadingHistoryEntry): Promise<void> {
    const store = await this.requireStore();
    const values: relationalStore.ValuesBucket = {
      'content_key': entry.content.key,
      'content_id': entry.content.id,
      'title': entry.content.title,
      'content_kind': entry.content.kind,
      'opened_at': entry.openedAt,
      'last_read_at': entry.lastReadAt,
      'scroll_offset': entry.scrollOffset,
      'completed': entry.completed ? 1 : 0
    };
    try {
      const rowId = await store.insert(
        TABLE_NAME,
        values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
      if (rowId < 0) {
        throw new Error(`写入阅读记录失败：${entry.content.key}`);
      }
    } catch (error) {
      throw this.historyError('写入', error);
    }
  }

  /** 仅在新增记录时维护最近记录上限；已有记录的进度更新不会重复扫描历史表。 */
  private async pruneNow(): Promise<void> {
    const store = await this.requireStore();
    try {
      await store.executeSql(PRUNE_HISTORY);
    } catch (error) {
      // 核心阅读记录已经成功写入；清理失败只影响空间维护，不伪装成保存失败。
      console.warn(
        `Prune reading history failed: ${error instanceof Error ? error.message : 'unknown error'}`
      );
    }
  }

  private enqueueMutation(operation: () => Promise<void>): Promise<void> {
    return this.operationLock.lockAsync<void>(
      operation,
      ArkTSUtils.locks.AsyncLockMode.EXCLUSIVE
    );
  }

  private async open(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await relationalStore.getRdbStore(context, {
        name: ANOMICON_DATABASE_NAME,
        securityLevel: relationalStore.SecurityLevel.S1,
        encrypt: false
      });
      await store.executeSql(CREATE_TABLE);
      // Existing installs predate the completion annotation.  Duplicate
      // column errors mean the migration already ran and are safe to ignore.
      try {
        await store.executeSql(ADD_COMPLETED_COLUMN);
      } catch (error) {
        const message = error instanceof Error ? error.message.toLowerCase() : '';
        if (message.indexOf('duplicate') < 0 && message.indexOf('exists') < 0) {
          console.warn(`Reading history completion migration skipped: ${message}`);
        }
      }
      await store.executeSql(CREATE_TIME_INDEX);
      // Complete the canonical-key migration before the repository becomes
      // visible to ViewModels.  Callers therefore never observe a mixed key
      // format during the lifetime of this repository.
      await this.migrateLegacyContentKeys(store);
      this.store = store;
    } catch (error) {
      this.initialization = undefined;
      throw this.historyError('初始化', error);
    }
  }

  /**
   * 把旧版 kind:slug 历史合并为主站 main:slug。合并保留最早首次打开时间，
   * 最近一次阅读的时间、元数据与滚动位置；先写新行后删旧行，异常中断可重试。
   */
  private async migrateLegacyContentKeys(store: relationalStore.RdbStore): Promise<void> {
    const rows = await this.readHistoryMigrationRows(store);
    const mergedRows: StoredHistoryMigrationRow[] = [];
    const mergedIndexes: Map<string, number> = new Map<string, number>();
    const migrationRows: StoredHistoryMigrationRow[] = [];

    for (let index = 0; index < rows.length; index++) {
      const row = rows[index];
      const canonicalKey = row.entry.content.key;
      const mergedIndex = mergedIndexes.get(canonicalKey);
      if (mergedIndex === undefined) {
        mergedIndexes.set(canonicalKey, mergedRows.length);
        mergedRows.push(row);
      } else {
        mergedRows[mergedIndex] = this.mergeHistoryMigrationRows(mergedRows[mergedIndex], row);
      }
      if (row.storedKey !== canonicalKey) {
        migrationRows.push(row);
      }
    }
    if (migrationRows.length === 0) {
      return;
    }

    try {
      for (let index = 0; index < mergedRows.length; index++) {
        await this.putMigrationRow(store, mergedRows[index].entry);
      }
      for (let index = 0; index < migrationRows.length; index++) {
        const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
        predicates.equalTo('content_key', migrationRows[index].storedKey);
        const deleted = await store.delete(predicates);
        if (deleted < 0) {
          throw new Error(`删除旧阅读主键失败：${migrationRows[index].storedKey}`);
        }
      }
    } catch (error) {
      throw this.historyError('主键迁移', error);
    }
  }

  private async readHistoryMigrationRows(
    store: relationalStore.RdbStore
  ): Promise<StoredHistoryMigrationRow[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    const rows: StoredHistoryMigrationRow[] = [];
    try {
      resultSet = await store.query(predicates, [
        'content_key',
        'content_id',
        'title',
        'content_kind',
        'opened_at',
        'last_read_at',
        'scroll_offset',
        'completed'
      ]);
      while (resultSet.goToNextRow()) {
        const kindValue = resultSet.getString(resultSet.getColumnIndex('content_kind'));
        const kind: LibraryContentKind | undefined = parseLibraryContentKind(kindValue);
        if (kind === undefined) {
          continue;
        }
        try {
          const content = new LibraryContentRef(
            kind,
            resultSet.getString(resultSet.getColumnIndex('content_id')),
            resultSet.getString(resultSet.getColumnIndex('title'))
          );
          rows.push(new StoredHistoryMigrationRow(
            resultSet.getString(resultSet.getColumnIndex('content_key')),
            new ReadingHistoryEntry(
              content,
              resultSet.getLong(resultSet.getColumnIndex('opened_at')),
              resultSet.getLong(resultSet.getColumnIndex('last_read_at')),
              resultSet.getLong(resultSet.getColumnIndex('scroll_offset')),
              resultSet.getLong(resultSet.getColumnIndex('completed')) > 0
            )
          ));
        } catch (error) {
          // 无法规范化的脏行原样保留，避免迁移造成不可逆删除。
        }
      }
      return rows;
    } catch (error) {
      throw this.historyError('迁移读取', error);
    } finally {
      this.closeResultSet(resultSet, 'Migration');
    }
  }

  private mergeHistoryMigrationRows(
    current: StoredHistoryMigrationRow,
    candidate: StoredHistoryMigrationRow
  ): StoredHistoryMigrationRow {
    const latest = this.preferHistoryMigrationRow(current, candidate) ? candidate : current;
    const fallback = latest === current ? candidate : current;
    const mergedContent = preferLibraryContentMetadata(
      latest.entry.content,
      fallback.entry.content
    );
    return new StoredHistoryMigrationRow(
      latest.storedKey,
      new ReadingHistoryEntry(
        mergedContent,
        Math.min(current.entry.openedAt, candidate.entry.openedAt),
        Math.max(current.entry.lastReadAt, candidate.entry.lastReadAt),
        latest.entry.scrollOffset,
        latest.entry.completed || fallback.entry.completed
      )
    );
  }

  private preferHistoryMigrationRow(
    current: StoredHistoryMigrationRow,
    candidate: StoredHistoryMigrationRow
  ): boolean {
    if (candidate.entry.lastReadAt !== current.entry.lastReadAt) {
      return candidate.entry.lastReadAt > current.entry.lastReadAt;
    }
    const currentCanonical = current.storedKey === current.entry.content.key;
    const candidateCanonical = candidate.storedKey === candidate.entry.content.key;
    if (currentCanonical !== candidateCanonical) {
      return candidateCanonical;
    }
    return candidate.storedKey.localeCompare(current.storedKey) < 0;
  }

  private async putMigrationRow(
    store: relationalStore.RdbStore,
    entry: ReadingHistoryEntry
  ): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      'content_key': entry.content.key,
      'content_id': entry.content.id,
      'title': entry.content.title,
      'content_kind': entry.content.kind,
      'opened_at': entry.openedAt,
      'last_read_at': entry.lastReadAt,
      'scroll_offset': entry.scrollOffset,
      'completed': entry.completed ? 1 : 0
    };
    try {
      const rowId = await store.insert(
        TABLE_NAME,
        values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
      if (rowId < 0) {
        throw new Error(`写入统一阅读主键失败：${entry.content.key}`);
      }
    } catch (error) {
      throw this.historyError('迁移写入', error);
    }
  }

  private async requireStore(): Promise<relationalStore.RdbStore> {
    await this.initialize();
    if (this.store === undefined) {
      throw new Error('阅读历史存储尚未初始化');
    }
    return this.store;
  }

  private closeResultSet(resultSet: relationalStore.ResultSet | undefined, operation: string): void {
    try {
      resultSet?.close();
    } catch (error) {
      console.warn(
        `Close reading history ${operation} result set failed: ` +
        `${error instanceof Error ? error.message : 'unknown error'}`
      );
    }
  }

  private historyError(operation: string, error: Object): Error {
    const message = error instanceof Error ? error.message : '未知数据库错误';
    return new Error(`阅读历史${operation}失败：${message}`);
  }
}
