import { MockKit, when } from '@ohos/hamock';
import { afterAll, beforeAll, describe, expect, it } from '@ohos/hypium';
import { installArticleUrlFixture } from './PreviewUrlFixture';
import { CachedArticleRepo } from '../main/ets/data/CachedArticleRepo';
import { CatalogRepoAdapter } from '../main/ets/data/CatalogRepoAdapter';
import { ScpCatalogCacheService, ScpStoredCatalog } from '../main/ets/data/ScpCatalogCacheService';
import { ScpCachedPage, ScpPageCacheService } from '../main/ets/data/ScpPageCacheService';
import { ScpPageFetchService, ScpPageRequestSchedule } from '../main/ets/data/ScpPageFetchService';
import { ScpRequestScheduler } from '../main/ets/data/ScpRequestScheduler';
import { StaticCatalogHtmlParser } from '../main/ets/data/StaticCatalogHtmlParser';
import {
  ArticleHtmlRepository,
  ScpHtmlLoadResult,
  ScpHtmlRequestPriority,
  ScpHtmlSource
} from '../main/ets/domain/ArticleHtmlRepository';
import {
  CatalogEntry,
  CatalogParser,
  CatalogParseResult,
  CatalogSnapshotSource,
  TaleParseResult
} from '../main/ets/domain/CatalogContracts';
import { SCP_SERIES } from '../main/ets/domain/ScpSeriesItem';
import { SCP_CATALOG_PARSER_VERSION } from '../main/ets/domain/StaticCatalogContracts';

const BAD_DIRECTORY_HTML: string = '<html><body>Service temporarily unavailable</body></html>';
const GOOD_DIRECTORY_HTML: string = '<div id="page-content"><a href="/scp-173">SCP-173 - 雕像</a></div>';

class MemoryCatalogCache extends ScpCatalogCacheService {
  stored: ScpStoredCatalog | undefined = undefined;

  async get(seriesId: string): Promise<ScpStoredCatalog | undefined> {
    return this.stored?.seriesId === seriesId ? this.stored : undefined;
  }

  async put(catalog: ScpStoredCatalog): Promise<void> {
    this.stored = catalog;
  }
}

class MemoryDirectoryHtml implements ArticleHtmlRepository {
  cached: ScpHtmlLoadResult | undefined = undefined;
  next: ScpHtmlLoadResult = new ScpHtmlLoadResult(BAD_DIRECTORY_HTML, ScpHtmlSource.NETWORK, 200);
  discarded: ScpHtmlLoadResult | undefined = undefined;
  requests: number = 0;

  async loadHtml(_url: string, forceNetwork: boolean = false): Promise<ScpHtmlLoadResult> {
    const cached = this.cached;
    if (!forceNetwork && cached !== undefined) {
      return new ScpHtmlLoadResult(cached.html, ScpHtmlSource.FRESH_CACHE, cached.fetchedAt);
    }
    this.requests++;
    this.cached = this.next;
    return this.next;
  }

  async discard(_url: string, rejected?: ScpHtmlLoadResult): Promise<void> {
    this.discarded = rejected;
    if (rejected !== undefined && this.cached?.html === rejected.html) {
      this.cached = undefined;
    }
  }
}

class DirectoryParser implements CatalogParser {
  failure: string = '';
  reject: boolean = false;
  beforeParse: ((html: string) => Promise<void>) | undefined = undefined;

  async parseCatalog(html: string): Promise<CatalogParseResult> {
    await this.beforeParse?.(html);
    if (this.reject) {
      throw new Error('TaskPool 暂时不可用');
    }
    if (this.failure.length > 0) {
      return { parserVersion: SCP_CATALOG_PARSER_VERSION, ok: false, error: this.failure, entries: [] };
    }
    const parsed = StaticCatalogHtmlParser.parseCatalog(html);
    return {
      parserVersion: parsed.parserVersion,
      ok: parsed.ok,
      error: parsed.error,
      entries: parsed.entries.map((entry): CatalogEntry => new CatalogEntry(entry.itemId, entry.title))
    };
  }

  async parseTales(_html: string): Promise<TaleParseResult> {
    throw new Error('此测试不解析故事目录');
  }
}

class ParseGate {
  readonly promise: Promise<void>;
  open: () => void = (): void => {};

  constructor() {
    this.promise = new Promise<void>((resolve) => {
      this.open = resolve;
    });
  }
}

const ARTICLE_URL: string = 'https://scp-wiki-cn.wikidot.com/scp-173';
const OLD_ARTICLE_HTML: string = '<p>旧正文</p>';
const NEW_ARTICLE_HTML: string = '<p>新正文</p>';
const OLD_ETAG: string = '"old"';
const OLD_LAST_MODIFIED: string = 'Wed, 21 Oct 2015 07:28:00 GMT';

interface ScpLifecycleFetchRequest {
  etag: string;
  lastModified: string;
  priority: ScpHtmlRequestPriority;
}

interface ScpLifecycleFetchReply {
  html: string;
  etag: string;
  lastModified: string;
  notModified: boolean;
}

const ARTICLE_200: ScpLifecycleFetchReply = {
  html: NEW_ARTICLE_HTML, etag: '"new"', lastModified: 'Thu, 22 Oct 2015 07:28:00 GMT', notModified: false
};
const ARTICLE_304: ScpLifecycleFetchReply = {
  html: '', etag: OLD_ETAG, lastModified: OLD_LAST_MODIFIED, notModified: true
};

class ScpLifecycleMemoryPageCache extends ScpPageCacheService {
  stored: ScpCachedPage | undefined = undefined;
  putGate: Promise<void> | undefined = undefined;
  puts: number = 0;
  renewals: number = 0;
  private currentGeneration: number = 0;

  registerGeneration(_sourceUrl: string, requestedGeneration: number): number {
    this.currentGeneration = Math.max(this.currentGeneration + 1, requestedGeneration);
    return this.currentGeneration;
  }

  async get(sourceUrl: string): Promise<ScpCachedPage | undefined> {
    return this.stored?.sourceUrl === sourceUrl ? this.stored : undefined;
  }

  async put(page: ScpCachedPage, generation?: number): Promise<void> {
    this.puts++;
    if (this.putGate !== undefined) {
      await this.putGate;
    }
    if (generation === this.currentGeneration) {
      this.stored = page;
    }
  }

  async updateFetchedAt(sourceUrl: string, fetchedAt: number, generation?: number): Promise<boolean> {
    this.renewals++;
    const page = this.stored;
    if (page === undefined || page.sourceUrl !== sourceUrl || generation !== this.currentGeneration) {
      return false;
    }
    this.stored = new ScpCachedPage(sourceUrl, page.html, fetchedAt, page.etag, page.lastModified);
    return true;
  }

  async remove(sourceUrl: string, rejectedHtml?: string): Promise<void> {
    const page = this.stored;
    if (rejectedHtml === undefined) {
      this.currentGeneration++;
    }
    if (page?.sourceUrl === sourceUrl && (rejectedHtml === undefined || page.html === rejectedHtml)) {
      this.stored = undefined;
    }
  }
}

class ScpLifecycleArticleFixture {
  private readonly scheduler: ScpRequestScheduler = new ScpRequestScheduler();
  private readonly fetchService: ScpPageFetchService = new ScpPageFetchService(this.scheduler);
  readonly cache: ScpLifecycleMemoryPageCache = new ScpLifecycleMemoryPageCache();
  readonly repo: CachedArticleRepo = new CachedArticleRepo(this.fetchService, this.cache, this.scheduler);
  readonly requests: ScpLifecycleFetchRequest[] = [];

  stubFetch(respond: (call: number) => Promise<ScpLifecycleFetchReply>): void {
    // fetchPage 的返回类型未导出，只替换实例方法，不改生产接口。
    const mock = new MockKit();
    const fetchPage = mock.mockFunc(this.fetchService, this.fetchService.fetchPage);
    when(fetchPage)(ARTICLE_URL).afterAction((
      _url: string, etag: string, lastModified: string, schedule: ScpPageRequestSchedule
    ): Promise<ScpLifecycleFetchReply> => {
      const request: ScpLifecycleFetchRequest = { etag: etag, lastModified: lastModified, priority: schedule.priority };
      this.requests.push(request);
      return respond(this.requests.length);
    });
  }

  seedStalePage(): void {
    this.cache.stored = new ScpCachedPage(ARTICLE_URL, OLD_ARTICLE_HTML, 0, OLD_ETAG, OLD_LAST_MODIFIED);
  }
}

export default function scpPageFetchLifecycleTest(): void {
  describe('ScpPageFetchLifecycle', () => {
    it('rejects new requests after repeated disposal', 0, async () => {
      const service = new ScpPageFetchService(new ScpRequestScheduler());

      service.dispose();
      service.dispose();

      let message: string = '';
      try {
        await service.fetchPage('https://scp-wiki-cn.wikidot.com/scp-173');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('RCP 会话已关闭');
    });
  });

  describe('CachedArticleRepo', () => {
    let restoreUrlParser: () => void;
    beforeAll((): void => { restoreUrlParser = installArticleUrlFixture(); });
    afterAll((): void => { restoreUrlParser(); });

    it('returns the 200 HTML while the queued cache put is still pending', 0, async (): Promise<void> => {
      const fixture = new ScpLifecycleArticleFixture();
      fixture.stubFetch(async (): Promise<ScpLifecycleFetchReply> => ARTICLE_200);
      const releasePut = new ParseGate();
      fixture.cache.putGate = releasePut.promise;
      const pending = fixture.repo.loadHtml(ARTICLE_URL);
      let timer: number = -1;
      // 全部依赖都是内存 Promise；下一轮事件循环只用来让错误地等待 put 的实现失败，而不是卡住。
      const endOfTurn = new Promise<undefined>((resolve: (result: undefined) => void): void => {
        timer = setTimeout((): void => { resolve(undefined); }, 0);
      });
      try {
        const result = await Promise.race<ScpHtmlLoadResult | undefined>([pending, endOfTurn]);
        expect(result?.source).assertEqual(ScpHtmlSource.NETWORK);
        expect(result?.html).assertEqual(NEW_ARTICLE_HTML);
        expect(fixture.cache.puts).assertEqual(1);
        expect(fixture.cache.stored === undefined).assertTrue();
      } finally {
        clearTimeout(timer);
        releasePut.open();
        await pending;
      }
      expect(fixture.cache.stored?.html).assertEqual(NEW_ARTICLE_HTML);
    });

    it('retries without validators when a 304 cannot renew a discarded body', 0, async (): Promise<void> => {
      const fixture = new ScpLifecycleArticleFixture();
      fixture.seedStalePage();
      fixture.stubFetch(async (call: number): Promise<ScpLifecycleFetchReply> => {
        if (call === 1) {
          await fixture.repo.discard(ARTICLE_URL,
            new ScpHtmlLoadResult(OLD_ARTICLE_HTML, ScpHtmlSource.STALE_CACHE, 0));
          return ARTICLE_304;
        }
        return ARTICLE_200;
      });

      const priority = ScpHtmlRequestPriority.VISIBLE;
      const result = await fixture.repo.loadHtml(ARTICLE_URL, false, priority);

      expect(fixture.cache.renewals).assertEqual(1);
      expect(fixture.requests.length).assertEqual(2);
      expect(fixture.requests[0]?.etag).assertEqual(OLD_ETAG);
      expect(fixture.requests[0]?.lastModified).assertEqual(OLD_LAST_MODIFIED);
      expect(fixture.requests[1]?.etag).assertEqual('');
      expect(fixture.requests[1]?.lastModified).assertEqual('');
      expect(fixture.requests[1]?.priority).assertEqual(priority);
      expect(result.source).assertEqual(ScpHtmlSource.NETWORK);
      expect(result.html).assertEqual(NEW_ARTICLE_HTML);
      expect(fixture.cache.puts).assertEqual(1);
      expect(fixture.cache.stored?.etag).assertEqual(ARTICLE_200.etag);
      expect(fixture.cache.stored?.html).assertEqual(NEW_ARTICLE_HTML);
    });

    it('uses the newer cached body when a late 304 cannot renew', 0, async (): Promise<void> => {
      const fixture = new ScpLifecycleArticleFixture();
      fixture.seedStalePage();
      const conditionalStarted = new ParseGate();
      const release304 = new ParseGate();
      fixture.stubFetch(async (call: number): Promise<ScpLifecycleFetchReply> => {
        if (call === 1) {
          conditionalStarted.open();
          await release304.promise;
          return ARTICLE_304;
        }
        if (call === 2) {
          return ARTICLE_200;
        }
        throw new Error('已有并发新正文，不应重试');
      });

      const older = fixture.repo.loadHtml(ARTICLE_URL);
      let storedNewer: ScpCachedPage | undefined = undefined;
      try {
        await Promise.race<void>([conditionalStarted.promise, older.then<void>((): void => {
          throw new Error('旧请求应先发起条件请求');
        })]);
        const newer = await fixture.repo.loadHtml(ARTICLE_URL, true);
        expect(newer.source).assertEqual(ScpHtmlSource.NETWORK);
        storedNewer = fixture.cache.stored;
        expect(storedNewer?.html).assertEqual(NEW_ARTICLE_HTML);
      } finally {
        release304.open();
      }
      const current = await older;
      expect(fixture.cache.renewals).assertEqual(1);
      expect(fixture.requests.length).assertEqual(2);
      expect(fixture.cache.puts).assertEqual(1);
      expect(current.source).assertEqual(ScpHtmlSource.FRESH_CACHE);
      expect(current.html).assertEqual(NEW_ARTICLE_HTML);
      expect(current.fetchedAt).assertEqual(storedNewer?.fetchedAt);
      expect(fixture.cache.stored === storedNewer).assertTrue();
    });
  });

  describe('CatalogRepoAdapter', () => {
    it('discards a bad 200 so the next cold load can get a usable 200', 0, async () => {
      const html = new MemoryDirectoryHtml();
      const cache = new MemoryCatalogCache();
      const repo = new CatalogRepoAdapter(cache, html, new DirectoryParser());
      const series = SCP_SERIES[0];

      let message: string = '';
      try {
        await repo.load(series);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertContain('page-content node not found');
      expect(html.discarded?.source).assertEqual(ScpHtmlSource.NETWORK);
      expect(html.cached === undefined).assertTrue();
      expect(cache.stored === undefined).assertTrue();

      html.next = new ScpHtmlLoadResult(GOOD_DIRECTORY_HTML, ScpHtmlSource.NETWORK, 300);
      const snapshot = await repo.load(series);
      expect(html.requests).assertEqual(2);
      expect(snapshot.entries[0].itemId).assertEqual('SCP-173');
      expect(snapshot.fetchedAt).assertEqual(300);
    });

    it('keeps the old derived snapshot through a bad 304 and renews it on a valid 304', 0, async () => {
      const html = new MemoryDirectoryHtml();
      const cache = new MemoryCatalogCache();
      const repo = new CatalogRepoAdapter(cache, html, new DirectoryParser());
      const series = SCP_SERIES[0];
      html.next = new ScpHtmlLoadResult(GOOD_DIRECTORY_HTML, ScpHtmlSource.NETWORK, 100);
      await repo.load(series);
      const stored = cache.stored;

      html.cached = new ScpHtmlLoadResult(BAD_DIRECTORY_HTML, ScpHtmlSource.FRESH_CACHE, 150);
      html.next = new ScpHtmlLoadResult(BAD_DIRECTORY_HTML, ScpHtmlSource.FRESH_CACHE, 200);
      const fallback = await repo.refresh(series);
      expect(html.discarded?.fetchedAt).assertEqual(200);
      expect(html.cached === undefined).assertTrue();
      expect(cache.stored === stored).assertTrue();
      expect(fallback.source).assertEqual(CatalogSnapshotSource.CACHE);
      expect(fallback.fetchedAt).assertEqual(100);
      expect(fallback.stale).assertTrue();
      expect(fallback.partial).assertTrue();
      expect(fallback.entries[0].itemId).assertEqual('SCP-173');

      html.cached = new ScpHtmlLoadResult(GOOD_DIRECTORY_HTML, ScpHtmlSource.FRESH_CACHE, 250);
      html.next = new ScpHtmlLoadResult(GOOD_DIRECTORY_HTML, ScpHtmlSource.FRESH_CACHE, 300);
      const renewed = await repo.refresh(series);
      expect(renewed.stale).assertFalse();
      expect(renewed.partial).assertFalse();
      expect(renewed.fetchedAt).assertEqual(300);
      expect(cache.stored?.parsedAt).assertEqual(300);
      expect(html.cached?.html).assertEqual(GOOD_DIRECTORY_HTML);
    });

    it('preserves good HTML on transient parser rejection or failure payload', 0, async () => {
      const html = new MemoryDirectoryHtml();
      const parser = new DirectoryParser();
      const repo = new CatalogRepoAdapter(new MemoryCatalogCache(), html, parser);
      const series = SCP_SERIES[0];
      html.next = new ScpHtmlLoadResult(GOOD_DIRECTORY_HTML, ScpHtmlSource.NETWORK, 100);
      parser.reject = true;
      let rejections: number = 0;
      try {
        await repo.load(series);
      } catch (error) {
        rejections++;
      }
      parser.reject = false;
      parser.failure = 'TaskPool 暂时不可用';
      try {
        await repo.load(series);
      } catch (error) {
        rejections++;
      }
      expect(rejections).assertEqual(2);
      expect(html.discarded === undefined).assertTrue();
      expect(html.cached?.html).assertEqual(GOOD_DIRECTORY_HTML);

      parser.failure = '';
      const snapshot = await repo.load(series);
      expect(html.requests).assertEqual(1);
      expect(snapshot.entries[0].itemId).assertEqual('SCP-173');
    });

    it('does not discard a newer good response when an earlier bad parse finishes late', 0, async () => {
      const html = new MemoryDirectoryHtml();
      const parser = new DirectoryParser();
      const cache = new MemoryCatalogCache();
      const repo = new CatalogRepoAdapter(cache, html, parser);
      const series = SCP_SERIES[0];
      const started = new ParseGate();
      const resume = new ParseGate();
      parser.beforeParse = async (body: string): Promise<void> => {
        if (body === BAD_DIRECTORY_HTML) {
          started.open();
          await resume.promise;
        }
      };

      const slow = repo.load(series);
      await started.promise;
      html.next = new ScpHtmlLoadResult(GOOD_DIRECTORY_HTML, ScpHtmlSource.NETWORK, 300);
      try {
        await repo.refresh(series);
      } finally {
        resume.open();
      }
      const snapshot = await slow;
      expect(html.discarded?.html).assertEqual(BAD_DIRECTORY_HTML);
      expect(html.cached?.html).assertEqual(GOOD_DIRECTORY_HTML);
      expect(cache.stored?.parsedAt).assertEqual(300);
      expect(snapshot.fetchedAt).assertEqual(300);
    });
  });
}
