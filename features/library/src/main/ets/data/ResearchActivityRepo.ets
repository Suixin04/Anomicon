import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { ArkTSUtils } from '@kit.ArkTS';
import { systemDateTime } from '@kit.BasicServicesKit';
import { ANOMICON_DATABASE_NAME } from 'anomiconbasic';
import {
  LibraryContentRef,
  parseLibraryContentKind
} from '../domain/LibraryContentRef';
import {
  ResearchActivityCheckpoint,
  ResearchActivityFinish,
  ResearchActivitySegment,
  ResearchActivityStart,
  ResearchSessionState,
  RESEARCH_TIME_ZONE_OFFSET_UNSET,
  checkpointResearchSegment,
  deriveResearchProgress,
  finalizeResearchSegment,
  interruptResearchSegment,
  normalizeResearchDuration,
  normalizeResearchTimeZoneOffset,
  parseResearchSessionState
} from '../domain/ResearchProgress';
import {
  ResearchActivityMutationResult,
  ResearchActivityRepo as ResearchActivityRepoPort,
  ResearchActivitySnapshot
} from '../domain/ResearchActivityRepo';

const TABLE_NAME: string = 'research_activity_segments';
const CREATE_TABLE: string =
  'CREATE TABLE IF NOT EXISTS research_activity_segments (' +
  'segment_id TEXT PRIMARY KEY, content_key TEXT NOT NULL, content_id TEXT NOT NULL, ' +
  'content_title TEXT NOT NULL, content_kind TEXT NOT NULL, started_at INTEGER NOT NULL, ' +
  'ended_at INTEGER NOT NULL, active_ms INTEGER NOT NULL, last_offset INTEGER NOT NULL, ' +
  'state TEXT NOT NULL, end_reason TEXT NOT NULL, updated_at INTEGER NOT NULL, ' +
  'checkpoint_sequence INTEGER NOT NULL DEFAULT 0, ' +
  `start_timezone_offset INTEGER NOT NULL DEFAULT ${RESEARCH_TIME_ZONE_OFFSET_UNSET})`;
const ADD_CHECKPOINT_SEQUENCE: string =
  'ALTER TABLE research_activity_segments ' +
  'ADD COLUMN checkpoint_sequence INTEGER NOT NULL DEFAULT 0';
const ADD_START_TIMEZONE_OFFSET: string =
  'ALTER TABLE research_activity_segments ' +
  `ADD COLUMN start_timezone_offset INTEGER NOT NULL DEFAULT ${RESEARCH_TIME_ZONE_OFFSET_UNSET}`;
const CREATE_TIME_INDEX: string =
  'CREATE INDEX IF NOT EXISTS idx_research_activity_time ' +
  'ON research_activity_segments(started_at ASC, segment_id ASC)';
const CREATE_STATE_INDEX: string =
  'CREATE INDEX IF NOT EXISTS idx_research_activity_state ' +
  'ON research_activity_segments(state, updated_at DESC)';
const RECOVER_OPEN_SESSIONS: string =
  "UPDATE research_activity_segments SET state = 'interrupted', " +
  'ended_at = CASE WHEN updated_at >= started_at THEN updated_at ELSE started_at END, ' +
  "end_reason = 'process_restart' WHERE state = 'open'";
const INTERRUPT_REPLACED_SESSIONS: string =
  "UPDATE research_activity_segments SET state = 'interrupted', " +
  'ended_at = CASE WHEN updated_at >= started_at THEN updated_at ELSE started_at END, ' +
  "end_reason = 'session_replaced' WHERE state = 'open'";

export type ResearchBonusExperienceReader = () => Promise<number>;

/**
 * 阅读活动账本。
 *
 * 所有写入由同一原生锁串行；启动恢复只把残留 open 行改为 interrupted，绝不通过
 * 墙钟推算丢失时长。经验、等级和每日统计始终从此表重新派生。
 */
export class ResearchActivityRepo implements ResearchActivityRepoPort {
  private readonly context: common.UIAbilityContext;
  private readonly bonusExperienceReader: ResearchBonusExperienceReader | undefined;
  private store: relationalStore.RdbStore | undefined = undefined;
  private initialization: Promise<void> | undefined = undefined;
  private readonly mutationLock: ArkTSUtils.locks.AsyncLock =
    new ArkTSUtils.locks.AsyncLock();
  /** 从 RDB 首次读取、且只在写成功后替换的运行时快照，不是第二份持久化。 */
  private cachedSessions: ResearchActivitySegment[] | undefined = undefined;
  private cachedBonusExperience: number = 0;

  constructor(
    context: common.UIAbilityContext,
    bonusExperienceReader?: ResearchBonusExperienceReader
  ) {
    this.context = context;
    this.bonusExperienceReader = bonusExperienceReader;
  }

  /** Opens the feature-owned store; repeated calls share one task. */
  public initialize(): Promise<void> {
    if (this.initialization !== undefined) {
      return this.initialization;
    }
    this.initialization = this.open(this.context);
    return this.initialization;
  }

  async snapshot(): Promise<ResearchActivitySnapshot> {
    await this.awaitPendingMutations();
    const sessions = await this.listNow();
    this.cachedSessions = sessions;
    await this.refreshBonusExperience();
    return this.snapshotFromSessions(sessions);
  }

  async startSession(start: ResearchActivityStart): Promise<ResearchActivityMutationResult> {
    let result: ResearchActivityMutationResult | undefined = undefined;
    await this.enqueueMutation(async (): Promise<void> => {
      const sessions = await this.ensureCachedSessionsNow();
      const existing = this.findInSessions(sessions, start.segmentId);
      if (existing !== undefined) {
        throw new Error('研读片段标识已存在');
      }
      const session = new ResearchActivitySegment(
        start.segmentId,
        start.content,
        start.startedAt,
        0,
        0,
        start.lastOffset,
        ResearchSessionState.OPEN,
        '',
        start.updatedAt,
        start.checkpointSequence,
        start.startTimeZoneOffsetMinutes
      );
      await this.insertStartedSessionNow(session);
      const nextSessions: ResearchActivitySegment[] = [];
      for (let index = 0; index < sessions.length; index++) {
        const candidate = sessions[index];
        if (candidate.state === ResearchSessionState.OPEN) {
          nextSessions.push(interruptResearchSegment(candidate, 'session_replaced'));
        } else {
          nextSessions.push(candidate);
        }
      }
      nextSessions.push(session);
      this.cachedSessions = this.sortedSessions(nextSessions);
      result = this.resultFromCache(session);
    });
    return result!;
  }

  async checkpointSession(
    checkpoint: ResearchActivityCheckpoint
  ): Promise<ResearchActivityMutationResult> {
    let result: ResearchActivityMutationResult | undefined = undefined;
    await this.enqueueMutation(async (): Promise<void> => {
      const sessions = await this.ensureCachedSessionsNow();
      const existing = this.requireSessionIn(sessions, checkpoint.segmentId);
      if (existing.state !== ResearchSessionState.OPEN) {
        result = this.resultFromCache(existing);
        return;
      }
      const updated = checkpointResearchSegment(existing, checkpoint);
      await this.putNow(updated);
      this.cachedSessions = this.replacingSession(sessions, updated);
      result = this.resultFromCache(updated);
    });
    return result!;
  }

  async finalizeSession(finish: ResearchActivityFinish): Promise<ResearchActivityMutationResult> {
    let result: ResearchActivityMutationResult | undefined = undefined;
    await this.enqueueMutation(async (): Promise<void> => {
      const sessions = await this.ensureCachedSessionsNow();
      const existing = this.requireSessionIn(sessions, finish.segmentId);
      if (existing.state !== ResearchSessionState.OPEN) {
        result = this.resultFromCache(existing);
        return;
      }
      const updated = finalizeResearchSegment(existing, finish);
      await this.putNow(updated);
      this.cachedSessions = this.replacingSession(sessions, updated);
      result = this.resultFromCache(updated);
    });
    return result!;
  }

  private async open(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await relationalStore.getRdbStore(context, {
        name: ANOMICON_DATABASE_NAME,
        securityLevel: relationalStore.SecurityLevel.S1,
        encrypt: false
      });
      await store.executeSql(CREATE_TABLE);
      await this.ensureActivityColumns(store);
      await store.executeSql(CREATE_TIME_INDEX);
      await store.executeSql(CREATE_STATE_INDEX);
      // 只保留上一次已 checkpoint 的 active_ms；ended_at 也停在 updated_at。
      await store.executeSql(RECOVER_OPEN_SESSIONS);
      this.store = store;
      this.cachedSessions = undefined;
    } catch (error) {
      this.store = undefined;
      this.cachedSessions = undefined;
      this.initialization = undefined;
      throw this.activityError('初始化', error);
    }
  }

  /** 中断旧 open 行并插入新行必须是一次原子状态切换。 */
  private async insertStartedSessionNow(session: ResearchActivitySegment): Promise<void> {
    const store = await this.requireStore();
    let transaction: relationalStore.Transaction;
    try {
      transaction = await store.createTransaction();
    } catch (error) {
      throw this.activityError('开始', error);
    }
    try {
      await transaction.execute(INTERRUPT_REPLACED_SESSIONS);
      const rowId = await transaction.insert(
        TABLE_NAME,
        this.valuesFor(session),
        relationalStore.ConflictResolution.ON_CONFLICT_NONE
      );
      if (rowId < 0) {
        throw new Error(`写入研读片段失败：${session.segmentId}`);
      }
      await transaction.commit();
    } catch (error) {
      try {
        await transaction.rollback();
      } catch (rollbackError) {
        console.warn(
          `Rollback research session failed: ${this.unknownErrorMessage(rollbackError)}`
        );
      }
      throw this.activityError('开始', error);
    }
  }

  private async putNow(session: ResearchActivitySegment): Promise<void> {
    const store = await this.requireStore();
    try {
      const rowId = await store.insert(
        TABLE_NAME,
        this.valuesFor(session),
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
      if (rowId < 0) {
        throw new Error(`写入研读片段失败：${session.segmentId}`);
      }
    } catch (error) {
      throw this.activityError('写入', error);
    }
  }

  private valuesFor(session: ResearchActivitySegment): relationalStore.ValuesBucket {
    return {
      'segment_id': session.segmentId,
      'content_key': session.content.key,
      'content_id': session.content.id,
      'content_title': session.content.title,
      'content_kind': session.content.kind,
      'started_at': session.startedAt,
      'ended_at': session.endedAt,
      'active_ms': session.activeMs,
      'last_offset': session.lastOffset,
      'state': session.state,
      'end_reason': session.endReason,
      'updated_at': session.updatedAt,
      'checkpoint_sequence': session.checkpointSequence,
      'start_timezone_offset': session.startTimeZoneOffsetMinutes
    };
  }

  private async listNow(): Promise<ResearchActivitySegment[]> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.orderByAsc('started_at');
    predicates.orderByAsc('segment_id');
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    const sessions: ResearchActivitySegment[] = [];
    try {
      resultSet = await store.query(predicates, [
        'segment_id',
        'content_id',
        'content_title',
        'content_kind',
        'started_at',
        'ended_at',
        'active_ms',
        'last_offset',
        'state',
        'end_reason',
        'updated_at',
        'checkpoint_sequence',
        'start_timezone_offset'
      ]);
      while (resultSet.goToNextRow()) {
        const session = this.sessionFromResultSet(resultSet);
        if (session !== undefined) {
          sessions.push(session);
        }
      }
      return sessions;
    } catch (error) {
      throw this.activityError('读取', error);
    } finally {
      this.closeResultSet(resultSet, 'list');
    }
  }

  private sessionFromResultSet(
    resultSet: relationalStore.ResultSet
  ): ResearchActivitySegment | undefined {
    try {
      const kind = parseLibraryContentKind(
        resultSet.getString(resultSet.getColumnIndex('content_kind'))
      );
      const state = parseResearchSessionState(
        resultSet.getString(resultSet.getColumnIndex('state'))
      );
      if (kind === undefined || state === undefined) {
        return undefined;
      }
      const content = new LibraryContentRef(
        kind,
        resultSet.getString(resultSet.getColumnIndex('content_id')),
        resultSet.getString(resultSet.getColumnIndex('content_title'))
      );
      return new ResearchActivitySegment(
        resultSet.getString(resultSet.getColumnIndex('segment_id')),
        content,
        resultSet.getLong(resultSet.getColumnIndex('started_at')),
        resultSet.getLong(resultSet.getColumnIndex('ended_at')),
        resultSet.getLong(resultSet.getColumnIndex('active_ms')),
        resultSet.getLong(resultSet.getColumnIndex('last_offset')),
        state,
        resultSet.getString(resultSet.getColumnIndex('end_reason')),
        resultSet.getLong(resultSet.getColumnIndex('updated_at')),
        resultSet.getLong(resultSet.getColumnIndex('checkpoint_sequence')),
        resultSet.getLong(resultSet.getColumnIndex('start_timezone_offset'))
      );
    } catch (error) {
      // 单行损坏不阻断其他可信账本记录；画像只从成功归一化的行派生。
      return undefined;
    }
  }

  private snapshotFromSessions(sessions: ResearchActivitySegment[]): ResearchActivitySnapshot {
    const now = this.currentWallTime();
    const timeZoneOffset = this.currentTimeZoneOffset(now);
    const profile = deriveResearchProgress(
      sessions,
      now,
      timeZoneOffset,
      this.cachedBonusExperience
    );
    let activeSession: ResearchActivitySegment | undefined = undefined;
    for (let index = sessions.length - 1; index >= 0; index--) {
      if (sessions[index].state === ResearchSessionState.OPEN) {
        activeSession = sessions[index];
        break;
      }
    }
    return new ResearchActivitySnapshot(profile, activeSession);
  }

  private async refreshBonusExperience(): Promise<void> {
    if (this.bonusExperienceReader === undefined) {
      return;
    }
    try {
      const value = await this.bonusExperienceReader();
      this.cachedBonusExperience = normalizeResearchDuration(value);
    } catch (_error) {
      // Keep the latest cached bonus XP if the secondary store temporarily fails.
    }
  }

  private async ensureCachedSessionsNow(): Promise<ResearchActivitySegment[]> {
    if (this.cachedSessions !== undefined) {
      return this.cachedSessions;
    }
    const sessions = await this.listNow();
    this.cachedSessions = sessions;
    return sessions;
  }

  private resultFromCache(session: ResearchActivitySegment): ResearchActivityMutationResult {
    const sessions = this.cachedSessions ?? [];
    return new ResearchActivityMutationResult(session, this.snapshotFromSessions(sessions));
  }

  private findInSessions(
    sessions: ResearchActivitySegment[],
    segmentId: string
  ): ResearchActivitySegment | undefined {
    for (let index = 0; index < sessions.length; index++) {
      if (sessions[index].segmentId === segmentId) {
        return sessions[index];
      }
    }
    return undefined;
  }

  private requireSessionIn(
    sessions: ResearchActivitySegment[],
    segmentId: string
  ): ResearchActivitySegment {
    const session = this.findInSessions(sessions, segmentId);
    if (session === undefined) {
      throw new Error('研读片段不存在');
    }
    return session;
  }

  private replacingSession(
    sessions: ResearchActivitySegment[],
    updated: ResearchActivitySegment
  ): ResearchActivitySegment[] {
    const next: ResearchActivitySegment[] = [];
    for (let index = 0; index < sessions.length; index++) {
      next.push(sessions[index].segmentId === updated.segmentId ? updated : sessions[index]);
    }
    return this.sortedSessions(next);
  }

  private sortedSessions(sessions: ResearchActivitySegment[]): ResearchActivitySegment[] {
    const sorted = sessions.slice();
    sorted.sort((left: ResearchActivitySegment, right: ResearchActivitySegment): number => {
      if (left.startedAt !== right.startedAt) {
        return left.startedAt - right.startedAt;
      }
      return left.segmentId.localeCompare(right.segmentId);
    });
    return sorted;
  }

  private currentWallTime(): number {
    try {
      return systemDateTime.getTime(false);
    } catch (error) {
      return Date.now();
    }
  }

  private currentTimeZoneOffset(now: number): number {
    return normalizeResearchTimeZoneOffset(-new Date(now).getTimezoneOffset());
  }

  /** 兼容开发阶段已经创建过旧表的本地数据库；按实际列存在性幂等补齐。 */
  private async ensureActivityColumns(store: relationalStore.RdbStore): Promise<void> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    let hasCheckpointSequence = false;
    let hasStartTimezoneOffset = false;
    try {
      resultSet = await store.querySql(`PRAGMA table_info(${TABLE_NAME})`);
      while (resultSet.goToNextRow()) {
        const name = resultSet.getString(resultSet.getColumnIndex('name'));
        if (name === 'checkpoint_sequence') {
          hasCheckpointSequence = true;
        } else if (name === 'start_timezone_offset') {
          hasStartTimezoneOffset = true;
        }
      }
    } catch (error) {
      throw this.activityError('检查表结构', error);
    } finally {
      this.closeResultSet(resultSet, 'schema');
    }
    try {
      if (!hasCheckpointSequence) {
        await store.executeSql(ADD_CHECKPOINT_SEQUENCE);
      }
      if (!hasStartTimezoneOffset) {
        await store.executeSql(ADD_START_TIMEZONE_OFFSET);
      }
    } catch (error) {
      throw this.activityError('升级表结构', error);
    }
  }

  private enqueueMutation(operation: () => Promise<void>): Promise<void> {
    const guarded = async (): Promise<void> => {
      try {
        await operation();
      } catch (error) {
        // 写入结果不确定时丢弃内存镜像，下一次动作必须以 RDB 为准重载。
        this.cachedSessions = undefined;
        if (error instanceof Error) {
          throw error;
        }
        throw new Error('研读活动写入失败');
      }
    };
    return this.mutationLock.lockAsync<void>(
      guarded,
      ArkTSUtils.locks.AsyncLockMode.EXCLUSIVE
    );
  }

  /** 等待调用前已提交的写入；后续快照读取保持原有的非排他语义。 */
  private awaitPendingMutations(): Promise<void> {
    return this.mutationLock.lockAsync<void>(
      async (): Promise<void> => {},
      ArkTSUtils.locks.AsyncLockMode.EXCLUSIVE
    );
  }

  private async requireStore(): Promise<relationalStore.RdbStore> {
    await this.initialize();
    if (this.store === undefined) {
      throw new Error('研读活动存储尚未初始化');
    }
    return this.store;
  }

  private closeResultSet(resultSet: relationalStore.ResultSet | undefined, operation: string): void {
    try {
      resultSet?.close();
    } catch (error) {
      console.warn(
        `Close research activity ${operation} result set failed: ${this.unknownErrorMessage(error)}`
      );
    }
  }

  private activityError(operation: string, error: Object): Error {
    return new Error(`研读活动${operation}失败：${this.unknownErrorMessage(error)}`);
  }

  private unknownErrorMessage(error: Object): string {
    return error instanceof Error ? error.message : '未知数据库错误';
  }
}
