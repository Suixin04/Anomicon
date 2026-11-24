import { webview } from '@kit.ArkWeb';
import { url } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppTypography, ExternalUrlPolicy } from 'anomiconbasic';

const DOMAIN = 0x0000;
const TAG = 'AnomiconWebReader';
const WIKI_HOST = 'scp-wiki-cn.wikidot.com';

const WIKIDOT_CLEANUP_SCRIPT: string = `(function() {
  if (!document || (!document.getElementById('main-content') && !document.getElementById('page-content'))) {
    return;
  }
  var head = document.head || document.documentElement;
  if (head && !document.querySelector('meta[name="viewport"]')) {
    var meta = document.createElement('meta');
    meta.name = 'viewport';
    meta.content = 'width=device-width, initial-scale=1.0, viewport-fit=cover';
    head.appendChild(meta);
  }
  if (!document.getElementById('anomicon-web-reader-style') && head) {
    var style = document.createElement('style');
    style.id = 'anomicon-web-reader-style';
    style.textContent = [
      '#header, #top-bar, #side-bar, #login-status, #search-top-box, #navi-bar, #navi-bar-shadow,',
      '#footer, #license-area, #page-options-container, #action-area, .page-options-bottom,',
      '.footer-wikiwalk-nav, .mobile-top-bar, .open-menu, .wd-adunit, #ads, #adend,',
      '#account-options, #header-extra-div-1 { display: none !important; }',
      'html, body { max-width: 100% !important; overflow-x: hidden !important; margin: 0 !important; padding: 0 !important; }',
      '#container-wrap, #container, #content-wrap { width: 100% !important; max-width: 100% !important; min-width: 0 !important; margin: 0 !important; padding: 0 !important; }',
      '#main-content { width: 100% !important; max-width: 100% !important; min-width: 0 !important; margin: 0 !important; padding: 12px 16px 64px 16px !important; box-sizing: border-box !important; }',
      '#page-content img { max-width: 100% !important; height: auto !important; }',
      '#page-content iframe.html-block-iframe { max-width: 100% !important; }'
    ].join('\\n');
    head.appendChild(style);
  }
  var wrap = document.getElementById('container-wrap');
  if (wrap && window.getComputedStyle) {
    var bg = window.getComputedStyle(wrap).backgroundImage || '';
    if (bg.indexOf('body_bg') !== -1 || bg.indexOf('sigma9.scpwikicn.com/cn/img/') !== -1) {
      wrap.style.setProperty('background-image', 'none', 'important');
    }
  }
})();`;

/**
 * In-app ArkWeb renderer for interactive SCP pages (`SCP-3125`), ListPages
 * `/offset/N` iterations (`SCP-CN-2000`), and heavy CSS format-screws
 * (`SCP-CN-1109`). Strips Wikidot navigation chrome while preserving
 * `#breadcrumbs` passcode hints and original author CSS.
 */
@ComponentV2
export struct ArticleWebRenderer {
  @Require @Param url: string;
  @Require @Param baseArticleUrl: string;
  @Param topPadding: number = 0;
  @Param reloadEpoch: number = 0;
  @Param backEpoch: number = 0;

  @Event onOpenArticleLink: (url: string, title: string) => void = () => {};
  @Event onOpenExternalUrl: (url: string) => void = () => {};
  @Event onCanGoBackChange: (canGoBack: boolean) => void = () => {};
  @Event onSwitchToNative: () => void = () => {};

  private readonly controller: webview.WebviewController = new webview.WebviewController();
  private initialUrl: string = '';
  private lastLoadedUrl: string = '';
  private controllerAttached: boolean = false;
  private pendingLoadTimer: number = -1;
  private clearedBlankHistory: boolean = false;
  private initialLoadDispatched: boolean = false;
  @Local private loadProgress: number = 0;
  @Local private pageLoading: boolean = true;
  @Local private loadError: string = '';

  aboutToAppear(): void {
    const normalized = this.normalizeWikiUrl(this.url);
    this.initialUrl = normalized;
    this.lastLoadedUrl = normalized;
  }

  aboutToDisappear(): void {
    if (this.pendingLoadTimer >= 0) {
      clearTimeout(this.pendingLoadTimer);
      this.pendingLoadTimer = -1;
    }
    this.controllerAttached = false;
    this.onCanGoBackChange(false);
    try {
      this.controller.stop();
    } catch (_error) {
    }
  }

  @Monitor('url')
  onTargetUrlChange(): void {
    const next = this.normalizeWikiUrl(this.url);
    if (next.length === 0) {
      return;
    }
    this.initialUrl = next;
    if (!this.initialLoadDispatched) {
      this.lastLoadedUrl = next;
      return;
    }
    if (!this.controllerAttached || next === this.lastLoadedUrl) {
      return;
    }
    this.lastLoadedUrl = next;
    this.loadError = '';
    this.pageLoading = true;
    this.loadProgress = 10;
    try {
      this.controller.loadUrl(next);
    } catch (error) {
      this.pageLoading = false;
      this.loadError = error instanceof Error ? error.message : '加载网页失败';
    }
  }

  @Monitor('reloadEpoch')
  onReloadRequested(): void {
    if (!this.controllerAttached || this.reloadEpoch <= 0) {
      return;
    }
    this.reloadPage();
  }

  @Monitor('backEpoch')
  onBackRequested(): void {
    if (!this.controllerAttached || this.backEpoch <= 0) {
      return;
    }
    try {
      if (this.controller.accessBackward()) {
        this.controller.backward();
      }
    } catch (_error) {
    }
    this.syncCanGoBack();
  }

  private reloadPage(): void {
    this.loadError = '';
    this.pageLoading = true;
    this.loadProgress = 10;
    try {
      this.controller.refresh();
    } catch (_error) {
      try {
        this.controller.loadUrl(this.lastLoadedUrl.length > 0 ? this.lastLoadedUrl : this.initialUrl);
      } catch (_loadError) {
        this.pageLoading = false;
        this.loadError = '重新加载失败，请重试';
      }
    }
  }

  private normalizeWikiUrl(raw: string): string {
    const trimmed = raw.trim();
    if (trimmed.length === 0) {
      return '';
    }
    if (trimmed.toLowerCase().indexOf(`http://${WIKI_HOST}`) === 0) {
      return `https://${trimmed.substring(7)}`;
    }
    return trimmed;
  }

  private baseSlug(): string {
    try {
      const parsed = url.URL.parseURL(this.baseArticleUrl);
      const segments = parsed.pathname.replace(/^\/+|\/+$/g, '').split('/');
      return segments.length > 0 ? segments[0].toLowerCase() : '';
    } catch (_error) {
      return '';
    }
  }

  private cleanedWikiPath(parsed: url.URL): string {
    return parsed.pathname.replace(/^\/+|\/+$/g, '').toLowerCase();
  }

  private isSameArticleOrOffsetPath(path: string): boolean {
    const slug = this.baseSlug();
    if (slug.length === 0) {
      return false;
    }
    if (path === slug || path === `${slug}/noredirect/true`) {
      return true;
    }
    if (path.indexOf(`${slug}/offset/`) === 0) {
      const rest = path.substring(`${slug}/offset/`.length);
      return /^\d+(?:\/.*)?$/.test(rest);
    }
    return path.indexOf(`${slug}/fragment:`) === 0;
  }

  private handleMainFrameNavigation(rawUrl: string): boolean {
    const trimmed = rawUrl.trim();
    if (trimmed.length === 0 ||
      trimmed.startsWith('about:') ||
      trimmed.startsWith('data:') ||
      trimmed.startsWith('blob:') ||
      trimmed.startsWith('javascript:')) {
      return false;
    }
    const base = this.lastLoadedUrl.length > 0 ? this.lastLoadedUrl : this.baseArticleUrl;
    let parsed: url.URL;
    try {
      parsed = url.URL.parseURL(trimmed, base);
    } catch (_error) {
      return false;
    }
    const protocol = parsed.protocol.toLowerCase();
    if (protocol !== 'http:' && protocol !== 'https:') {
      this.onOpenExternalUrl(trimmed);
      return true;
    }
    if (parsed.hostname.toLowerCase() === WIKI_HOST) {
      const httpsUrl = protocol === 'http:' ? `https://${parsed.href.substring(7)}` : parsed.href;
      const path = this.cleanedWikiPath(parsed);
      if (this.isSameArticleOrOffsetPath(path)) {
        if (protocol === 'http:') {
          try {
            this.controller.loadUrl(httpsUrl);
          } catch (_error) {
          }
          return true;
        }
        return false;
      }
      if (path.length > 0 && path.indexOf('/') < 0 && path.indexOf(':') < 0) {
        this.onOpenArticleLink(httpsUrl, '');
        return true;
      }
      this.onOpenExternalUrl(httpsUrl);
      return true;
    }
    try {
      const safeUrl = ExternalUrlPolicy.resolveHttps(
        protocol === 'http:' ? `https://${parsed.href.substring(7)}` : parsed.href,
        this.baseArticleUrl
      );
      this.onOpenExternalUrl(safeUrl);
    } catch (_error) {
      this.onOpenExternalUrl(trimmed);
    }
    return true;
  }

  private syncCanGoBack(): void {
    if (!this.controllerAttached) {
      this.onCanGoBackChange(false);
      return;
    }
    try {
      this.onCanGoBackChange(this.controller.accessBackward());
    } catch (_error) {
      this.onCanGoBackChange(false);
    }
  }

  private injectCleanupCss(): void {
    if (!this.controllerAttached) {
      return;
    }
    try {
      this.controller.runJavaScript(WIKIDOT_CLEANUP_SCRIPT)
        .catch((): void => {
        });
    } catch (_error) {
    }
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Top }) {
        Web({
          src: 'about:blank',
          controller: this.controller,
          renderMode: RenderMode.ASYNC_RENDER
        })
          .width('100%')
          .height('100%')
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .databaseAccess(true)
          .imageAccess(true)
          .onlineImageAccess(true)
          .mixedMode(MixedMode.Compatible)
          .zoomAccess(true)
          .multiWindowAccess(false)
          .fileAccess(false)
          .geolocationAccess(false)
          .javaScriptOnDocumentEnd([{
            script: WIKIDOT_CLEANUP_SCRIPT,
            scriptRules: ['*']
          }])
          .onControllerAttached(() => {
            this.controllerAttached = true;
            if (this.pendingLoadTimer >= 0) {
              clearTimeout(this.pendingLoadTimer);
            }
            this.pendingLoadTimer = setTimeout((): void => {
              this.pendingLoadTimer = -1;
              if (!this.controllerAttached || this.initialLoadDispatched || this.initialUrl.length === 0) {
                return;
              }
              this.initialLoadDispatched = true;
              this.lastLoadedUrl = this.initialUrl;
              this.loadError = '';
              this.pageLoading = true;
              this.loadProgress = 12;
              try {
                this.controller.loadUrl(this.initialUrl);
              } catch (error) {
                this.pageLoading = false;
                this.loadError = error instanceof Error ? error.message : '加载网页失败';
              }
            }, 300);
          })
          .onLoadIntercept((event): boolean => {
            if (!event.data.isMainFrame()) {
              return false;
            }
            if (!event.data.isRequestGesture()) {
              return false;
            }
            return this.handleMainFrameNavigation(event.data.getRequestUrl());
          })
          .onPageBegin((event: OnPageBeginEvent) => {
            if (event.url === 'about:blank' || event.url.trim().length === 0) {
              return;
            }
            this.pageLoading = true;
            this.loadError = '';
            this.lastLoadedUrl = event.url;
            this.syncCanGoBack();
          })
          .onProgressChange((event: OnProgressChangeEvent) => {
            if (!this.initialLoadDispatched) {
              return;
            }
            this.loadProgress = event.newProgress;
            if (event.newProgress >= 100) {
              this.pageLoading = false;
            }
          })
          .onPageEnd((event: OnPageEndEvent) => {
            if (event.url === 'about:blank' || event.url.trim().length === 0) {
              return;
            }
            if (!this.clearedBlankHistory) {
              this.clearedBlankHistory = true;
              try {
                this.controller.clearHistory();
              } catch (_error) {
              }
            }
            this.pageLoading = false;
            this.loadProgress = 100;
            this.injectCleanupCss();
            this.syncCanGoBack();
          })
          .onErrorReceive((event: OnErrorReceiveEvent) => {
            if (!event.request.isMainFrame()) {
              return;
            }
            const code = event.error.getErrorCode();
            const info = event.error.getErrorInfo();
            if (code === -3 || info.indexOf('ERR_ABORTED') >= 0) {
              return;
            }
            hilog.warn(DOMAIN, TAG, 'Web main frame error code=%{public}d info=%{public}s', code, info);
            this.pageLoading = false;
            this.loadError = info.length > 0 ?
              `网页加载失败（${info}）` : '网页加载失败，请检查网络后重试';
          })

        if (this.pageLoading && this.loadError.length === 0) {
          Progress({
            value: Math.max(8, this.loadProgress),
            total: 100,
            type: ProgressType.Linear
          })
            .width('100%')
            .height(2)
            .color($r('sys.color.icon_emphasize'))
            .backgroundColor(Color.Transparent)
        }

        if (this.loadError.length > 0) {
          Column({ space: 14 }) {
            SymbolGlyph($r('sys.symbol.website'))
              .fontSize(36)
              .fontColor([$r('sys.color.icon_secondary')])
            Text(this.loadError)
              .fontSize(AppTypography.BODY_M)
              .fontColor($r('sys.color.font_secondary'))
              .textAlign(TextAlign.Center)
            Row({ space: 10 }) {
              Button('重新加载', { stateEffect: false })
                .onClick(() => this.reloadPage())
              Button('返回原生阅读', { stateEffect: false })
                .backgroundColor($r('sys.color.comp_background_tertiary'))
                .fontColor($r('sys.color.font'))
                .onClick(() => this.onSwitchToNative())
            }
          }
          .width('100%')
          .height('100%')
          .padding(24)
          .backgroundColor($r('sys.color.background_secondary'))
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topPadding })
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
