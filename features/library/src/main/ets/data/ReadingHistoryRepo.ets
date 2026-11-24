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
  ReadingStateEntry
} from '../domain/ReadingHistoryEntry';
import { ReadingHistoryRepository } from '../domain/LibraryRepositories';
import {
  ReadingHistoryMutation,
  ReadingHistoryStorageAdapter,
  ReadingHistoryStoreEngine
} from './ReadingHistoryEngine';
import {
  ADD_HISTORY_COMPLETED_COLUMN,
  BACKFILL_STATE_FROM_HISTORY,
  CREATE_HISTORY_TABLE,
  CREATE_HISTORY_TIME_INDEX,
  CREATE_STATE_TABLE,
  CREATE_STATE_UPDATED_INDEX,
  HISTORY_TABLE_NAME,
  STATE_TABLE_NAME,
  buildPruneHistorySql
} from './ReadingHistorySchema';

/** 初始化迁移使用的数据库原始行；storedKey 可能仍是旧版 kind:id。 */
class StoredHistoryMigrationRow {
  readonly storedKey: string;
  readonly entry: ReadingHistoryEntry;

  constructor(storedKey: string, entry: ReadingHistoryEntry) {
    this.storedKey = storedKey;
    this.entry = entry;
  }
}

class RdbReadingHistoryStorage implements ReadingHistoryStorageAdapter {
  private readonly storeProvider: () => Promise<relationalStore.RdbStore>;

  constructor(storeProvider: () => Promise<relationalStore.RdbStore>) {
    this.storeProvider = storeProvider;
  }

  async listHistory(limit: number): Promise<ReadingHistoryEntry[]> {
    const store = await this.storeProvider();
    const predicates = new relationalStore.RdbPredicates(HISTORY_TABLE_NAME);
    predicates.orderByDesc('last_read_at');
    predicates.orderByAsc('content_key');
    predicates.limitAs(limit);
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
      throw historyError('读取', error);
    } finally {
      closeResultSet(resultSet, 'list');
    }
  }

  async findHistory(contentKey: string): Promise<ReadingHistoryEntry | undefined> {
    const store = await this.storeProvider();
    const predicates = new relationalStore.RdbPredicates(HISTORY_TABLE_NAME);
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
      throw historyError('查询', error);
    } finally {
      closeResultSet(resultSet, 'lookup');
    }
  }

  async listStates(): Promise<ReadingStateEntry[]> {
    const store = await this.storeProvider();
    const predicates = new relationalStore.RdbPredicates(STATE_TABLE_NAME);
    predicates.orderByDesc('updated_at');
    predicates.orderByAsc('content_key');
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    const states: ReadingStateEntry[] = [];
    try {
      resultSet = await store.query(predicates, [
        'content_id',
        'title',
        'content_kind',
        'scroll_offset',
        'completed',
        'completed_at',
        'updated_at'
      ]);
      while (resultSet.goToNextRow()) {
        const state = this.stateFromResultSet(resultSet);
        if (state !== undefined) {
          states.push(state);
        }
      }
      return states;
    } catch (error) {
      throw historyError('读取状态', error);
    } finally {
      closeResultSet(resultSet, 'listStates');
    }
  }

  async findState(contentKey: string): Promise<ReadingStateEntry | undefined> {
    const store = await this.storeProvider();
    const predicates = new relationalStore.RdbPredicates(STATE_TABLE_NAME);
    predicates.equalTo('content_key', contentKey);
    predicates.limitAs(1);
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await store.query(predicates, [
        'content_id',
        'title',
        'content_kind',
        'scroll_offset',
        'completed',
        'completed_at',
        'updated_at'
      ]);
      if (!resultSet.goToFirstRow()) {
        return undefined;
      }
      return this.stateFromResultSet(resultSet);
    } catch (error) {
      throw historyError('查询状态', error);
    } finally {
      closeResultSet(resultSet, 'findState');
    }
  }

  async commitMutation(mutation: ReadingHistoryMutation): Promise<void> {
    if (mutation.historyEntry === undefined &&
      mutation.stateEntry === undefined &&
      mutation.deleteStateKey === undefined) {
      return;
    }
    const store = await this.storeProvider();
    let transaction: relationalStore.Transaction;
    try {
      transaction = await store.createTransaction();
    } catch (error) {
      throw historyError('写入', error);
    }
    try {
      if (mutation.historyEntry !== undefined) {
        const rowId = await transaction.insert(
          HISTORY_TABLE_NAME,
          historyValuesFor(mutation.historyEntry),
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
        );
        if (rowId < 0) {
          throw new Error(`写入阅读记录失败：${mutation.historyEntry.content.key}`);
        }
      }
      if (mutation.stateEntry !== undefined) {
        const rowId = await transaction.insert(
          STATE_TABLE_NAME,
          stateValuesFor(mutation.stateEntry),
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
        );
        if (rowId < 0) {
          throw new Error(`写入阅读状态失败：${mutation.stateEntry.content.key}`);
        }
      } else if (mutation.deleteStateKey !== undefined) {
        const predicates = new relationalStore.RdbPredicates(STATE_TABLE_NAME);
        predicates.equalTo('content_key', mutation.deleteStateKey);
        const deleted = await transaction.delete(predicates);
        if (deleted < 0) {
          throw new Error(`清除阅读状态失败：${mutation.deleteStateKey}`);
        }
      }
      await transaction.commit();
    } catch (error) {
      try {
        await transaction.rollback();
      } catch (rollbackError) {
        console.warn(
          `Rollback reading history mutation failed: ` +
          `${rollbackError instanceof Error ? rollbackError.message : 'unknown error'}`
        );
      }
      throw historyError('写入', error);
    }
  }

  async pruneHistory(limit: number): Promise<void> {
    const store = await this.storeProvider();
    try {
      await store.executeSql(buildPruneHistorySql(limit));
    } catch (error) {
      // 核心阅读记录已经成功写入；清理失败只影响空间维护，不伪装成保存失败。
      console.warn(
        `Prune reading history failed: ${error instanceof Error ? error.message : 'unknown error'}`
      );
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
    } catch (_error) {
      // 单条历史脏数据不应阻断其他记录展示；再次打开时会重建该条记录。
      return undefined;
    }
  }

  private stateFromResultSet(resultSet: relationalStore.ResultSet): ReadingStateEntry | undefined {
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
      return new ReadingStateEntry(
        content,
        resultSet.getLong(resultSet.getColumnIndex('scroll_offset')),
        resultSet.getLong(resultSet.getColumnIndex('completed')) > 0,
        resultSet.getLong(resultSet.getColumnIndex('completed_at')),
        resultSet.getLong(resultSet.getColumnIndex('updated_at'))
      );
    } catch (_error) {
      return undefined;
    }
  }
}

/**
 * 阅读历史与永久阅读状态持久化。
 *
 * 最近浏览队列维持有界裁剪；已读标记与续读滚动位置独立保存于永久状态表，
 * 同一内容写入由原生异步锁与数据库事务共同保证一致性。
 */
export class ReadingHistoryRepo implements ReadingHistoryRepository {
  private readonly context: common.UIAbilityContext;
  private store: relationalStore.RdbStore | undefined = undefined;
  private initialization: Promise<void> | undefined = undefined;
  private readonly operationLock: ArkTSUtils.locks.AsyncLock =
    new ArkTSUtils.locks.AsyncLock();
  private readonly engine: ReadingHistoryStoreEngine;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.engine = new ReadingHistoryStoreEngine(
      new RdbReadingHistoryStorage((): Promise<relationalStore.RdbStore> => this.requireStore()),
      READING_HISTORY_LIMIT
    );
  }

  /** Opens the feature-owned store; repeated calls share one task. */
  public initialize(): Promise<void> {
    if (this.initialization !== undefined) {
      return this.initialization;
    }
    this.initialization = this.open(this.context);
    return this.initialization;
  }

  /** 按最后阅读时间倒序读取最近浏览快照。 */
  async list(): Promise<ReadingHistoryEntry[]> {
    return this.operationLock.lockAsync<ReadingHistoryEntry[]>(
      (): Promise<ReadingHistoryEntry[]> => this.engine.list(),
      ArkTSUtils.locks.AsyncLockMode.SHARED
    );
  }

  /** 读取不受 500 条裁剪限制的永久阅读状态快照。 */
  async listStates(): Promise<ReadingStateEntry[]> {
    return this.operationLock.lockAsync<ReadingStateEntry[]>(
      (): Promise<ReadingStateEntry[]> => this.engine.listStates(),
      ArkTSUtils.locks.AsyncLockMode.SHARED
    );
  }

  /** 查找条目的最新权威阅读记录（最近队列优先，已裁出则回退到永久状态）。 */
  async find(contentKey: string): Promise<ReadingHistoryEntry | undefined> {
    return this.operationLock.lockAsync<ReadingHistoryEntry | undefined>(
      (): Promise<ReadingHistoryEntry | undefined> => this.engine.find(contentKey),
      ArkTSUtils.locks.AsyncLockMode.SHARED
    );
  }

  /** 记录一次进入文章：从永久状态恢复进度与已读标记，不覆盖已有位置。 */
  async recordOpened(content: LibraryContentRef): Promise<ReadingHistoryEntry> {
    let updated: ReadingHistoryEntry | undefined = undefined;
    await this.enqueueMutation(async (): Promise<void> => {
      updated = await this.engine.recordOpened(content);
    });
    return updated!;
  }

  /** 更新进度；尚无历史时同时创建记录。 */
  async updateProgress(content: LibraryContentRef, offset: number): Promise<ReadingHistoryEntry> {
    let updated: ReadingHistoryEntry | undefined = undefined;
    await this.enqueueMutation(async (): Promise<void> => {
      updated = await this.engine.updateProgress(content, offset);
    });
    return updated!;
  }

  async setCompleted(content: LibraryContentRef, completed: boolean): Promise<ReadingHistoryEntry> {
    let updated: ReadingHistoryEntry | undefined = undefined;
    await this.enqueueMutation(async (): Promise<void> => {
      updated = await this.engine.setCompleted(content, completed);
    });
    return updated!;
  }

  /** 旧记录名称补全不能伪造一次新的浏览，因此完整保留三个时间/进度字段。 */
  async updateMetadata(content: LibraryContentRef): Promise<ReadingHistoryEntry | undefined> {
    let updated: ReadingHistoryEntry | undefined = undefined;
    await this.enqueueMutation(async (): Promise<void> => {
      updated = await this.engine.updateMetadata(content);
    });
    return updated;
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
      await store.executeSql(CREATE_HISTORY_TABLE);
      // Existing installs predate the completion annotation.  Duplicate
      // column errors mean the migration already ran and are safe to ignore.
      try {
        await store.executeSql(ADD_HISTORY_COMPLETED_COLUMN);
      } catch (error) {
        const message = error instanceof Error ? error.message.toLowerCase() : '';
        if (message.indexOf('duplicate') < 0 && message.indexOf('exists') < 0) {
          console.warn(`Reading history completion migration skipped: ${message}`);
        }
      }
      await store.executeSql(CREATE_HISTORY_TIME_INDEX);
      await store.executeSql(CREATE_STATE_TABLE);
      await store.executeSql(CREATE_STATE_UPDATED_INDEX);
      // Canonicalize legacy keys before backfilling the permanent state table
      // so every migrated row lands directly under `main:<slug>`.
      await this.migrateLegacyContentKeys(store);
      await store.executeSql(BACKFILL_STATE_FROM_HISTORY);
      this.store = store;
    } catch (error) {
      this.initialization = undefined;
      throw historyError('初始化', error);
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
        const predicates = new relationalStore.RdbPredicates(HISTORY_TABLE_NAME);
        predicates.equalTo('content_key', migrationRows[index].storedKey);
        const deleted = await store.delete(predicates);
        if (deleted < 0) {
          throw new Error(`删除旧阅读主键失败：${migrationRows[index].storedKey}`);
        }
      }
    } catch (error) {
      throw historyError('主键迁移', error);
    }
  }

  private async readHistoryMigrationRows(
    store: relationalStore.RdbStore
  ): Promise<StoredHistoryMigrationRow[]> {
    const predicates = new relationalStore.RdbPredicates(HISTORY_TABLE_NAME);
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
        } catch (_error) {
          // 无法规范化的脏行原样保留，避免迁移造成不可逆删除。
        }
      }
      return rows;
    } catch (error) {
      throw historyError('迁移读取', error);
    } finally {
      closeResultSet(resultSet, 'Migration');
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
    try {
      const rowId = await store.insert(
        HISTORY_TABLE_NAME,
        historyValuesFor(entry),
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
      if (rowId < 0) {
        throw new Error(`写入统一阅读主键失败：${entry.content.key}`);
      }
    } catch (error) {
      throw historyError('迁移写入', error);
    }
  }

  private async requireStore(): Promise<relationalStore.RdbStore> {
    await this.initialize();
    if (this.store === undefined) {
      throw new Error('阅读历史存储尚未初始化');
    }
    return this.store;
  }
}

function historyValuesFor(entry: ReadingHistoryEntry): relationalStore.ValuesBucket {
  return {
    'content_key': entry.content.key,
    'content_id': entry.content.id,
    'title': entry.content.title,
    'content_kind': entry.content.kind,
    'opened_at': entry.openedAt,
    'last_read_at': entry.lastReadAt,
    'scroll_offset': entry.scrollOffset,
    'completed': entry.completed ? 1 : 0
  };
}

function stateValuesFor(state: ReadingStateEntry): relationalStore.ValuesBucket {
  return {
    'content_key': state.content.key,
    'content_id': state.content.id,
    'title': state.content.title,
    'content_kind': state.content.kind,
    'scroll_offset': state.scrollOffset,
    'completed': state.completed ? 1 : 0,
    'completed_at': state.completedAt,
    'updated_at': state.updatedAt
  };
}

function closeResultSet(resultSet: relationalStore.ResultSet | undefined, operation: string): void {
  try {
    resultSet?.close();
  } catch (error) {
    console.warn(
      `Close reading history ${operation} result set failed: ` +
      `${error instanceof Error ? error.message : 'unknown error'}`
    );
  }
}

function historyError(operation: string, error: Object): Error {
  const message = error instanceof Error ? error.message : '未知数据库错误';
  return new Error(`阅读历史${operation}失败：${message}`);
}
