import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { ANOMICON_DATABASE_NAME } from 'anomiconbasic';
import {
  ExplorePayload,
  ExploreSource
} from '../domain/ExploreContracts';
import {
  ExploreHtmlLoadResult,
  ExploreHtmlRepository,
  ExploreHtmlSource
} from '../domain/ExploreRepositories';
import { parseExploreHtmlOffThread } from './ExploreHtmlParseTask';
import { RetryableInitialization } from './RetryableInitialization';

const TABLE_NAME: string = 'explore_list_cache';
const CREATE_TABLE: string =
  'CREATE TABLE IF NOT EXISTS explore_list_cache (' +
  'cache_key TEXT PRIMARY KEY, json TEXT NOT NULL, parsed_at INTEGER NOT NULL)';
/** Cache schema version for the native static Explore index payload. */
const CACHE_SCHEMA: string = 'v5';

/** 已解析的探索条目缓存。 */
class ScpStoredExploreList {
  readonly json: string;
  readonly parsedAt: number;

  constructor(json: string, parsedAt: number) {
    this.json = json;
    this.parsedAt = parsedAt;
  }
}

/** 已完成来源语义校验的探索响应。 */
class LoadedExplorePayload {
  readonly payload: ExplorePayload;
  readonly htmlSource: ExploreHtmlSource;
  readonly fetchedAt: number;

  constructor(
    payload: ExplorePayload,
    htmlSource: ExploreHtmlSource,
    fetchedAt: number
  ) {
    this.payload = payload;
    this.htmlSource = htmlSource;
    this.fetchedAt = fetchedAt;
  }
}

/**
 * One logical URL request. A force load can upgrade a normal request while it
 * is still running; callers then observe the forced result instead of the
 * superseded normal snapshot.
 */
class ExploreInflightRequest {
  readonly source: ExploreSource;
  readonly url: string;
  readonly promise: Promise<LoadedExplorePayload>;
  forceRequested: boolean = false;
  forceStarted: boolean = false;
  private resolveTask: (value: LoadedExplorePayload) => void =
    (_value: LoadedExplorePayload): void => {};
  private rejectTask: (reason?: Object) => void =
    (_reason?: Object): void => {};
  private settled: boolean = false;

  constructor(source: ExploreSource, url: string) {
    this.source = source;
    this.url = url;
    this.promise = new Promise<LoadedExplorePayload>((resolve, reject) => {
      this.resolveTask = resolve;
      this.rejectTask = (reason?: Object): void => reject(reason);
    });
  }

  requestForce(): void {
    this.forceRequested = true;
  }

  resolve(value: LoadedExplorePayload): void {
    if (this.settled) {
      return;
    }
    this.settled = true;
    this.resolveTask(value);
  }

  reject(reason: Object): void {
    if (this.settled) {
      return;
    }
    this.settled = true;
    this.rejectTask(reason);
  }
}

const SOURCE_URLS: Map<ExploreSource, string> = new Map([
  [ExploreSource.TOP_RATED, 'https://scp-wiki-cn.wikidot.com/top-rated-pages'],
  [ExploreSource.RECENT_TRANSLATED, 'https://scp-wiki-cn.wikidot.com/most-recently-created-translated'],
  [ExploreSource.RECENT_ORIGINAL, 'https://scp-wiki-cn.wikidot.com/most-recently-created-cn'],
  [ExploreSource.JOKE_SCPS, 'https://scp-wiki-cn.wikidot.com/joke-scps'],
  [ExploreSource.JOKE_TALES, 'https://scp-wiki-cn.wikidot.com/joke-scps-tales-edition']
]);

/**
 * 探索页数据源（热门榜 / 最近新增×2 / 搞笑专区×2）的统一抓取与持久化：
 * - 6h 新鲜度窗口内直接返回缓存；
 * - 过期后走条件请求（ETag/Last-Modified），304 只续期；
 * - 网络失败回退旧缓存。
 * 页面 HTML 由 ExploreHtmlParser 原生静态解析，JSON 落库；探索数据不再依赖离屏 ArkWeb。
 */
export class ExploreListService {
  private store: relationalStore.RdbStore | undefined = undefined;
  private readonly initialization: RetryableInitialization = new RetryableInitialization();
  private readonly repository: ExploreHtmlRepository;
  private readonly inflight: Map<string, ExploreInflightRequest> =
    new Map<string, ExploreInflightRequest>();

  constructor(repository: ExploreHtmlRepository) {
    this.repository = repository;
  }

  initialize(context: common.UIAbilityContext): Promise<void> {
    return this.initialization.run((): Promise<void> => this.open(context));
  }

  /** 无条件读缓存（网络失败回退路径用）。 */
  async read(source: ExploreSource): Promise<ScpStoredExploreList | undefined> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('cache_key', `${CACHE_SCHEMA}:${source}`);
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await store.query(predicates, ['json', 'parsed_at']);
      if (!resultSet.goToFirstRow()) {
        return undefined;
      }
      return new ScpStoredExploreList(
        resultSet.getString(resultSet.getColumnIndex('json')),
        resultSet.getLong(resultSet.getColumnIndex('parsed_at'))
      );
    } catch (error) {
      throw this.exploreError('读取', error);
    } finally {
      try {
        resultSet?.close();
      } catch (error) {
        console.warn(`Close explore result set failed: ${error instanceof Error ? error.message : 'unknown error'}`);
      }
    }
  }

  /** 写入解析结果；新鲜度绑定原始 HTML 的抓取时间，不因稍后重新解析而延长。 */
  async put(source: ExploreSource, payload: ExplorePayload, parsedAt: number = Date.now()): Promise<void> {
    const store = await this.requireStore();
    const values: relationalStore.ValuesBucket = {
      'cache_key': `${CACHE_SCHEMA}:${source}`,
      'json': JSON.stringify(payload),
      'parsed_at': parsedAt
    };
    try {
      const rowId = await store.insert(
        TABLE_NAME,
        values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
      if (rowId < 0) {
        throw new Error(`探索列表写入返回无效行号：${source}`);
      }
    } catch (error) {
      throw this.exploreError('写入', error);
    }
  }

  /**
   * 拉取数据源原始 HTML，并保留来源语义。
   * 上层必须区分「服务器确认的新鲜副本」与「网络失败后的过期回退」，
   * 后者不能重新写成刚更新的派生列表。
   */
  async load(source: ExploreSource, forceNetwork: boolean = false): Promise<LoadedExplorePayload> {
    const url = SOURCE_URLS.get(source);
    if (url === undefined) {
      throw new Error(`未知探索数据源：${source}`);
    }
    const existing = this.inflight.get(url);
    if (existing !== undefined) {
      if (forceNetwork) {
        existing.requestForce();
        // The normal request remains the single physical task for now; its
        // result is held back and a force request starts when it settles.
      }
      return existing.promise;
    }
    const request = new ExploreInflightRequest(source, url);
    request.forceStarted = forceNetwork;
    this.inflight.set(url, request);
    this.runRequest(request, forceNetwork);
    return request.promise;
  }

  /** Run one URL request, upgrading a pending normal load when requested. */
  private runRequest(request: ExploreInflightRequest, forceNetwork: boolean): void {
    this.loadSingle(request.source, request.url, forceNetwork).then(
      (loaded: LoadedExplorePayload): void => {
        if (!forceNetwork && request.forceRequested && !request.forceStarted) {
          // Do not resolve the public Promise with the superseded normal
          // snapshot.  Starting force only after normal settles also prevents
          // two ExploreListService parses from racing each other.
          request.forceStarted = true;
          this.runRequest(request, true);
          return;
        }
        request.resolve(loaded);
        this.clearRequest(request);
      },
      (error: Object): void => {
        if (!forceNetwork && request.forceRequested && !request.forceStarted) {
          // A failed normal request must not consume an explicit retry.
          request.forceStarted = true;
          this.runRequest(request, true);
          return;
        }
        request.reject(error);
        this.clearRequest(request);
      }
    );
  }

  private clearRequest(request: ExploreInflightRequest): void {
    if (this.inflight.get(request.url) === request) {
      this.inflight.delete(request.url);
    }
  }

  private async loadSingle(
    source: ExploreSource,
    url: string,
    forceNetwork: boolean
  ): Promise<LoadedExplorePayload> {
    let result: ExploreHtmlLoadResult = await this.repository.loadHtml(url, forceNetwork);
    let payload = await parseExploreHtmlOffThread(source, result.html);
    if (payload.ok && payload.entries.length > 0) {
      return new LoadedExplorePayload(payload, result.source, result.fetchedAt);
    }

    // 200 text/html 并不保证是目标页面。缓存中的空壳页/通用错误页必须定向
    // 失效；网络返回的坏内容不能删除一份可能仍可用的旧缓存。
    if (result.source !== ExploreHtmlSource.NETWORK) {
      await this.repository.discard(url);
    }
    if (result.source !== ExploreHtmlSource.NETWORK && !forceNetwork) {
      result = await this.repository.loadHtml(url, true);
      payload = await parseExploreHtmlOffThread(source, result.html);
      if ((!payload.ok || payload.entries.length === 0) && result.source !== ExploreHtmlSource.NETWORK) {
        await this.repository.discard(url);
      }
    }
    return new LoadedExplorePayload(payload, result.source, result.fetchedAt);
  }

  private async open(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await relationalStore.getRdbStore(context, {
        name: ANOMICON_DATABASE_NAME,
        securityLevel: relationalStore.SecurityLevel.S1,
        encrypt: false
      });
      await store.executeSql(CREATE_TABLE);
      this.store = store;
    } catch (error) {
      throw this.exploreError('初始化', error);
    }
  }

  private async requireStore(): Promise<relationalStore.RdbStore> {
    await this.initialization.waitForCurrent();
    if (this.store === undefined) {
      throw new Error('探索列表缓存尚未初始化');
    }
    return this.store;
  }

  private exploreError(operation: string, error: Object): Error {
    const message = error instanceof Error ? error.message : '未知数据库错误';
    return new Error(`探索列表${operation}失败：${message}`);
  }
}
