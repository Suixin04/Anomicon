import { describe, expect, it } from '@ohos/hypium';
import { ExploreSource } from '../main/ets/domain/ExploreContracts';
import { parseExploreHtmlOffThread } from '../main/ets/data/ExploreHtmlParseTask';

export default function exploreHtmlParseTaskTest(): void {
  describe('ExploreHtmlParseTask', () => {
    it('parses small and large top-rated payloads seamlessly', 0, async (): Promise<void> => {
      const smallHtml = '<div id="page-content"><table>' +
        '<tr><td><a href="/scp-173">SCP-173 雕像</a></td><td>+999</td><td>42</td></tr>' +
        '</table></div><div id="page-info-break"></div>';
      const smallPayload = await parseExploreHtmlOffThread(ExploreSource.TOP_RATED, smallHtml);
      expect(smallPayload.ok).assertTrue();
      expect(smallPayload.entries.length).assertEqual(1);
      expect(smallPayload.entries[0].url).assertEqual('/scp-173');
      expect(smallPayload.entries[0].score).assertEqual('999');

      const padding = '<!-- pad -->'.repeat(500);
      const largeHtml = `<div id="page-content">${padding}<table>` +
        '<tr><td><a href="/scp-049">SCP-049 疫医</a></td><td>+888</td><td>30</td></tr>' +
        '</table></div><div id="page-info-break"></div>';
      const largePayload = await parseExploreHtmlOffThread(ExploreSource.TOP_RATED, largeHtml);
      expect(largePayload.ok).assertTrue();
      expect(largePayload.entries.length).assertEqual(1);
      expect(largePayload.entries[0].url).assertEqual('/scp-049');

      const cnJokesHtml = '<div id="page-content">' +
        '<div class="content-panel standalone series">' +
        '<ul><li><a href="/scp-cn-001-j">SCP-CN-001-J</a> - 原创搞笑档案</li>' +
        '<li><a href="/scp-cn-963-j">SCP-CN-963-J</a> - 神烦代码</li></ul>' +
        '</div></div><div class="page-tags"></div>';
      const cnJokesPayload = await parseExploreHtmlOffThread(ExploreSource.JOKE_SCPS_CN, cnJokesHtml);
      expect(cnJokesPayload.ok).assertTrue();
      expect(cnJokesPayload.entries.length).assertEqual(2);
      expect(cnJokesPayload.entries[0].url).assertEqual('/scp-cn-001-j');
      expect(cnJokesPayload.entries[1].url).assertEqual('/scp-cn-963-j');
    });
  });
}
