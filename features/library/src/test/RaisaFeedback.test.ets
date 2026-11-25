import { describe, expect, it } from '@ohos/hypium';
import { IdGeneratorPort } from 'anomiconbasic';
import {
  RAISA_GITHUB_ISSUES_URL,
  RAISA_MAX_ATTACHMENT_BYTES,
  RaisaDiagnosticSnapshot,
  RaisaFeedbackAttachment,
  RaisaFeedbackCategory,
  RaisaFeedbackRelayGateway,
  RaisaFeedbackRepository,
  RaisaFeedbackSubmission,
  RaisaFeedbackSubmitResult,
  RaisaFeedbackTicket,
  formatRaisaAttachmentBytes,
  formatRaisaDiagnosticLines,
  formatRaisaTicketPlainReport,
  sanitizeFeedbackSingleLine,
  validateRaisaFeedbackAttachments,
  validateRaisaFeedbackInput
} from '../main/ets/domain/RaisaFeedbackContracts';
import { RaisaFeedbackViewModel } from '../main/ets/presentation/viewmodel/RaisaFeedbackViewModel';

class StubIdGenerator implements IdGeneratorPort {
  private seq: number = 0;

  generate(): string {
    this.seq++;
    return `idemp-${this.seq}`;
  }
}

class InMemoryFeedbackRepo implements RaisaFeedbackRepository {
  failSave: boolean = false;
  private readonly items: Map<string, RaisaFeedbackTicket> = new Map();

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  listTickets(): Promise<RaisaFeedbackTicket[]> {
    const rows: RaisaFeedbackTicket[] = [];
    this.items.forEach((ticket: RaisaFeedbackTicket): void => {
      rows.push(ticket);
    });
    return Promise.resolve(rows);
  }

  saveTicket(ticket: RaisaFeedbackTicket): Promise<RaisaFeedbackTicket> {
    if (this.failSave) {
      return Promise.reject(new Error('模拟磁盘写入失败'));
    }
    this.items.set(ticket.ticketId, ticket);
    return Promise.resolve(ticket);
  }

  deleteTicket(ticketId: string): Promise<void> {
    this.items.delete(ticketId);
    return Promise.resolve();
  }
}

class StubRelayGateway implements RaisaFeedbackRelayGateway {
  configured: boolean = true;
  failSubmit: boolean = false;
  nextIssueNumber: number = 101;
  deduplicatedOnNext: boolean = false;
  submissions: RaisaFeedbackSubmission[] = [];

  isConfigured(): boolean {
    return this.configured;
  }

  endpointUrl(): string {
    return this.configured ? 'https://raisa.example.com/v1/raisa/tickets' : '';
  }

  submitTicket(submission: RaisaFeedbackSubmission): Promise<RaisaFeedbackSubmitResult> {
    this.submissions.push(submission);
    if (this.failSubmit) {
      return Promise.reject(new Error('服务端限流测试错误'));
    }
    const num = this.nextIssueNumber;
    const ticket = new RaisaFeedbackTicket(
      `issue-${num}`,
      `RAISA-#${num}`,
      num,
      `${RAISA_GITHUB_ISSUES_URL}/${num}`,
      submission.category,
      submission.summary,
      submission.diagnostics.appVersionLabel,
      submission.includeDiagnostics ? submission.diagnostics.articleId : '',
      submission.includeDiagnostics ? submission.diagnostics.articleTitle : '',
      1764000000000 + num
    );
    return Promise.resolve(new RaisaFeedbackSubmitResult(ticket, this.deduplicatedOnNext));
  }
}

function buildSnapshot(withArticle: boolean): RaisaDiagnosticSnapshot {
  return new RaisaDiagnosticSnapshot(
    '1.2.9',
    1020009,
    '1.2.9 (1020009)',
    'phone',
    'HarmonyOS 6.0 (API 26)',
    412,
    'dark',
    true,
    withArticle ? 'article' : 'settings',
    withArticle ? 'scp-3125' : '',
    withArticle ? 'SCP-3125 - 逃逸者' : '',
    withArticle ? 'https://scp-wiki-cn.wikidot.com/scp-3125' : '',
    withArticle ? 'native' : '',
    withArticle
  );
}

export default function raisaFeedbackTest(): void {
  describe('RaisaFeedback', () => {
    it('validates summary and details lengths and sanitizes line breaks', 0, () => {
      expect(validateRaisaFeedbackInput('太短', '足够长度的详细描述内容').length > 0).assertTrue();
      expect(validateRaisaFeedbackInput('合法的四字以上简述', '太短了').length > 0).assertTrue();
      expect(validateRaisaFeedbackInput('SCP-3125 折叠异常', '打开第 3 个折叠块后无法正确换行')).assertEqual('');
      expect(sanitizeFeedbackSingleLine('  第一行\n第二行\t内容  ', 100)).assertEqual('第一行 第二行 内容');
    });

    it('formats diagnostic lines and plain text fallback reports with optional article context', 0, () => {
      const articleSnap = buildSnapshot(true);
      const lines = formatRaisaDiagnosticLines(articleSnap);
      expect(lines.some((line: string): boolean => line.includes('1.2.9 (1020009)'))).assertTrue();
      expect(lines.some((line: string): boolean => line.includes('scp-3125'))).assertTrue();
      expect(lines.some((line: string): boolean => line.includes('原生阅读'))).assertTrue();

      const plainWithDiag = formatRaisaTicketPlainReport(
        RaisaFeedbackCategory.ARCHIVE_RENDER,
        '折叠块排版错位',
        '复现步骤：打开条目并点击折叠按钮。',
        'tester',
        true,
        articleSnap
      );
      expect(plainWithDiag.includes('提交版本：1.2.9 (1020009)')).assertTrue();
      expect(plainWithDiag.includes('终端诊断快照')).assertTrue();

      const plainNoDiag = formatRaisaTicketPlainReport(
        RaisaFeedbackCategory.SYSTEM_PROPOSAL,
        '增加书架筛选',
        '希望能按系列筛选离线副本。',
        '',
        false,
        buildSnapshot(false)
      );
      expect(plainNoDiag.includes('提交版本：1.2.9 (1020009)')).assertTrue();
      expect(plainNoDiag.includes('终端诊断快照')).assertFalse();
    });

    it('rejects submission cleanly when relay URL is unconfigured', 0, async () => {
      const repo = new InMemoryFeedbackRepo();
      const relay = new StubRelayGateway();
      relay.configured = false;
      const vm = new RaisaFeedbackViewModel(repo, relay, new StubIdGenerator());

      let failed = false;
      try {
        await vm.submit(
          RaisaFeedbackCategory.TERMINAL_BUG,
          '搜索栏偶现卡顿',
          '连续输入多次后界面轻微延迟。',
          '',
          true,
          buildSnapshot(false)
        );
      } catch (_error) {
        failed = true;
      }
      expect(failed).assertTrue();
      expect(vm.submitError.includes('未配置')).assertTrue();
      expect(vm.tickets.length).assertEqual(0);
    });

    it('submits ticket, records submittedAppVersion, deduplicates retries, and preserves receipt if local save fails', 0, async () => {
      const repo = new InMemoryFeedbackRepo();
      const relay = new StubRelayGateway();
      const vm = new RaisaFeedbackViewModel(repo, relay, new StubIdGenerator(), (): number => 1764000001000);

      await vm.initialize();
      const first = await vm.submit(
        RaisaFeedbackCategory.ARCHIVE_RENDER,
        'SCP-3125 排版错位',
        '第 3 段折叠展开后文字偏右。',
        '',
        true,
        buildSnapshot(true),
        'stable-draft-key'
      );
      expect(first.ticket.ticketCode).assertEqual('RAISA-#101');
      expect(first.ticket.submittedAppVersion).assertEqual('1.2.9 (1020009)');
      expect(first.localSaveWarning).assertEqual('');
      expect(vm.tickets.length).assertEqual(1);

      const persisted = await repo.listTickets();
      expect(persisted.length).assertEqual(1);
      expect(persisted[0].submittedAppVersion).assertEqual('1.2.9 (1020009)');

      // Retrying same draft key returns deduplicated issue without creating duplicate row
      relay.deduplicatedOnNext = true;
      const retry = await vm.submit(
        RaisaFeedbackCategory.ARCHIVE_RENDER,
        'SCP-3125 排版错位',
        '第 3 段折叠展开后文字偏右。',
        '',
        true,
        buildSnapshot(true),
        'stable-draft-key'
      );
      expect(retry.deduplicated).assertTrue();
      expect(vm.tickets.length).assertEqual(1);

      // Next distinct submission when local disk write fails still yields cloud receipt with warning
      relay.deduplicatedOnNext = false;
      relay.nextIssueNumber = 102;
      repo.failSave = true;
      const second = await vm.submit(
        RaisaFeedbackCategory.SYSTEM_PROPOSAL,
        '建议支持书架分类',
        '希望能按主站与 CN 原创分组离线副本。',
        '',
        false,
        buildSnapshot(false)
      );
      expect(second.ticket.issueNumber).assertEqual(102);
      expect(second.localSaveWarning.length > 0).assertTrue();
      expect(vm.tickets.length).assertEqual(2);
      expect(vm.tickets[0].issueNumber).assertEqual(102);
    });

    it('validates attachment limits and forwards valid attachments to relay', 0, async () => {
      const sample = (id: string, bytes: number): RaisaFeedbackAttachment =>
        new RaisaFeedbackAttachment(id, `${id}.png`, 'image/png', bytes, true, `file://${id}.png`, 'iVBORw0KGgo=');

      expect(validateRaisaFeedbackAttachments([])).assertEqual('');
      expect(validateRaisaFeedbackAttachments([sample('a', 1024)])).assertEqual('');
      expect(validateRaisaFeedbackAttachments([
        sample('1', 100), sample('2', 100), sample('3', 100), sample('4', 100)
      ]).includes('最多上传')).assertTrue();
      expect(validateRaisaFeedbackAttachments([
        sample('huge', RAISA_MAX_ATTACHMENT_BYTES + 1)
      ]).includes('单个附件')).assertTrue();
      expect(validateRaisaFeedbackAttachments([
        sample('a', RAISA_MAX_ATTACHMENT_BYTES),
        sample('b', RAISA_MAX_ATTACHMENT_BYTES),
        sample('c', RAISA_MAX_ATTACHMENT_BYTES)
      ]).includes('总大小')).assertTrue();
      expect(formatRaisaAttachmentBytes(1536)).assertEqual('1.5 KB');

      const repo = new InMemoryFeedbackRepo();
      const relay = new StubRelayGateway();
      const vm = new RaisaFeedbackViewModel(repo, relay, new StubIdGenerator());
      const attachment = new RaisaFeedbackAttachment(
        'att-1', 'screenshot.jpg', 'image/jpeg', 2048, true, 'file://screenshot.jpg', '/9j/4AAQ'
      );
      await vm.submit(
        RaisaFeedbackCategory.ARCHIVE_RENDER,
        '折叠块截图上报',
        '附上截图与异常详情说明。',
        '',
        true,
        buildSnapshot(true),
        'att-key-1',
        [attachment]
      );
      expect(relay.submissions.length).assertEqual(1);
      expect(relay.submissions[0].attachments.length).assertEqual(1);
      expect(relay.submissions[0].attachments[0].fileName).assertEqual('screenshot.jpg');
    });
  });
}
