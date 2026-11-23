import { describe, expect, it } from '@ohos/hypium';
import {
  ScpBlockType,
  ScpContentBlock,
  ScpFootnote,
  ScpTextSpan,
  ScpTextStyle
} from '../main/ets/domain/ScpDocument';
import { ArticleRenderer } from '../main/ets/presentation/view/ArticleRenderer';
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
  });
}
