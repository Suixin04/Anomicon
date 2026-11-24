import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { ArkTSUtils } from '@kit.ArkTS';
import { ANOMICON_DATABASE_NAME } from 'anomiconbasic';
import {
  StorySeriesEnrollment,
  StorySeriesRepository,
  normalizeSeriesPageId
} from '../domain/StorySeriesContracts';

const TABLE_NAME: string = 'story_series_progress';
const CREATE_TABLE_SQL: string =
  'CREATE TABLE IF NOT EXISTS story_series_progress (' +
  'series_id TEXT PRIMARY KEY, enrolled INTEGER NOT NULL, ' +
  'current_entry_id TEXT NOT NULL, enrolled_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)';
const CREATE_INDEX_SQL: string =
  'CREATE INDEX IF NOT EXISTS idx_story_series_updated ' +
  'ON story_series_progress(updated_at DESC, series_id ASC)';

/** SQLite storage for enrolled story series progress; stays private to library. */
export class StorySeriesRepo implements StorySeriesRepository {
  private readonly context: common.UIAbilityContext;
  private store: relationalStore.RdbStore | undefined = undefined;
  private initialization: Promise<void> | undefined = undefined;
  private readonly operationLock: ArkTSUtils.locks.AsyncLock =
    new ArkTSUtils.locks.AsyncLock();

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  initialize(): Promise<void> {
    if (this.initialization !== undefined) {
      return this.initialization;
    }
    this.initialization = this.open(this.context);
    return this.initialization;
  }

  async listEnrollments(): Promise<StorySeriesEnrollment[]> {
    return this.operationLock.lockAsync<StorySeriesEnrollment[]>(
      (): Promise<StorySeriesEnrollment[]> => this.listNow(),
      ArkTSUtils.locks.AsyncLockMode.SHARED
    );
  }

  async saveEnrollment(enrollment: StorySeriesEnrollment): Promise<StorySeriesEnrollment> {
    return this.operationLock.lockAsync<StorySeriesEnrollment>(
      (): Promise<StorySeriesEnrollment> => this.saveNow(enrollment),
      ArkTSUtils.locks.AsyncLockMode.EXCLUSIVE
    );
  }

  async removeEnrollment(seriesId: string): Promise<void> {
    await this.operationLock.lockAsync<void>(
      (): Promise<void> => this.removeNow(seriesId),
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
      await store.executeSql(CREATE_TABLE_SQL);
      await store.executeSql(CREATE_INDEX_SQL);
      this.store = store;
    } catch (error) {
      this.initialization = undefined;
      const message = error instanceof Error ? error.message : '未知数据库错误';
      throw new Error(`系列进度初始化失败：${message}`);
    }
  }

  private async requireStore(): Promise<relationalStore.RdbStore> {
    await this.initialize();
    if (this.store === undefined) {
      throw new Error('系列进度存储尚未初始化');
    }
    return this.store;
  }

  private async listNow(): Promise<StorySeriesEnrollment[]> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.orderByDesc('updated_at');
    predicates.orderByAsc('series_id');
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    const rows: StorySeriesEnrollment[] = [];
    try {
      resultSet = await store.query(predicates, [
        'series_id',
        'enrolled',
        'current_entry_id',
        'enrolled_at',
        'updated_at'
      ]);
      while (resultSet.goToNextRow()) {
        const seriesId = resultSet.getString(resultSet.getColumnIndex('series_id'));
        const enrolled = resultSet.getLong(resultSet.getColumnIndex('enrolled')) === 1;
        const currentEntryId = resultSet.getString(resultSet.getColumnIndex('current_entry_id'));
        const enrolledAt = resultSet.getLong(resultSet.getColumnIndex('enrolled_at'));
        const updatedAt = resultSet.getLong(resultSet.getColumnIndex('updated_at'));
        if (seriesId.trim().length > 0) {
          rows.push(new StorySeriesEnrollment(
            seriesId,
            enrolled,
            currentEntryId,
            enrolledAt,
            updatedAt
          ));
        }
      }
      return rows;
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知数据库错误';
      throw new Error(`读取系列进度失败：${message}`);
    } finally {
      try {
        resultSet?.close();
      } catch (_error) {
      }
    }
  }

  private async saveNow(enrollment: StorySeriesEnrollment): Promise<StorySeriesEnrollment> {
    const store = await this.requireStore();
    const normalizedSeriesId = normalizeSeriesPageId(enrollment.seriesId);
    const normalizedEntryId = normalizeSeriesPageId(enrollment.currentEntryId);
    const values: relationalStore.ValuesBucket = {
      'series_id': normalizedSeriesId,
      'enrolled': enrollment.enrolled ? 1 : 0,
      'current_entry_id': normalizedEntryId,
      'enrolled_at': enrollment.enrolledAt,
      'updated_at': enrollment.updatedAt
    };
    const rowId = await store.insert(
      TABLE_NAME,
      values,
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
    );
    if (rowId < 0) {
      throw new Error(`保存系列进度失败：${normalizedSeriesId}`);
    }
    return new StorySeriesEnrollment(
      normalizedSeriesId,
      enrollment.enrolled,
      normalizedEntryId,
      enrollment.enrolledAt,
      enrollment.updatedAt
    );
  }

  private async removeNow(seriesId: string): Promise<void> {
    const store = await this.requireStore();
    const normalizedSeriesId = normalizeSeriesPageId(seriesId);
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('series_id', normalizedSeriesId);
    await store.delete(predicates);
  }
}
