import { rcp } from '@kit.RemoteCommunicationKit';
import { ExternalUrlPolicy } from 'anomiconbasic';
import {
  RAISA_GITHUB_ISSUES_URL,
  RAISA_RELAY_BASE_URL,
  RaisaDiagnosticSnapshot,
  RaisaFeedbackRelayGateway,
  RaisaFeedbackSubmission,
  RaisaFeedbackSubmitResult,
  RaisaFeedbackTicket
} from '../domain/RaisaFeedbackContracts';

interface RelayDiagnosticsPayload {
  appVersion: string;
  appVersionCode: number;
  appVersionLabel: string;
  deviceType: string;
  osLabel: string;
  windowWidthVp: number;
  themeMode: string;
  immersiveMaterial: boolean;
  entrySource: string;
  articleId: string;
  articleTitle: string;
  articleUrl: string;
  renderMode: string;
  revealHiddenText: boolean;
}

interface RelayAttachmentPayload {
  fileName: string;
  mimeType: string;
  base64Data: string;
}

interface RelayTicketRequestPayload {
  category: string;
  summary: string;
  details: string;
  contact: string;
  includeDiagnostics: boolean;
  appVersionLabel: string;
  diagnostics?: RelayDiagnosticsPayload;
  attachments?: RelayAttachmentPayload[];
}

interface RelayTicketResponsePayload {
  ticketCode?: string;
  issueNumber?: number;
  issueUrl?: string;
  createdAt?: string | number;
  deduplicated?: boolean;
  error?: string;
  message?: string;
}

function normalizeRelayBaseUrl(rawUrl: string): string {
  const trimmed = rawUrl.trim();
  if (trimmed.length === 0) {
    return '';
  }
  try {
    const resolved = ExternalUrlPolicy.resolveHttps(trimmed, 'https://localhost/');
    return resolved.endsWith('/') ? resolved.slice(0, resolved.length - 1) : resolved;
  } catch (_error) {
    return '';
  }
}

function buildDiagnosticsPayload(snapshot: RaisaDiagnosticSnapshot): RelayDiagnosticsPayload {
  return {
    appVersion: snapshot.appVersion,
    appVersionCode: snapshot.appVersionCode,
    appVersionLabel: snapshot.appVersionLabel,
    deviceType: snapshot.deviceType,
    osLabel: snapshot.osLabel,
    windowWidthVp: snapshot.windowWidthVp,
    themeMode: snapshot.themeMode,
    immersiveMaterial: snapshot.immersiveMaterial,
    entrySource: snapshot.entrySource,
    articleId: snapshot.articleId,
    articleTitle: snapshot.articleTitle,
    articleUrl: snapshot.articleUrl,
    renderMode: snapshot.renderMode,
    revealHiddenText: snapshot.revealHiddenText
  };
}

function parseTimestampMs(raw: string | number | undefined): number {
  if (typeof raw === 'number' && Number.isFinite(raw) && raw > 0) {
    return Math.floor(raw);
  }
  if (typeof raw === 'string' && raw.trim().length > 0) {
    const parsed = Date.parse(raw.trim());
    if (Number.isFinite(parsed) && parsed > 0) {
      return Math.floor(parsed);
    }
  }
  return Date.now();
}

/**
 * RCP client that dispatches RAISA feedback tickets to the user's self-hosted relay.
 * GitHub App credentials stay strictly on the relay server, never in the client HAP.
 */
export class RaisaFeedbackRelayClient implements RaisaFeedbackRelayGateway {
  private readonly normalizedBaseUrl: string;

  constructor(baseUrl: string = RAISA_RELAY_BASE_URL) {
    this.normalizedBaseUrl = normalizeRelayBaseUrl(baseUrl);
  }

  isConfigured(): boolean {
    return this.normalizedBaseUrl.length > 0;
  }

  endpointUrl(): string {
    return this.normalizedBaseUrl.length > 0 ? `${this.normalizedBaseUrl}/v1/raisa/tickets` : '';
  }

  async submitTicket(submission: RaisaFeedbackSubmission): Promise<RaisaFeedbackSubmitResult> {
    const targetUrl = this.endpointUrl();
    if (targetUrl.length === 0) {
      throw new Error('尚未配置 RAISA 中转服务地址，可先复制工单报文或前往 GitHub Issues 提交');
    }

    const attachmentsPayload: RelayAttachmentPayload[] = [];
    for (let index: number = 0; index < submission.attachments.length; index++) {
      const item = submission.attachments[index];
      attachmentsPayload.push({
        fileName: item.fileName,
        mimeType: item.mimeType,
        base64Data: item.base64Data
      });
    }

    const bodyPayload: RelayTicketRequestPayload = {
      category: submission.category,
      summary: submission.summary,
      details: submission.details,
      contact: submission.contact,
      includeDiagnostics: submission.includeDiagnostics,
      appVersionLabel: submission.diagnostics.appVersionLabel,
      diagnostics: submission.includeDiagnostics ?
        buildDiagnosticsPayload(submission.diagnostics) : undefined,
      attachments: attachmentsPayload.length > 0 ? attachmentsPayload : undefined
    };

    const hasAttachments = attachmentsPayload.length > 0;
    const headers: rcp.RequestHeaders = {
      'content-type': 'application/json; charset=utf-8',
      'accept': 'application/json',
      'x-anomicon-client': 'harmonyos',
      'x-anomicon-version': submission.diagnostics.appVersionLabel,
      'x-idempotency-key': submission.idempotencyKey
    };

    let session: rcp.Session | undefined = undefined;
    try {
      session = rcp.createSession({
        requestConfiguration: {
          transfer: {
            autoRedirect: false,
            timeout: {
              connectMs: 15000,
              transferMs: hasAttachments ? 45000 : 15000,
              inactivityMs: hasAttachments ? 30000 : 15000
            }
          },
          security: {
            remoteValidation: 'system'
          }
        }
      });
      const request = new rcp.Request(targetUrl, 'POST', headers, JSON.stringify(bodyPayload));
      const response = await session.fetch(request);
      const rawBody = response.toString() ?? '';
      const parsed = this.parseJsonSafely(rawBody);

      if (response.statusCode === 413) {
        const detail = parsed?.message ?? parsed?.error ?? '';
        throw new Error(detail.length > 0 ? detail : '附件总大小超出限制，请精简后重试');
      }

      if (response.statusCode === 429) {
        const detail = parsed?.message ?? parsed?.error ?? '';
        throw new Error(detail.length > 0 ? detail : '工单提交过于频繁，请稍后再试');
      }
      if (response.statusCode === 400 || response.statusCode === 422) {
        const detail = parsed?.message ?? parsed?.error ?? '';
        throw new Error(detail.length > 0 ? detail : '工单内容格式未通过服务端校验');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        const detail = parsed?.message ?? parsed?.error ?? '';
        throw new Error(detail.length > 0 ?
          `RAISA 中转服务响应异常（HTTP ${response.statusCode}）：${detail}` :
          `RAISA 中转服务响应异常（HTTP ${response.statusCode}）`);
      }

      if (parsed === undefined || typeof parsed.issueNumber !== 'number' || parsed.issueNumber <= 0) {
        throw new Error('中转服务返回回执格式无效，请检查服务端配置');
      }

      const issueNumber = Math.floor(parsed.issueNumber);
      const fallbackUrl = `${RAISA_GITHUB_ISSUES_URL}/${issueNumber}`;
      const issueUrl = this.safeIssueUrl(parsed.issueUrl ?? '', fallbackUrl);
      const ticketCode = typeof parsed.ticketCode === 'string' && parsed.ticketCode.trim().length > 0 ?
        parsed.ticketCode.trim() : `RAISA-#${issueNumber}`;
      const submittedAt = parseTimestampMs(parsed.createdAt);
      const ticketId = `issue-${issueNumber}`;

      const ticket = new RaisaFeedbackTicket(
        ticketId,
        ticketCode,
        issueNumber,
        issueUrl,
        submission.category,
        submission.summary,
        submission.diagnostics.appVersionLabel,
        submission.includeDiagnostics ? submission.diagnostics.articleId : '',
        submission.includeDiagnostics ? submission.diagnostics.articleTitle : '',
        submittedAt
      );
      return new RaisaFeedbackSubmitResult(ticket, parsed.deduplicated === true);
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('连接 RAISA 中转服务失败，请检查网络或服务状态');
    } finally {
      if (session !== undefined) {
        try {
          session.close();
        } catch (_error) {
        }
      }
    }
  }

  private parseJsonSafely(raw: string): RelayTicketResponsePayload | undefined {
    const trimmed = raw.trim();
    if (trimmed.length === 0) {
      return undefined;
    }
    try {
      return JSON.parse(trimmed) as RelayTicketResponsePayload;
    } catch (_error) {
      return undefined;
    }
  }

  private safeIssueUrl(candidate: string, fallback: string): string {
    const trimmed = candidate.trim();
    if (trimmed.length === 0) {
      return fallback;
    }
    try {
      return ExternalUrlPolicy.resolveHttps(trimmed, RAISA_GITHUB_ISSUES_URL);
    } catch (_error) {
      return fallback;
    }
  }
}
