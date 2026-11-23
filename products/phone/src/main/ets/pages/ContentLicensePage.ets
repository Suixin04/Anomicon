import {
  ContentLicenseContent,
  ContentLicenseLink,
  ContentLicensePageBuilder as SettingsContentLicensePageBuilder
} from 'settings';

/** Thin phone adapter that supplies product-specific licence copy and links. */
@Builder
export function ContentLicensePageBuilder() {
  SettingsContentLicensePageBuilder(new ContentLicenseContent(
    '内容来源与许可',
    'CC BY-SA 3.0',
    '各 SCP 条目与衍生素材的授权可能因来源而异，请以具体页面及原始出处说明为准。',
    [
      new ContentLicenseLink('SCP Wiki', 'https://scp-wiki.wikidot.com/'),
      new ContentLicenseLink('SCP 官方许可指南', 'https://scp-foundation.net/licensing-guide'),
      new ContentLicenseLink(
        'SCP 三维模型来源',
        'https://github.com/Yni-Viar/scp-unity-assets/tree/7fda38944f51db7ee3aeb4d9e5ca821263153da5'
      ),
      new ContentLicenseLink(
        '三维模型许可声明',
        'https://github.com/Yni-Viar/scp-unity-assets/blob/7fda38944f51db7ee3aeb4d9e5ca821263153da5/LICENSE.CCBYSA3'
      ),
      new ContentLicenseLink('CC BY-SA 3.0 许可文本', 'https://creativecommons.org/licenses/by-sa/3.0/')
    ],
    '格异录为非官方应用，与 SCP Wiki 不存在隶属或认可关系。'
  ));
}
