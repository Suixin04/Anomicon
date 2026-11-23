import { common } from '@kit.AbilityKit';
import { buffer, Queue, util, url } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const WIKI_REFERER: string = 'https://scp-wiki-cn.wikidot.com/';
const MAX_IMAGE_BYTES: number = 20 * 1024 * 1024;
const MAX_REDIRECTS: number = 5;
const MAX_ATTEMPTS: number = 2;
const DEFAULT_MAX_CONCURRENT_DOWNLOADS: number = 4;
const TEMP_FILE_CLEANUP_GRACE_MS: number = 5000;
// SCP 图床在弱网下下载 1 MiB 图片可能超过 50 秒。transferMs 是整段传输总时限，
// 不是“连续多久没收到数据”；旧值 20 秒会把仍在下载的正常请求误判为失败。
const IMAGE_TRANSFER_TIMEOUT_MS: number = 120000;
const IMAGE_INACTIVITY_TIMEOUT_MS: number = 30000;
const MAX_IMAGE_PIXELS: number = 64 * 1024 * 1024;
const CACHE_EXTENSIONS: string[] = [
  'jpg', 'png', 'gif', 'bmp', 'webp', 'dng', 'heic', 'heif', 'heifs', 'tif', 'wbmp', 'svg', 'ico', 'avif'
];
const DOMAIN = 0x0000;
const TAG = 'AnomiconImage';

class ScpImageRequestError extends Error {
  readonly code: number;
  readonly retryable: boolean;

  constructor(code: number, message: string, retryable: boolean) {
    super(message);
    this.code = code;
    this.retryable = retryable;
  }
}

/** RCP 流式响应收集器：在每个数据块到达时执行硬上限，不让默认 50 MiB 缓冲先发生。 */
class ScpImageByteCollector {
  private readonly maxBytes: number;
  private readonly chunks: Uint8Array[] = [];
  private totalBytes: number = 0;
  private exceeded: boolean = false;

  constructor(maxBytes: number) {
    this.maxBytes = maxBytes;
  }

  reset(): void {
    this.chunks.length = 0;
    this.totalBytes = 0;
    this.exceeded = false;
  }

  receive(incomingData: ArrayBuffer): void {
    const nextTotal = this.totalBytes + incomingData.byteLength;
    if (nextTotal > this.maxBytes) {
      this.exceeded = true;
      throw new Error(`图片超过 ${this.maxBytes} 字节限制`);
    }
    // RCP 回调缓冲区的生命周期由原生层管理，必须复制后再异步持有。
    const copy = new Uint8Array(incomingData.byteLength);
    copy.set(new Uint8Array(incomingData));
    this.chunks.push(copy);
    this.totalBytes = nextTotal;
  }

  limitExceeded(): boolean {
    return this.exceeded;
  }

  byteLength(): number {
    return this.totalBytes;
  }

  finish(): ArrayBuffer {
    const output = new Uint8Array(this.totalBytes);
    let offset: number = 0;
    for (let index: number = 0; index < this.chunks.length; index++) {
      output.set(this.chunks[index], offset);
      offset += this.chunks[index].byteLength;
    }
    this.reset();
    return output.buffer as ArrayBuffer;
  }
}

class ScpDownloadedImage {
  readonly bytes: ArrayBuffer;
  readonly declaredMimeType: string;

  constructor(bytes: ArrayBuffer, declaredMimeType: string) {
    this.bytes = bytes;
    this.declaredMimeType = declaredMimeType;
  }
}

class ScpImageInspection {
  readonly mimeType: string;
  readonly extension: string;

  constructor(mimeType: string, extension: string) {
    this.mimeType = mimeType;
    this.extension = extension;
  }
}

/**
 * 文章配图管线：通过 RCP 请求 HTTPS 图片（带 UA/Referer），验证响应后
 * 原子落到应用沙盒 cacheDir，之后 Image 直接渲染本地文件。
 * 历史 http 链接只会被确定性升级为 https，不会回退到明文传输。
 */
export class ScpImageCacheService {
  private imageDir: string = '';
  private context: common.UIAbilityContext | undefined = undefined;
  private tempSequence: number = 0;
  private maxConcurrentDownloads: number = DEFAULT_MAX_CONCURRENT_DOWNLOADS;
  private activeDownloads: number = 0;
  private imageSession: rcp.Session | undefined = undefined;
  private disposed: boolean = false;
  private readonly activePerSession: Map<rcp.Session, number> = new Map();
  private readonly retiredSessions: Set<rcp.Session> = new Set();
  private readonly inflight: Map<string, Promise<string>> = new Map();
  private readonly downloadWaiters: Queue<() => void> = new Queue<() => void>();
  private readonly validatedPaths: Set<string> = new Set();

  initialize(context: common.UIAbilityContext): void {
    this.context = context;
    if (this.imageDir.length > 0) {
      return;
    }
    const imageDir = `${context.cacheDir}/scp_images`;
    try {
      // accessSync throws when the path does not exist on a fresh install.
      // Do not let that exception skip creation of the cache directory.
      if (!this.existsSync(imageDir)) {
        fs.mkdirSync(imageDir, true);
      }
      // Publish the directory immediately so synchronous callers can validate paths,
      // while sweeping only stale leftover temp files asynchronously off the main thread.
      this.imageDir = imageDir;
      const cutoffMs = Date.now() - TEMP_FILE_CLEANUP_GRACE_MS;
      this.cleanupAbandonedTempFilesAsync(imageDir, cutoffMs).catch((): void => {
      });
    } catch (error) {
      console.warn(`Create image cache dir failed: ${error instanceof Error ? error.message : 'unknown error'}`);
    }
  }

  setMaxConcurrentDownloads(limit: number): void {
    this.maxConcurrentDownloads = Math.max(1, Math.min(6, Math.floor(limit)));
    this.drainDownloadWaiters();
  }

  retireSessionForHandover(): void {
    const session = this.imageSession;
    if (session === undefined) {
      return;
    }
    this.imageSession = undefined;
    if ((this.activePerSession.get(session) ?? 0) === 0) {
      this.closeSessionSafely(session, false);
    } else {
      this.retiredSessions.add(session);
    }
  }

  dispose(): void {
    if (this.disposed) {
      return;
    }
    this.disposed = true;
    const session = this.imageSession;
    this.imageSession = undefined;
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

  /** 返回本地文件路径；命中缓存直接返回，未命中则下载。 */
  async load(url: string): Promise<string> {
    if (this.disposed) {
      throw new Error('图片缓存服务已关闭');
    }
    if (this.imageDir.length === 0 && this.context !== undefined) {
      this.initialize(this.context);
    }
    if (this.imageDir.length === 0) {
      throw new Error('图片缓存服务尚未初始化');
    }
    const normalizedUrl = this.normalizeHttpsUrl(url);
    const existing = this.inflight.get(normalizedUrl);
    if (existing !== undefined) {
      return existing;
    }
    const task = this.loadNormalized(normalizedUrl);
    this.inflight.set(normalizedUrl, task);
    task.then(() => {
      this.inflight.delete(normalizedUrl);
    }).catch(() => {
      this.inflight.delete(normalizedUrl);
    });
    return task;
  }

  /**
   * 仅认可当前 cacheDir/scp_images 直接管理的正式缓存文件。
   * 历史 filesDir 路径、相邻目录、路径穿越片段和未完成的临时文件都会被拒绝。
   */
  isManagedCachePath(path: string): boolean {
    if (this.imageDir.length === 0 || path.length === 0) {
      return false;
    }
    const prefix = `${this.imageDir}/`;
    if (!path.startsWith(prefix)) {
      return false;
    }
    const name = path.substring(prefix.length);
    return /^img_[0-9a-f]{64}\.(?:jpg|png|gif|bmp|webp|dng|heic|heif|heifs|tif|wbmp|svg|ico|avif)$/.test(name);
  }

  /**
   * 给数据库等相邻缓存复用方使用：除路径归属外，还会校验文件大小并让 ImageKit
   * 实际解码首帧。空文件、截断文件、扩展名伪装文件会被删除并视为缓存未命中。
   */
  async isReusableManagedCachePath(path: string): Promise<boolean> {
    if (!this.isManagedCachePath(path) || !(await this.hasValidFileSize(path))) {
      this.validatedPaths.delete(path);
      return false;
    }
    if (this.validatedPaths.has(path)) {
      return true;
    }
    try {
      const inspection = await this.inspectFile(path);
      if (!path.endsWith(`.${inspection.extension}`)) {
        throw new Error(`缓存扩展名与图片实际格式不符：${inspection.mimeType}`);
      }
      this.validatedPaths.add(path);
      return true;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'discard invalid image cache %{private}s: %{public}s', path,
        error instanceof Error ? error.message : '未知错误');
      await this.removeFileIfExists(path);
      this.validatedPaths.delete(path);
      return false;
    }
  }

  private async loadNormalized(normalizedUrl: string): Promise<string> {
    const stem = `img_${this.sha256Hex(normalizedUrl)}`;
    const cachedPath = await this.findReusablePath(stem);
    if (cachedPath !== undefined) {
      return cachedPath;
    }

    const downloaded = await this.downloadWithSlot(normalizedUrl);
    const inspection = await this.inspectBuffer(downloaded.bytes);
    const declaredExtension = this.extensionForMimeType(downloaded.declaredMimeType);
    if (declaredExtension.length > 0 && declaredExtension !== inspection.extension) {
      hilog.warn(DOMAIN, TAG,
        'image MIME differs from decoded format for %{private}s: declared %{public}s, actual %{public}s',
        normalizedUrl, downloaded.declaredMimeType, inspection.mimeType);
    }
    const path = `${this.imageDir}/${stem}.${inspection.extension}`;
    await this.writeAtomically(path, downloaded.bytes);
    this.validatedPaths.add(path);
    return path;
  }

  /** 不同 URL 共享受网络策略调控的下载槽位；同 URL 已在 load() 层合并为同一个 Promise。 */
  private async downloadWithSlot(url: string): Promise<ScpDownloadedImage> {
    await this.acquireDownloadSlot();
    try {
      return await this.download(url);
    } finally {
      // 下载、重试、会话创建任一路径失败都必须交还槽位，避免队列永久阻塞。
      this.releaseDownloadSlot();
    }
  }

  private acquireDownloadSlot(): Promise<void> {
    if (this.activeDownloads < this.maxConcurrentDownloads && this.downloadWaiters.length === 0) {
      this.activeDownloads += 1;
      return Promise.resolve();
    }
    return new Promise<void>((resolve: () => void) => {
      if (!this.downloadWaiters.add(resolve)) {
        throw new Error('图片下载等待队列入队失败');
      }
      this.drainDownloadWaiters();
    });
  }

  private releaseDownloadSlot(): void {
    if (this.activeDownloads <= 0) {
      hilog.error(DOMAIN, TAG, '%{public}s', 'image download slot underflow');
      return;
    }
    this.activeDownloads -= 1;
    this.drainDownloadWaiters();
  }

  private drainDownloadWaiters(): void {
    while (this.activeDownloads < this.maxConcurrentDownloads && this.downloadWaiters.length > 0) {
      try {
        const next = this.downloadWaiters.pop();
        this.activeDownloads += 1;
        next();
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'dequeue image download waiter failed: %{public}s',
          error instanceof Error ? error.message : 'unknown error');
        return;
      }
    }
  }

  private async writeAtomically(path: string, bytes: ArrayBuffer): Promise<void> {
    this.tempSequence += 1;
    const tempPath = `${path}.tmp_${Date.now()}_${this.tempSequence}`;
    try {
      let file: fs.File | undefined = undefined;
      try {
        file = await fs.open(tempPath,
          fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC | fs.OpenMode.NOFOLLOW);
        const written = await fs.write(file.fd, bytes);
        if (written !== bytes.byteLength) {
          throw new Error(`图片缓存写入不完整：${written}/${bytes.byteLength}`);
        }
        await fs.fsync(file.fd);
      } finally {
        if (file !== undefined) {
          await fs.close(file);
        }
      }
      // 临时文件与目标文件位于同一缓存目录，rename 不会暴露部分写入的图片。
      await fs.rename(tempPath, path);
    } catch (error) {
      await this.removeFileIfExists(tempPath);
      throw new Error(`图片缓存写入失败：${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  private async download(url: string): Promise<ScpDownloadedImage> {
    const collector = new ScpImageByteCollector(MAX_IMAGE_BYTES);
    let lastError: Error = new Error('图片下载失败');
    for (let attempt: number = 0; attempt < MAX_ATTEMPTS; attempt++) {
      this.assertActive();
      try {
        return await this.fetchBytes(url, collector);
      } catch (error) {
        const requestError = error instanceof ScpImageRequestError ? error :
          new ScpImageRequestError(-1,
            error instanceof Error ? error.message : '未知错误', false);
        hilog.warn(DOMAIN, TAG,
          'image download failed (attempt %{public}d) for %{private}s: %{public}d %{public}s',
          attempt + 1, url, requestError.code, requestError.message);
        lastError = new Error(`图片下载失败：${requestError.message}`);
        // URL/MIME/大小/4xx 等确定性错误立即返回；只重试明确的瞬时网络失败和 5xx。
        if (!requestError.retryable || this.disposed) {
          throw lastError;
        }
      }
    }
    throw lastError;
  }

  private async fetchBytes(
    initialUrl: string,
    collector: ScpImageByteCollector
  ): Promise<ScpDownloadedImage> {
    let currentUrl = initialUrl;
    for (let redirectCount: number = 0; redirectCount <= MAX_REDIRECTS; redirectCount++) {
      collector.reset();
      let response: rcp.Response;
      try {
        response = await this.fetchResponse(currentUrl, collector);
      } catch (error) {
        if (collector.limitExceeded()) {
          throw new ScpImageRequestError(-1, `图片超过 ${MAX_IMAGE_BYTES} 字节限制`, false);
        }
        throw error instanceof Error ? error : new Error('图片流式接收失败');
      }
      if (this.isRedirect(response.statusCode)) {
        if (redirectCount === MAX_REDIRECTS) {
          throw new Error(`图片重定向超过 ${MAX_REDIRECTS} 次`);
        }
        const location = this.firstHeader(response.headers['location']);
        if (location.length === 0) {
          throw new Error(`图片重定向缺少 Location：HTTP ${response.statusCode}`);
        }
        currentUrl = this.normalizeHttpsUrl(location, currentUrl);
        continue;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw new ScpImageRequestError(
          response.statusCode,
          `图片请求失败：HTTP ${response.statusCode}`,
          response.statusCode >= 500 && response.statusCode < 600
        );
      }
      if (response.effectiveUrl !== undefined) {
        this.assertHttpsUrl(response.effectiveUrl.toString());
      }
      const contentType = this.firstHeader(response.headers['content-type']).toLowerCase();
      const mimeType = contentType.split(';')[0].trim();
      if (!mimeType.startsWith('image/')) {
        throw new Error(`图片响应类型无效：${mimeType.length > 0 ? mimeType : '缺失 Content-Type'}`);
      }
      const contentLengthText = this.firstHeader(response.headers['content-length']).trim();
      if (contentLengthText.length > 0) {
        const contentLength = Number(contentLengthText);
        if (!Number.isFinite(contentLength) || contentLength < 0) {
          throw new Error('图片响应的 Content-Length 无效');
        }
        if (contentLength > MAX_IMAGE_BYTES) {
          throw new Error(`图片超过 ${MAX_IMAGE_BYTES} 字节限制`);
        }
      }
      if (collector.byteLength() === 0) {
        throw new Error('图片响应内容为空');
      }
      return new ScpDownloadedImage(collector.finish(), mimeType);
    }
    throw new Error('图片重定向处理失败');
  }

  private getImageSession(): rcp.Session {
    this.assertActive();
    if (this.imageSession !== undefined) {
      return this.imageSession;
    }
    try {
      this.imageSession = rcp.createSession({
        headers: {
          'user-agent': 'Anomicon/0.1 image cache',
          'referer': WIKI_REFERER,
          'accept': 'image/*'
        },
        connectionConfiguration: {
          maxConnectionsPerHost: 6,
          maxTotalConnections: 16
        },
        requestConfiguration: {
          transfer: {
            autoRedirect: false,
            timeout: {
              connectMs: 15000,
              transferMs: IMAGE_TRANSFER_TIMEOUT_MS,
              inactivityMs: IMAGE_INACTIVITY_TIMEOUT_MS
            }
          },
          security: {
            remoteValidation: 'system'
          }
        }
      });
    } catch (error) {
      throw new Error(`无法创建图片网络会话：${error instanceof Error ? error.message : '未知错误'}`);
    }
    return this.imageSession;
  }

  private async fetchResponse(requestUrl: string, collector: ScpImageByteCollector): Promise<rcp.Response> {
    let session: rcp.Session | undefined = undefined;
    try {
      session = this.getImageSession();
      this.acquireSessionFetch(session);
      const request = new rcp.Request(requestUrl, 'GET');
      request.destination = (incomingData: ArrayBuffer): void => {
        collector.receive(incomingData);
      };
      const response = await session.fetch(request);
      this.assertActive();
      return response;
    } catch (error) {
      if (error instanceof ScpImageRequestError) {
        throw error;
      }
      const businessError: BusinessError = error as BusinessError;
      const code: number = businessError.code !== undefined ? businessError.code : -1;
      const message = error instanceof Error ? error.message : '网络请求异常';
      throw new ScpImageRequestError(code, `${message}（错误码 ${code}）`, this.isTransientNetworkCode(code));
    } finally {
      if (session !== undefined) {
        this.releaseSessionFetch(session);
      }
    }
  }

  private assertActive(): void {
    if (this.disposed) {
      throw new ScpImageRequestError(-1, '图片缓存服务已关闭', false);
    }
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

  private closeSessionSafely(session: rcp.Session, cancelActive: boolean): void {
    if (cancelActive) {
      try {
        session.cancel();
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'cancel image session failed: %{public}s',
          error instanceof Error ? error.message : '未知错误');
      }
    }
    try {
      session.close();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'close image session failed: %{public}s',
        error instanceof Error ? error.message : '未知错误');
    }
  }

  private normalizeHttpsUrl(rawUrl: string, baseUrl?: string): string {
    let candidate = rawUrl.trim();
    if (candidate.length === 0) {
      throw new Error('图片地址为空');
    }
    if (candidate.startsWith('//')) {
      candidate = `https:${candidate}`;
    }
    let parsed: url.URL;
    try {
      parsed = baseUrl === undefined ? url.URL.parseURL(candidate) : url.URL.parseURL(candidate, baseUrl);
    } catch (error) {
      throw new Error('图片地址无效');
    }
    if (parsed.protocol === 'http:') {
      parsed.protocol = 'https:';
    }
    this.assertParsedHttpsUrl(parsed);
    parsed.hash = '';
    return parsed.toString();
  }

  private assertHttpsUrl(rawUrl: string): void {
    let parsed: url.URL;
    try {
      parsed = url.URL.parseURL(rawUrl);
    } catch (error) {
      throw new Error('图片最终地址无效');
    }
    this.assertParsedHttpsUrl(parsed);
  }

  private assertParsedHttpsUrl(parsed: url.URL): void {
    if (parsed.protocol !== 'https:') {
      throw new Error('图片地址必须使用 HTTPS');
    }
    if (parsed.hostname.length === 0) {
      throw new Error('图片地址缺少主机名');
    }
    const host = parsed.hostname.toLowerCase();
    if (host === 'localhost' || host.endsWith('.localhost') || host.endsWith('.local') ||
      host.endsWith('.internal') || /^\d{1,3}(?:\.\d{1,3}){3}$/.test(host) || host.indexOf(':') >= 0) {
      throw new Error('图片地址不得指向本机、内网名称或 IP 字面量');
    }
    if (parsed.username.length > 0 || parsed.password.length > 0) {
      throw new Error('图片地址不得携带用户凭据');
    }
    if (parsed.port.length > 0) {
      throw new Error('图片地址不得使用自定义端口');
    }
  }

  private firstHeader(value: string | string[] | undefined): string {
    if (value === undefined) {
      return '';
    }
    if (typeof value === 'string') {
      return value;
    }
    return value.length > 0 ? value[0] : '';
  }

  private isRedirect(statusCode: number): boolean {
    return statusCode === 301 || statusCode === 302 || statusCode === 303 ||
      statusCode === 307 || statusCode === 308;
  }

  private isTransientNetworkCode(code: number): boolean {
    return code === 1007900005 || code === 1007900006 || code === 1007900007 ||
      code === 1007900018 || code === 1007900028 || code === 1007900052 ||
      code === 1007900055 || code === 1007900056 || code === 1007900089 ||
      code === 1007900092 || code === 1007900095 || code === 1007900097 ||
      code === 1007900999;
  }

  private async removeFileIfExists(path: string): Promise<void> {
    try {
      if (await this.existsAsync(path)) {
        await fs.unlink(path);
      }
    } catch (error) {
      // 临时文件清理失败不应覆盖原始写入错误。
    }
  }

  private async cleanupAbandonedTempFilesAsync(imageDir: string, cutoffMs: number): Promise<void> {
    try {
      const names = await fs.listFile(imageDir);
      for (let index: number = 0; index < names.length; index++) {
        const name = names[index];
        const match = /^img_[0-9a-f]+\.[a-z0-9]+\.tmp_([0-9]+)_[0-9]+$/.exec(name);
        if (match !== null && Number(match[1]) < cutoffMs) {
          await this.removeFileIfExists(`${imageDir}/${name}`);
        }
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'cleanup abandoned image files failed: %{public}s',
        error instanceof Error ? error.message : '未知错误');
    }
  }

  private async findReusablePath(stem: string): Promise<string | undefined> {
    for (let index: number = 0; index < CACHE_EXTENSIONS.length; index++) {
      const path = `${this.imageDir}/${stem}.${CACHE_EXTENSIONS[index]}`;
      if (await this.isReusableManagedCachePath(path)) {
        return path;
      }
    }
    return undefined;
  }

  private async hasValidFileSize(path: string): Promise<boolean> {
    try {
      if (!(await this.existsAsync(path))) {
        return false;
      }
      const stat = await fs.lstat(path);
      return stat.isFile() && stat.size > 0 && stat.size <= MAX_IMAGE_BYTES;
    } catch (error) {
      return false;
    }
  }

  private async existsAsync(path: string): Promise<boolean> {
    try {
      return await fs.access(path);
    } catch (_error) {
      return false;
    }
  }

  /** CoreFileKit accessSync throws for a missing path (and older variants may
   * return void), so existence checks must be exception-safe. */
  private existsSync(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (error) {
      return false;
    }
  }

  private async inspectBuffer(bytes: ArrayBuffer): Promise<ScpImageInspection> {
    const source = image.createImageSource(bytes);
    return this.inspectImageSource(source);
  }

  private async inspectFile(path: string): Promise<ScpImageInspection> {
    let file: fs.File | undefined = undefined;
    try {
      file = await fs.open(path, fs.OpenMode.READ_ONLY | fs.OpenMode.NOFOLLOW);
      const source = image.createImageSource(file.fd);
      return await this.inspectImageSource(source);
    } catch (error) {
      throw new Error(`图片缓存解码校验失败：${error instanceof Error ? error.message : '未知错误'}`);
    } finally {
      if (file !== undefined) {
        try {
          await fs.close(file);
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'close cached image failed: %{public}s',
            error instanceof Error ? error.message : '未知错误');
        }
      }
    }
  }

  private async inspectImageSource(source: image.ImageSource): Promise<ScpImageInspection> {
    let probe: image.PixelMap | undefined = undefined;
    try {
      const info = await source.getImageInfo();
      if (info.size.width <= 0 || info.size.height <= 0 ||
        info.size.width * info.size.height > MAX_IMAGE_PIXELS) {
        throw new Error('图片尺寸无效或过大');
      }
      const extension = this.extensionForMimeType(info.mimeType);
      if (extension.length === 0) {
        throw new Error(`ImageKit 返回了不支持的图片类型：${info.mimeType}`);
      }
      // getImageInfo 只读取元数据；1x1 解码探针可发现空内容、截断数据和伪装图片，
      // 同时把解码内存约束在极小范围。PixelMap 与 ImageSource 都必须主动释放。
      probe = await source.createPixelMap({ desiredSize: { width: 1, height: 1 } });
      return new ScpImageInspection(info.mimeType.toLowerCase(), extension);
    } finally {
      if (probe !== undefined) {
        try {
          await probe.release();
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'release image validation pixel map failed: %{public}s',
            error instanceof Error ? error.message : '未知错误');
        }
      }
      try {
        await source.release();
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'release image validation source failed: %{public}s',
          error instanceof Error ? error.message : '未知错误');
      }
    }
  }

  private extensionForMimeType(rawMimeType: string): string {
    const mimeType = rawMimeType.toLowerCase().split(';')[0].trim();
    switch (mimeType) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/bmp':
      case 'image/x-ms-bmp':
        return 'bmp';
      case 'image/webp':
        return 'webp';
      case 'image/dng':
      case 'image/x-adobe-dng':
        return 'dng';
      case 'image/heic':
      case 'image/heic-sequence':
        return 'heic';
      case 'image/heif':
        return 'heif';
      case 'image/heifs':
      case 'image/heif-sequence':
        return 'heifs';
      case 'image/tiff':
        return 'tif';
      case 'image/vnd.wap.wbmp':
        return 'wbmp';
      case 'image/svg+xml':
        return 'svg';
      case 'image/x-icon':
      case 'image/vnd.microsoft.icon':
        return 'ico';
      case 'image/avif':
        return 'avif';
      default:
        return '';
    }
  }

  private sha256Hex(value: string): string {
    try {
      const md = cryptoFramework.createMd('SHA256');
      md.updateSync({ data: util.TextEncoder.create('utf-8').encodeInto(value) });
      return buffer.from(md.digestSync().data).toString('hex');
    } catch (error) {
      throw new Error(`图片缓存键生成失败：${error instanceof Error ? error.message : '未知错误'}`);
    }
  }
}
