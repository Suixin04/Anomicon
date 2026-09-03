import {
  HdsNavDestination,
  HdsNavigationMenuItemOptions,
  HdsNavDestinationTitleMode
} from '@kit.UIDesignKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
// Article visuals are exported by the article feature; the product page only
// supplies serializable document data and interaction callbacks.
import {
  ScpHtmlExtractor,
  ScpImagePreviewer,
  ARTICLE_READING_STATUS_HEIGHT,
  ArticleReadingStatusBar,
  ArticleNativeRenderer,
  ArticleScrollRestore,
  ArticleRelatedTale,
  ArticleViewModel,
  ScpArticleDocument,
  ScpContentBlock
} from 'article';
import {
  AppRoutes,
  ScpArticleRouteParams,
  Scp3DArchiveRouteParams
} from '../navigation/AppRoutes';
import {
  parseArticleRouteContent
} from '../navigation/RouteParamAdapters';
import { AppNavigationCoordinator } from '../navigation/AppNavigationCoordinator';
import {
  PHONE_PAGE_MARGIN,
  createAppTitleBarStyle,
  pageContentTop
} from 'anomiconbasic';
import { ExternalUrlPolicy } from 'anomiconbasic';
import {
  LibraryContentKind,
  LibraryContentRef,
  createLibraryContentRef,
  isLibraryContentTitlePlaceholder
} from 'library';
import { HapticFeedbackPort } from 'anomiconbasic';
import {
  ResearchProfileViewModel
} from 'library';
import { ReadingSettingsRange, SettingsViewModel } from 'settings';
import { ViewModelLoadState } from 'anomiconbasic';
import { ImagePreviewActions } from 'anomiconbasic';

const WIKI_BASE_URL: string = 'https://scp-wiki-cn.wikidot.com';
const DOMAIN = 0x0000;
const TAG = 'AnomiconArticle';

@Builder
export function ScpArticlePageBuilder(
  viewModel: ArticleViewModel,
  imageActions: ImagePreviewActions,
  hapticService: HapticFeedbackPort,
  settings: SettingsViewModel,
  research: ResearchProfileViewModel,
  archive3dAvailability: (contentId: string) => boolean
) {
  // The product route adapter is the only composition boundary.  This View
  // receives serializable state and narrow capabilities; it never constructs
  // repositories, caches, or shared ViewModels.
  ScpArticlePage({
    viewModel: viewModel,
    imageActions: imageActions,
    hapticService: hapticService,
    settings: settings,
    research: research,
    archive3dAvailability: archive3dAvailability
  })
}

@ComponentV2
struct ScpArticlePage {
  @Require @Param viewModel: ArticleViewModel;
  @Require @Param imageActions: ImagePreviewActions;
  @Require @Param hapticService: HapticFeedbackPort;
  @Require @Param settings: SettingsViewModel;
  @Require @Param research: ResearchProfileViewModel;
  @Require @Param archive3dAvailability: (contentId: string) => boolean;
  private pageStack: NavPathStack | undefined = undefined;
  private scroller: Scroller = new Scroller();
  private sourceUrl: string = '';
  private pendingHtml: string = '';
  private pendingSourceUrl: string = '';
  private activeExtractionRequestId: number = 0;
  /** 离屏后拒绝迟到的 scrollStop 保存，避免覆盖 onWillDisappear 的最终位置。 */
  private acceptsProgressEvents: boolean = true;
  private scrollContentHeight: number = 0;
  private scrollViewportHeight: number = 0;
  /** 仅在 Scroll 仍处于有效布局/滚动回调期间采样，离屏生命周期只读该稳定值。 */
  private lastKnownReadingOffset: number = 0;
  private readonly scrollRestore: ArticleScrollRestore =
    new ArticleScrollRestore();
  private viewModelUnsubscribe: (() => void) | undefined = undefined;
  /** Keep the original serialized payload so an invalid route can be parsed again. */
  private routeParam: Object | null | undefined = undefined;
  @Local private document: ScpArticleDocument | undefined = undefined;
  @Local private loading: boolean = true;
  @Local private parsing: boolean = false;
  @Local private errorMessage: string = '';
  @Local private routeResolved: boolean = false;
  @Local private routeErrorMessage: string = '';
  @Local private partialNoticeVisible: boolean = false;
  @Local private partialRefreshing: boolean = false;
  @Local private partialErrorMessage: string = '';
  @Local private expandedKeys: string[] = [];
  @Local private previewVisible: boolean = false;
  @Local private previewIndex: number = 0;
  @Local private galleryReturnEpoch: number = 0;
  // 标题栏用 @Local 状态承载：onReady 在首帧后才赋值，
  // 普通字段的变化不会触发标题栏重渲染，必须走状态。
  @Local private itemId: string = '';
  @Local private itemName: string = '';
  @Local private contentKind: LibraryContentKind = LibraryContentKind.SCP;
  /** 关联故事（缓存中匹配当前 SCP 编号的故事）；未加载/无匹配时为空。 */
  @Local private relatedTales: ArticleRelatedTale[] = [];
  // 阅读设置快照：进入与重新显示时从全局设置同步，
  // 保证从设置页返回后字号/行距立即生效。
  @Local private fontSize: number = ReadingSettingsRange.FONT_SIZE_DEFAULT;
  @Local private lineHeightMultiple: number = ReadingSettingsRange.LINE_HEIGHT_DEFAULT;
  @Local private readingPercent: number = 0;
  @Local private completed: boolean = false;

  aboutToAppear(): void {
    this.viewModelUnsubscribe?.();
    this.viewModelUnsubscribe = this.viewModel.subscribe(() => this.syncViewModelState());
    this.viewModel.activate();
    this.syncViewModelState();
    this.syncReadingSettings();
  }

  aboutToDisappear(): void {
    // A route can be retained while hidden, so only dispose on actual component
    // destruction. NavDestination callbacks below handle temporary inactivity.
    this.acceptsProgressEvents = false;
    this.viewModelUnsubscribe?.();
    this.viewModelUnsubscribe = undefined;
    this.viewModel.releaseReadingSession(this.currentReadingOffset());
    this.viewModel.dispose();
  }

  /** Project feature state into the existing native renderer without changing its visuals. */
  private syncViewModelState(): void {
    const vm = this.viewModel;
    // A malformed route must remain visible as a route error even when the
    // lifecycle callbacks activate the otherwise empty ViewModel afterwards.
    if (!this.routeResolved && this.routeErrorMessage.length > 0) {
      this.document = undefined;
      this.loading = false;
      this.parsing = false;
      this.errorMessage = this.routeErrorMessage;
      this.partialNoticeVisible = false;
      this.partialRefreshing = false;
      this.partialErrorMessage = '';
      this.pendingHtml = '';
      this.pendingSourceUrl = '';
      this.activeExtractionRequestId = 0;
      this.relatedTales = [];
      this.expandedKeys = [];
      this.readingPercent = 0;
      return;
    }
    this.document = vm.document;
    // A stale document remains visible while the VM revalidates in the
    // background; only an empty document should show the full-screen loader.
    const hasDocument = vm.document !== undefined;
    this.loading = vm.state === ViewModelLoadState.LOADING && !hasDocument;
    this.parsing = vm.parsing;
    // Article revalidation errors are non-blocking when a cached document is
    // already rendered. Project them into the inline notice below instead of
    // replacing the reader with a full-screen error state.
    const partial = hasDocument && (vm.stale ||
      vm.state === ViewModelLoadState.PARTIAL ||
      vm.state === ViewModelLoadState.REFRESHING ||
      vm.state === ViewModelLoadState.LOADING ||
      vm.error !== undefined);
    this.partialNoticeVisible = partial;
    this.partialRefreshing = partial &&
      (vm.state === ViewModelLoadState.REFRESHING ||
        (vm.state === ViewModelLoadState.LOADING && vm.error === undefined));
    this.partialErrorMessage = vm.error?.message ?? '';
    this.errorMessage = this.routeErrorMessage.length > 0 ? this.routeErrorMessage :
      (partial ? '' : vm.error?.message ?? '');
    this.readingPercent = vm.readingPercent;
    this.completed = vm.completed;
    // Article owns title enrichment and related-tale lookup.  The product
    // page only projects the serializable VM snapshot into the established
    // renderer types, preserving the existing visual layout.
    if (vm.content !== undefined &&
      !isLibraryContentTitlePlaceholder(vm.content.id, vm.content.title)) {
      this.itemName = vm.content.title;
    }
    this.relatedTales = vm.relatedTales.slice();
    this.pendingHtml = vm.pendingExtraction?.html ?? '';
    this.pendingSourceUrl = vm.pendingExtraction?.sourceUrl ?? '';
    this.activeExtractionRequestId = vm.pendingExtraction?.requestId ?? 0;
    this.expandedKeys = vm.expandedKeys.slice();
    // The cached document can finish layout before the RDB lookup completes.
    // Offer every positive snapshot to the coordinator; it applies exactly
    // once when both prerequisites exist, regardless of their arrival order.
    const restoreOffset = this.scrollRestore.observeRestoredOffset(
      vm.restoredScrollOffset,
      vm.readingRestoreReady
    );
    if (restoreOffset !== undefined) {
      this.applyRestoredScrollOffset(restoreOffset);
    }
  }

  private syncReadingSettings(): void {
    this.fontSize = this.settings.fontSize;
    this.lineHeightMultiple = this.settings.lineHeightMultiple;
  }

  /** Clear route-bound rendering state before applying a new payload. */
  private resetContentProjection(): void {
    this.document = undefined;
    this.loading = true;
    this.parsing = false;
    this.errorMessage = '';
    this.partialNoticeVisible = false;
    this.partialRefreshing = false;
    this.partialErrorMessage = '';
    this.pendingHtml = '';
    this.pendingSourceUrl = '';
    this.activeExtractionRequestId = 0;
    this.relatedTales = [];
    this.expandedKeys = [];
    this.lastKnownReadingOffset = 0;
    this.scrollRestore.reset();
    this.scrollContentHeight = 0;
    this.scrollViewportHeight = 0;
    this.readingPercent = 0;
    this.previewVisible = false;
    this.previewIndex = 0;
    this.galleryReturnEpoch++;
  }

  /** Parse and apply a route payload; this is also the invalid-route retry path. */
  private applyRouteParam(param: Object | null | undefined): boolean {
    this.routeParam = param;
    const content: LibraryContentRef | undefined = parseArticleRouteContent(param);
    if (content === undefined) {
      this.routeResolved = false;
      this.routeErrorMessage = '档案参数无效';
      this.itemId = '';
      this.itemName = '';
      this.contentKind = LibraryContentKind.SCP;
      this.sourceUrl = '';
      this.resetContentProjection();
      this.loading = false;
      // Do not let a previously active VM continue publishing a document for
      // a route that failed validation.
      this.viewModel.deactivate();
      this.syncViewModelState();
      return false;
    }

    this.routeResolved = true;
    this.routeErrorMessage = '';
    this.resetContentProjection();
    this.itemName = content.title;
    this.contentKind = content.kind;
    // 内容主键统一小写；SCP 标题栏仍沿用站点惯例展示大写编号。
    this.itemId = content.kind === LibraryContentKind.SCP ? content.id.toUpperCase() : content.id;
    hilog.info(DOMAIN, TAG,
      'route content: itemId=%{public}s, name=%{public}s, kind=%{public}s',
      this.itemId, this.itemName, this.contentKind);
    this.sourceUrl = `${WIKI_BASE_URL}/${this.itemId.toLowerCase()}`;
    this.acceptsProgressEvents = true;
    // Route parsing stays at the product boundary. The VM owns content
    // loading, metadata, extraction tokens, history and reading effects.
    this.viewModel.setRouteContent(content);
    this.viewModel.attachReadingSession(content, this.currentReadingOffset());
    this.viewModel.activate();
    this.syncViewModelState();
    return true;
  }

  private retryArticle(): void {
    if (!this.routeResolved) {
      // Re-run the adapter even when the payload is still invalid. This keeps
      // the retry action meaningful and allows a retained route to recover if
      // its serialized payload has since been corrected.
      if (this.applyRouteParam(this.routeParam)) {
        this.viewModel.retry();
      }
      return;
    }
    this.viewModel.retry();
  }

  /** ArkWeb extraction is a View adapter: only the payload and request id
   * cross the feature boundary, where the VM performs parsing and persistence. */
  private onExtracted(json: string, requestId: number): void {
    this.viewModel.onExtractionResult(requestId, json);
  }

  private onExtractionFailed(message: string, requestId: number): void {
    this.viewModel.onExtractionFailed(requestId, message);
  }

  /** 当前组件仍在布局树中时采样；不能从 onHidden/onInactive 直接访问 Scroller。 */
  private captureReadingOffset(): void {
    const result = this.scroller.offset();
    if (result !== undefined && Number.isFinite(result.yOffset)) {
      this.lastKnownReadingOffset = Math.max(0, Math.floor(result.yOffset));
    }
  }

  private currentReadingOffset(): number {
    return this.lastKnownReadingOffset;
  }

  /** 高频滚动只在整数百分比变化时发布 V2 状态，避免标题栏逐帧重组。 */
  private updateReadingPercent(): void {
    if (this.document === undefined || !Number.isFinite(this.scrollContentHeight) ||
      !Number.isFinite(this.scrollViewportHeight) || this.scrollContentHeight <= 0 ||
      this.scrollViewportHeight <= 0) {
      if (this.readingPercent !== 0) {
        this.readingPercent = 0;
      }
      return;
    }
    const scrollableDistance = Math.max(0, this.scrollContentHeight - this.scrollViewportHeight);
    const offset = this.currentReadingOffset();
    const ratio = scrollableDistance <= 0 || !Number.isFinite(offset) ? 1 :
      Math.max(0, Math.min(1, offset / scrollableDistance));
    const next = Math.round(ratio * 100);
    if (next !== this.readingPercent) {
      this.readingPercent = next;
      this.viewModel.setReadingPercent(next);
    }
  }

  private noteReadingInteraction(): void {
    this.viewModel.noteInteraction(this.currentReadingOffset());
  }

  private checkpointReadingActivity(): void {
    this.viewModel.checkpoint(this.currentReadingOffset());
  }

  private setReadingScrollActive(active: boolean): void {
    this.viewModel.setContinuousInteraction(active, this.currentReadingOffset());
  }

  private openPreview(index: number): void {
    if (this.document === undefined || this.document.images.length === 0 ||
      !Number.isFinite(index)) {
      return;
    }
    this.noteReadingInteraction();
    this.previewIndex = Math.max(0, Math.min(Math.floor(index), this.document.images.length - 1));
    this.previewVisible = true;
  }

  private closePreview(): void {
    this.previewVisible = false;
    // Notify the feature renderer even when the selected preview index did
    // not change, so its private SwiperController is always realigned.
    this.galleryReturnEpoch++;
  }

  private toggleRendererBlock(block: ScpContentBlock): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    this.noteReadingInteraction();
    this.viewModel.toggleExpanded(block.key);
  }

  private requestRendererScroll(offset: number): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    this.scroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, offset), animation: true });
  }

  /** Product coordination after the feature-owned native body has a layout. */
  private onRendererContentLaidOut(): void {
    const restoreOffset = this.scrollRestore.markContentLaidOut();
    if (restoreOffset !== undefined) {
      this.applyRestoredScrollOffset(restoreOffset);
    }
    this.updateReadingPercent();
  }

  private applyRestoredScrollOffset(offset: number): void {
    const normalized = Math.max(0, Math.floor(offset));
    this.lastKnownReadingOffset = normalized;
    this.scroller.scrollTo({
      xOffset: 0,
      yOffset: normalized,
      animation: false
    });
    this.updateReadingPercent();
  }

  private async openUrl(url: string): Promise<void> {
    try {
      const safeUrl = ExternalUrlPolicy.resolveHttps(url, this.sourceUrl);
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (context === undefined) {
        throw new Error('当前页面上下文不可用');
      }
      await context.openLink(safeUrl);
    } catch (error) {
      this.showToast('无法打开浏览器');
    }
  }

  /**
   * Keep links to other readable main-site pages inside the app. Wikidot also
   * emits links to tag/system pages and media assets; those remain external so
   * a decorative image or a management page can never become a fake article.
   */
  private openArticleLink(rawUrl: string, linkTitle: string): void {
    if (rawUrl.trim().startsWith('#')) {
      // Same-page anchors are intentionally left to the reader document; do
      // not bounce them out to an external browser.
      return;
    }
    if (linkTitle.trim().startsWith('[图片')) {
      this.openUrl(rawUrl);
      return;
    }
    const content = this.resolveInternalArticle(rawUrl, linkTitle);
    if (content === undefined) {
      this.openUrl(rawUrl);
      return;
    }
    this.hapticService.playSelection(this.settings.hapticEnabled);
    const params: ScpArticleRouteParams = { content: content };
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.ARTICLE, params);
  }

  private resolveInternalArticle(rawUrl: string, linkTitle: string): LibraryContentRef | undefined {
    let safeUrl: string;
    try {
      safeUrl = ExternalUrlPolicy.resolveHttps(rawUrl, this.sourceUrl);
    } catch (_error) {
      return undefined;
    }
    const origin = `${WIKI_BASE_URL}/`;
    if (safeUrl.toLowerCase().indexOf(origin.toLowerCase()) !== 0) {
      return undefined;
    }
    let path = safeUrl.substring(origin.length);
    const queryIndex = path.indexOf('?');
    if (queryIndex >= 0) {
      path = path.substring(0, queryIndex);
    }
    const hashIndex = path.indexOf('#');
    if (hashIndex >= 0) {
      path = path.substring(0, hashIndex);
    }
    path = path.replace(/^\/+|\/+$/g, '').trim();
    if (path.length === 0 || path.indexOf('/') >= 0 || path.indexOf(':') >= 0) {
      return undefined;
    }
    const normalized = path.toLowerCase();
    // A same-page anchor is a document-local interaction, not a new route.
    if (normalized === this.itemId.toLowerCase()) {
      return undefined;
    }
    // SCP pages use a numeric object number (optionally with a language/site
    // prefix such as `cn`); this avoids misclassifying a story slug beginning
    // with the letters "scp" as an object page.
    const isScp = /^scp-(?:\d+|[a-z]{2,4}-\d+)(?:-[a-z0-9]+)*$/.test(normalized);
    const title = linkTitle.trim().length > 0 ? linkTitle.trim() : path;
    return createLibraryContentRef(
      isScp ? LibraryContentKind.SCP : LibraryContentKind.TALE,
      path,
      title
    );
  }

  private showToast(message: string): void {
    promptAction.openToast({ message: message })
      .catch((error: BusinessError) => {
        console.error(`openToast error code is ${error.code}, message is ${error.message}`);
      });
  }

  /** 收藏始终使用路由内容身份；解析后的正文标题仅负责补全展示名称。 */
  private currentLibraryContent(): LibraryContentRef | undefined {
    return this.routeResolved ? this.viewModel.content : undefined;
  }

  /** SCP 使用编号作主标题；故事和知识页优先显示可读名称，避免暴露站点 slug。 */
  private navigationMainTitle(): string {
    if (this.contentKind === LibraryContentKind.SCP) {
      return this.itemId;
    }
    return this.itemName.trim().length > 0 ? this.itemName : this.itemId;
  }

  private navigationSubTitle(): string {
    return this.contentKind === LibraryContentKind.SCP ? this.itemName : '';
  }

  private isCurrentFavorite(): boolean {
    return this.viewModel.favorite;
  }

  /** 页面级互斥保护菜单连点；服务层仍会串行化来自其他页面的写操作。 */
  private async toggleFavorite(): Promise<void> {
    try {
      const favorite = await this.viewModel.toggleFavorite();
      if (favorite !== undefined) {
        this.showToast(favorite ? '已收藏' : '已取消收藏');
      }
    } catch (error) {
      this.showToast(error instanceof Error ? error.message : '收藏操作失败');
    }
  }

  private async toggleCompleted(): Promise<void> {
    try {
      const next = !this.completed;
      await this.viewModel.setCompleted(next);
      this.completed = next;
      this.showToast(next ? '已标记为已读完' : '已取消已读标记');
    } catch (error) {
      this.showToast(error instanceof Error ? error.message : '保存完成标记失败');
    }
  }

  /** Product navigation effect emitted by the feature-owned related-tale list. */
  private openTale(tale: ArticleRelatedTale): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    const params: ScpArticleRouteParams = {
      content: createLibraryContentRef(LibraryContentKind.TALE, tale.id, tale.title)
    };
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.ARTICLE, params);
  }

  /** Keep the 3D entry scoped to SCP objects and to a reviewed asset row. */
  private canOpenArchive3D(): boolean {
    return this.contentKind === LibraryContentKind.SCP && this.itemId.length > 0 &&
      this.archive3dAvailability(this.itemId.toLowerCase());
  }

  private openArchive3D(): void {
    if (!this.canOpenArchive3D()) {
      return;
    }
    const content = this.currentLibraryContent();
    if (content === undefined) {
      return;
    }
    this.hapticService.playSelection(this.settings.hapticEnabled);
    const params: Scp3DArchiveRouteParams = { content: content };
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.ARCHIVE_3D, params);
  }

  /**
   * HDS `maxCount` is the total title-bar menu slot count, including the
   * generated More affordance when source items overflow.  Reserve one slot
   * for More and keep only the primary actions outside it.
   */
  private articleMenuMaxCount(): number {
    // Every article keeps 收藏 and the explicit completion annotation as
    // first-level actions. Browser and reading settings remain in More.
    return this.canOpenArchive3D() ? 4 : 3;
  }

  private articleMenuItems(): HdsNavigationMenuItemOptions[] {
    const items: HdsNavigationMenuItemOptions[] = [{
      content: {
        icon: this.isCurrentFavorite() ?
          $r('sys.symbol.star_fill') : $r('sys.symbol.star'),
        label: this.isCurrentFavorite() ? '取消收藏' : '收藏',
        isEnabled: this.itemId.length > 0 &&
          this.viewModel.favoriteReady && !this.viewModel.favoritePending,
        action: () => {
          this.toggleFavorite();
        }
      }
    }];
    items.push({
      content: {
        icon: this.completed ? $r('sys.symbol.checkmark_circle_fill') :
          $r('sys.symbol.checkmark_circle'),
        label: this.completed ? '取消已读标记' : '标记为已读完',
        action: () => {
          this.toggleCompleted();
        }
      }
    });
    if (this.canOpenArchive3D()) {
      items.push({
        content: {
          icon: $r('sys.symbol.puzzle'),
          label: '三维档案',
          action: () => this.openArchive3D()
        }
      });
    }
    items.push({
      content: {
        icon: $r('sys.symbol.arrow_up_right'),
        label: '在浏览器中打开',
        action: () => this.openUrl(this.sourceUrl)
      }
    });
    items.push({
      content: {
        icon: $r('sys.symbol.textformat'),
        label: '阅读设置',
        action: () => AppNavigationCoordinator.push(this.pageStack, AppRoutes.SETTINGS)
      }
    });
    return items;
  }

  @Builder
  private readingStatusBuilder() {
    ArticleReadingStatusBar({
      progress: this.readingPercent,
      level: this.research.profile.level,
      experience: this.research.profile.experience,
      contentReady: this.document !== undefined && !this.loading
    })
  }

  @Builder
  private partialNotice() {
    Row({ space: 8 }) {
      SymbolGlyph(this.partialRefreshing ? $r('sys.symbol.clock') :
        $r('sys.symbol.exclamationmark_circle'))
        .fontSize(17)
        .fontColor([$r('sys.color.icon_secondary')])
      Column({ space: 2 }) {
        Text(this.partialRefreshing ? '正在更新正文…' : '当前显示缓存正文')
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (!this.partialRefreshing && this.partialErrorMessage.length > 0) {
          Text(this.partialErrorMessage)
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Button('重试', { stateEffect: false })
        .height(32)
        .enabled(!this.partialRefreshing)
        .onClick(() => this.retryArticle())
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(12)
  }

  build() {
    HdsNavDestination() {
      Stack() {
        Scroll(this.scroller) {
          Column() {
            if (this.loading || (this.parsing && this.document === undefined)) {
              Column({ space: 12 }) {
                LoadingProgress()
                  .width(32)
                  .height(32)
                  .color($r('sys.color.icon_emphasize'))
                Text(this.parsing ? '正在整理档案内容…' : '正在加载档案…')
                  .fontSize(14)
                  .fontColor($r('sys.color.font_secondary'))
              }
              .width('100%')
              .height(320)
              .justifyContent(FlexAlign.Center)
            } else if (this.errorMessage.length > 0) {
              Column({ space: 12 }) {
                Text(this.errorMessage)
                  .fontSize(14)
                  .fontColor($r('sys.color.font_secondary'))
                  .textAlign(TextAlign.Center)
                Button('重试', { stateEffect: false })
                  .onClick(() => {
                    this.retryArticle();
                  })
              }
              .width('100%')
              .height(320)
              .justifyContent(FlexAlign.Center)
            } else {
              if (this.document !== undefined) {
                if (this.partialNoticeVisible) {
                  this.partialNotice()
                }
                ArticleNativeRenderer({
                  document: this.document!,
                  expandedKeys: this.expandedKeys,
                  relatedTales: this.relatedTales,
                  fontSize: this.fontSize,
                  lineHeightMultiple: this.lineHeightMultiple,
                  galleryReturnIndex: this.previewIndex,
                  galleryReturnEpoch: this.galleryReturnEpoch,
                  onOpenUrl: (url: string) => this.openUrl(url),
                  onOpenArticleLink: (url: string, title: string) => this.openArticleLink(url, title),
                  onOpenImage: (index: number) => this.openPreview(index),
                  onToggleExpanded: (block: ScpContentBlock) => this.toggleRendererBlock(block),
                  onOpenRelatedTale: (tale: ArticleRelatedTale) => this.openTale(tale),
                  onRequestScrollTo: (offset: number) => this.requestRendererScroll(offset),
                  onContentLaidOut: () => this.onRendererContentLaidOut()
                })
              }
            }

            // 离屏解析：仅在一次解析期间挂载，完成后由状态移除。
            if (this.parsing && this.pendingHtml.length > 0) {
              ForEach([this.activeExtractionRequestId], (requestId: number) => {
                ScpHtmlExtractor({
                  html: this.pendingHtml,
                  baseUrl: this.pendingSourceUrl,
                  requestId: requestId,
                  onExtracted: (json: string, callbackRequestId: number): void => {
                    this.onExtracted(json, callbackRequestId);
                  },
                  onFailed: (message: string, callbackRequestId: number): void => {
                    this.onExtractionFailed(message, callbackRequestId);
                  }
                })
              }, (requestId: number) => `article-extractor:${requestId}`)
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: 680 })
          .padding({
            left: PHONE_PAGE_MARGIN,
            right: PHONE_PAGE_MARGIN,
            top: pageContentTop() + ARTICLE_READING_STATUS_HEIGHT,
            bottom: 48
          })
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            this.scrollContentHeight = Number(newArea.height);
            this.updateReadingPercent();
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('sys.color.background_secondary'))
        .clip(false)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          this.scrollViewportHeight = Number(newArea.height);
          this.updateReadingPercent();
        })
        .onDidScroll((_xOffset: number, _yOffset: number, _state: ScrollState) => {
          this.captureReadingOffset();
          this.updateReadingPercent();
        })
        .onScrollStart(() => {
          // Official ArkUI semantics do not emit onScrollStart for our
          // non-animated restore scroll.  Reaching here before restoration
          // therefore means the reader interacted first; their position wins.
          this.scrollRestore.cancelForInteraction();
          this.captureReadingOffset();
          this.setReadingScrollActive(true);
        })
        .onScrollStop(() => {
          this.captureReadingOffset();
          this.setReadingScrollActive(false);
          if (this.acceptsProgressEvents) {
            this.viewModel.updateProgress(this.currentReadingOffset()).catch((): void => {
            });
            this.checkpointReadingActivity();
          }
        })

        // 全屏图片预览层
        if (this.previewVisible && this.document !== undefined && this.document!.images.length > 0) {
          ScpImagePreviewer({
            images: this.document!.images,
            initialIndex: this.previewIndex,
            actions: this.imageActions,
            onClose: () => {
              this.closePreview();
            },
            onIndexChange: (index: number) => {
              this.previewIndex = index;
            },
            onNotice: (message: string) => {
              this.showToast(message);
            }
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false,
      content: {
        title: {
          mainTitle: this.navigationMainTitle(),
          // 副标题保留项目名称（如“疫医”）；阅读状态与经验统一放在底部状态区。
          subTitle: this.navigationSubTitle()
        },
        bottomBuilder: {
          builder: (): void => this.readingStatusBuilder(),
          height: ARTICLE_READING_STATUS_HEIGHT
        },
        backIcon: { label: '返回', componentId: 'articleBackButton' },
        menu: {
          // HDS 当前实现会把“更多”本身计入 maxCount；因此无模型为 3
          // （收藏 + 已读完 + 更多），有模型为 4（再加三维档案）。
          value: this.articleMenuItems(),
          maxCount: this.articleMenuMaxCount()
        }
      },
      style: createAppTitleBarStyle()
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    // 全屏预览时隐藏标题栏，沉浸式看图；关闭后恢复。
    .hideTitleBar(this.previewVisible, true)
    .backgroundColor($r('sys.color.background_secondary'))
    .bindToScrollable([this.scroller])
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
      const param: Object | null | undefined =
        context.pathInfo.param as Object | null | undefined;
      this.applyRouteParam(param);
    })
    .onShown(() => {
      this.acceptsProgressEvents = true;
      this.viewModel.activate();
      this.syncViewModelState();
      const content = this.currentLibraryContent();
      if (content !== undefined) {
        this.viewModel.setPageShown(true, this.document !== undefined, this.currentReadingOffset());
      }
    })
    .onHidden(() => {
      if (this.acceptsProgressEvents) {
        this.viewModel.updateProgress(this.currentReadingOffset()).catch((): void => {
        });
        this.checkpointReadingActivity();
      }
      this.acceptsProgressEvents = false;
      const content = this.currentLibraryContent();
      if (content !== undefined) {
        this.viewModel.setPageShown(false, this.document !== undefined, this.currentReadingOffset());
      }
      this.viewModel.deactivate();
    })
    .onActive(() => {
      this.viewModel.activate();
      this.syncViewModelState();
      const content = this.currentLibraryContent();
      if (content !== undefined) {
        this.viewModel.setPageActive(true, this.document !== undefined, this.currentReadingOffset());
      }
    })
    .onInactive(() => {
      if (this.acceptsProgressEvents) {
        this.viewModel.updateProgress(this.currentReadingOffset()).catch((): void => {
        });
        this.checkpointReadingActivity();
      }
      const content = this.currentLibraryContent();
      if (content !== undefined) {
        this.viewModel.setPageActive(false, this.document !== undefined, this.currentReadingOffset());
      }
      this.viewModel.deactivate();
    })
    .onWillShow(() => {
      // 从设置页返回时强制重读阅读设置，避免覆盖页面的渲染快照过期。
      this.syncReadingSettings();
      this.acceptsProgressEvents = true;
      this.viewModel.activate();
      this.syncViewModelState();
      const content = this.currentLibraryContent();
      if (content !== undefined) {
        this.viewModel.attachReadingSession(content, this.currentReadingOffset());
        this.viewModel.setContentReady(this.document !== undefined, this.currentReadingOffset());
      }
    })
    .onWillDisappear(() => {
      this.acceptsProgressEvents = false;
      this.viewModel.updateProgress(this.currentReadingOffset()).catch((): void => {
      });
      this.viewModel.checkpoint(this.currentReadingOffset());
      this.viewModel.releaseReadingSession(this.currentReadingOffset());
      this.viewModel.deactivate();
    })
    .onBackPressed(() => {
      // 预览打开时，系统返回先关闭预览层，不再退出文章页。
      if (this.previewVisible) {
        this.closePreview();
        return true;
      }
      return false;
    })
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    )
  }
}
