import { IdGeneratorPort } from 'anomiconbasic';
import {
  RAISA_CONTACT_MAX_LENGTH,
  RAISA_DETAILS_MAX_LENGTH,
  RAISA_SUMMARY_MAX_LENGTH,
  RaisaDiagnosticSnapshot,
  RaisaFeedbackAttachment,
  RaisaFeedbackCategory,
  RaisaFeedbackRelayGateway,
  RaisaFeedbackRepository,
  RaisaFeedbackSubmission,
  RaisaFeedbackSubmitResult,
  RaisaFeedbackTicket,
  sanitizeFeedbackMultiline,
  sanitizeFeedbackSingleLine,
  validateRaisaFeedbackAttachments,
  validateRaisaFeedbackInput
} from '../../domain/RaisaFeedbackContracts';

export type RaisaFeedbackViewModelListener = () => void;
export type RaisaFeedbackNowProvider = () => number;

/**
 * Shared state for RAISA feedback submission, GitHub relay dispatch, and locally archived tickets.
 */
@ObservedV2
export class RaisaFeedbackViewModel {
  @Trace tickets: RaisaFeedbackTicket[] = [];
  @Trace loading: boolean = false;
  @Trace initialized: boolean = false;
  @Trace submitting: boolean = false;
  @Trace loadError: string = '';
  @Trace submitError: string = '';
  @Trace lastResult: RaisaFeedbackSubmitResult | undefined = undefined;

  private readonly repository: RaisaFeedbackRepository;
  private readonly relay: RaisaFeedbackRelayGateway;
  private readonly idGenerator: IdGeneratorPort;
  private readonly nowProvider: RaisaFeedbackNowProvider;
  private readonly listeners: RaisaFeedbackViewModelListener[] = [];
  private initialization: Promise<void> | undefined = undefined;
  private operationTail: Promise<void> = Promise.resolve();
  private disposed: boolean = false;

  constructor(
    repository: RaisaFeedbackRepository,
    relay: RaisaFeedbackRelayGateway,
    idGenerator: IdGeneratorPort,
    nowProvider?: RaisaFeedbackNowProvider
  ) {
    this.repository = repository;
    this.relay = relay;
    this.idGenerator = idGenerator;
    this.nowProvider = nowProvider ?? ((): number => Date.now());
  }

  subscribe(listener: RaisaFeedbackViewModelListener): () => void {
    if (this.disposed) {
      return (): void => {};
    }
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
    return (): void => {
      const index = this.listeners.indexOf(listener);
      if (index >= 0) {
        this.listeners.splice(index, 1);
      }
    };
  }

  dispose(): void {
    this.disposed = true;
    this.listeners.length = 0;
  }

  isRelayConfigured(): boolean {
    return this.relay.isConfigured();
  }

  relayEndpoint(): string {
    return this.relay.endpointUrl();
  }

  clearLastResult(): void {
    this.lastResult = undefined;
    this.notify();
  }

  clearSubmitError(): void {
    this.submitError = '';
    this.notify();
  }

  initialize(): Promise<void> {
    if (this.initialization !== undefined) {
      return this.initialization;
    }
    this.initialization = this.enqueue(async (): Promise<void> => {
      this.loading = true;
      this.loadError = '';
      this.notify();
      try {
        await this.repository.initialize();
        const rows = await this.repository.listTickets();
        if (this.disposed) {
          return;
        }
        this.tickets = this.sortTickets(rows);
        this.initialized = true;
      } catch (error) {
        this.initialization = undefined;
        this.loadError = error instanceof Error ? error.message : '读取工单历史失败';
        throw error instanceof Error ? error : new Error(this.loadError);
      } finally {
        this.loading = false;
        this.notify();
      }
    });
    return this.initialization;
  }

  reload(): Promise<void> {
    return this.enqueue(async (): Promise<void> => {
      this.loading = true;
      this.loadError = '';
      this.notify();
      try {
        await this.repository.initialize();
        const rows = await this.repository.listTickets();
        if (this.disposed) {
          return;
        }
        this.tickets = this.sortTickets(rows);
        this.initialized = true;
      } catch (error) {
        this.loadError = error instanceof Error ? error.message : '读取工单历史失败';
        throw error instanceof Error ? error : new Error(this.loadError);
      } finally {
        this.loading = false;
        this.notify();
      }
    });
  }

  async submit(
    category: RaisaFeedbackCategory,
    summary: string,
    details: string,
    contact: string,
    includeDiagnostics: boolean,
    diagnostics: RaisaDiagnosticSnapshot,
    explicitIdempotencyKey: string = '',
    attachments: RaisaFeedbackAttachment[] = []
  ): Promise<RaisaFeedbackSubmitResult> {
    if (this.submitting) {
      throw new Error('工单正在签发中，请稍候');
    }
    const cleanSummary = sanitizeFeedbackSingleLine(summary, RAISA_SUMMARY_MAX_LENGTH);
    const cleanDetails = sanitizeFeedbackMultiline(details, RAISA_DETAILS_MAX_LENGTH);
    const cleanContact = sanitizeFeedbackSingleLine(contact, RAISA_CONTACT_MAX_LENGTH);
    const validationError = validateRaisaFeedbackInput(cleanSummary, cleanDetails);
    if (validationError.length > 0) {
      this.submitError = validationError;
      this.notify();
      throw new Error(validationError);
    }
    const attachmentsError = validateRaisaFeedbackAttachments(attachments);
    if (attachmentsError.length > 0) {
      this.submitError = attachmentsError;
      this.notify();
      throw new Error(attachmentsError);
    }
    if (!this.relay.isConfigured()) {
      const message = '尚未配置 RAISA 中转服务地址，可先复制工单报文或前往 GitHub Issues 提交';
      this.submitError = message;
      this.notify();
      throw new Error(message);
    }

    const key = explicitIdempotencyKey.trim().length > 0 ?
      explicitIdempotencyKey.trim() : this.idGenerator.generate();
    const submission = new RaisaFeedbackSubmission(
      key,
      category,
      cleanSummary,
      cleanDetails,
      cleanContact,
      includeDiagnostics,
      diagnostics,
      attachments
    );

    let outcome: RaisaFeedbackSubmitResult | undefined = undefined;
    await this.enqueue(async (): Promise<void> => {
      this.submitting = true;
      this.submitError = '';
      this.notify();
      try {
        const relayResult = await this.relay.submitTicket(submission);
        const submittedVersion = relayResult.ticket.submittedAppVersion.length > 0 ?
          relayResult.ticket.submittedAppVersion : diagnostics.appVersionLabel;
        const normalizedAt = relayResult.ticket.submittedAt > 0 ?
          relayResult.ticket.submittedAt : this.nowProvider();
        const savedTicket = new RaisaFeedbackTicket(
          relayResult.ticket.ticketId.length > 0 ?
            relayResult.ticket.ticketId : `issue-${relayResult.ticket.issueNumber}`,
          relayResult.ticket.ticketCode,
          relayResult.ticket.issueNumber,
          relayResult.ticket.issueUrl,
          relayResult.ticket.category,
          relayResult.ticket.summary,
          submittedVersion,
          relayResult.ticket.articleId,
          relayResult.ticket.articleTitle,
          normalizedAt
        );

        let localSaveWarning = '';
        try {
          await this.repository.initialize();
          await this.repository.saveTicket(savedTicket);
          this.initialized = true;
        } catch (_persistError) {
          localSaveWarning = '云端工单已成功签发，但本地工单缓存写入失败，请妥善保存上方工单编号。';
        }

        if (!this.disposed) {
          this.tickets = this.upsertTicket(savedTicket);
          outcome = new RaisaFeedbackSubmitResult(
            savedTicket,
            relayResult.deduplicated,
            localSaveWarning
          );
          this.lastResult = outcome;
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : '工单提交失败，请稍后重试';
        this.submitError = message;
        throw error instanceof Error ? error : new Error(message);
      } finally {
        this.submitting = false;
        this.notify();
      }
    });

    if (outcome === undefined) {
      throw new Error('工单提交结果不可用');
    }
    return outcome;
  }

  private upsertTicket(ticket: RaisaFeedbackTicket): RaisaFeedbackTicket[] {
    const next: RaisaFeedbackTicket[] = [ticket];
    for (let index: number = 0; index < this.tickets.length; index++) {
      const existing = this.tickets[index];
      if (existing.ticketId === ticket.ticketId ||
        (ticket.issueNumber > 0 && existing.issueNumber === ticket.issueNumber)) {
        continue;
      }
      next.push(existing);
    }
    return this.sortTickets(next);
  }

  private sortTickets(rows: RaisaFeedbackTicket[]): RaisaFeedbackTicket[] {
    const copied: RaisaFeedbackTicket[] = [];
    for (let index: number = 0; index < rows.length; index++) {
      copied.push(rows[index]);
    }
    copied.sort((left: RaisaFeedbackTicket, right: RaisaFeedbackTicket): number => {
      if (left.submittedAt !== right.submittedAt) {
        return right.submittedAt - left.submittedAt;
      }
      return left.ticketId.localeCompare(right.ticketId);
    });
    return copied;
  }

  private enqueue(task: () => Promise<void>): Promise<void> {
    const run = this.operationTail.then(task, task);
    this.operationTail = run.then((): void => {}, (): void => {});
    return run;
  }

  private notify(): void {
    for (let index: number = 0; index < this.listeners.length; index++) {
      try {
        this.listeners[index]();
      } catch (_error) {
      }
    }
  }
}
