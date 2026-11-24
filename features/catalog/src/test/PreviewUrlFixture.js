import url from '@ohos.url';

// API 26's previewer has no working URL parser. This cache suite uses one page.
export function installArticleUrlFixture() {
  const parseURL = url.URL.parseURL;
  const protocol = 'https:';
  const hostname = 'scp-wiki-cn.wikidot.com';
  const pathname = '/scp-173';
  const href = `${protocol}//${hostname}${pathname}`;
  url.URL.parseURL = (input) => {
    if (input !== href) throw new Error(`Unexpected cache fixture URL: ${input}`);
    return { href, protocol, hostname, pathname, username: '', password: '', port: '', hash: '' };
  };
  return () => { url.URL.parseURL = parseURL; };
}
