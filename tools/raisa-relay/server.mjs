#!/usr/bin/env node
/**
 * Anomicon RAISA Relay — zero-dependency Node.js >= 20 HTTP service.
 *
 * Holds the dedicated GitHub App private key on the server, validates and
 * rate-limits feedback tickets submitted by the HarmonyOS client, mints a
 * short-lived installation token, and opens a GitHub Issue on the target repo.
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';

const MAX_BODY_BYTES = 32 * 1024;
const SUMMARY_MIN_LEN = 4;
const SUMMARY_MAX_LEN = 80;
const DETAILS_MIN_LEN = 8;
const DETAILS_MAX_LEN = 2000;
const CONTACT_MAX_LEN = 64;
const MAX_IDEMPOTENCY_ENTRIES = 2000;
const IDEMPOTENCY_TTL_MS = 24 * 60 * 60 * 1000;
const TOKEN_REFRESH_MARGIN_MS = 5 * 60 * 1000;

export const CATEGORY_CONFIG = Object.freeze({
  archive_render: { title: '档案解析异常', label: 'type:render' },
  terminal_bug: { title: '终端运行故障', label: 'type:bug' },
  archive_3d: { title: '三维收容异常', label: 'type:3d' },
  system_proposal: { title: '系统演进提案', label: 'type:feature' }
});

/** Load key=value pairs from a local .env file without overriding existing env vars. */
export function loadDotEnv(filePath) {
  if (!filePath || !fs.existsSync(filePath)) {
    return;
  }
  const content = fs.readFileSync(filePath, 'utf8');
  for (const rawLine of content.split(/\r?\n/)) {
    const trimmed = rawLine.trim();
    if (trimmed.length === 0 || trimmed.startsWith('#')) {
      continue;
    }
    const eqIndex = trimmed.indexOf('=');
    if (eqIndex <= 0) {
      continue;
    }
    const key = trimmed.slice(0, eqIndex).trim();
    let value = trimmed.slice(eqIndex + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

function base64UrlEncode(input) {
  return Buffer.from(input).toString('base64url');
}

/** Sign a short-lived RS256 GitHub App JWT (max 10 minutes per GitHub docs). */
export function signGitHubAppJwt(appId, privateKeyPem, nowSeconds = Math.floor(Date.now() / 1000)) {
  const normalizedAppId = String(appId ?? '').trim();
  if (!normalizedAppId) {
    throw new Error('Missing GITHUB_APP_ID');
  }
  const header = base64UrlEncode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = base64UrlEncode(JSON.stringify({
    iat: nowSeconds - 60,
    exp: nowSeconds + 540,
    iss: normalizedAppId
  }));
  const signingInput = `${header}.${payload}`;
  const signature = crypto.createSign('RSA-SHA256')
    .update(signingInput)
    .end()
    .sign(privateKeyPem, 'base64url');
  return `${signingInput}.${signature}`;
}

export function sanitizeSingleLine(value, maxLength) {
  const text = String(value ?? '').replace(/[\r\n\t]+/g, ' ').replace(/\s{2,}/g, ' ').trim();
  return text.length > maxLength ? text.slice(0, maxLength) : text;
}

export function sanitizeMultiline(value, maxLength) {
  const text = String(value ?? '').replace(/\r\n/g, '\n').replace(/\r/g, '\n').trim();
  return text.length > maxLength ? text.slice(0, maxLength) : text;
}

/** Neutralize @mentions and raw HTML brackets in untrusted user-submitted Markdown. */
export function escapeMarkdownMentionsAndHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/@([A-Za-z0-9_-]+)/g, '@\u200B$1');
}

function safeHttpsUrl(raw) {
  const text = sanitizeSingleLine(raw, 400);
  if (!text) {
    return '';
  }
  try {
    const parsed = new URL(text);
    if (parsed.protocol === 'https:' && !parsed.username && !parsed.password) {
      return parsed.href;
    }
  } catch (_error) {
  }
  return '';
}

function normalizeRenderMode(mode) {
  if (mode === 'native') return '原生阅读';
  if (mode === 'web') return '原版网页';
  if (mode === 'offline') return '离线副本';
  return sanitizeSingleLine(mode, 32) || '未提供';
}

function normalizeEntrySource(source) {
  if (source === 'article') return '条目菜单上报';
  if (source === 'foundation') return '基金会中心页';
  if (source === 'settings') return '系统设置';
  return sanitizeSingleLine(source, 32) || '未提供';
}

/** Validate client payload and format the GitHub Issue payload. */
export function validateAndFormatTicket(payload) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    return { error: '请求正文必须为 JSON 对象' };
  }

  const category = sanitizeSingleLine(payload.category, 32).toLowerCase();
  const categoryMeta = CATEGORY_CONFIG[category];
  if (!categoryMeta) {
    return { error: '不支持的工单分类' };
  }

  const summary = sanitizeSingleLine(payload.summary, SUMMARY_MAX_LEN);
  if (summary.length < SUMMARY_MIN_LEN) {
    return { error: `工单简述至少填写 ${SUMMARY_MIN_LEN} 个字符` };
  }

  const details = sanitizeMultiline(payload.details, DETAILS_MAX_LEN);
  if (details.length < DETAILS_MIN_LEN) {
    return { error: `详细说明至少填写 ${DETAILS_MIN_LEN} 个字符` };
  }

  const contact = sanitizeSingleLine(payload.contact, CONTACT_MAX_LEN);
  const includeDiagnostics = payload.includeDiagnostics !== false;
  const diag = payload.diagnostics && typeof payload.diagnostics === 'object' ? payload.diagnostics : {};

  const appVersionLabel = sanitizeSingleLine(
    diag.appVersionLabel || payload.appVersionLabel || diag.appVersion || '',
    48
  );
  const issueTitle = `[${categoryMeta.title}] ${summary}`;

  const bodyLines = [
    `> 由 **格异录 Anomicon** 客户端 RAISA 运维通道自动提交${appVersionLabel ? ` · 版本 \`${appVersionLabel}\`` : ''}`,
    '',
    '### 详细说明',
    '',
    escapeMarkdownMentionsAndHtml(details)
  ];

  if (contact.length > 0) {
    bodyLines.push('', `**联络代号**：\`${contact}\``);
  }

  if (includeDiagnostics) {
    const safeUrl = safeHttpsUrl(diag.articleUrl);
    const articleId = sanitizeSingleLine(diag.articleId, 80);
    const articleTitle = escapeMarkdownMentionsAndHtml(sanitizeSingleLine(diag.articleTitle, 160));
    const deviceType = sanitizeSingleLine(diag.deviceType, 32) || 'unknown';
    const osLabel = sanitizeSingleLine(diag.osLabel, 64) || 'HarmonyOS';
    const widthVp = Number.isFinite(Number(diag.windowWidthVp)) ? Math.max(0, Math.round(Number(diag.windowWidthVp))) : 0;
    const themeMode = sanitizeSingleLine(diag.themeMode, 24) || '未知';
    const immersiveMaterial = typeof diag.immersiveMaterial === 'boolean' ?
      (diag.immersiveMaterial ? '开启' : '关闭') : '未知';
    const entrySource = normalizeEntrySource(diag.entrySource);
    const renderMode = diag.renderMode ? normalizeRenderMode(diag.renderMode) : '';
    const revealHidden = diag.revealHiddenText === true ? '开启' : '关闭';

    bodyLines.push(
      '',
      '<details>',
      '<summary>终端诊断快照</summary>',
      '',
      '| 字段 | 值 |',
      '|---|---|',
      `| 工单分类 | \`${category}\` (${categoryMeta.title}) |`,
      `| 应用版本 | ${appVersionLabel ? `\`${appVersionLabel}\`` : '未知'} |`,
      `| 设备与视口 | \`${deviceType}\` · ${widthVp} vp |`,
      `| 系统环境 | ${escapeMarkdownMentionsAndHtml(osLabel)} |`,
      `| 界面与材质 | 主题 ${escapeMarkdownMentionsAndHtml(themeMode)} · 沉浸光感 ${immersiveMaterial} |`,
      `| 工单入口 | ${escapeMarkdownMentionsAndHtml(entrySource)} |`
    );
    if (articleId || articleTitle) {
      const targetText = articleTitle && articleId ? `${articleTitle} (\`${articleId}\`)` : (articleTitle || `\`${articleId}\``);
      bodyLines.push(`| 关联档案 | ${targetText} |`);
    }
    if (renderMode) {
      bodyLines.push(`| 阅读模式 | ${renderMode} · 反白透视 ${revealHidden} |`);
    }
    if (safeUrl) {
      bodyLines.push(`| 档案地址 | ${safeUrl} |`);
    }
    bodyLines.push('', '</details>');
  }

  return {
    category,
    categoryMeta,
    summary,
    issueTitle,
    issueBody: bodyLines.join('\n'),
    labels: ['raisa-feedback', categoryMeta.label]
  };
}

/** Sliding-window per-IP limiter protecting the repository from spam bursts. */
export function createRateLimiter({
  hourlyLimit = 5,
  burstLimit = 3,
  burstWindowMs = 10 * 60 * 1000,
  hourlyWindowMs = 60 * 60 * 1000,
  nowFn = () => Date.now()
} = {}) {
  const buckets = new Map();

  function prune(list, now) {
    const cutoff = now - hourlyWindowMs;
    while (list.length > 0 && list[0] <= cutoff) {
      list.shift();
    }
  }

  return {
    checkAndConsume(ip) {
      const key = String(ip || 'unknown');
      const now = nowFn();
      let list = buckets.get(key);
      if (!list) {
        list = [];
        buckets.set(key, list);
      }
      prune(list, now);

      if (list.length >= hourlyLimit) {
        const retryAfterSec = Math.max(1, Math.ceil((list[0] + hourlyWindowMs - now) / 1000));
        return { allowed: false, retryAfterSec };
      }

      const burstCutoff = now - burstWindowMs;
      const recentBurst = list.filter((ts) => ts > burstCutoff);
      if (recentBurst.length >= burstLimit) {
        const retryAfterSec = Math.max(1, Math.ceil((recentBurst[0] + burstWindowMs - now) / 1000));
        return { allowed: false, retryAfterSec };
      }

      list.push(now);
      if (buckets.size > 5000) {
        for (const [entryKey, timestamps] of buckets.entries()) {
          prune(timestamps, now);
          if (timestamps.length === 0) {
            buckets.delete(entryKey);
          }
        }
      }
      return { allowed: true, retryAfterSec: 0 };
    }
  };
}

class GitHubAppClient {
  constructor(config) {
    this.appId = config.appId;
    this.installationId = config.installationId;
    this.privateKeyPem = config.privateKeyPem;
    this.owner = config.owner;
    this.repo = config.repo;
    this.apiBase = (config.githubApiBase || 'https://api.github.com').replace(/\/+$/, '');
    this.cachedToken = '';
    this.cachedExpiresAtMs = 0;
  }

  async getInstallationToken() {
    if (this.cachedToken && Date.now() + TOKEN_REFRESH_MARGIN_MS < this.cachedExpiresAtMs) {
      return this.cachedToken;
    }
    const jwt = signGitHubAppJwt(this.appId, this.privateKeyPem);
    const url = `${this.apiBase}/app/installations/${encodeURIComponent(this.installationId)}/access_tokens`;
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': `Bearer ${jwt}`,
        'User-Agent': 'anomicon-raisa-relay/1.0',
        'X-GitHub-Api-Version': '2022-11-28'
      },
      signal: AbortSignal.timeout(10000)
    });
    if (!response.ok) {
      const text = await response.text().catch(() => '');
      throw new Error(`GitHub 签发 Installation Token 失败（HTTP ${response.status}）${text ? `: ${text.slice(0, 200)}` : ''}`);
    }
    const data = await response.json();
    if (!data || typeof data.token !== 'string') {
      throw new Error('GitHub Installation Token 响应缺少 token 字段');
    }
    this.cachedToken = data.token;
    const parsedExpiry = Date.parse(data.expires_at ?? '');
    this.cachedExpiresAtMs = Number.isFinite(parsedExpiry) ? parsedExpiry : Date.now() + 50 * 60 * 1000;
    return this.cachedToken;
  }

  async createIssue({ title, body, labels }) {
    const token = await this.getInstallationToken();
    const url = `${this.apiBase}/repos/${this.owner}/${this.repo}/issues`;
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json; charset=utf-8',
        'User-Agent': 'anomicon-raisa-relay/1.0',
        'X-GitHub-Api-Version': '2022-11-28'
      },
      body: JSON.stringify({ title, body, labels }),
      signal: AbortSignal.timeout(12000)
    });
    if (!response.ok) {
      // Clear cached token on 401 so next request refreshes cleanly.
      if (response.status === 401) {
        this.cachedToken = '';
        this.cachedExpiresAtMs = 0;
      }
      const text = await response.text().catch(() => '');
      throw new Error(`GitHub 创建 Issue 失败（HTTP ${response.status}）${text ? `: ${text.slice(0, 200)}` : ''}`);
    }
    const data = await response.json();
    return {
      issueNumber: Number(data.number),
      issueUrl: String(data.html_url || `https://github.com/${this.owner}/${this.repo}/issues/${data.number}`),
      createdAt: String(data.created_at || new Date().toISOString())
    };
  }
}

function sendJson(res, statusCode, payload, extraHeaders = {}) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    ...extraHeaders
  });
  res.end(body);
}

function readJsonBody(req, maxBytes = MAX_BODY_BYTES) {
  return new Promise((resolve, reject) => {
    const contentLength = Number(req.headers['content-length'] ?? 0);
    if (Number.isFinite(contentLength) && contentLength > maxBytes) {
      reject(Object.assign(new Error('请求体过大'), { statusCode: 413 }));
      return;
    }
    const chunks = [];
    let total = 0;
    let settled = false;
    req.on('data', (chunk) => {
      if (settled) return;
      total += chunk.length;
      if (total > maxBytes) {
        settled = true;
        req.destroy();
        reject(Object.assign(new Error('请求体超过 32KB 限制'), { statusCode: 413 }));
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (settled) return;
      settled = true;
      const raw = Buffer.concat(chunks).toString('utf8');
      try {
        resolve(JSON.parse(raw));
      } catch (_error) {
        reject(Object.assign(new Error('无效的 JSON 请求体'), { statusCode: 400 }));
      }
    });
    req.on('error', (error) => {
      if (settled) return;
      settled = true;
      reject(error);
    });
  });
}

function resolveClientIp(req, trustProxy) {
  if (trustProxy) {
    const cfIp = String(req.headers['cf-connecting-ip'] ?? '').trim();
    if (cfIp) return cfIp;
    const forwarded = String(req.headers['x-forwarded-for'] ?? '').split(',')[0].trim();
    if (forwarded) return forwarded;
  }
  return req.socket?.remoteAddress || 'unknown';
}

export function createRelayApp(config, dependencies = {}) {
  const owner = sanitizeSingleLine(config.owner || 'Suixin04', 80);
  const repo = sanitizeSingleLine(config.repo || 'Anomicon', 80);
  if (!/^[A-Za-z0-9_.-]+$/.test(owner) || !/^[A-Za-z0-9_.-]+$/.test(repo)) {
    throw new Error('GITHUB_OWNER 或 GITHUB_REPO 格式无效');
  }

  const githubClient = dependencies.githubClient ?? new GitHubAppClient({
    appId: config.appId,
    installationId: config.installationId,
    privateKeyPem: config.privateKeyPem,
    owner,
    repo,
    githubApiBase: config.githubApiBase
  });
  const rateLimiter = dependencies.rateLimiter ?? createRateLimiter({
    hourlyLimit: config.hourlyLimit ?? 5,
    burstLimit: config.burstLimit ?? 3
  });
  const trustProxy = config.trustProxy === true;
  const idempotencyStore = new Map();
  const inFlightKeys = new Map();

  function lookupIdempotency(key) {
    if (!key) return undefined;
    const entry = idempotencyStore.get(key);
    if (!entry) return undefined;
    if (Date.now() - entry.storedAt > IDEMPOTENCY_TTL_MS) {
      idempotencyStore.delete(key);
      return undefined;
    }
    return entry.value;
  }

  function rememberIdempotency(key, value) {
    if (!key) return;
    idempotencyStore.set(key, { storedAt: Date.now(), value });
    if (idempotencyStore.size > MAX_IDEMPOTENCY_ENTRIES) {
      const oldestKey = idempotencyStore.keys().next().value;
      if (oldestKey !== undefined) {
        idempotencyStore.delete(oldestKey);
      }
    }
  }

  return http.createServer(async (req, res) => {
    const requestUrl = new URL(req.url || '/', 'http://localhost');
    const method = (req.method || 'GET').toUpperCase();

    if (method === 'GET' && requestUrl.pathname === '/health') {
      sendJson(res, 200, {
        ok: true,
        service: 'anomicon-raisa-relay',
        repo: `${owner}/${repo}`,
        time: new Date().toISOString()
      });
      return;
    }

    if (method === 'POST' && requestUrl.pathname === '/v1/raisa/tickets') {
      const contentType = String(req.headers['content-type'] ?? '').split(';')[0].trim().toLowerCase();
      if (contentType !== 'application/json') {
        sendJson(res, 415, { error: 'unsupported_media_type', message: 'Content-Type 必须为 application/json' });
        return;
      }

      const idempotencyKey = sanitizeSingleLine(req.headers['x-idempotency-key'], 128);
      const cachedReceipt = lookupIdempotency(idempotencyKey);
      if (cachedReceipt) {
        sendJson(res, 200, {
          ticketCode: cachedReceipt.ticketCode,
          issueNumber: cachedReceipt.issueNumber,
          issueUrl: cachedReceipt.issueUrl,
          createdAt: cachedReceipt.createdAt,
          deduplicated: true
        });
        return;
      }

      if (idempotencyKey && inFlightKeys.has(idempotencyKey)) {
        try {
          const receipt = await inFlightKeys.get(idempotencyKey);
          sendJson(res, 200, {
            ticketCode: receipt.ticketCode,
            issueNumber: receipt.issueNumber,
            issueUrl: receipt.issueUrl,
            createdAt: receipt.createdAt,
            deduplicated: true
          });
        } catch (error) {
          sendJson(res, 502, {
            error: 'upstream_failed',
            message: error instanceof Error ? error.message : '工单提交失败'
          });
        }
        return;
      }

      let rawBody;
      try {
        rawBody = await readJsonBody(req);
      } catch (error) {
        const status = Number(error?.statusCode) || 400;
        sendJson(res, status, { error: 'invalid_request', message: error.message });
        return;
      }

      const formatted = validateAndFormatTicket(rawBody);
      if (formatted.error) {
        sendJson(res, 400, { error: 'validation_failed', message: formatted.error });
        return;
      }

      const clientIp = resolveClientIp(req, trustProxy);
      const limitCheck = rateLimiter.checkAndConsume(clientIp);
      if (!limitCheck.allowed) {
        sendJson(
          res,
          429,
          { error: 'rate_limited', message: `提交过于频繁，请在 ${limitCheck.retryAfterSec} 秒后再试` },
          { 'Retry-After': String(limitCheck.retryAfterSec) }
        );
        return;
      }

      const work = (async () => {
        const created = await githubClient.createIssue({
          title: formatted.issueTitle,
          body: formatted.issueBody,
          labels: formatted.labels
        });
        const receipt = {
          ticketCode: `RAISA-#${created.issueNumber}`,
          issueNumber: created.issueNumber,
          issueUrl: created.issueUrl,
          createdAt: created.createdAt
        };
        rememberIdempotency(idempotencyKey, receipt);
        return receipt;
      })();

      if (idempotencyKey) {
        inFlightKeys.set(idempotencyKey, work);
      }

      try {
        const receipt = await work;
        console.log(`[raisa-relay] created ${receipt.ticketCode} category=${formatted.category}`);
        sendJson(res, 201, {
          ticketCode: receipt.ticketCode,
          issueNumber: receipt.issueNumber,
          issueUrl: receipt.issueUrl,
          createdAt: receipt.createdAt,
          deduplicated: false
        });
      } catch (error) {
        const detail = error instanceof Error ? error.message : '未知错误';
        console.error(`[raisa-relay] failed category=${formatted.category} error=${detail}`);
        sendJson(res, 502, {
          error: 'github_relay_failed',
          message: '向 GitHub 签发工单失败，请稍后重试'
        });
      } finally {
        if (idempotencyKey) {
          inFlightKeys.delete(idempotencyKey);
        }
      }
      return;
    }

    sendJson(res, 404, { error: 'not_found', message: '未找到对应的 RAISA 接口' });
  });
}

function loadPrivateKeyPemFromEnv() {
  const keyPath = sanitizeSingleLine(process.env.GITHUB_APP_PRIVATE_KEY_PATH, 512);
  if (keyPath) {
    return fs.readFileSync(keyPath, 'utf8');
  }
  const inline = String(process.env.GITHUB_APP_PRIVATE_KEY ?? '');
  if (inline.trim().length > 0) {
    return inline.replace(/\\n/g, '\n');
  }
  throw new Error('请配置 GITHUB_APP_PRIVATE_KEY_PATH 或 GITHUB_APP_PRIVATE_KEY');
}

export function startServer() {
  const envFile = process.env.RAISA_ENV_FILE || path.join(process.cwd(), '.env');
  loadDotEnv(envFile);

  const port = Number(process.env.PORT ?? 8787);
  const host = sanitizeSingleLine(process.env.HOST ?? '127.0.0.1', 64);
  const appId = sanitizeSingleLine(process.env.GITHUB_APP_ID, 64);
  const installationId = sanitizeSingleLine(process.env.GITHUB_INSTALLATION_ID, 64);
  if (!appId || !installationId) {
    throw new Error('请配置 GITHUB_APP_ID 与 GITHUB_INSTALLATION_ID');
  }
  const privateKeyPem = loadPrivateKeyPemFromEnv();
  const app = createRelayApp({
    appId,
    installationId,
    privateKeyPem,
    owner: process.env.GITHUB_OWNER || 'Suixin04',
    repo: process.env.GITHUB_REPO || 'Anomicon',
    githubApiBase: process.env.GITHUB_API_BASE || 'https://api.github.com',
    hourlyLimit: Number(process.env.RATE_LIMIT_PER_HOUR ?? 5),
    burstLimit: Number(process.env.RATE_LIMIT_BURST_10M ?? 3),
    trustProxy: String(process.env.TRUST_PROXY ?? 'true').toLowerCase() === 'true'
  });

  app.listen(port, host, () => {
    console.log(`[raisa-relay] listening on http://${host}:${port} for ${process.env.GITHUB_OWNER || 'Suixin04'}/${process.env.GITHUB_REPO || 'Anomicon'}`);
  });
  return app;
}

if (process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url) {
  startServer();
}
