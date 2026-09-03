import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { ANOMICON_DATABASE_NAME } from 'anomiconbasic';
import { TalePayload } from '../domain/StaticCatalogContracts';
import {
  CachedArticleRepo
} from './CachedArticleRepo';
import { ScpHtmlLoadResult, ScpHtmlRequestPriority } from '../domain/ArticleHtmlRepository';

const TABLE_NAME: string = 'tale_list_cache';
const CREATE_TABLE: string =
  'CREATE TABLE IF NOT EXISTS tale_list_cache (' +
  'cache_key TEXT PRIMARY KEY, json TEXT NOT NULL, parsed_at INTEGER NOT NULL)';
const CACHE_KEY: string = 'tales';

/** 故事目录页地址（全部故事静态渲染在 page-content 内）。 */
const TALES_INDEX_URL: string = 'https://scp-wiki-cn.wikidot.com/tales-by-page-name';
/** 中文分部原创故事目录；主站故事列表不会收录这部分页面。 */
const ORIGINAL_TALES_INDEX_URL: string = 'https://scp-wiki-cn.wikidot.com/tales-cn-by-page-name';

export class ScpStoredTaleList {
  readonly json: string;
  readonly parsedAt: number;

  constructor(json: string, parsedAt: number) {
    this.json = json;
    this.parsedAt = parsedAt;
  }
}

/**
 * 故事列表（tales-by-page-name）的抓取与持久化：
 * - 6h 新鲜度窗口内直接返回缓存；
 * - 过期后走条件请求（ETag/Last-Modified），304 只续期；
 * - 网络失败回退旧缓存。
 * 页面 HTML 由上层通过 TaskPool 原生静态解析，解析结果以 JSON 落库，
 * 二次打开秒出。
 */
export class TaleListService {
  private store: relationalStore.RdbStore | undefined = undefined;
  private initialization: Promise<void> | undefined = undefined;
  private context: common.UIAbilityContext | undefined = undefined;
  private readonly repository: CachedArticleRepo;

  constructor(repository: CachedArticleRepo) {
    this.repository = repository;
  }

  initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.store !== undefined) {
      return Promise.resolve();
    }
    if (this.initialization !== undefined) {
      return this.initialization;
    }
    this.initialization = this.open(context);
    return this.initialization;
  }

  /** 无条件读缓存（网络失败回退路径用）。 */
  async read(): Promise<ScpStoredTaleList | undefined> {
    const store = await this.requireStore();
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('cache_key', CACHE_KEY);
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await store.query(predicates, ['json', 'parsed_at']);
      if (!resultSet.goToFirstRow()) {
        return undefined;
      }
      return new ScpStoredTaleList(
        resultSet.getString(resultSet.getColumnIndex('json')),
        resultSet.getLong(resultSet.getColumnIndex('parsed_at'))
      );
    } catch (error) {
      throw this.taleError('读取', error);
    } finally {
      try {
        resultSet?.close();
      } catch (error) {
        console.warn(`Close tale list result set failed: ${error instanceof Error ? error.message : 'unknown error'}`);
      }
    }
  }

  /** 写入解析结果，并沿用对应原始 HTML 的抓取时间。 */
  async put(payload: TalePayload, fetchedAt: number): Promise<void> {
    const store = await this.requireStore();
    const values: relationalStore.ValuesBucket = {
      'cache_key': CACHE_KEY,
      'json': JSON.stringify(payload),
      'parsed_at': fetchedAt
    };
    try {
      const rowId = await store.insert(
        TABLE_NAME,
        values,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
      if (rowId < 0) {
        throw new Error('故事目录写入返回无效行号');
      }
    } catch (error) {
      throw this.taleError('写入', error);
    }
  }

  /** 拉取故事目录页原始 HTML，并显式传递请求语义。 */
  async loadHtmlForRequest(
    forceNetwork: boolean,
    priority: ScpHtmlRequestPriority
  ): Promise<ScpHtmlLoadResult> {
    return this.repository.loadHtml(TALES_INDEX_URL, forceNetwork, priority);
  }

  /** 拉取中文分部原创故事目录，供统一故事仓储合并。 */
  async loadOriginalHtmlForRequest(
    forceNetwork: boolean,
    priority: ScpHtmlRequestPriority
  ): Promise<ScpHtmlLoadResult> {
    return this.repository.loadHtml(ORIGINAL_TALES_INDEX_URL, forceNetwork, priority);
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
      this.initialization = undefined;
      throw this.taleError('初始化', error);
    }
  }

  private async requireStore(): Promise<relationalStore.RdbStore> {
    if (this.initialization !== undefined) {
      await this.initialization;
    }
    if (this.store === undefined && this.context !== undefined) {
      // A failed open clears initialization; retry lazily on the next cache
      // operation instead of leaving the feature permanently unavailable.
      await this.initialize(this.context);
    }
    if (this.store === undefined) {
      throw new Error('故事列表缓存尚未初始化');
    }
    return this.store;
  }

  private taleError(operation: string, error: Object): Error {
    const message = error instanceof Error ? error.message : '未知数据库错误';
    return new Error(`故事列表${operation}失败：${message}`);
  }
}
