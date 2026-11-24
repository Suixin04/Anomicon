import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { ArkTSUtils } from '@kit.ArkTS';
import { ANOMICON_DATABASE_NAME } from 'anomiconbasic';
import {
  RaisaFeedbackRepository,
  RaisaFeedbackTicket,
  parseRaisaFeedbackCategory
} from '../domain/RaisaFeedbackContracts';

const TABLE_NAME: string = 'raisa_feedback_tickets';
const MAX_LOCAL_TICKETS: number = 100;
const CREATE_TABLE_SQL: string =
  'CREATE TABLE IF NOT EXISTS raisa_feedback_tickets (' +
  'ticket_id TEXT PRIMARY KEY, ticket_code TEXT NOT NULL, issue_number INTEGER NOT NULL, ' +
  'issue_url TEXT NOT NULL, category TEXT NOT NULL, summary TEXT NOT NULL, ' +
  'submitted_app_version TEXT NOT NULL, article_id TEXT NOT NULL, article_title TEXT NOT NULL, ' +
  'submitted_at INTEGER NOT NULL)';
const CREATE_INDEX_SQL: string =
  'CREATE INDEX IF NOT EXISTS idx_raisa_tickets_submitted ' +
  'ON raisa_feedback_tickets(submitted_at DESC, ticket_id ASC)';

/** SQLite repository storing locally archived RAISA feedback tickets and submitted app versions. */
export class RaisaFeedbackRepo implements RaisaFeedbackRepository {
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

  async listTickets(): Promise<RaisaFeedbackTicket[]> {
    return this.operationLock.lockAsync<RaisaFeedbackTicket[]>(
      (): Promise<RaisaFeedbackTicket[]> => this.listNow(),
      ArkTSUtils.locks.AsyncLockMode.SHARED
    );
  }

  async saveTicket(ticket: RaisaFeedbackTicket): Promise<RaisaFeedbackTicket> {
    return this.operationLock.lockAsync<RaisaFeedbackTicket>(
      (): Promise<RaisaFeedbackTicket> => this.saveNow(ticket),
      ArkTSUtils.locks.AsyncLockMode.EXCLUSIVE
    );
  }

  async deleteTicket(ticketId: string): Promise<void> {
    return this.operationLock.lockAsync<void>(
      (): Promise<void> => this.deleteNow(ticketId),
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
      throw new Error(`RAISA 工单档案库初始化失败：${message}`);
    }
  }

  private async requireStore(): Promise<relationalStore.RdbStore> {
    await this.initialize();
    if (this.store === undefined) {
      throw new Error('RAISA 工单档案库尚未初始化');
    }
    return this.store;
  }

  private async listNow(): Promise<RaisaFeedbackTicket[]> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.orderByDesc('submitted_at');
    predicates.orderByAsc('ticket_id');
    predicates.limitAs(MAX_LOCAL_TICKETS);
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    const rows: RaisaFeedbackTicket[] = [];
    try {
      resultSet = await store.query(predicates, [
        'ticket_id',
        'ticket_code',
        'issue_number',
        'issue_url',
        'category',
        'summary',
        'submitted_app_version',
        'article_id',
        'article_title',
        'submitted_at'
      ]);
      while (resultSet.goToNextRow()) {
        const ticketId = resultSet.getString(resultSet.getColumnIndex('ticket_id')).trim();
        if (ticketId.length === 0) {
          continue;
        }
        const ticketCode = resultSet.getString(resultSet.getColumnIndex('ticket_code')).trim();
        const issueNumber = resultSet.getLong(resultSet.getColumnIndex('issue_number'));
        const issueUrl = resultSet.getString(resultSet.getColumnIndex('issue_url')).trim();
        const category = parseRaisaFeedbackCategory(
          resultSet.getString(resultSet.getColumnIndex('category'))
        );
        const summary = resultSet.getString(resultSet.getColumnIndex('summary')).trim();
        const submittedAppVersion = resultSet.getString(
          resultSet.getColumnIndex('submitted_app_version')
        ).trim();
        const articleId = resultSet.getString(resultSet.getColumnIndex('article_id')).trim();
        const articleTitle = resultSet.getString(resultSet.getColumnIndex('article_title')).trim();
        const submittedAt = resultSet.getLong(resultSet.getColumnIndex('submitted_at'));
        rows.push(new RaisaFeedbackTicket(
          ticketId,
          ticketCode,
          issueNumber,
          issueUrl,
          category,
          summary,
          submittedAppVersion,
          articleId,
          articleTitle,
          submittedAt
        ));
      }
      return rows;
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知数据库错误';
      throw new Error(`读取本地工单档案失败：${message}`);
    } finally {
      try {
        resultSet?.close();
      } catch (_error) {
      }
    }
  }

  private async saveNow(ticket: RaisaFeedbackTicket): Promise<RaisaFeedbackTicket> {
    const store = await this.requireStore();
    const values: relationalStore.ValuesBucket = {
      'ticket_id': ticket.ticketId,
      'ticket_code': ticket.ticketCode,
      'issue_number': ticket.issueNumber,
      'issue_url': ticket.issueUrl,
      'category': ticket.category,
      'summary': ticket.summary,
      'submitted_app_version': ticket.submittedAppVersion,
      'article_id': ticket.articleId,
      'article_title': ticket.articleTitle,
      'submitted_at': ticket.submittedAt
    };
    const rowId = await store.insert(
      TABLE_NAME,
      values,
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
    );
    if (rowId < 0) {
      throw new Error(`保存本地工单记录失败：${ticket.ticketCode}`);
    }
    return ticket;
  }

  private async deleteNow(ticketId: string): Promise<void> {
    const normalized = ticketId.trim();
    if (normalized.length === 0) {
      return;
    }
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('ticket_id', normalized);
    await store.delete(predicates);
  }
}
