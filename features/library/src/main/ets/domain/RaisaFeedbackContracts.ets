/**
 * Domain contracts, validation, diagnostic formatting, and offline fallback formatting
 * for RAISA Archive System Feedback.
 *
 * When the overseas RAISA relay service (`tools/raisa-relay/`) is deployed behind your
 * Cloudflare subdomain, set `RAISA_RELAY_BASE_URL` to e.g. `https://raisa.example.com`.
 */
export const RAISA_RELAY_BASE_URL: string = 'https://raisa.xiaotau.com';

export const RAISA_GITHUB_ISSUES_URL: string = 'https://github.com/Suixin04/Anomicon/issues';

export const RAISA_SUMMARY_MIN_LENGTH: number = 4;
export const RAISA_SUMMARY_MAX_LENGTH: number = 80;
export const RAISA_DETAILS_MIN_LENGTH: number = 8;
export const RAISA_DETAILS_MAX_LENGTH: number = 2000;
export const RAISA_CONTACT_MAX_LENGTH: number = 64;
export const RAISA_MAX_ATTACHMENTS: number = 3;
export const RAISA_MAX_ATTACHMENT_BYTES: number = 2 * 1024 * 1024;
export const RAISA_MAX_TOTAL_ATTACHMENT_BYTES: number = 5 * 1024 * 1024;

export enum RaisaFeedbackCategory {
  ARCHIVE_RENDER = 'archive_render',
  TERMINAL_BUG = 'terminal_bug',
  ARCHIVE_3D = 'archive_3d',
  SYSTEM_PROPOSAL = 'system_proposal'
}

export class RaisaFeedbackCategoryDescriptor {
  readonly category: RaisaFeedbackCategory;
  readonly title: string;
  readonly shortTag: string;
  readonly githubLabel: string;
  readonly subtitle: string;
  readonly summaryPlaceholder: string;

  constructor(
    category: RaisaFeedbackCategory,
    title: string,
    shortTag: string,
    githubLabel: string,
    subtitle: string,
    summaryPlaceholder: string
  ) {
    this.category = category;
    this.title = title;
    this.shortTag = shortTag;
    this.githubLabel = githubLabel;
    this.subtitle = subtitle;
    this.summaryPlaceholder = summaryPlaceholder;
  }
}

export const RAISA_FEEDBACK_CATEGORIES: RaisaFeedbackCategoryDescriptor[] = [
  new RaisaFeedbackCategoryDescriptor(
    RaisaFeedbackCategory.ARCHIVE_RENDER,
    '档案解析异常',
    '档案解析',
    'type:render',
    '排版错位、折叠块、表格或配图异常',
    '例：SCP-3125 第 3 个折叠块展开后排版异常'
  ),
  new RaisaFeedbackCategoryDescriptor(
    RaisaFeedbackCategory.TERMINAL_BUG,
    '终端运行故障',
    '终端故障',
    'type:bug',
    '闪退、卡顿、离线副本或搜索异常',
    '例：离线书架重新打开后未恢复上次位置'
  ),
  new RaisaFeedbackCategoryDescriptor(
    RaisaFeedbackCategory.ARCHIVE_3D,
    '三维收容异常',
    '三维档案',
    'type:3d',
    '三维模型下载、校验或观察舞台异常',
    '例：SCP-131 下载完成后模型加载空白'
  ),
  new RaisaFeedbackCategoryDescriptor(
    RaisaFeedbackCategory.SYSTEM_PROPOSAL,
    '系统演进提案',
    '功能提案',
    'type:feature',
    '新功能构想、阅读体验与界面改进',
    '例：希望离线书架支持按系列分组筛选'
  )
];

export function parseRaisaFeedbackCategory(raw: string): RaisaFeedbackCategory {
  const normalized = raw.trim().toLowerCase();
  if (normalized === RaisaFeedbackCategory.ARCHIVE_RENDER) {
    return RaisaFeedbackCategory.ARCHIVE_RENDER;
  }
  if (normalized === RaisaFeedbackCategory.ARCHIVE_3D) {
    return RaisaFeedbackCategory.ARCHIVE_3D;
  }
  if (normalized === RaisaFeedbackCategory.SYSTEM_PROPOSAL) {
    return RaisaFeedbackCategory.SYSTEM_PROPOSAL;
  }
  return RaisaFeedbackCategory.TERMINAL_BUG;
}

export function findRaisaFeedbackCategoryDescriptor(
  category: RaisaFeedbackCategory
): RaisaFeedbackCategoryDescriptor {
  for (let index: number = 0; index < RAISA_FEEDBACK_CATEGORIES.length; index++) {
    if (RAISA_FEEDBACK_CATEGORIES[index].category === category) {
      return RAISA_FEEDBACK_CATEGORIES[index];
    }
  }
  return RAISA_FEEDBACK_CATEGORIES[1];
}

export class RaisaFeedbackContext {
  readonly entrySource: string;
  readonly initialCategory: RaisaFeedbackCategory;
  readonly articleId: string;
  readonly articleTitle: string;
  readonly articleKind: string;
  readonly articleUrl: string;
  readonly renderMode: string;
  readonly revealHiddenText: boolean;

  constructor(
    entrySource: string,
    initialCategory: RaisaFeedbackCategory,
    articleId: string = '',
    articleTitle: string = '',
    articleKind: string = '',
    articleUrl: string = '',
    renderMode: string = '',
    revealHiddenText: boolean = false
  ) {
    this.entrySource = entrySource.trim().length > 0 ? entrySource.trim() : 'settings';
    this.initialCategory = initialCategory;
    this.articleId = articleId.trim();
    this.articleTitle = articleTitle.trim();
    this.articleKind = articleKind.trim();
    this.articleUrl = articleUrl.trim();
    this.renderMode = renderMode.trim();
    this.revealHiddenText = revealHiddenText;
  }

  hasArticleContext(): boolean {
    return this.articleId.length > 0 || this.articleTitle.length > 0 || this.articleUrl.length > 0;
  }
}

export function emptyRaisaFeedbackContext(entrySource: string = 'settings'): RaisaFeedbackContext {
  return new RaisaFeedbackContext(entrySource, RaisaFeedbackCategory.TERMINAL_BUG);
}

export class RaisaDiagnosticSnapshot {
  readonly appVersion: string;
  readonly appVersionCode: number;
  readonly appVersionLabel: string;
  readonly deviceType: string;
  readonly osLabel: string;
  readonly windowWidthVp: number;
  readonly themeMode: string;
  readonly immersiveMaterial: boolean;
  readonly entrySource: string;
  readonly articleId: string;
  readonly articleTitle: string;
  readonly articleUrl: string;
  readonly renderMode: string;
  readonly revealHiddenText: boolean;

  constructor(
    appVersion: string,
    appVersionCode: number,
    appVersionLabel: string,
    deviceType: string,
    osLabel: string,
    windowWidthVp: number,
    themeMode: string,
    immersiveMaterial: boolean,
    entrySource: string,
    articleId: string = '',
    articleTitle: string = '',
    articleUrl: string = '',
    renderMode: string = '',
    revealHiddenText: boolean = false
  ) {
    this.appVersion = appVersion.trim();
    this.appVersionCode = appVersionCode;
    this.appVersionLabel = appVersionLabel.trim().length > 0 ?
      appVersionLabel.trim() : this.appVersion;
    this.deviceType = deviceType.trim().length > 0 ? deviceType.trim() : 'unknown';
    this.osLabel = osLabel.trim().length > 0 ? osLabel.trim() : 'HarmonyOS';
    this.windowWidthVp = Math.max(0, Math.round(windowWidthVp));
    this.themeMode = themeMode.trim().length > 0 ? themeMode.trim() : 'system';
    this.immersiveMaterial = immersiveMaterial;
    this.entrySource = entrySource.trim().length > 0 ? entrySource.trim() : 'settings';
    this.articleId = articleId.trim();
    this.articleTitle = articleTitle.trim();
    this.articleUrl = articleUrl.trim();
    this.renderMode = renderMode.trim();
    this.revealHiddenText = revealHiddenText;
  }
}

export class RaisaFeedbackAttachment {
  readonly id: string;
  readonly fileName: string;
  readonly mimeType: string;
  readonly byteLength: number;
  readonly isImage: boolean;
  readonly previewUri: string;
  readonly base64Data: string;

  constructor(
    id: string,
    fileName: string,
    mimeType: string,
    byteLength: number,
    isImage: boolean,
    previewUri: string,
    base64Data: string
  ) {
    this.id = id.trim();
    this.fileName = fileName.trim();
    this.mimeType = mimeType.trim().toLowerCase();
    this.byteLength = Math.max(0, Math.floor(byteLength));
    this.isImage = isImage;
    this.previewUri = previewUri.trim();
    this.base64Data = base64Data.trim();
  }
}

export class RaisaFeedbackSubmission {
  readonly idempotencyKey: string;
  readonly category: RaisaFeedbackCategory;
  readonly summary: string;
  readonly details: string;
  readonly contact: string;
  readonly includeDiagnostics: boolean;
  readonly diagnostics: RaisaDiagnosticSnapshot;
  readonly attachments: RaisaFeedbackAttachment[];

  constructor(
    idempotencyKey: string,
    category: RaisaFeedbackCategory,
    summary: string,
    details: string,
    contact: string,
    includeDiagnostics: boolean,
    diagnostics: RaisaDiagnosticSnapshot,
    attachments: RaisaFeedbackAttachment[] = []
  ) {
    this.idempotencyKey = idempotencyKey.trim();
    this.category = category;
    this.summary = summary;
    this.details = details;
    this.contact = contact;
    this.includeDiagnostics = includeDiagnostics;
    this.diagnostics = diagnostics;
    this.attachments = attachments.slice();
  }
}

export class RaisaFeedbackTicket {
  readonly ticketId: string;
  readonly ticketCode: string;
  readonly issueNumber: number;
  readonly issueUrl: string;
  readonly category: RaisaFeedbackCategory;
  readonly summary: string;
  readonly submittedAppVersion: string;
  readonly articleId: string;
  readonly articleTitle: string;
  readonly submittedAt: number;

  constructor(
    ticketId: string,
    ticketCode: string,
    issueNumber: number,
    issueUrl: string,
    category: RaisaFeedbackCategory,
    summary: string,
    submittedAppVersion: string,
    articleId: string,
    articleTitle: string,
    submittedAt: number
  ) {
    this.ticketId = ticketId.trim();
    this.ticketCode = ticketCode.trim();
    this.issueNumber = Math.max(0, Math.floor(issueNumber));
    this.issueUrl = issueUrl.trim();
    this.category = category;
    this.summary = summary.trim();
    this.submittedAppVersion = submittedAppVersion.trim();
    this.articleId = articleId.trim();
    this.articleTitle = articleTitle.trim();
    this.submittedAt = submittedAt;
  }
}

export class RaisaFeedbackSubmitResult {
  readonly ticket: RaisaFeedbackTicket;
  readonly deduplicated: boolean;
  readonly localSaveWarning: string;

  constructor(
    ticket: RaisaFeedbackTicket,
    deduplicated: boolean = false,
    localSaveWarning: string = ''
  ) {
    this.ticket = ticket;
    this.deduplicated = deduplicated;
    this.localSaveWarning = localSaveWarning;
  }
}

export interface RaisaFeedbackRepository {
  initialize(): Promise<void>;
  listTickets(): Promise<RaisaFeedbackTicket[]>;
  saveTicket(ticket: RaisaFeedbackTicket): Promise<RaisaFeedbackTicket>;
  deleteTicket(ticketId: string): Promise<void>;
}

export interface RaisaFeedbackRelayGateway {
  isConfigured(): boolean;
  endpointUrl(): string;
  submitTicket(submission: RaisaFeedbackSubmission): Promise<RaisaFeedbackSubmitResult>;
}

export interface RaisaAttachmentPickerPort {
  pickImages(maxCount: number): Promise<RaisaFeedbackAttachment[]>;
  pickDocuments(maxCount: number): Promise<RaisaFeedbackAttachment[]>;
}

export function sanitizeFeedbackSingleLine(raw: string, maxLength: number): string {
  const collapsed = raw.replace(/[\r\n\t]+/g, ' ').replace(/\s{2,}/g, ' ').trim();
  return collapsed.length > maxLength ? collapsed.slice(0, maxLength) : collapsed;
}

export function sanitizeFeedbackMultiline(raw: string, maxLength: number): string {
  const normalized = raw.replace(/\r\n/g, '\n').replace(/\r/g, '\n').trim();
  return normalized.length > maxLength ? normalized.slice(0, maxLength) : normalized;
}

export function validateRaisaFeedbackInput(summary: string, details: string): string {
  const cleanSummary = sanitizeFeedbackSingleLine(summary, RAISA_SUMMARY_MAX_LENGTH);
  if (cleanSummary.length < RAISA_SUMMARY_MIN_LENGTH) {
    return `工单简述至少填写 ${RAISA_SUMMARY_MIN_LENGTH} 个字符`;
  }
  const cleanDetails = sanitizeFeedbackMultiline(details, RAISA_DETAILS_MAX_LENGTH);
  if (cleanDetails.length < RAISA_DETAILS_MIN_LENGTH) {
    return `详细说明至少填写 ${RAISA_DETAILS_MIN_LENGTH} 个字符，便于快速定位问题`;
  }
  return '';
}

export function validateRaisaFeedbackAttachments(attachments: RaisaFeedbackAttachment[]): string {
  if (attachments.length > RAISA_MAX_ATTACHMENTS) {
    return `最多上传 ${RAISA_MAX_ATTACHMENTS} 个附件`;
  }
  let totalBytes = 0;
  for (let index: number = 0; index < attachments.length; index++) {
    const item = attachments[index];
    if (item.fileName.length === 0 || item.base64Data.length === 0 || item.byteLength <= 0) {
      return `附件内容无效：${item.fileName.length > 0 ? item.fileName : '未知文件'}`;
    }
    if (item.byteLength > RAISA_MAX_ATTACHMENT_BYTES) {
      return `单个附件不能超过 ${formatRaisaAttachmentBytes(RAISA_MAX_ATTACHMENT_BYTES)}：${item.fileName}`;
    }
    totalBytes += item.byteLength;
  }
  if (totalBytes > RAISA_MAX_TOTAL_ATTACHMENT_BYTES) {
    return `所有附件总大小不能超过 ${formatRaisaAttachmentBytes(RAISA_MAX_TOTAL_ATTACHMENT_BYTES)}`;
  }
  return '';
}

export function formatRaisaAttachmentBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) {
    return '0 B';
  }
  if (bytes < 1024) {
    return `${Math.round(bytes)} B`;
  }
  if (bytes < 1024 * 1024) {
    return `${(bytes / 1024).toFixed(1)} KB`;
  }
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function renderModeDisplayLabel(renderMode: string): string {
  if (renderMode === 'native') {
    return '原生阅读';
  }
  if (renderMode === 'web') {
    return '原版网页';
  }
  if (renderMode === 'offline') {
    return '离线副本';
  }
  return renderMode.length > 0 ? renderMode : '未提供';
}

function entrySourceDisplayLabel(entrySource: string): string {
  if (entrySource === 'article') {
    return '条目菜单上报';
  }
  if (entrySource === 'foundation') {
    return '基金会中心页';
  }
  if (entrySource === 'settings') {
    return '系统设置';
  }
  return entrySource.length > 0 ? entrySource : '系统设置';
}

export function formatRaisaDiagnosticLines(snapshot: RaisaDiagnosticSnapshot): string[] {
  const lines: string[] = [
    `应用版本：${snapshot.appVersionLabel.length > 0 ? snapshot.appVersionLabel : '未知'}`,
    `设备形态：${snapshot.deviceType} · 视口宽度 ${snapshot.windowWidthVp} vp`,
    `系统环境：${snapshot.osLabel}`,
    `界面材质：主题 ${snapshot.themeMode} · 沉浸光感 ${snapshot.immersiveMaterial ? '开启' : '关闭'}`,
    `工单入口：${entrySourceDisplayLabel(snapshot.entrySource)}`
  ];
  if (snapshot.articleId.length > 0 || snapshot.articleTitle.length > 0) {
    const target = snapshot.articleTitle.length > 0 && snapshot.articleId.length > 0 ?
      `${snapshot.articleTitle} (${snapshot.articleId})` :
      (snapshot.articleTitle.length > 0 ? snapshot.articleTitle : snapshot.articleId);
    lines.push(`关联档案：${target}`);
  }
  if (snapshot.renderMode.length > 0) {
    lines.push(
      `阅读模式：${renderModeDisplayLabel(snapshot.renderMode)} · 反白透视 ${snapshot.revealHiddenText ? '开启' : '关闭'}`
    );
  }
  if (snapshot.articleUrl.length > 0) {
    lines.push(`档案地址：${snapshot.articleUrl}`);
  }
  return lines;
}

export function formatRaisaTicketPlainReport(
  category: RaisaFeedbackCategory,
  summary: string,
  details: string,
  contact: string,
  includeDiagnostics: boolean,
  snapshot: RaisaDiagnosticSnapshot
): string {
  const descriptor = findRaisaFeedbackCategoryDescriptor(category);
  const cleanSummary = sanitizeFeedbackSingleLine(summary, RAISA_SUMMARY_MAX_LENGTH);
  const cleanDetails = sanitizeFeedbackMultiline(details, RAISA_DETAILS_MAX_LENGTH);
  const cleanContact = sanitizeFeedbackSingleLine(contact, RAISA_CONTACT_MAX_LENGTH);
  const lines: string[] = [
    `[RAISA 工单报文 // ${descriptor.title}]`,
    `简述：${cleanSummary.length > 0 ? cleanSummary : '(未填写简述)'}`,
    `说明：\n${cleanDetails.length > 0 ? cleanDetails : '(未填写详细说明)'}`
  ];
  if (cleanContact.length > 0) {
    lines.push(`联络代号：${cleanContact}`);
  }
  lines.push(`提交版本：${snapshot.appVersionLabel.length > 0 ? snapshot.appVersionLabel : snapshot.appVersion}`);
  if (includeDiagnostics) {
    lines.push('--- 终端诊断快照 ---');
    const diagnosticLines = formatRaisaDiagnosticLines(snapshot);
    for (let index: number = 0; index < diagnosticLines.length; index++) {
      lines.push(diagnosticLines[index]);
    }
  }
  return lines.join('\n');
}

function padTwoDigits(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

export function formatRaisaTicketTimestamp(timestampMs: number): string {
  if (!Number.isFinite(timestampMs) || timestampMs <= 0) {
    return '时间未知';
  }
  const date = new Date(timestampMs);
  const year = date.getFullYear();
  const month = padTwoDigits(date.getMonth() + 1);
  const day = padTwoDigits(date.getDate());
  const hour = padTwoDigits(date.getHours());
  const minute = padTwoDigits(date.getMinutes());
  return `${year}-${month}-${day} ${hour}:${minute}`;
}
