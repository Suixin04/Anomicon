import { describe, expect, it } from '@ohos/hypium';
import {
  ScpArticleDocument,
  ScpBlockType,
  ScpContentBlock,
  ScpFootnote,
  ScpHiddenTextKind,
  ScpTextSpan,
  ScpTextStyle
} from '../main/ets/domain/ScpDocument';
import {
  ArticleRenderer,
  ArticleWebModeRecommendation
} from '../main/ets/presentation/view/ArticleRenderer';
import { ImagePreviewGeometry, PreviewPoint, PreviewTransform } from '../main/ets/presentation/view/ImagePreviewGeometry';
import { createRendererDocument } from './ArticleTestFixtures';

function makeFootnote(id: string, index: number): ScpFootnote {
  const block = new ScpContentBlock(
    `fn:${id}`,
    ScpBlockType.PARAGRAPH,
    [new ScpTextSpan(ScpTextStyle.PLAIN, `内容 ${index}`)]
  );
  return new ScpFootnote(id, index, [block]);
}

export default function articleRendererTest(): void {
  describe('ArticleRendererProjection', () => {
    it('keeps the selected photo detail under the fingers until its edge reaches the viewport', 0, () => {
      const view = new ImagePreviewGeometry();
      view.width = 400;
      view.height = 800;
      view.imageRatio = 2;
      const initial: PreviewTransform = { scale: 1, x: 0, y: 0 };
      const tap: PreviewPoint = { x: 300, y: 360 };
      const zoomed = view.zoom(initial, 2.5, tap, tap);
      expect(zoomed.x).assertEqual(-150);
      expect(zoomed.y).assertEqual(0);
      const moved: PreviewPoint = { x: 320, y: 380 };
      expect(view.zoom(zoomed, 2.5, tap, moved).x).assertEqual(-130);
      expect(view.pan(2.5, -500, 80).x).assertEqual(-300);
      const reset = view.zoom(zoomed, 0.5, moved, tap);
      expect(reset.scale).assertEqual(1);
      expect(reset.x).assertEqual(0);
      expect(reset.y).assertEqual(0);
    });

    it('projects spans and collapse state immutably', 0, () => {
      const document = createRendererDocument();
      const text = document.blocks[0];
      const collapsible = document.blocks[1];
      const initialKeys: string[] = [];

      expect(ArticleRenderer.textOf(text)).assertEqual('AB1');
      expect(JSON.stringify(ArticleRenderer.footnoteReferenceIds(text)))
        .assertEqual('["note-1"]');

      const openedKeys = ArticleRenderer.toggleExpanded(initialKeys, collapsible.key);
      expect(initialKeys.length).assertEqual(0);
      expect(openedKeys === initialKeys).assertFalse();
      expect(ArticleRenderer.isExpanded(openedKeys, collapsible.key)).assertTrue();

      const closedKeys = ArticleRenderer.toggleExpanded(openedKeys, collapsible.key);
      expect(ArticleRenderer.isExpanded(closedKeys, collapsible.key)).assertFalse();
      expect(ArticleRenderer.isExpanded(openedKeys, collapsible.key)).assertTrue();
    });

    it('finds footnotes by referenceId and numeric label fallback', 0, () => {
      const footnotes = [
        makeFootnote('f-alpha', 1),
        makeFootnote('f-beta', 2),
        makeFootnote('f-gamma', 4)
      ];

      expect(ArticleRenderer.findFootnoteIndex(footnotes, 'f-beta', '99')).assertEqual(1);
      expect(ArticleRenderer.findFootnoteIndex(footnotes, 'missing-id', ' 4 ')).assertEqual(2);
      expect(ArticleRenderer.findFootnoteIndex(footnotes, '', '2')).assertEqual(1);
      expect(ArticleRenderer.findFootnoteIndex(footnotes, 'missing-id', 'note')).assertEqual(-1);
      expect(ArticleRenderer.findFootnoteIndex([], 'f-alpha', '1')).assertEqual(-1);
    });

    it('steps footnote index within bounds', 0, () => {
      expect(ArticleRenderer.stepFootnoteIndex(0, -1, 4)).assertEqual(0);
      expect(ArticleRenderer.stepFootnoteIndex(1, 1, 4)).assertEqual(2);
      expect(ArticleRenderer.stepFootnoteIndex(3, 1, 4)).assertEqual(3);
      expect(ArticleRenderer.stepFootnoteIndex(2, -1, 4)).assertEqual(1);
      expect(ArticleRenderer.stepFootnoteIndex(0, 1, 0)).assertEqual(-1);
    });

    it('formats footnote sheet header title and subtitle', 0, () => {
      const aligned = ArticleRenderer.footnoteSheetHeader(makeFootnote('n2', 2), 1, 5);
      expect(aligned.title).assertEqual('脚注 2 / 5');
      expect(aligned.subtitle).assertEqual('');

      const skipped = ArticleRenderer.footnoteSheetHeader(makeFootnote('n4', 4), 1, 5);
      expect(skipped.title).assertEqual('脚注 4');
      expect(skipped.subtitle).assertEqual('第 2 / 5 条');

      const zeroIndexed = ArticleRenderer.footnoteSheetHeader(makeFootnote('n0', 0), 0, 3);
      expect(zeroIndexed.title).assertEqual('脚注 1 / 3');
      expect(zeroIndexed.subtitle).assertEqual('');
    });

    it('adapts inline colors across light and dark surfaces and counts hidden Easter eggs', 0, () => {
      const darkRed = ArticleRenderer.resolveAdaptiveSpanColor('#990011', true);
      expect(darkRed.length).assertEqual(7);
      expect(darkRed === '#990011').assertFalse();

      const darkBlue = ArticleRenderer.resolveAdaptiveSpanColor('#0000FF', true);
      expect(darkBlue.length).assertEqual(7);
      expect(darkBlue === '#0000FF').assertFalse();

      const brightYellowOnLight = ArticleRenderer.resolveAdaptiveSpanColor('#FFFF00', false);
      expect(brightYellowOnLight.length).assertEqual(7);
      expect(brightYellowOnLight === '#FFFF00').assertFalse();

      const whisperBlock = new ScpContentBlock(
        'b:w',
        ScpBlockType.PARAGRAPH,
        [
          new ScpTextSpan(
            ScpTextStyle.PLAIN,
            '低语一',
            '',
            '',
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            '',
            1,
            ScpHiddenTextKind.ZERO_SIZE_WHISPER
          ),
          new ScpTextSpan(
            ScpTextStyle.PLAIN,
            '低语二',
            '',
            '',
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            '',
            1,
            ScpHiddenTextKind.ZERO_SIZE_WHISPER
          )
        ]
      );
      expect(ArticleRenderer.isPureWhisperBlock(whisperBlock)).assertTrue();

      const mixedBlock = new ScpContentBlock(
        'b:m',
        ScpBlockType.PARAGRAPH,
        [
          new ScpTextSpan(ScpTextStyle.PLAIN, '正常文本'),
          new ScpTextSpan(
            ScpTextStyle.PLAIN,
            '反白A',
            '',
            '',
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            '',
            1,
            ScpHiddenTextKind.WHITE_EASTER_EGG
          ),
          new ScpTextSpan(
            ScpTextStyle.PLAIN,
            '涂黑B',
            '',
            '',
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            '',
            1,
            ScpHiddenTextKind.BLACKBOX
          )
        ]
      );
      expect(ArticleRenderer.isPureWhisperBlock(mixedBlock)).assertFalse();
      expect(ArticleRenderer.countHiddenTextSegments([whisperBlock, mixedBlock])).assertEqual(3);
    });

    it('evaluates original web mode recommendation across normal, recommended, and auto-direct articles', 0, () => {
      const normalDoc = createRendererDocument();
      expect(ArticleRenderer.evaluateWebModeRecommendation(normalDoc).level)
        .assertEqual(ArticleWebModeRecommendation.NONE);

      const imageOnlyDoc = new ScpArticleDocument(
        'SCP-2521',
        'SCP-2521',
        'Keter',
        'https://scp-wiki-cn.wikidot.com/scp-2521',
        100,
        [
          new ScpContentBlock('i0', ScpBlockType.IMAGE, [], 'https://example.com/a.png', ''),
          new ScpContentBlock('i1', ScpBlockType.IMAGE, [], 'https://example.com/b.png', '')
        ]
      );
      expect(ArticleRenderer.evaluateWebModeRecommendation(imageOnlyDoc).level)
        .assertEqual(ArticleWebModeRecommendation.NONE);

      const autoDirectDoc = new ScpArticleDocument(
        'SCP-3125',
        'SCP-3125 - 逃亡者',
        'Keter',
        'https://scp-wiki-cn.wikidot.com/scp-3125',
        100,
        [
          new ScpContentBlock(
            'e0',
            ScpBlockType.EMBED,
            [],
            'https://scp-wiki-cn.wdfiles.com/local--html/scp-3125/widget/scp-3125.html'
          )
        ],
        [],
        '',
        ['interactive:html-block-iframe']
      );
      expect(ArticleRenderer.evaluateWebModeRecommendation(autoDirectDoc).level)
        .assertEqual(ArticleWebModeRecommendation.AUTO_DIRECT);

      const richInteractiveDoc = new ScpArticleDocument(
        'SCP-CN-963-J',
        'SCP-CN-963-J',
        'Keter',
        'https://scp-wiki-cn.wikidot.com/scp-cn-963-j',
        100,
        [
          new ScpContentBlock(
            'p0',
            ScpBlockType.PARAGRAPH,
            [new ScpTextSpan(ScpTextStyle.PLAIN, '这是一段足够长的幽默正文文本，包含完整的收容措施、实验记录、人员访谈和交互式广告弹窗说明，用于验证带正文的交互页面不会强制直接跳出原生视图。'.repeat(2))]
          )
        ],
        [],
        '',
        ['interactive:html-block-iframe']
      );
      expect(ArticleRenderer.evaluateWebModeRecommendation(richInteractiveDoc).level)
        .assertEqual(ArticleWebModeRecommendation.RECOMMENDED);

      const offsetDoc = new ScpArticleDocument(
        'SCP-CN-2000',
        'SCP-CN-2000 - 混沌理论',
        'Thaumiel',
        'https://scp-wiki-cn.wikidot.com/scp-cn-2000',
        100,
        [
          new ScpContentBlock(
            'p0',
            ScpBlockType.PARAGRAPH,
            [new ScpTextSpan(ScpTextStyle.PLAIN, '混沌理论正文内容。'.repeat(20))]
          )
        ],
        [],
        '',
        ['interactive:listpages-offset']
      );
      expect(ArticleRenderer.evaluateWebModeRecommendation(offsetDoc).level)
        .assertEqual(ArticleWebModeRecommendation.RECOMMENDED);

      const customCssDoc = new ScpArticleDocument(
        'SCP-CN-1109',
        'SCP-CN-1109',
        'Euclid',
        'https://scp-wiki-cn.wikidot.com/scp-cn-1109',
        100,
        [
          new ScpContentBlock(
            'p0',
            ScpBlockType.PARAGRAPH,
            [new ScpTextSpan(ScpTextStyle.PLAIN, '特殊视觉版式正文。'.repeat(20))]
          )
        ],
        [],
        '',
        ['format-screw:custom-css']
      );
      expect(ArticleRenderer.evaluateWebModeRecommendation(customCssDoc).level)
        .assertEqual(ArticleWebModeRecommendation.RECOMMENDED);
    });
  });
}
