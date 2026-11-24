import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { ScpRequestScheduler } from './ScpRequestScheduler';
import { ScpWikiUrlPolicy } from './ScpWikiUrlPolicy';
import { ScpHtmlRequestPriority } from '../domain/ArticleHtmlRepository';

const MAX_MANUAL_REDIRECTS: number = 5;
const MAX_REQUEST_ATTEMPTS: number = 2;
const MAX_PAGE_BYTES: number = 32 * 1024 * 1024;
const RCP_EMPTY_RESPONSE_CODE: number = 1007900052;
const RCP_SESSION_CLOSED_CODE: number = 1007900993;
const DOMAIN: number = 0x0000;
const TAG: string = 'AnomiconPageFetch';

/** A logical fetch keeps its original queue key and any promotion across attempts and redirects. */
export interface ScpPageRequestSchedule {
  readonly key: string;
  priority: ScpHtmlRequestPriority;
}

class ScpRequestError extends Error {
  readonly code: number;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
  }
}

class ScpPageByteCollector {
  private readonly chunks: Uint8Array[] = [];
  private totalBytes: number = 0;
  private exceeded: boolean = false;

  receive(incomingData: ArrayBuffer): void {
    if (this.exceeded) {
      throw new Error(`页面超过 ${MAX_PAGE_BYTES} 字节限制`);
    }
    const nextTotal = this.totalBytes + incomingData.byteLength;
    if (nextTotal > MAX_PAGE_BYTES) {
      this.exceeded = true;
      throw new Error(`页面超过 ${MAX_PAGE_BYTES} 字节限制`);
    }
    // RCP 回调缓冲区由原生层管理；离开回调前复制，避免异步持有失效内存。
    const copy = new Uint8Array(incomingData.byteLength);
    copy.set(new Uint8Array(incomingData));
    this.chunks.push(copy);
    this.totalBytes = nextTotal;
  }

  limitExceeded(): boolean {
    return this.exceeded;
  }

  finish(): Uint8Array {
    if (this.exceeded) {
      throw new Error(`页面超过 ${MAX_PAGE_BYTES} 字节限制`);
    }
    const output = new Uint8Array(this.totalBytes);
    let offset: number = 0;
    for (let index: number = 0; index < this.chunks.length; index++) {
      const chunk = this.chunks[index];
      output.set(chunk, offset);
      offset += chunk.byteLength;
    }
    this.chunks.length = 0;
    return output;
  }
}

class ScpPageResponse {
  readonly statusCode: number;
  readonly headers: rcp.ResponseHeaders;
  readonly body: Uint8Array;

  constructor(statusCode: number, headers: rcp.ResponseHeaders, body: Uint8Array) {
    this.statusCode = statusCode;
    this.headers = headers;
    this.body = body;
  }
}

class ScpFetchedPage {
  readonly html: string;
  readonly etag: string;
  readonly lastModified: string;
  readonly notModified: boolean;

  constructor(
    html: string,
    etag: string = '',
    lastModified: string = '',
    notModified: boolean = false
  ) {
    this.html = html;
    this.etag = etag;
    this.lastModified = lastModified;
    this.notModified = notModified;
  }
}

/**
 * 解析实验使用的轻量网络入口。携带 ETag/Last-Modified 做条件请求，
 * 服务器确认内容未变时返回 304，避免重复传输整页正文。
 */
export class ScpPageFetchService {
  private readonly scheduler: ScpRequestScheduler;
  private readonly onRequestMetrics:
    ((latencyMs: number, statusCode: number, failed: boolean) => void) | undefined;
  private pageSession: rcp.Session | undefined = undefined;
  private readonly activePerSession: Map<rcp.Session, number> = new Map();
  private readonly retiredSessions: Set<rcp.Session> = new Set();
  private disposed: boolean = false;

  constructor(
    scheduler: ScpRequestScheduler,
    onRequestMetrics?: (latencyMs: number, statusCode: number, failed: boolean) => void
  ) {
    this.scheduler = scheduler;
    this.onRequestMetrics = onRequestMetrics;
  }

  async fetchPage(
    url: string,
    etag: string = '',
    lastModified: string = '',
    schedule: ScpPageRequestSchedule = { key: url, priority: ScpHtmlRequestPriority.USER_INITIATED }
  ): Promise<ScpFetchedPage> {
    this.assertActive();
    const normalizedUrl = ScpWikiUrlPolicy.normalizePageUrl(url);
    const header: rcp.RequestHeaders = {
      'Accept': 'text/html,application/xhtml+xml',
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'User-Agent': 'Anomicon/0.1 HarmonyOS reader'
    };
    if (etag.length > 0) {
      header['If-None-Match'] = etag;
    }
    if (lastModified.length > 0) {
      header['If-Modified-Since'] = lastModified;
    }
    try {
      const response = await this.requestFollowingRedirects(normalizedUrl, header, schedule);
      this.assertActive();
      return this.toFetchedPage(response, etag, lastModified);
    } catch (error) {
      this.assertActive();
      const businessError = error as BusinessError;
      // 个别系统版本把无响应体的条件请求映射为 RCP 1007900052，无法从错误对象确认
      // 它一定是 304。此时退化为一次无条件 GET，而不是把所有空响应误判为未修改。
      if (businessError.code === RCP_EMPTY_RESPONSE_CODE && (etag.length > 0 || lastModified.length > 0)) {
        const retryHeaders: rcp.RequestHeaders = {
          'Accept': header['Accept'],
          'Accept-Language': header['Accept-Language'],
          'User-Agent': header['User-Agent']
        };
        try {
          const retryResponse = await this.requestFollowingRedirects(normalizedUrl, retryHeaders, schedule);
          return this.toFetchedPage(retryResponse, '', '');
        } catch (retryError) {
          throw this.fetchError(retryError);
        }
      }
      throw this.fetchError(error);
    }
  }

  /** Retire the current session on network handover so fresh fetches establish new sockets. */
  retireSessionForHandover(): void {
    const session = this.pageSession;
    if (session === undefined) {
      return;
    }
    this.pageSession = undefined;
    if ((this.activePerSession.get(session) ?? 0) === 0) {
      this.closeSessionSafely(session, false);
    } else {
      this.retiredSessions.add(session);
    }
  }

  /** Close the graph-owned native connection pool and reject later work. */
  dispose(): void {
    if (this.disposed) {
      return;
    }
    this.disposed = true;
    const session = this.pageSession;
    this.pageSession = undefined;
    if (session !== undefined) {
      this.closeSessionSafely(session, true);
    }
    const retired = Array.from(this.retiredSessions);
    this.retiredSessions.clear();
    this.activePerSession.clear();
    for (let index: number = 0; index < retired.length; index++) {
      this.closeSessionSafely(retired[index], true);
    }
  }

  private closeSessionSafely(session: rcp.Session, cancelActive: boolean): void {
    if (cancelActive) {
      try {
        session.cancel();
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'cancel page session failed: %{public}s',
          error instanceof Error ? error.message : '未知错误');
      }
    }
    try {
      session.close();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'close page session failed: %{public}s',
        error instanceof Error ? error.message : '未知错误');
    }
  }

  private async requestFollowingRedirects(
    initialUrl: string,
    header: rcp.RequestHeaders,
    schedule: ScpPageRequestSchedule
  ): Promise<ScpPageResponse> {
    let currentUrl: string = ScpWikiUrlPolicy.normalizePageUrl(initialUrl);
    let redirectCount: number = 0;

    while (true) {
      const response = await this.requestWithRetry(currentUrl, header, schedule);
      if (!this.isRedirectResponse(response.statusCode)) {
        return response;
      }
      if (redirectCount >= MAX_MANUAL_REDIRECTS) {
        throw new Error(`SCP 页面重定向超过 ${MAX_MANUAL_REDIRECTS} 次`);
      }

      const location = this.headerValue(response.headers, 'location').trim();
      if (location.length === 0) {
        throw new Error(`SCP 页面重定向缺少 Location（HTTP ${response.statusCode}）`);
      }

      // 每一跳都相对当前地址解析，并重新经过主站 HTTPS/主机/端口/凭据校验。
      currentUrl = ScpWikiUrlPolicy.resolvePageUrl(location, currentUrl);
      redirectCount++;
    }
  }

  /** Wikidot 偶发网关错误或连接复位时只重试一次，避免无限等待。 */
  private async requestWithRetry(
    url: string,
    header: rcp.RequestHeaders,
    schedule: ScpPageRequestSchedule
  ): Promise<ScpPageResponse> {
    let lastError: ScpRequestError | undefined = undefined;
    for (let attempt = 0; attempt < MAX_REQUEST_ATTEMPTS; attempt++) {
      this.assertActive();
      try {
        const response = await this.requestOnce(url, header, schedule);
        this.assertActive();
        if (!this.isTransientResponse(response.statusCode) ||
          attempt === MAX_REQUEST_ATTEMPTS - 1) {
          return response;
        }
      } catch (error) {
        this.assertActive();
        lastError = this.requestError(error);
        if (attempt === MAX_REQUEST_ATTEMPTS - 1) {
          throw lastError;
        }
      }
      this.assertActive();
      await this.retryDelay(350 * (attempt + 1));
    }
    if (lastError !== undefined) {
      throw lastError;
    }
    throw new Error('SCP 页面请求失败');
  }

  private isTransientResponse(responseCode: number): boolean {
    return responseCode === 408 || responseCode === 425 || responseCode === 429 ||
      responseCode === 502 || responseCode === 503 || responseCode === 504;
  }

  private retryDelay(delay: number): Promise<void> {
    return new Promise<void>((resolve: () => void): void => {
      setTimeout(resolve, delay);
    });
  }

  private async requestOnce(
    url: string,
    header: rcp.RequestHeaders,
    schedule: ScpPageRequestSchedule
  ): Promise<ScpPageResponse> {
    return this.scheduler.run(async (): Promise<ScpPageResponse> => {
      const collector = new ScpPageByteCollector();
      let session: rcp.Session | undefined = undefined;
      const startedAt = Date.now();
      try {
        // 已排队任务可能在 Graph 销毁后才取得调度槽；不得复活原生 Session。
        this.assertActive();
        session = this.getPageSession();
        this.acquireSessionFetch(session);
        const request = new rcp.Request(url, 'GET', header);
        // 收集器属于当前 Request；共享 Session 并发工作时，各响应正文不会互相串流。
        request.destination = (incomingData: ArrayBuffer): void => {
          collector.receive(incomingData);
        };
        const response = await session.fetch(request);
        // close 与 fetch 完成的先后顺序没有保证；销毁后的响应不能再写入旧 Graph 的缓存。
        this.assertActive();
        this.reportRequestMetrics(Date.now() - startedAt, response.statusCode, false);
        return new ScpPageResponse(response.statusCode, response.headers, collector.finish());
      } catch (error) {
        const requestError = this.requestError(error);
        this.reportRequestMetrics(Date.now() - startedAt, requestError.code, true);
        if (collector.limitExceeded()) {
          throw new ScpRequestError(requestError.code, `页面超过 ${MAX_PAGE_BYTES} 字节限制`);
        }
        throw requestError;
      } finally {
        if (session !== undefined) {
          this.releaseSessionFetch(session);
        }
      }
    }, schedule.priority, schedule.key);
  }

  private acquireSessionFetch(session: rcp.Session): void {
    this.activePerSession.set(session, (this.activePerSession.get(session) ?? 0) + 1);
  }

  private releaseSessionFetch(session: rcp.Session): void {
    const remaining = (this.activePerSession.get(session) ?? 0) - 1;
    if (remaining > 0) {
      this.activePerSession.set(session, remaining);
      return;
    }
    this.activePerSession.delete(session);
    if (this.retiredSessions.delete(session) && !this.disposed) {
      this.closeSessionSafely(session, false);
    }
  }

  private reportRequestMetrics(latencyMs: number, statusCode: number, failed: boolean): void {
    if (this.onRequestMetrics === undefined) {
      return;
    }
    try {
      this.onRequestMetrics(Math.max(0, latencyMs), statusCode, failed);
    } catch (_error) {
    }
  }

  private toFetchedPage(
    response: ScpPageResponse,
    previousEtag: string,
    previousLastModified: string
  ): ScpFetchedPage {
    if (response.statusCode === 304) {
      return new ScpFetchedPage('', previousEtag, previousLastModified, true);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`页面请求失败：HTTP ${response.statusCode}`);
    }
    const contentType = this.headerValue(response.headers, 'content-type')
      .split(';')[0]
      .trim()
      .toLowerCase();
    if (contentType !== 'text/html' && contentType !== 'application/xhtml+xml') {
      const receivedType = contentType.length > 0 ? contentType : '未提供';
      throw new Error(`页面响应类型不受支持：${receivedType}`);
    }
    const html = util.TextDecoder.create('utf-8', {
      fatal: true,
      ignoreBOM: false
    }).decodeToString(response.body, { stream: false });
    if (html.length === 0) {
      throw new Error('页面请求成功但正文为空');
    }
    return new ScpFetchedPage(
      html,
      this.headerValue(response.headers, 'etag'),
      this.headerValue(response.headers, 'last-modified'),
      false
    );
  }

  private getPageSession(): rcp.Session {
    this.assertActive();
    if (this.pageSession !== undefined) {
      return this.pageSession;
    }
    // FeatureGraph 内复用一个长连接池，不为每一页重复创建原生 Session。
    try {
      this.pageSession = rcp.createSession({
        connectionConfiguration: {
          maxConnectionsPerHost: 6,
          maxTotalConnections: 16
        },
        requestConfiguration: {
          transfer: {
            // 自动跟随会绕过应用的主站 URL 策略；由业务层逐跳解析并重新校验。
            autoRedirect: false,
            timeout: {
              connectMs: 15000,
              transferMs: 20000,
              inactivityMs: 20000
            }
          },
          security: {
            remoteValidation: 'system'
          }
        }
      });
    } catch (error) {
      const businessError = error as BusinessError;
      const code = businessError.code !== undefined ? businessError.code : -1;
      const message = error instanceof Error ? error.message : 'RCP 会话创建失败';
      throw new ScpRequestError(code, message);
    }
    return this.pageSession;
  }

  private assertActive(): void {
    if (this.disposed) {
      throw new ScpRequestError(RCP_SESSION_CLOSED_CODE, 'RCP 会话已关闭');
    }
  }

  private isRedirectResponse(responseCode: number): boolean {
    return responseCode === 301 || responseCode === 302 || responseCode === 303 ||
      responseCode === 307 || responseCode === 308;
  }

  private fetchError(error: Object): ScpRequestError {
    const businessError = error as BusinessError;
    const code = businessError.code !== undefined ? businessError.code : -1;
    const message = error instanceof Error ? error.message : '网络请求异常';
    return new ScpRequestError(code, `无法读取 SCP 页面：${message}（错误码 ${code}）`);
  }

  private requestError(error: Object): ScpRequestError {
    if (error instanceof ScpRequestError) {
      return error;
    }
    const businessError = error as BusinessError;
    const code = businessError.code !== undefined ? businessError.code : -1;
    const message = error instanceof Error ? error.message : 'SCP 页面网络请求异常';
    return new ScpRequestError(code, message);
  }

  private headerValue(headers: rcp.ResponseHeaders, name: string): string {
    const normalizedName = name.toLowerCase();
    const keys = Object.keys(headers);
    for (let index: number = 0; index < keys.length; index++) {
      const key = keys[index];
      if (key.toLowerCase() === normalizedName) {
        const value = headers[key];
        if (typeof value === 'string') {
          return value;
        }
        return value !== undefined && value.length > 0 ? value[0] : '';
      }
    }
    return '';
  }
}
