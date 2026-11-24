import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { ArkTSUtils } from '@kit.ArkTS';
import { ANOMICON_DATABASE_NAME } from 'anomiconbasic';
import {
  FoundationAssessmentRecord,
  FoundationAssessmentRepository,
  normalizeAssessmentExamId
} from '../domain/FoundationAssessmentContracts';

const TABLE_NAME: string = 'foundation_assessment_records';
const CREATE_TABLE_SQL: string =
  'CREATE TABLE IF NOT EXISTS foundation_assessment_records (' +
  'exam_id TEXT PRIMARY KEY, passed INTEGER NOT NULL, best_score INTEGER NOT NULL, ' +
  'total_questions INTEGER NOT NULL, attempts INTEGER NOT NULL, xp_awarded INTEGER NOT NULL, ' +
  'passed_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)';
const CREATE_INDEX_SQL: string =
  'CREATE INDEX IF NOT EXISTS idx_assessment_updated ' +
  'ON foundation_assessment_records(updated_at DESC, exam_id ASC)';

/** SQLite repository for permanent RAISA assessment records and earned bonus XP. */
export class FoundationAssessmentRepo implements FoundationAssessmentRepository {
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

  async listRecords(): Promise<FoundationAssessmentRecord[]> {
    return this.operationLock.lockAsync<FoundationAssessmentRecord[]>(
      (): Promise<FoundationAssessmentRecord[]> => this.listNow(),
      ArkTSUtils.locks.AsyncLockMode.SHARED
    );
  }

  async saveRecord(record: FoundationAssessmentRecord): Promise<FoundationAssessmentRecord> {
    return this.operationLock.lockAsync<FoundationAssessmentRecord>(
      (): Promise<FoundationAssessmentRecord> => this.saveNow(record),
      ArkTSUtils.locks.AsyncLockMode.EXCLUSIVE
    );
  }

  async totalAwardedXp(): Promise<number> {
    return this.operationLock.lockAsync<number>(
      async (): Promise<number> => {
        const records = await this.listNow();
        let total = 0;
        for (let index = 0; index < records.length; index++) {
          total += records[index].xpAwarded;
        }
        return total;
      },
      ArkTSUtils.locks.AsyncLockMode.SHARED
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
      throw new Error(`资质考核记录初始化失败：${message}`);
    }
  }

  private async requireStore(): Promise<relationalStore.RdbStore> {
    await this.initialize();
    if (this.store === undefined) {
      throw new Error('资质考核存储尚未初始化');
    }
    return this.store;
  }

  private async listNow(): Promise<FoundationAssessmentRecord[]> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.orderByAsc('exam_id');
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    const rows: FoundationAssessmentRecord[] = [];
    try {
      resultSet = await store.query(predicates, [
        'exam_id',
        'passed',
        'best_score',
        'total_questions',
        'attempts',
        'xp_awarded',
        'passed_at',
        'updated_at'
      ]);
      while (resultSet.goToNextRow()) {
        const examId = normalizeAssessmentExamId(
          resultSet.getString(resultSet.getColumnIndex('exam_id'))
        );
        if (examId.length === 0) {
          continue;
        }
        const passed = resultSet.getLong(resultSet.getColumnIndex('passed')) === 1;
        const bestScore = resultSet.getLong(resultSet.getColumnIndex('best_score'));
        const totalQuestions = resultSet.getLong(resultSet.getColumnIndex('total_questions'));
        const attempts = resultSet.getLong(resultSet.getColumnIndex('attempts'));
        const xpAwarded = resultSet.getLong(resultSet.getColumnIndex('xp_awarded'));
        const passedAt = resultSet.getLong(resultSet.getColumnIndex('passed_at'));
        const updatedAt = resultSet.getLong(resultSet.getColumnIndex('updated_at'));
        rows.push(new FoundationAssessmentRecord(
          examId,
          passed,
          bestScore,
          totalQuestions,
          attempts,
          xpAwarded,
          passedAt,
          updatedAt
        ));
      }
      return rows;
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知数据库错误';
      throw new Error(`读取资质考核记录失败：${message}`);
    } finally {
      try {
        resultSet?.close();
      } catch (_error) {
      }
    }
  }

  private async saveNow(record: FoundationAssessmentRecord): Promise<FoundationAssessmentRecord> {
    const store = await this.requireStore();
    const normalizedId = normalizeAssessmentExamId(record.examId);
    const values: relationalStore.ValuesBucket = {
      'exam_id': normalizedId,
      'passed': record.passed ? 1 : 0,
      'best_score': record.bestScore,
      'total_questions': record.totalQuestions,
      'attempts': record.attempts,
      'xp_awarded': record.xpAwarded,
      'passed_at': record.passedAt,
      'updated_at': record.updatedAt
    };
    const rowId = await store.insert(
      TABLE_NAME,
      values,
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
    );
    if (rowId < 0) {
      throw new Error(`保存资质考核记录失败：${normalizedId}`);
    }
    return new FoundationAssessmentRecord(
      normalizedId,
      record.passed,
      record.bestScore,
      record.totalQuestions,
      record.attempts,
      record.xpAwarded,
      record.passedAt,
      record.updatedAt
    );
  }
}
