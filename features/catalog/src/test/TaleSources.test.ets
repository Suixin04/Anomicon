import { describe, expect, it } from '@ohos/hypium';
import { StaticCatalogHtmlParser } from '../main/ets/data/StaticCatalogHtmlParser';
import { ScpStoredTaleList, TaleDirectoryCache, TaleListService } from '../main/ets/data/TaleListService';
import { TaleRepositoryAdapter } from '../main/ets/data/TaleRepositoryAdapter';
import { ArticleHtmlRepository, ScpHtmlLoadResult, ScpHtmlSource } from '../main/ets/domain/ArticleHtmlRepository';
import { CatalogParser, CatalogParseResult, CatalogTaleEntry, TaleParseResult, TaleSnapshot } from '../main/ets/domain/CatalogContracts';

function page(id: string, title: string): string {
  return `<div id="page-content"><a href="/${id}">${title}</a></div>`;
}

class TaleHtml implements ArticleHtmlRepository {
  translated: string = page('translated-one', '旧译文');
  original: string = page('original-one', '旧原创');
  originalsOnline: boolean = true;
  requests: number = 0;

  async loadHtml(url: string): Promise<ScpHtmlLoadResult> {
    this.requests++;
    const original = url.endsWith('/tales-cn-by-page-name');
    if (original && !this.originalsOnline) {
      throw new Error('HTTP 503');
    }
    return new ScpHtmlLoadResult(original ? this.original : this.translated, ScpHtmlSource.NETWORK, Date.now());
  }

  async discard(_url: string, _rejected?: ScpHtmlLoadResult): Promise<void> {}
}

class TestTaleStore extends TaleListService {
  row?: ScpStoredTaleList;

  async read(): Promise<ScpStoredTaleList | undefined> { return this.row; }

  async put(cache: TaleDirectoryCache, fetchedAt: number): Promise<void> {
    this.row = new ScpStoredTaleList(JSON.stringify(cache), fetchedAt);
  }
}

class TaleParser implements CatalogParser {
  async parseCatalog(_html: string): Promise<CatalogParseResult> { throw new Error('非系列索引'); }

  async parseTales(html: string): Promise<TaleParseResult> {
    const data = StaticCatalogHtmlParser.parseTales(html);
    return { parserVersion: data.parserVersion, ok: data.ok, error: data.error,
      tales: data.tales.map((entry): CatalogTaleEntry => new CatalogTaleEntry(entry.id, entry.title)) };
  }
}

function titles(value: TaleSnapshot): string {
  return value.tales.map((row: CatalogTaleEntry): string => row.title).join('/');
}

export default function taleSourcesTest(): void {
  describe('TaleDirectorySources', () => {
    it('replaces the valid source, keeps an empty index result retryable across reopen, and recovers', 0, async () => {
      const html = new TaleHtml();
      const store = new TestTaleStore(html);
      const repo = new TaleRepositoryAdapter(store, new TaleParser());
      expect(titles(await repo.load())).assertEqual('旧译文/旧原创');
      html.translated = page('translated-two', '新译文');
      html.original = '<div id="page-content">目录暂时不可用</div>';
      const half = await repo.refresh();
      expect(titles(half)).assertEqual('新译文/旧原创');
      expect(half.partial && half.stale && half.error.includes('原创')).assertTrue();
      const reopened = new TaleRepositoryAdapter(store, new TaleParser());
      const cached = await reopened.load();
      expect(titles(cached)).assertEqual('新译文/旧原创');
      expect(cached.partial && cached.error.includes('原创')).assertTrue();
      expect(html.requests).assertEqual(4);
      html.original = page('original-two', '新原创');
      const retried = await reopened.refresh();
      expect(titles(retried)).assertEqual('新译文/新原创');
      expect(retried.partial || retried.stale).assertFalse();
      expect(html.requests).assertEqual(6);
    });

    it('retains unclassified v4 rows during a one-source outage until both indexes are available', 0, async () => {
      const html = new TaleHtml();
      const store = new TestTaleStore(html);
      store.row = new ScpStoredTaleList('{"parserVersion":4,"ok":true,"error":"","tales":[{"id":"original-one","title":"原安装缓存"}]}', Date.now());
      const repo = new TaleRepositoryAdapter(store, new TaleParser());
      expect(titles(await repo.load())).assertEqual('原安装缓存');
      html.originalsOnline = false;
      expect(titles(await repo.refresh())).assertEqual('旧译文/原安装缓存');
      const reopened = new TaleRepositoryAdapter(store, new TaleParser());
      expect(titles(await reopened.load())).assertEqual('旧译文/原安装缓存');
      html.originalsOnline = true;
      html.original = page('original-new', '新目录原创');
      const updated = await reopened.refresh();
      expect(titles(updated)).assertEqual('旧译文/新目录原创');
      expect(updated.partial).assertFalse();
    });
  });
}
