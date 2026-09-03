import { describe, expect, it } from '@ohos/hypium';
import {
  SCP_CATALOG_PARSER_VERSION,
  TALE_LIST_PARSER_VERSION
} from '../main/ets/domain/StaticCatalogContracts';
import { StaticCatalogHtmlParser } from '../main/ets/data/StaticCatalogHtmlParser';

export default function staticCatalogHtmlParserTest(): void {
  describe('StaticCatalogHtmlParserContract', () => {
    it('returns a validated catalog payload for the series panel', 0, () => {
      const html = '<div id="page-content"><div class="content-panel series">' +
        '<a href="/scp-173">SCP-173 - 雕像</a>' +
        '<a href="/scp-174">SCP-174 - 項目測試</a></div></div>';
      const result = StaticCatalogHtmlParser.parseCatalog(html);

      expect(result.ok).assertTrue();
      expect(result.parserVersion).assertEqual(SCP_CATALOG_PARSER_VERSION);
      expect(result.entries.length).assertEqual(2);
      expect(result.entries[0].itemId).assertEqual('SCP-173');
      expect(result.entries[1].title).assertEqual('项目测试');
    });

    it('keeps original CN SCP entries and their parent titles', 0, () => {
      const html = '<div id="page-content"><div class="content-panel series"><ul>' +
        '<li><a href="/scp-cn-2000">SCP-CN-2000</a> - 混沌理论</li>' +
        '<li><a href="/scp-cn-963-j">SCP-CN-963-J</a> - 这不是演习</li>' +
        '</ul></div></div>';
      const result = StaticCatalogHtmlParser.parseCatalog(html);
      expect(result.ok).assertTrue();
      expect(result.entries.length).assertEqual(2);
      expect(result.entries[0].itemId).assertEqual('SCP-CN-2000');
      expect(result.entries[0].title).assertEqual('混沌理论');
      expect(result.entries[1].itemId).assertEqual('SCP-CN-963-J');
      expect(result.entries[1].title).assertEqual('这不是演习');
    });

    it('keeps entertainment SCP-J entries from a joke index', 0, () => {
      const html = '<div id="page-content"><p><a href="/scp-700-j">SCP-700-J</a> - ' +
        '会唱歌的计算器</p><p><a href="/scp-cn-963-j">SCP-CN-963-J</a> - 神烦代码</p></div>';
      const result = StaticCatalogHtmlParser.parseCatalog(html);
      expect(result.ok).assertTrue();
      expect(result.entries.length).assertEqual(2);
      expect(result.entries[0].title).assertEqual('会唱歌的计算器');
      expect(result.entries[1].title).assertEqual('神烦代码');
    });

    it('normalizes Traditional Chinese tale titles before rendering', 0, () => {
      const html = '<div id="page-content">' +
        '<a href="/1-mr-headless">1. 無頭先生</a>' +
        '<a href="/10-mr-mission">10. 任務先生</a></div>';
      const result = StaticCatalogHtmlParser.parseTales(html);

      expect(result.ok).assertTrue();
      expect(result.tales[0].title).assertEqual('1. 无头先生');
      expect(result.tales[1].title).assertEqual('10. 任务先生');
    });

    it('rejects malformed pages with a typed failure payload', 0, () => {
      const catalog = StaticCatalogHtmlParser.parseCatalog('<html></html>');
      const tales = StaticCatalogHtmlParser.parseTales('<html></html>');

      expect(catalog.ok).assertFalse();
      expect(catalog.parserVersion).assertEqual(SCP_CATALOG_PARSER_VERSION);
      expect(catalog.entries.length).assertEqual(0);
      expect(tales.ok).assertFalse();
      expect(tales.parserVersion).assertEqual(TALE_LIST_PARSER_VERSION);
      expect(tales.tales.length).assertEqual(0);
    });
  });
}
