import { describe, expect, it } from '@ohos/hypium';
import { createLibraryContentRef, LibraryContentKind, LibraryContentRef } from 'library';
import {
  ArticleContentSource,
  ArticleDocumentCachePort,
  ArticleDocumentCacheRecord,
  ArticleHtmlPort,
  ArticleHtmlSnapshot
} from '../main/ets/domain/ArticleContracts';
import { ScpArticleDocument, ScpBlockType, ScpTextStyle } from '../main/ets/domain/ScpDocument';
import { createArticleDocumentParser } from '../main/ets/composition/ArticleFeatureFactory';
import { ContentGateway } from '../main/ets/data/ContentGateway';
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
          '{"parserVersion":4,"ok":true,"error":"","title":"bad","rating":"","pageVersion":"","tags":[],"images":[],"blocks":[null],"footnotes":[],"warnings":[]}',
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
        '{"parserVersion":4,"ok":true,"error":"","title":"測試項目","rating":"","pageVersion":"","tags":["scp","containment-class-safe","異常"],"images":[],"blocks":[{"k":"paragraph","spans":[{"s":"plain","t":"特別收容措施"}]}],"footnotes":[{"id":"empty","index":1,"blocks":[{"k":"paragraph","spans":[{"s":"plain","t":"   "}]},{"k":"divider"}]},{"id":"readable","index":2,"blocks":[{"k":"paragraph","spans":[{"s":"plain","t":"腳註內容"}]}]}],"warnings":[]}',
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
  });
}
