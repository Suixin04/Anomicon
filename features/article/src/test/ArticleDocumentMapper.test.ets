import { describe, expect, it } from '@ohos/hypium';
import { createLibraryContentRef, LibraryContentKind, LibraryContentRef } from 'library';
import {
  ArticleContentSource,
  ArticleDocumentCachePort,
  ArticleDocumentCacheRecord,
  ArticleHtmlPort,
  ArticleHtmlSnapshot,
  ArticleHtmlSource
} from '../main/ets/domain/ArticleContracts';
import { ScpArticleDocument, ScpBlockType, ScpTextStyle } from '../main/ets/domain/ScpDocument';
import { createArticleDocumentParser } from '../main/ets/composition/ArticleFeatureFactory';
import { ContentGateway } from '../main/ets/data/ContentGateway';
import { ScpNativeHtmlParser } from '../main/ets/data/ScpNativeHtmlParser';
import {
  CURRENT_PAYLOAD,
  UNSUPPORTED_PARSER_PAYLOAD
} from './ArticleTestFixtures';

class FailingHtmlPort implements ArticleHtmlPort {
  loadCount: number = 0;

  load(_sourceUrl: string, _forceNetwork: boolean = false): Promise<ArticleHtmlSnapshot> {
    this.loadCount += 1;
    return Promise.reject(new Error('source unavailable'));
  }
}

class SingleHtmlPort implements ArticleHtmlPort {
  readonly html: string;

  constructor(html: string) {
    this.html = html;
  }

  load(_sourceUrl: string, _forceNetwork: boolean = false): Promise<ArticleHtmlSnapshot> {
    return Promise.resolve(new ArticleHtmlSnapshot(this.html, ArticleHtmlSource.NETWORK, 1_700_000_000_000));
  }
}

class EmptyDocumentCache implements ArticleDocumentCachePort {
  get(_itemId: string): Promise<ArticleDocumentCacheRecord | undefined> {
    return Promise.resolve(undefined);
  }

  put(_record: ArticleDocumentCacheRecord): Promise<void> {
    return Promise.resolve();
  }

  isFresh(_record: ArticleDocumentCacheRecord): boolean {
    return true;
  }
}

class SingleRecordCache implements ArticleDocumentCachePort {
  readonly record: ArticleDocumentCacheRecord;

  constructor(record: ArticleDocumentCacheRecord) {
    this.record = record;
  }

  get(_itemId: string): Promise<ArticleDocumentCacheRecord | undefined> {
    return Promise.resolve(this.record);
  }

  put(_record: ArticleDocumentCacheRecord): Promise<void> {
    return Promise.resolve();
  }

  isFresh(_record: ArticleDocumentCacheRecord): boolean {
    return true;
  }
}

export default function articleDocumentMapperTest(): void {
  describe('ArticleDocumentMapper', () => {
    it('maps the complete schema-v4 payload into Article-owned models', 0, () => {
      const fetchedAt = 1_700_000_000_000;
      const parser = createArticleDocumentParser();
      const document = parser.parse(
        CURRENT_PAYLOAD,
        'https://scp-wiki-cn.wikidot.com/scp-173',
        fetchedAt
      );

      expect(parser.currentSchemaVersion()).assertEqual(ScpArticleDocument.CURRENT_SCHEMA_VERSION);
      expect(document.schemaVersion).assertEqual(ScpArticleDocument.CURRENT_SCHEMA_VERSION);
      expect(document.itemId).assertEqual('SCP-173');
      expect(document.title).assertEqual('SCP-173 - 雕像');
      expect(document.objectClass).assertEqual('Safe');
      expect(document.rating).assertEqual('+321');
      expect(document.pageVersion).assertEqual('页面版本：4');
      expect(document.fetchedAt).assertEqual(fetchedAt);
      expect(document.tags.length).assertEqual(1);
      expect(document.tags[0]).assertEqual('人形生物');
      expect(document.images.length).assertEqual(1);
      expect(document.images[0].type).assertEqual(ScpBlockType.IMAGE);
      expect(document.blocks.length).assertEqual(4);
      expect(document.blocks[0].type).assertEqual(ScpBlockType.PARAGRAPH);
      expect(document.blocks[0].spans[1].style).assertEqual(ScpTextStyle.STRONG);
      expect(document.blocks[0].spans[2].target).assertEqual('/scp-682');
      expect(document.blocks[0].spans[3].referenceId).assertEqual('note-1');
      expect(document.blocks[1].type).assertEqual(ScpBlockType.COLLAPSIBLE);
      expect(document.blocks[1].children[0].key).assertEqual('SCP-173:0:1:0');
      expect(document.blocks[2].children[0].type).assertEqual(ScpBlockType.TABLE_ROW);
      expect(document.blocks[2].children[0].children[0].type).assertEqual(ScpBlockType.TABLE_CELL);
      expect(document.footnotes[0].blocks[0].key).assertEqual('SCP-173:fn:1:0');
      expect(document.parserWarnings.length).assertEqual(1);
      expect(document.parserWarnings[0]).assertEqual('degraded:test-warning');
    });

    it('discards a cache record with an unsupported parser version', 0, async () => {
      const parsedAt = 1_600_000_000_000;
      const cache = new SingleRecordCache({
        itemId: 'scp-173',
        json: UNSUPPORTED_PARSER_PAYLOAD,
        schemaVersion: ScpArticleDocument.CURRENT_SCHEMA_VERSION,
        parsedAt: parsedAt
      });
      const html = new FailingHtmlPort();
      const gateway = new ContentGateway(
        html,
        cache,
        createArticleDocumentParser()
      );
      const content: LibraryContentRef = createLibraryContentRef(
        LibraryContentKind.SCP,
        'scp-173',
        'SCP-173'
      );

      const result = await gateway.load(content, 77, false);

      expect(html.loadCount).assertEqual(1);
      expect(result.source).assertEqual(ArticleContentSource.NETWORK);
      expect(result.document === undefined).assertTrue();
      expect(result.error).assertEqual('source unavailable');
    });

    it('rejects payloads from unsupported parser versions', 0, () => {
      const parser = createArticleDocumentParser();
      let rejected = false;
      try {
        parser.parse(
          UNSUPPORTED_PARSER_PAYLOAD,
          'https://scp-wiki-cn.wikidot.com/scp-173',
          1_600_000_000_000
        );
      } catch (_error) {
        rejected = true;
      }
      expect(rejected).assertTrue();
    });

    it('rejects malformed nested payload entries before mapping', 0, () => {
      const parser = createArticleDocumentParser();
      let rejected = false;
      try {
        parser.parse(
          '{"parserVersion":5,"ok":true,"error":"","title":"bad","rating":"","pageVersion":"","tags":[],"images":[],"blocks":[null],"footnotes":[],"warnings":[]}',
          'https://scp-wiki-cn.wikidot.com/scp-173',
          1_600_000_000_000
        );
      } catch (error) {
        rejected = true;
      }
      expect(rejected).assertTrue();
    });

    it('normalizes Traditional prose and removes empty footnote rows', 0, () => {
      const parser = createArticleDocumentParser();
      const document = parser.parse(
        '{"parserVersion":5,"ok":true,"error":"","title":"測試項目","rating":"","pageVersion":"","tags":["scp","containment-class-safe","異常"],"images":[],"blocks":[{"k":"paragraph","spans":[{"s":"plain","t":"特別收容措施"}]}],"footnotes":[{"id":"empty","index":1,"blocks":[{"k":"paragraph","spans":[{"s":"plain","t":"   "}]},{"k":"divider"}]},{"id":"readable","index":2,"blocks":[{"k":"paragraph","spans":[{"s":"plain","t":"腳註內容"}]}]}],"warnings":[]}',
        'https://scp-wiki-cn.wikidot.com/scp-999',
        1_700_000_000_000
      );

      expect(document.title).assertEqual('测试项目');
      expect(document.blocks[0].spans[0].text).assertEqual('特别收容措施');
      expect(document.tags.length).assertEqual(1);
      expect(document.tags[0]).assertEqual('异常');
      expect(document.footnotes.length).assertEqual(1);
      expect(document.footnotes[0].blocks[0].spans[0].text).assertEqual('脚注内容');
    });

    it('parses common Wikidot article HTML without ArkWeb', 0, () => {
      const html = '<div id="page-title">SCP-999 - 測試</div>' +
        '<span id="prw123">+42</span>' +
        '<div class="page-tags"><a href="/system:page-tags/tag/scp">scp</a>' +
        '<a href="/system:page-tags/tag/異常">異常</a></div>' +
        '<div id="page-content"><div class="scp-image-block"><img src="/x.jpg" alt="圖" />' +
        '<div class="scp-image-caption">測試圖</div></div>' +
        '<p><strong>項目編號：</strong>SCP-999</p>' +
        '<p><a href="/scp-173">連結</a><sup class="footnoteref"><a id="footnoteref-1">[1]</a></sup></p>' +
        '<hr /><p>正文</p><div class="footer-wikiwalk-nav">噪音</div></div>' +
        '<div id="page-info">頁面版本：8</div>';
      const payload = ScpNativeHtmlParser.parse(html);
      expect(payload.ok).assertTrue();
      const document = createArticleDocumentParser().parse(
        JSON.stringify(payload),
        'https://scp-wiki-cn.wikidot.com/scp-999',
        1_700_000_000_000
      );
      expect(document.title).assertEqual('SCP-999 - 测试');
      expect(document.rating).assertEqual('+42');
      expect(document.tags.length).assertEqual(1);
      expect(document.tags[0]).assertEqual('异常');
      expect(document.images.length).assertEqual(1);
      expect(document.footnotes.length).assertEqual(0);
      expect(document.blocks.length > 0).assertTrue();
    });

    it('publishes the native result directly from ContentGateway', 0, async () => {
      const html = '<div id="page-title">SCP-1000</div>' +
        '<div id="page-content"><p>原生解析正文</p></div>';
      const content = createLibraryContentRef(LibraryContentKind.SCP, 'scp-1000', 'SCP-1000');
      const result = await new ContentGateway(
        new SingleHtmlPort(html),
        new EmptyDocumentCache(),
        createArticleDocumentParser()
      ).load(content, 9, false);
      expect(result.document === undefined).assertFalse();
      expect(result.pendingExtraction === undefined).assertTrue();
      expect(result.document?.title).assertEqual('SCP-1000');
      expect(result.document?.blocks[0].spans[0].text).assertEqual('原生解析正文');
    });

    it('keeps only the visible language branch in original CN markup', 0, () => {
      const html = '<div id="page-title">SCP-CN-2000</div>' +
        '<div id="page-content"><div class="anom-bar-container">' +
        '<span class="lang-cn">项目编号：</span><span class="lang-tr">項目編號：</span>' +
        '<span class="number">CN-2000</span></div></div>';
      const payload = ScpNativeHtmlParser.parse(html);
      expect(payload.ok).assertTrue();
      const document = createArticleDocumentParser().parse(
        JSON.stringify(payload),
        'https://scp-wiki-cn.wikidot.com/scp-cn-2000',
        1_700_000_000_000
      );
      expect(document.blocks[0].spans[0].text).assertEqual('项目编号：');
      expect(document.blocks[0].spans[1].text).assertEqual('CN-2000');
    });

    it('filters nested presentation nodes by semantic id, not string shape', 0, () => {
      const html = '<div id="page-title">SCP-CN-963-J</div>' +
        '<div class="page-tags"><a href="/system:page-tags/tag/搞笑">搞笑</a></div>' +
        '<div id="page-content"><p>正文前</p><p>广告链接是本文笑点的一部分</p>' +
        '<blockquote id=ads><div><p>广告提示不应出现</p></div></blockquote>' +
        '<section id="adend"><div><p>第二段广告不应出现</p></div></section>' +
        '<p>正文后</p></div>';
      const payload = ScpNativeHtmlParser.parse(html);
      expect(payload.ok).assertTrue();
      const serialized = JSON.stringify(payload);
      expect(serialized.indexOf('广告提示不应出现')).assertEqual(-1);
      expect(serialized.indexOf('第二段广告不应出现')).assertEqual(-1);
      expect(serialized.indexOf('正文前') >= 0).assertTrue();
      expect(serialized.indexOf('广告链接是本文笑点的一部分') >= 0).assertTrue();
      expect(serialized.indexOf('正文后') >= 0).assertTrue();
      const document = createArticleDocumentParser().parse(
        JSON.stringify(payload),
        'https://scp-wiki-cn.wikidot.com/scp-cn-963-j',
        1_700_000_000_000
      );
      expect(document.tags.length).assertEqual(1);
      expect(document.tags[0]).assertEqual('搞笑');
    });
  });
}
