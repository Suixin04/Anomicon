import { url } from '@kit.ArkTS';

/** 当前产品只接入 SCP 中文站主站内容。 */
const SCP_WIKI_ORIGIN: string = 'https://scp-wiki-cn.wikidot.com';
const SCP_WIKI_HOST: string = 'scp-wiki-cn.wikidot.com';
// Wikidot serves generated html-block-iframe documents from this static host.
// It is intentionally not treated as a general page host: only the generated
// `/local--html/` endpoint used by the CN site is accepted below.
const SCP_WIKI_STATIC_HOST: string = 'scp-wiki-cn.wdfiles.com';
const SCP_WIKI_STATIC_PATH_PREFIX: string = '/local--html/';

/**
 * 主站页面 URL 的唯一入口。
 *
 * 页面抓取只接受无凭据、无自定义端口的 HTTPS 主站地址，避免页面数据或
 * 路由参数把网络层变成任意 URL 抓取器。图片资源有独立策略，因为正文图片
 * 可能托管在 Wikidot 的静态资源域名或作品作者选择的 HTTPS 图床。
 */
export class ScpWikiUrlPolicy {
  static normalizePageUrl(rawUrl: string): string {
    let parsed: url.URL;
    try {
      parsed = url.URL.parseURL(rawUrl);
    } catch (error) {
      throw new Error('SCP 页面地址无效');
    }

    if (parsed.protocol.toLowerCase() !== 'https:') {
      throw new Error('SCP 页面只允许使用 HTTPS');
    }
    const hostname = parsed.hostname.toLowerCase();
    if (hostname !== SCP_WIKI_HOST &&
      !(hostname === SCP_WIKI_STATIC_HOST &&
        parsed.pathname.toLowerCase().startsWith(SCP_WIKI_STATIC_PATH_PREFIX))) {
      throw new Error(`SCP 页面地址不属于当前主站：${hostname}${parsed.pathname}`);
    }
    if (parsed.username.length > 0 || parsed.password.length > 0) {
      throw new Error('SCP 页面地址不能包含身份凭据');
    }
    // HTTPS 默认端口会被 URL 解析器规范化为空字符串；其余端口一律拒绝。
    if (parsed.port.length > 0) {
      throw new Error('SCP 页面地址不能使用自定义端口');
    }
    parsed.hash = '';
    return parsed.href;
  }

  static resolvePageUrl(rawUrl: string, baseUrl: string = SCP_WIKI_ORIGIN): string {
    let resolved: url.URL;
    try {
      resolved = url.URL.parseURL(rawUrl, baseUrl);
    } catch (error) {
      throw new Error('SCP 页面链接无效');
    }
    return ScpWikiUrlPolicy.normalizePageUrl(resolved.href);
  }
}
