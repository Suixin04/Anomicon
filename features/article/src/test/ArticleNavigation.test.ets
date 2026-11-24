import { describe, expect, it } from '@ohos/hypium';
import {
  ArticleIndexSectionInput,
  ArticleTocKind,
  buildArticleNavigationIndex,
  extractUrlAnchorFragment,
  isNoiseArticleAnchor,
  normalizeArticleAnchor,
  resolveAnchorLocation,
  searchArticleDocument,
  splitTextForSearchHighlight
} from '../main/ets/domain/ArticleNavigation';
import {
  ScpArticleDocument,
  ScpBlockType,
  ScpCalloutTone,
  ScpContentBlock,
  ScpFootnote,
  ScpTextAlign,
  ScpTextSpan,
  ScpTextStyle
} from '../main/ets/domain/ScpDocument';

function makeBlock(
  key: string,
  type: ScpBlockType,
  spans: ScpTextSpan[] = [],
  caption: string = '',
  level: number = 0,
  children: ScpContentBlock[] = [],
  anchors: string[] = []
): ScpContentBlock {
  return new ScpContentBlock(
    key,
    type,
    spans,
    '',
    caption,
    level,
    children,
    '',
    false,
    false,
    false,
    ScpCalloutTone.NEUTRAL,
    0,
    undefined,
    ScpTextAlign.DEFAULT,
    anchors
  );
}

function createNavigationTestDocument(): ScpArticleDocument {
  const headingIntro = makeBlock(
    'doc:h1',
    ScpBlockType.HEADING,
    [new ScpTextSpan(ScpTextStyle.PLAIN, '特殊收容措施')],
    '',
    1,
    [],
    ['u-toc0']
  );

  const quoteInner = makeBlock(
    'doc:quote:0',
    ScpBlockType.PARAGRAPH,
    [new ScpTextSpan(ScpTextStyle.PLAIN, '引文首段')]
  );
  const quote = makeBlock(
    'doc:quote',
    ScpBlockType.QUOTE,
    [],
    '',
    0,
    [quoteInner],
    ['alpha-quote']
  );

  const nestedHeading = makeBlock(
    'doc:col:h2',
    ScpBlockType.HEADING,
    [new ScpTextSpan(ScpTextStyle.PLAIN, '实验记录 A')],
    '',
    2,
    [],
    ['exp-a']
  );
  const collapsible = makeBlock(
    'doc:col',
    ScpBlockType.COLLAPSIBLE,
    [],
    '展开附录 A',
    0,
    [nestedHeading]
  );

  const tab0Panel = makeBlock(
    'doc:tabs:0',
    ScpBlockType.PARAGRAPH,
    [],
    '迭代一',
    0,
    [makeBlock('doc:tabs:0:p', ScpBlockType.PARAGRAPH, [new ScpTextSpan(ScpTextStyle.PLAIN, '首页正文')])]
  );
  const tab1Target = makeBlock(
    'doc:tabs:1:target',
    ScpBlockType.PARAGRAPH,
    [new ScpTextSpan(ScpTextStyle.PLAIN, 'Second tab secret code Alpha-9')],
    '',
    0,
    [],
    ['tab-secret']
  );
  const tab1Panel = makeBlock(
    'doc:tabs:1',
    ScpBlockType.PARAGRAPH,
    [],
    '迭代二',
    0,
    [tab1Target]
  );
  const tabs = makeBlock(
    'doc:tabs',
    ScpBlockType.TABS,
    [],
    '',
    0,
    [tab0Panel, tab1Panel]
  );

  const creditParagraph = makeBlock(
    'doc:credits:p',
    ScpBlockType.PARAGRAPH,
    [new ScpTextSpan(ScpTextStyle.PLAIN, 'Author Beta')]
  );

  const fnParagraph = makeBlock(
    'doc:fn:1:p',
    ScpBlockType.PARAGRAPH,
    [new ScpTextSpan(ScpTextStyle.PLAIN, 'Footnote Alpha Note')]
  );
  const fn = new ScpFootnote('1', 1, [fnParagraph]);

  return new ScpArticleDocument(
    'scp-test',
    '测试档案',
    'Safe',
    'https://scp-wiki-cn.wikidot.com/scp-test',
    1_700_000_000_000,
    [headingIntro, quote, collapsible, tabs],
    [fn],
    '',
    [],
    '',
    [],
    '',
    [],
    [creditParagraph]
  );
}

export default function articleNavigationTest(): void {
  describe('ArticleNavigation', () => {
    it('normalizes anchors, filters noise ids, and extracts URL fragments', 0, () => {
      expect(normalizeArticleAnchor(' ##Alpha-1%20Test ')).assertEqual('alpha-1 test');
      expect(extractUrlAnchorFragment('https://scp-wiki-cn.wikidot.com/task-forces#Alpha-1')).assertEqual('alpha-1');
      expect(extractUrlAnchorFragment('/scp-173')).assertEqual('');

      expect(isNoiseArticleAnchor('page-content')).assertTrue();
      expect(isNoiseArticleAnchor('footnote-1')).assertTrue();
      expect(isNoiseArticleAnchor('footnoteref-1')).assertTrue();
      expect(isNoiseArticleAnchor('prw123')).assertTrue();
      expect(isNoiseArticleAnchor('alpha-1')).assertFalse();
    });

    it('resolves anchors with u- prefix fallback, flattened quote extras, nested collapsibles, and inactive tabs', 0, () => {
      const doc = createNavigationTestDocument();
      const syntheticCreditsBlock = makeBlock(
        `${doc.itemId}:__credits__`,
        ScpBlockType.COLLAPSIBLE,
        [],
        '著作信息',
        0,
        doc.creditBlocks
      );
      const sections: ArticleIndexSectionInput[] = [
        { sectionIndex: 0, block: doc.blocks[0] },
        { sectionIndex: 1, block: doc.blocks[1].children[0], extraAnchors: doc.blocks[1].anchors },
        { sectionIndex: 2, block: doc.blocks[2] },
        { sectionIndex: 3, block: doc.blocks[3] },
        { sectionIndex: 4, block: syntheticCreditsBlock },
        { sectionIndex: 6, block: doc.footnotes[0].blocks[0], extraAnchors: [`footnote-${doc.footnotes[0].id}`] }
      ];
      const nav = buildArticleNavigationIndex(sections, doc.footnotes, 5);

      const tocLoc = resolveAnchorLocation(nav, '#toc0');
      expect(tocLoc !== undefined).assertTrue();
      expect(tocLoc!.sectionIndex).assertEqual(0);
      expect(tocLoc!.blockKey).assertEqual('doc:h1');

      const quoteLoc = resolveAnchorLocation(nav, 'alpha-quote');
      expect(quoteLoc !== undefined).assertTrue();
      expect(quoteLoc!.sectionIndex).assertEqual(1);

      const nestedLoc = resolveAnchorLocation(nav, 'exp-a');
      expect(nestedLoc !== undefined).assertTrue();
      expect(nestedLoc!.sectionIndex).assertEqual(2);
      expect(nestedLoc!.expandCollapsibleKeys.length).assertEqual(1);
      expect(nestedLoc!.expandCollapsibleKeys[0]).assertEqual('doc:col');

      const tabLoc = resolveAnchorLocation(nav, 'tab-secret');
      expect(tabLoc !== undefined).assertTrue();
      expect(tabLoc!.sectionIndex).assertEqual(3);
      expect(tabLoc!.tabTargets.length).assertEqual(1);
      expect(tabLoc!.tabTargets[0].tabsBlockKey).assertEqual('doc:tabs');
      expect(tabLoc!.tabTargets[0].tabIndex).assertEqual(1);

      // TOC includes headings, non-credit collapsibles, and footnotes while omitting synthetic __credits__
      expect(nav.tocItems.length).assertEqual(4);
      expect(nav.tocItems[0].kind).assertEqual(ArticleTocKind.HEADING);
      expect(nav.tocItems[0].level).assertEqual(1);
      expect(nav.tocItems[1].kind).assertEqual(ArticleTocKind.COLLAPSIBLE);
      expect(nav.tocItems[2].title).assertEqual('实验记录 A');
      expect(nav.tocItems[2].level).assertEqual(2);
      expect(nav.tocItems[3].kind).assertEqual(ArticleTocKind.FOOTNOTES);
      expect(nav.tocItems[3].location.sectionIndex).assertEqual(5);
    });

    it('searches across visible, collapsed, tab, credit, and footnote blocks with location metadata', 0, () => {
      const doc = createNavigationTestDocument();
      const sections: ArticleIndexSectionInput[] = [
        { sectionIndex: 0, block: doc.blocks[0] },
        { sectionIndex: 1, block: doc.blocks[1].children[0], extraAnchors: doc.blocks[1].anchors },
        { sectionIndex: 2, block: doc.blocks[2] },
        { sectionIndex: 3, block: doc.blocks[3] },
        { sectionIndex: 6, block: doc.footnotes[0].blocks[0], extraAnchors: [`footnote-${doc.footnotes[0].id}`] }
      ];
      const nav = buildArticleNavigationIndex(sections, doc.footnotes, 5);

      const tabHits = searchArticleDocument(doc, nav, 'alpha-9');
      expect(tabHits.length).assertEqual(1);
      expect(tabHits[0].location.tabTargets.length).assertEqual(1);
      expect(tabHits[0].location.tabTargets[0].tabIndex).assertEqual(1);
      expect(tabHits[0].contextLabel).assertEqual('标签：迭代二');

      const collapsedHits = searchArticleDocument(doc, nav, '实验记录');
      expect(collapsedHits.length).assertEqual(1);
      expect(collapsedHits[0].location.expandCollapsibleKeys.indexOf('doc:col') >= 0).assertTrue();

      const fnHits = searchArticleDocument(doc, nav, 'footnote alpha');
      expect(fnHits.length).assertEqual(1);
      expect(fnHits[0].isFootnote).assertTrue();
      expect(fnHits[0].footnoteIndex).assertEqual(0);
      expect(fnHits[0].location.sectionIndex).assertEqual(6);

      const creditHits = searchArticleDocument(doc, nav, 'author beta');
      expect(creditHits.length).assertEqual(1);
      expect(creditHits[0].contextLabel).assertEqual('著作信息');
    });

    it('returns from a footnote to the first referencing child of a collapsed, inactive tab', 0, () => {
      const reference = new ScpTextSpan(ScpTextStyle.FOOTNOTE_REFERENCE, '[1]', '', '1');
      const paragraphs: ScpContentBlock[] = [];
      for (let index = 0; index < 60; index++) {
        paragraphs.push(makeBlock(`p:${index}`, ScpBlockType.PARAGRAPH, [new ScpTextSpan(ScpTextStyle.PLAIN, '正文')]));
      }
      paragraphs.push(makeBlock('p:60', ScpBlockType.HEADING, [reference], '', 2, [], ['target']));
      paragraphs.push(makeBlock('p:61', ScpBlockType.PARAGRAPH, [reference]));
      const fold = makeBlock('fold', ScpBlockType.COLLAPSIBLE, [], '附录', 0, paragraphs);
      const tabs = makeBlock('tabs', ScpBlockType.TABS, [], '', 0, [
        makeBlock('first', ScpBlockType.PARAGRAPH), makeBlock('second', ScpBlockType.PARAGRAPH, [], '', 0, [fold])
      ]);
      const nav = buildArticleNavigationIndex([{ sectionIndex: 2, block: tabs }], [], -1);
      const ref = resolveAnchorLocation(nav, '#footnoteref-1');
      expect(ref?.blockKey).assertEqual('p:60');
      expect(ref?.sectionIndex).assertEqual(2);
      expect(ref?.expandCollapsibleKeys[0]).assertEqual('fold');
      expect(ref?.tabTargets[0].tabIndex).assertEqual(1);
      expect(resolveAnchorLocation(nav, 'target') === ref).assertTrue();
    });

    it('splits text into highlight segments case-insensitively', 0, () => {
      const segments = splitTextForSearchHighlight('Mobile Task Force Alpha-1 and alpha-9', 'ALPHA');
      expect(segments.length).assertEqual(5);
      expect(segments[0].text).assertEqual('Mobile Task Force ');
      expect(segments[0].matched).assertFalse();
      expect(segments[1].text).assertEqual('Alpha');
      expect(segments[1].matched).assertTrue();
      expect(segments[2].text).assertEqual('-1 and ');
      expect(segments[2].matched).assertFalse();
      expect(segments[3].text).assertEqual('alpha');
      expect(segments[3].matched).assertTrue();
      expect(segments[4].text).assertEqual('-9');
      expect(segments[4].matched).assertFalse();

      const emptyQuery = splitTextForSearchHighlight('Plain text', '   ');
      expect(emptyQuery.length).assertEqual(1);
      expect(emptyQuery[0].matched).assertFalse();
    });
  });
}
