import { describe, expect, it, xit } from '@ohos/hypium';
import { url } from '@kit.ArkTS';
import { ScpPreviewHtmlExtractor } from '../main/ets/data/ScpPreviewHtmlExtractor';

function supportsUrlParser(): boolean {
  try {
    url.URL.parseURL('https://example.com/image.jpg');
    return true;
  } catch (_error) {
    return false;
  }
}

export default function scpPreviewHtmlExtractorTest(): void {
  describe('ScpPreviewHtmlExtractor', () => {
    it('extracts description and handles no-image articles cleanly', 0, (): void => {
      const html = '<html><body><div id="page-content">' +
        '<p><strong>项目编号：</strong>SCP-002</p>' +
        '<p><strong>描述：</strong>SCP-002 是一个外形酷似肉质球体的神秘房间，内部陈设异常。</p>' +
        '</div></body></html>';

      const result = ScpPreviewHtmlExtractor.extractPreview(html);
      expect(result.error).assertEqual('');
      expect(result.imageUrl).assertEqual('');
      expect(result.aspect).assertEqual(0);
      expect(result.description.indexOf('肉质球体') >= 0).assertTrue();
    });

    it('reports missing page-content node', 0, (): void => {
      const result = ScpPreviewHtmlExtractor.extractPreview('<html><body><p>Empty shell</p></body></html>');
      expect(result.error.length > 0).assertTrue();
    });

    const imageTest = (): void => {
      const html = '<html><body><div id="page-content">' +
        '<img src="https://scp-wiki.wikidot.com/local--files/theme:black-highlighter/logo.png" width="400" height="400" />' +
        '<img src="https://scp-wiki.wikidot.com/avatar.php?userid=1" width="64" height="64" />' +
        '<img src="http://scp-wiki.wikidot.com/local--files/scp-173/scp-173.jpg" width="800" height="600" />' +
        '<p>描述：SCP-173 是一座由混凝土与钢筋构成的雕像，必须在视线直视下才能静止。</p>' +
        '</div></body></html>';

      const result = ScpPreviewHtmlExtractor.extractPreview(html);
      expect(result.error).assertEqual('');
      expect(result.imageUrl).assertEqual('https://scp-wiki.wikidot.com/local--files/scp-173/scp-173.jpg');
      expect(Math.abs(result.aspect - 800 / 600) < 0.01).assertTrue();
      expect(result.description.indexOf('混凝土') >= 0).assertTrue();
    };

    if (supportsUrlParser()) {
      it('skips decorative theme/avatar images and resolves HTTPS content image', 0, imageTest);
    } else {
      xit('skips decorative theme/avatar images and resolves HTTPS content image', 0, (): void => {});
    }
  });
}
