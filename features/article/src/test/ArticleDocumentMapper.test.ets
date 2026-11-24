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
import {
  ScpArticleDocument,
  ScpBlockType,
  ScpCalloutTone,
  ScpHiddenTextKind,
  ScpTextAlign,
  ScpTextStyle
} from '../main/ets/domain/ScpDocument';
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
          '{"parserVersion":9,"ok":true,"error":"","title":"bad","rating":"","pageVersion":"","tags":[],"images":[],"blocks":[null],"footnotes":[],"warnings":[]}',
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
        '{"parserVersion":9,"ok":true,"error":"","title":"測試項目","rating":"","pageVersion":"","tags":["scp","containment-class-safe","異常"],"images":[],"blocks":[{"k":"paragraph","spans":[{"s":"plain","t":"特別收容措施"}]}],"footnotes":[{"id":"empty","index":1,"blocks":[{"k":"paragraph","spans":[{"s":"plain","t":"   "}]},{"k":"divider"}]},{"id":"readable","index":2,"blocks":[{"k":"paragraph","spans":[{"s":"plain","t":"腳註內容"}]}]}],"warnings":[]}',
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

    it('strips Wikidot footnote backlink numbering and keeps inline spans together', 0, () => {
      const html = '<div id="page-title">SCP-049</div>' +
        '<div id="page-content"><p>正文中引用<sup class="footnoteref">' +
        '<a id="footnoteref-1" href="javascript:;">[1]</a></sup>。</p>' +
        '<div class="footnotes-footer"><div class="footnote-footer" id="footnote-1">' +
        '<a href="javascript:;" onclick="WIKIDOT.page.utils.scrollToReference(\'footnoteref-1\')">1</a>' +
        '. 脚注<em>正文</em>内容</div></div></div>';
      const payload = ScpNativeHtmlParser.parse(html);
      expect(payload.ok).assertTrue();
      const document = createArticleDocumentParser().parse(
        JSON.stringify(payload),
        'https://scp-wiki-cn.wikidot.com/scp-049',
        1_700_000_000_000
      );
      expect(document.blocks[0].spans[1].text).assertEqual('1');
      expect(document.footnotes.length).assertEqual(1);
      expect(document.footnotes[0].blocks.length).assertEqual(1);
      expect(document.footnotes[0].blocks[0].spans.length).assertEqual(3);
      expect(document.footnotes[0].blocks[0].spans[0].text).assertEqual('脚注');
      expect(document.footnotes[0].blocks[0].spans[1].text).assertEqual('正文');
      expect(document.footnotes[0].blocks[0].spans[2].text).assertEqual('内容');
    });

    it('deduplicates legacy cached footnote numbering without harming plain numbers', 0, () => {
      const parser = createArticleDocumentParser();
      const payload = '{"parserVersion":9,"ok":true,"error":"","title":"SCP-049",' +
        '"rating":"","pageVersion":"","tags":[],"images":[],' +
        '"blocks":[{"k":"paragraph","spans":[{"s":"footnote","t":"[1]","r":"1"}]}],' +
        '"footnotes":[' +
        '{"id":"1","index":1,"blocks":[{"k":"paragraph","spans":[{"s":"plain","t":"1"}]},{"k":"paragraph","spans":[{"s":"plain","t":". 旧缓存拆分脚注"}]}]},' +
        '{"id":"2","index":2,"blocks":[{"k":"paragraph","spans":[{"s":"plain","t":"2. 旧缓存同行脚注"}]}]},' +
        '{"id":"3","index":3,"blocks":[{"k":"paragraph","spans":[{"s":"plain","t":"2024年记录不应被裁掉"}]}]}' +
        '],"warnings":[]}';
      const document = parser.parse(
        payload,
        'https://scp-wiki-cn.wikidot.com/scp-049',
        1_700_000_000_000
      );
      expect(document.blocks[0].spans[0].text).assertEqual('1');
      expect(document.footnotes.length).assertEqual(3);
      expect(document.footnotes[0].blocks.length).assertEqual(1);
      expect(document.footnotes[0].blocks[0].spans[0].text).assertEqual('旧缓存拆分脚注');
      expect(document.footnotes[1].blocks[0].spans[0].text).assertEqual('旧缓存同行脚注');
      expect(document.footnotes[2].blocks[0].spans[0].text).assertEqual('2024年记录不应被裁掉');
    });

    it('purifies CSS/JS, display:none, rate widgets, avatars and extracts credits', 0, () => {
      const html = '<div id="page-title">SCP-CN-9999</div>' +
        '<div id="page-content">' +
        '<div class="page-rate-widget-box"><span class="rate-points">+99</span><a>+</a><a>-</a></div>' +
        '<span class="myTitle" style="display: none;">隐藏标题</span>' +
        '<div id="u-credit-view"><div class="modalbox"><h2>著作信息</h2><div class="credit">' +
        '<p>作者：<img class="small" src="https://www.wikidot.com/avatar.php?userid=1" alt="User" />A</p>' +
        '</div></div></div>' +
        '<p><div class="anomicon-embedded-html"><style>.x{color:red}</style><script>var a=1<2;</script>' +
        '<p>嵌入列表项一</p><p>嵌入列表项二</p></div></p>' +
        '<p><img class="small" src="https://www.wikidot.com/avatar.php?userid=2" alt="Bot" />正文内容</p>' +
        '</div>';
      const payload = ScpNativeHtmlParser.parse(html);
      expect(payload.ok).assertTrue();
      const serialized = JSON.stringify(payload);
      expect(serialized.indexOf('.x{color:red}')).assertEqual(-1);
      expect(serialized.indexOf('var a=1')).assertEqual(-1);
      expect(serialized.indexOf('隐藏标题')).assertEqual(-1);
      expect(serialized.indexOf('+99')).assertEqual(-1);
      const doc = createArticleDocumentParser().parse(
        serialized,
        'https://scp-wiki-cn.wikidot.com/scp-cn-9999',
        1_700_000_000_000
      );
      expect(doc.images.length).assertEqual(0);
      expect(doc.creditBlocks.length).assertEqual(1);
      expect(doc.blocks.length).assertEqual(3);
      expect(doc.blocks[0].spans[0].text).assertEqual('嵌入列表项一');
      expect(doc.blocks[1].spans[0].text).assertEqual('嵌入列表项二');
      expect(doc.blocks[2].spans[0].text).assertEqual('正文内容');
    });

    it('emits in-place images with cleaned filename captions and preferred width', 0, () => {
      const html = '<div id="page-title">SCP-2521</div>' +
        '<div id="page-content">' +
        '<div class="scp-image-block" style="width:120px;"><img src="https://img/a.png" />' +
        '<div class="scp-image-caption">收容图注</div></div>' +
        '<div class="image-container"><img src="https://img/b.png" alt="lock2.png" width="110" /></div>' +
        '<p>前段<img src="https://img/c.png" alt="fractal.jpg" />后段</p>' +
        '</div>';
      const doc = createArticleDocumentParser().parse(
        JSON.stringify(ScpNativeHtmlParser.parse(html)),
        'https://scp-wiki-cn.wikidot.com/scp-2521',
        1_700_000_000_000
      );
      expect(doc.images.length).assertEqual(3);
      expect(doc.blocks[0].type).assertEqual(ScpBlockType.IMAGE);
      expect(doc.blocks[0].caption).assertEqual('收容图注');
      expect(doc.blocks[0].preferredWidth).assertEqual(120);
      expect(doc.blocks[1].type).assertEqual(ScpBlockType.IMAGE);
      expect(doc.blocks[1].caption).assertEqual('');
      expect(doc.blocks[1].preferredWidth).assertEqual(110);
      expect(doc.blocks[2].type).assertEqual(ScpBlockType.PARAGRAPH);
      expect(doc.blocks[3].type).assertEqual(ScpBlockType.IMAGE);
      expect(doc.blocks[3].caption).assertEqual('');
      expect(doc.blocks[4].type).assertEqual(ScpBlockType.PARAGRAPH);
    });

    it('parses ACS header, Tabviews, Colmod, Callouts, Code, Lists, Tables and CN Ruby', 0, () => {
      const html = '<div id="page-title">SCP-2316</div>' +
        '<div id="page-content">' +
        '<div class="anom-bar-container item-2316 clear-4"><div class="anom-bar">' +
        '<div class="top-left-box"><span class="number">2316</span></div>' +
        '<div class="top-right-box"><div class="level">等级4</div></div>' +
        '<div class="contain-class"><div class="class-text">Keter</div></div>' +
        '<div class="second-class"><div class="class-text">none</div></div>' +
        '<div class="disrupt-class"><div class="class-text">keneq</div></div>' +
        '<div class="risk-class"><div class="class-text">危险</div></div>' +
        '</div></div>' +
        '<div class="yui-navset"><ul class="yui-nav"><li><a href="javascript:;">Tab1</a></li>' +
        '<li><a href="javascript:;">Tab2</a></li></ul>' +
        '<div class="yui-content"><div><p>第一页</p></div>' +
        '<div style="display:none"><p>第二页隐藏面板</p></div></div></div>' +
        '<div class="colmod-block"><ul><li class="unfolded">' +
        '<div class="colmod-link-top"><a href="javascript:;">打开</a><a href="javascript:;">收起</a></div>' +
        '<div class="colmod-content"><p>默认展开内容</p></div></li></ul></div>' +
        '<div style="border:solid 1px #909090; background:black;"><p>终端输出</p></div>' +
        '<pre>line1\n  line2</pre>' +
        '<ol><li>一级列表<ul><li>二级列表</li></ul></li></ol>' +
        '<table><tr><th>表头A</th><th>表头B</th></tr><tr><td><strong>C1</strong></td><td>C2</td></tr></table>' +
        '<p>前往<span class="ruby">特外站点<span class="rt">Site-06</span></span>。</p>' +
        '</div>';
      const doc = createArticleDocumentParser().parse(
        JSON.stringify(ScpNativeHtmlParser.parse(html)),
        'https://scp-wiki-cn.wikidot.com/scp-2316',
        1_700_000_000_000
      );
      expect(doc.objectClass).assertEqual('Keter');
      expect(doc.blocks[0].type).assertEqual(ScpBlockType.ACS_HEADER);
      expect(doc.blocks[0].acs?.clearanceLevel).assertEqual('4');
      expect(doc.blocks[0].acs?.secondaryClass).assertEqual('');
      expect(doc.blocks[0].acs?.disruptionClass).assertEqual('keneq');
      expect(doc.blocks[1].type).assertEqual(ScpBlockType.TABS);
      expect(doc.blocks[1].children.length).assertEqual(2);
      expect(doc.blocks[1].children[1].children[0].spans[0].text).assertEqual('第二页隐藏面板');
      expect(doc.blocks[2].type).assertEqual(ScpBlockType.COLLAPSIBLE);
      expect(doc.blocks[2].initiallyExpanded).assertTrue();
      expect(doc.blocks[2].closeCaption).assertEqual('收起');
      expect(doc.blocks[3].type).assertEqual(ScpBlockType.CALLOUT);
      expect(doc.blocks[3].calloutTone).assertEqual(ScpCalloutTone.TERMINAL);
      expect(doc.blocks[4].type).assertEqual(ScpBlockType.CODE_BLOCK);
      expect(doc.blocks[4].spans[0].text).assertEqual('line1\n  line2');
      expect(doc.blocks[5].type).assertEqual(ScpBlockType.LIST);
      expect(doc.blocks[5].ordered).assertTrue();
      expect(doc.blocks[5].children[0].children[0].type).assertEqual(ScpBlockType.LIST);
      expect(doc.blocks[6].type).assertEqual(ScpBlockType.TABLE);
      expect(doc.blocks[6].children[0].children[0].isHeader).assertTrue();
      expect(doc.blocks[7].spans.map((span) => span.text).join('')).assertEqual('前往特外站点（Site-06）。');
    });

    it('keeps interactive html-block-iframe widgets as EMBED without leaking CSS/JS', 0, async () => {
      const outerHtml = '<div id="page-title">SCP-3125</div>' +
        '<div id="page-content"><p><iframe class="html-block-iframe" src="/scp-3125/html/widget"></iframe></p></div>';
      const innerHtml = '<html><head><style>.keypad{color:red}</style></head>' +
        '<body><div class="keypad"><input type="button" value="5" /></div>' +
        '<script>var magicNumber = 55555; button.onclick = function(){};</script></body></html>';
      class WidgetHtmlPort implements ArticleHtmlPort {
        load(sourceUrl: string, _forceNetwork: boolean = false): Promise<ArticleHtmlSnapshot> {
          return Promise.resolve(new ArticleHtmlSnapshot(
            sourceUrl.indexOf('/html/widget') >= 0 ? innerHtml : outerHtml,
            ArticleHtmlSource.NETWORK,
            1_700_000_000_000
          ));
        }
      }
      const gateway = new ContentGateway(
        new WidgetHtmlPort(),
        new EmptyDocumentCache(),
        createArticleDocumentParser()
      );
      const content = createLibraryContentRef(LibraryContentKind.SCP, 'scp-3125', 'SCP-3125');
      const res = await gateway.load(content, 1, false);
      expect(res.document !== undefined).assertTrue();
      expect(res.document?.blocks[0].type).assertEqual(ScpBlockType.EMBED);
      expect(JSON.stringify(res.document).indexOf('magicNumber')).assertEqual(-1);
    });

    it('unwraps double-wrapped iframe lists, adult modal warnings, extensionless image alts, and colmod hide labels', 0, async () => {
      const outerHtml = '<div id="page-title">SCP-001</div>' +
        '<div id="page-content"><p><iframe class="html-block-iframe" src="/scp-001/html/proposals"></iframe></p></div>';
      const doubleWrappedInner = '<body><!DOCTYPE html><html><head><style>body{color:red}</style></head>' +
        '<body><ul id="zero-zero-ones"><li><p><a href="/jonathan-ball">代号：Jonathan</a> - 资料卷</p></li>' +
        '<li><p><a href="/dr-gears">代号：Gears</a> - 原型</p></li></ul></body></html></body>';
      class ProposalsHtmlPort implements ArticleHtmlPort {
        load(sourceUrl: string, _forceNetwork: boolean = false): Promise<ArticleHtmlSnapshot> {
          return Promise.resolve(new ArticleHtmlSnapshot(
            sourceUrl.indexOf('/html/proposals') >= 0 ? doubleWrappedInner : outerHtml,
            ArticleHtmlSource.NETWORK,
            1_700_000_000_000
          ));
        }
      }
      const proposalsRes = await new ContentGateway(
        new ProposalsHtmlPort(),
        new EmptyDocumentCache(),
        createArticleDocumentParser()
      ).load(createLibraryContentRef(LibraryContentKind.SCP, 'scp-001', 'SCP-001'), 2, false);
      expect(proposalsRes.document !== undefined).assertTrue();
      expect(proposalsRes.document?.blocks[0].type).assertEqual(ScpBlockType.LIST);
      expect(proposalsRes.document?.blocks[0].children.length).assertEqual(2);
      expect(proposalsRes.document?.blocks[0].children[0].spans[0].text).assertEqual('代号：Jonathan');

      const polishHtml = '<div id="page-title">SCP-3999</div>' +
        '<div id="page-content">' +
        '<ul class="modal-wrapper"><li class="unfolded"><div id="u-adult-warning">' +
        '<div class="content-descriptor"><span style="display: syntax error near `{$sexually">性露骨：跳过</span>' +
        '<span style="display: block">血腥：描绘血液。</span><span>{$custom-content}</span></div>' +
        '</div></li></ul>' +
        '<p><img src="http://example.com/path/skiplogosmall" alt="skiplogosmall" /></p>' +
        '<div class="colmod-block"><ul><li class="unfolded">' +
        '<div class="colmod-link-top"><a href="javascript:;">访问文档</a><a href="javascript:;">- Hide block</a></div>' +
        '<div class="colmod-content"><p>正片</p></div></li></ul></div>' +
        '</div>';
      const polishDoc = createArticleDocumentParser().parse(
        JSON.stringify(ScpNativeHtmlParser.parse(polishHtml)),
        'https://scp-wiki-cn.wikidot.com/scp-3999',
        1_700_000_000_000
      );
      expect(polishDoc.blocks[0].type).assertEqual(ScpBlockType.CALLOUT);
      expect(polishDoc.blocks[0].calloutTone).assertEqual(ScpCalloutTone.WARNING);
      expect(JSON.stringify(polishDoc.blocks[0]).indexOf('{$custom-content}')).assertEqual(-1);
      expect(polishDoc.blocks[1].type).assertEqual(ScpBlockType.IMAGE);
      expect(polishDoc.blocks[1].caption).assertEqual('');
      expect(polishDoc.blocks[2].type).assertEqual(ScpBlockType.COLLAPSIBLE);
      expect(polishDoc.blocks[2].closeCaption).assertEqual('');
    });

    it('parses combinable inline styles and inherited block alignment', 0, () => {
      const html = '<div id="page-title">SCP-001</div>' +
        '<div id="page-content">' +
        '<div style="text-align: center;"><h1><span style="font-size:200%; color:#990000;">警告：</span></h1>' +
        '<p><span style="text-decoration: line-through;"><a href="/scp-001-o5">代号：Bright</a> - 工厂</span></p></div>' +
        '<p style="text-align: right;"><u>我</u>与<tt><strong><span style="color:green;">状态</span></strong></tt><sup>上</sup><sub>下</sub></p>' +
        '</div>';
      const doc = createArticleDocumentParser().parse(
        JSON.stringify(ScpNativeHtmlParser.parse(html)),
        'https://scp-wiki-cn.wikidot.com/scp-001',
        1_700_000_000_000
      );
      expect(doc.blocks[0].type).assertEqual(ScpBlockType.HEADING);
      expect(doc.blocks[0].textAlign).assertEqual(ScpTextAlign.CENTER);
      expect(doc.blocks[0].spans[0].color).assertEqual('#990000');
      expect(doc.blocks[0].spans[0].fontScale > 1.5).assertTrue();

      expect(doc.blocks[1].textAlign).assertEqual(ScpTextAlign.CENTER);
      expect(doc.blocks[1].spans[0].style).assertEqual(ScpTextStyle.LINK);
      expect(doc.blocks[1].spans[0].target).assertEqual('/scp-001-o5');
      expect(doc.blocks[1].spans[0].deleted).assertTrue();
      expect(doc.blocks[1].spans[1].deleted).assertTrue();

      expect(doc.blocks[2].textAlign).assertEqual(ScpTextAlign.END);
      expect(doc.blocks[2].spans[0].underline).assertTrue();
      expect(doc.blocks[2].spans[2].bold).assertTrue();
      expect(doc.blocks[2].spans[2].monospace).assertTrue();
      expect(doc.blocks[2].spans[2].color).assertEqual('#16A34A');
      expect(doc.blocks[2].spans[3].superscript).assertTrue();
      expect(doc.blocks[2].spans[4].subscript).assertTrue();
    });

    it('detects context-aware hidden Easter eggs while keeping dark-terminal white text and dropping transparent spacers', 0, () => {
      const html = '<div id="page-title">SCP-2316</div>' +
        '<div id="page-content">' +
        '<p><tt><span style="color:#F5F5F5">他们已经等了很久了。</span></tt></p>' +
        '<p><span style="color:black; background-color: black">你不认识水中的尸体</span>：正常正文</p>' +
        '<p><span class="blackbox">机密抹黑</span></p>' +
        '<p><span style="color:white">我们曾和他们在一起</span></p>' +
        '<div style="border:solid 1px #909090; background:black; color:#909090;"><p><span style="color: white">O5-11</span></p></div>' +
        '<p><span style="font-size:0px;">第一句低语。</span></p>' +
        '<p><span style="font-size:0px;">第二句低语。</span></p>' +
        '<p><span style="font-size:0%;">零百分比低语</span></p>' +
        '<p><span style="color: transparent">.</span><br /><span style="color: transparent">&#8230;</span></p>' +
        '</div>';
      const doc = createArticleDocumentParser().parse(
        JSON.stringify(ScpNativeHtmlParser.parse(html)),
        'https://scp-wiki-cn.wikidot.com/scp-2316',
        1_700_000_000_000
      );

      // Transparent single-dot/ellipsis spacer paragraph dropped completely.
      expect(doc.blocks.length).assertEqual(6);
      expect(doc.blocks[0].spans[0].hiddenKind).assertEqual(ScpHiddenTextKind.WHITE_EASTER_EGG);
      expect(doc.blocks[0].spans[0].monospace).assertTrue();

      expect(doc.blocks[1].spans[0].hiddenKind).assertEqual(ScpHiddenTextKind.BLACKBOX);
      expect(doc.blocks[1].spans[1].hiddenKind).assertEqual(ScpHiddenTextKind.NONE);

      expect(doc.blocks[2].spans[0].hiddenKind).assertEqual(ScpHiddenTextKind.BLACKBOX);
      expect(doc.blocks[3].spans[0].hiddenKind).assertEqual(ScpHiddenTextKind.WHITE_EASTER_EGG);

      // White text inside black terminal container stays visible white, NOT hidden!
      expect(doc.blocks[4].type).assertEqual(ScpBlockType.CALLOUT);
      expect(doc.blocks[4].calloutTone).assertEqual(ScpCalloutTone.TERMINAL);
      expect(doc.blocks[4].children[0].spans[0].hiddenKind).assertEqual(ScpHiddenTextKind.NONE);
      expect(doc.blocks[4].children[0].spans[0].color).assertEqual('#FFFFFF');

      // Consecutive 0px / 0% whisper paragraphs coalesce into one whisper block!
      expect(doc.blocks[5].spans.map((s) => s.text).join('')).assertEqual('第一句低语。\n第二句低语。\n零百分比低语');
      expect(doc.blocks[5].spans[0].hiddenKind).assertEqual(ScpHiddenTextKind.ZERO_SIZE_WHISPER);
    });

    it('detects listpages-offset links and large custom format-screw CSS without BHL/ACS false positives', 0, () => {
      const paddingCss = '/* pad */ '.repeat(500);
      const offsetHtml = '<head><style id="internal-style">@keyframes k{from{opacity:0}} ' + paddingCss + '</style>' +
        '<style>.anom-bar-container{display:grid;grid-template-columns:1fr;} @keyframes a{from{opacity:0}} ' + paddingCss + '</style></head>' +
        '<div id="page-title">SCP-CN-2000</div>' +
        '<div id="page-content"><div class="collapsible-block"><div class="collapsible-block-unfolded" style="display:none">' +
        '<div class="collapsible-block-content"><p><a href="https://scp-wiki-cn.wikidot.com/scp-cn-2000/offset/1">访问迭代一</a></p></div>' +
        '</div></div></div>';
      const offsetPayload = ScpNativeHtmlParser.parse(offsetHtml);
      expect(offsetPayload.warnings.indexOf('interactive:listpages-offset') >= 0).assertTrue();
      expect(offsetPayload.warnings.indexOf('format-screw:custom-css') >= 0).assertFalse();

      const customCssHtml = '<head><style>:root{--bg:#120824;} @keyframes glitch{0%{clip-path:inset(0);}} ' + paddingCss + '</style></head>' +
        '<div id="page-title">SCP-CN-1109</div>' +
        '<div id="page-content"><p>特殊视觉版式正文</p></div>';
      const customCssPayload = ScpNativeHtmlParser.parse(customCssHtml);
      expect(customCssPayload.warnings.indexOf('format-screw:custom-css') >= 0).assertTrue();
      expect(customCssPayload.warnings.indexOf('interactive:listpages-offset') >= 0).assertFalse();

      const cleanBhlHtml = '<head><style>.black-highlighter{--x:1;} @keyframes k{from{opacity:0}} ' + paddingCss + '</style></head>' +
        '<div id="page-title">SCP-1730</div>' +
        '<div id="page-content"><p>普通长文档正文</p><div class="footer-wikiwalk-nav"><a href="/scp-1730/offset/1">噪音</a></div></div>';
      const cleanPayload = ScpNativeHtmlParser.parse(cleanBhlHtml);
      expect(cleanPayload.warnings.indexOf('format-screw:custom-css') >= 0).assertFalse();
      expect(cleanPayload.warnings.indexOf('interactive:listpages-offset') >= 0).assertFalse();
    });

    it('preserves anchors across preceding empty blocks and detects pre-expanded collapsibles', 0, () => {
      const html = '<div id="page-title">机动特遣队</div>' +
        '<div id="page-content">' +
        '<blockquote><div class="collapsible-block">' +
        '<div class="collapsible-block-folded" style="display:none"><a class="collapsible-block-link" href="javascript:;">+ 展开目录</a></div>' +
        '<div class="collapsible-block-unfolded"><div class="collapsible-block-unfolded-link"><a class="collapsible-block-link" href="javascript:;">- 收起目录</a></div>' +
        '<div class="collapsible-block-content"><p><a href="#alpha-1">红右手</a></p></div></div>' +
        '</div></blockquote>' +
        '<div class="collapsible-block">' +
        '<div class="collapsible-block-folded"><a class="collapsible-block-link" href="javascript:;">+ 默认折叠</a></div>' +
        '<div class="collapsible-block-unfolded" style="display:none"><div class="collapsible-block-content"><p>秘密内容</p></div></div>' +
        '</div>' +
        '<p><a name="alpha-1"></a></p>' +
        '<div class="content-panel standalone series"><div><h1 id="toc0"><span>机动特遣队Alpha-1</span></h1><p>详细档案</p></div></div>' +
        '</div>';
      const doc = createArticleDocumentParser().parse(
        JSON.stringify(ScpNativeHtmlParser.parse(html)),
        'https://scp-wiki-cn.wikidot.com/task-forces',
        1_700_000_000_000
      );

      expect(doc.blocks.length).assertEqual(3);
      expect(doc.blocks[0].type).assertEqual(ScpBlockType.QUOTE);
      expect(doc.blocks[0].children[0].type).assertEqual(ScpBlockType.COLLAPSIBLE);
      expect(doc.blocks[0].children[0].initiallyExpanded).assertTrue();
      expect(doc.blocks[0].children[0].children[0].spans[0].target).assertEqual('#alpha-1');

      expect(doc.blocks[1].type).assertEqual(ScpBlockType.COLLAPSIBLE);
      expect(doc.blocks[1].initiallyExpanded).assertFalse();

      expect(doc.blocks[2].type).assertEqual(ScpBlockType.CALLOUT);
      expect(doc.blocks[2].anchors.indexOf('alpha-1') >= 0).assertTrue();
      expect(doc.blocks[2].children[0].type).assertEqual(ScpBlockType.HEADING);
      expect(doc.blocks[2].children[0].anchors.indexOf('toc0') >= 0).assertTrue();
    });
  });
}
