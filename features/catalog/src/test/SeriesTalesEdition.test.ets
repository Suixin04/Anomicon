import { describe, expect, it } from '@ohos/hypium';
import {
  ArticleHtmlRepository,
  ScpHtmlLoadResult,
  ScpHtmlRequestPriority,
  ScpHtmlSource
} from '../main/ets/domain/ArticleHtmlRepository';
import { ScpCachePolicy } from '../main/ets/domain/ScpCachePolicy';
import {
  matchesExactScpReference,
  resolveSeriesTalesEditionPageId,
  SERIES_TALES_PARSER_VERSION,
  SeriesTalesEditionPayload
} from '../main/ets/domain/SeriesTalesContracts';
import { SeriesTalesEditionParser } from '../main/ets/data/SeriesTalesEditionParser';
import {
  SeriesTalesCacheRecord,
  SeriesTalesCacheStore,
  SeriesTalesRepositoryAdapter
} from '../main/ets/data/SeriesTalesRepositoryAdapter';

class FakeSeriesTalesHtmlRepo implements ArticleHtmlRepository {
  loadCalls: number = 0;
  lastUrl: string = '';
  private readonly replies: Map<string, string> = new Map();
  private readonly errors: Map<string, string> = new Map();

  setHtml(url: string, html: string): void {
    this.errors.delete(url);
    this.replies.set(url, html);
  }

  setError(url: string, message: string): void {
    this.replies.delete(url);
    this.errors.set(url, message);
  }

  loadHtml(
    sourceUrl: string,
    _forceNetwork?: boolean,
    _priority?: ScpHtmlRequestPriority
  ): Promise<ScpHtmlLoadResult> {
    this.loadCalls += 1;
    this.lastUrl = sourceUrl;
    const errorMessage = this.errors.get(sourceUrl);
    if (errorMessage !== undefined) {
      return Promise.reject(new Error(errorMessage));
    }
    const html = this.replies.get(sourceUrl);
    if (html === undefined) {
      return Promise.reject(new Error('页面请求失败：HTTP 404'));
    }
    return Promise.resolve(new ScpHtmlLoadResult(html, ScpHtmlSource.NETWORK, Date.now()));
  }

  discard(_sourceUrl: string, _rejected?: ScpHtmlLoadResult): Promise<void> {
    return Promise.resolve();
  }
}

class MemorySeriesTalesCacheStore implements SeriesTalesCacheStore {
  getCalls: number = 0;
  putCalls: number = 0;
  private readonly records: Map<string, SeriesTalesCacheRecord> = new Map();

  setRecord(record: SeriesTalesCacheRecord): void {
    this.records.set(record.seriesId, record);
  }

  get(key: string): Promise<SeriesTalesCacheRecord | undefined> {
    this.getCalls += 1;
    return Promise.resolve(this.records.get(key));
  }

  put(record: SeriesTalesCacheRecord): Promise<void> {
    this.putCalls += 1;
    this.records.set(record.seriesId, record);
    return Promise.resolve();
  }
}

const SAMPLE_SERIES_1_HTML: string = `
<div id="page-content">
  <ul>
    <li><a href="/scp-001">SCP-001</a>
      <ul>
        <li><a href="/spc-001">SPC-001</a>
          <ul>
            <li><a href="/peppersghosts-stupid-proposal">大概是PeppersGhost的提案吧</a></li>
            <li><a href="/ouroborealis">衔尾鲨</a>（系列）</li>
          </ul>
        </li>
      </ul>
    </li>
    <li><a href="/scp-173">SCP-173</a> - 雕像 -<strong>最初之作</strong>
      <ul>
        <li><a href="/crunch">折颈</a></li>
        <li><a class="newpage" href="/addendum-scp-173-containment-procedures-update">Addendum: Untranslated</a></li>
        <li><a href="/a-concrete-shrine">混凝土神龛</a></li>
        <li><a href="/crunch#top">折颈</a></li>
        <li><a href="/scp-173">self link</a></li>
        <li><a href="/system:recent-changes">最近更改</a></li>
      </ul>
    </li>
  </ul>
</div>
<div class="page-tags"></div>`;

const SAMPLE_SERIES_2_HTML: string = `
<div id="page-content">
  <ul>
    <li><a href="/scp-1730">SCP-1730</a> - Site-13发生了什么？
      <ul>
        <li><a href="/mzl-1730">MZL-1730：Site-19发生了什么？</a></li>
      </ul>
    </li>
    <li><a href="/scp-1733">SCP-1733</a> - 开季赛
      <ul>
        <li><a href="/ennui">忽怠</a></li>
      </ul>
    </li>
  </ul>
</div>`;

const SAMPLE_SERIES_CN_3_HTML: string = `
<div id="page-content">
  <ul>
    <li><a href="/scp-cn-2000">SCP-CN-2000</a> - 混沌理论
      <ul>
        <li><a href="/sc-18-200-20-003">SC-18/200-20/003：基金會開關測試檔案</a></li>
        <li><a href="https://scp-wiki-cn.wikidot.com/ennuis-age">忽怠新纪元</a></li>
        <li><a href="https://example.com/external">外部站点</a></li>
      </ul>
    </li>
  </ul>
</div>`;

export default function seriesTalesEditionTest(): void {
  describe('SeriesTalesEditionContract', () => {
    it('maps Main I-X and CN I-V SCP IDs to Wiki series tales edition slugs', 0, () => {
      expect(resolveSeriesTalesEditionPageId('SCP-001')).assertEqual('scp-series-1-tales-edition');
      expect(resolveSeriesTalesEditionPageId('scp-173')).assertEqual('scp-series-1-tales-edition');
      expect(resolveSeriesTalesEditionPageId('SCP-173-D')).assertEqual('scp-series-1-tales-edition');
      expect(resolveSeriesTalesEditionPageId('SCP-1730')).assertEqual('scp-series-2-tales-edition');
      expect(resolveSeriesTalesEditionPageId('SCP-9000')).assertEqual('scp-series-10-tales-edition');
      expect(resolveSeriesTalesEditionPageId('SCP-CN-001')).assertEqual('scp-series-cn-1-tales-edition');
      expect(resolveSeriesTalesEditionPageId('SCP-CN-2000')).assertEqual('scp-series-cn-3-tales-edition');
      expect(resolveSeriesTalesEditionPageId('SCP-CN-4005')).assertEqual('scp-series-cn-5-tales-edition');

      expect(resolveSeriesTalesEditionPageId('SCP-173-J') === undefined).assertTrue();
      expect(resolveSeriesTalesEditionPageId('SCP-CN-963-J') === undefined).assertTrue();
      expect(resolveSeriesTalesEditionPageId('antimemetics-division-hub') === undefined).assertTrue();
    });

    it('matches exact SCP references without false positives from longer numbers or joke variants', 0, () => {
      expect(matchesExactScpReference('scp-173', 'SCP-173')).assertTrue();
      expect(matchesExactScpReference('how-scp-173-got-to-site-19', 'SCP-173')).assertTrue();
      expect(matchesExactScpReference('关于SCP-173的故事', 'SCP-173')).assertTrue();
      expect(matchesExactScpReference('scp-1730 与 scp-173 的对比', 'SCP-173')).assertTrue();
      expect(matchesExactScpReference('scp-cn-2000', 'SCP-CN-2000')).assertTrue();

      expect(matchesExactScpReference('scp-1730', 'SCP-173')).assertFalse();
      expect(matchesExactScpReference('mzl-1730', 'SCP-173')).assertFalse();
      expect(matchesExactScpReference('SCP-1733的故事', 'SCP-173')).assertFalse();
      expect(matchesExactScpReference('scp-173-j', 'SCP-173')).assertFalse();
      expect(matchesExactScpReference('scp-cn-173', 'SCP-173')).assertFalse();
      expect(matchesExactScpReference('scp-cn-20001', 'SCP-CN-2000')).assertFalse();
      expect(matchesExactScpReference('scp-2000', 'SCP-CN-2000')).assertFalse();
    });

    it('parses nested SCP-to-tale mappings while skipping newpage stubs and system links', 0, () => {
      const s1 = SeriesTalesEditionParser.parse(SAMPLE_SERIES_1_HTML, 'scp-series-1-tales-edition');
      expect(s1.version).assertEqual(SERIES_TALES_PARSER_VERSION);
      expect(s1.buckets.length).assertEqual(2);

      const scp001 = s1.buckets[0];
      expect(scp001.scpId).assertEqual('SCP-001');
      expect(scp001.tales.length).assertEqual(3);
      expect(scp001.tales[0].id).assertEqual('spc-001');
      expect(scp001.tales[1].id).assertEqual('peppersghosts-stupid-proposal');
      expect(scp001.tales[2].id).assertEqual('ouroborealis');

      const scp173 = s1.buckets[1];
      expect(scp173.scpId).assertEqual('SCP-173');
      expect(scp173.tales.length).assertEqual(2);
      expect(scp173.tales[0].id).assertEqual('crunch');
      expect(scp173.tales[0].title).assertEqual('折颈');
      expect(scp173.tales[1].id).assertEqual('a-concrete-shrine');
      expect(scp173.tales[1].title).assertEqual('混凝土神龛');

      const s2 = SeriesTalesEditionParser.parse(SAMPLE_SERIES_2_HTML, 'scp-series-2-tales-edition');
      expect(s2.buckets.length).assertEqual(2);
      expect(s2.buckets[0].scpId).assertEqual('SCP-1730');
      expect(s2.buckets[0].tales.length).assertEqual(1);
      expect(s2.buckets[0].tales[0].id).assertEqual('mzl-1730');

      const cn3 = SeriesTalesEditionParser.parse(SAMPLE_SERIES_CN_3_HTML, 'scp-series-cn-3-tales-edition');
      expect(cn3.buckets.length).assertEqual(1);
      expect(cn3.buckets[0].scpId).assertEqual('SCP-CN-2000');
      expect(cn3.buckets[0].tales.length).assertEqual(2);
      expect(cn3.buckets[0].tales[0].title).assertEqual('SC-18/200-20/003：基金会开关测试档案');
      expect(cn3.buckets[0].tales[1].id).assertEqual('ennuis-age');
    });

    it('uses memory and persistent cache, caches 404 misses, and falls back to stale cache on network failure', 0, async () => {
      const htmlRepo = new FakeSeriesTalesHtmlRepo();
      htmlRepo.setHtml(
        'https://scp-wiki-cn.wikidot.com/scp-series-1-tales-edition',
        SAMPLE_SERIES_1_HTML
      );
      htmlRepo.setError(
        'https://scp-wiki-cn.wikidot.com/scp-series-10-tales-edition',
        '页面请求失败：HTTP 404'
      );
      const cacheStore = new MemorySeriesTalesCacheStore();

      const adapter = new SeriesTalesRepositoryAdapter(htmlRepo, cacheStore);
      const firstTales = await adapter.listCuratedTalesForScp('SCP-173');
      expect(firstTales.length).assertEqual(2);
      expect(firstTales[0].id).assertEqual('crunch');
      expect(firstTales[1].id).assertEqual('a-concrete-shrine');
      expect(htmlRepo.loadCalls).assertEqual(1);
      expect(cacheStore.putCalls).assertEqual(1);

      // Same-session lookup for SCP-001 hits in-memory parsed index without HTML fetch or RDB read.
      const prevGets = cacheStore.getCalls;
      const zeroZeroOne = await adapter.listCuratedTalesForScp('SCP-001');
      expect(zeroZeroOne.length).assertEqual(3);
      expect(htmlRepo.loadCalls).assertEqual(1);
      expect(cacheStore.getCalls).assertEqual(prevGets);

      // Fresh second instance reads derived index from RDB without calling HTML repo.
      const secondAdapter = new SeriesTalesRepositoryAdapter(htmlRepo, cacheStore);
      const cachedSecond = await secondAdapter.listCuratedTalesForScp('SCP-173');
      expect(cachedSecond.length).assertEqual(2);
      expect(htmlRepo.loadCalls).assertEqual(1);

      // 404 negative cache suppresses repeat network calls for Series 10 in the same session.
      expect((await adapter.listCuratedTalesForScp('SCP-9000')).length).assertEqual(0);
      expect(htmlRepo.loadCalls).assertEqual(2);
      expect((await adapter.listCuratedTalesForScp('SCP-9001')).length).assertEqual(0);
      expect(htmlRepo.loadCalls).assertEqual(2);

      // Offline stale fallback returns stored stale payload when network refresh fails.
      const stalePayload: SeriesTalesEditionPayload = {
        version: SERIES_TALES_PARSER_VERSION,
        pageId: 'scp-series-2-tales-edition',
        buckets: [
          {
            scpId: 'SCP-1730',
            tales: [{ id: 'mzl-1730', title: 'MZL-1730：Site-19发生了什么？' }]
          }
        ]
      };
      cacheStore.setRecord({
        seriesId: 'tales-edition:scp-series-2-tales-edition',
        json: JSON.stringify(stalePayload),
        parsedAt: Date.now() - (ScpCachePolicy.FRESH_DURATION_MS + 60 * 1000)
      });
      htmlRepo.setError(
        'https://scp-wiki-cn.wikidot.com/scp-series-2-tales-edition',
        '网络连接失败'
      );
      const staleFallback = await adapter.listCuratedTalesForScp('SCP-1730');
      expect(staleFallback.length).assertEqual(1);
      expect(staleFallback[0].id).assertEqual('mzl-1730');
    });
  });
}
