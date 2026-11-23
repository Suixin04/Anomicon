import { curves } from '@kit.ArkUI';
import { ExploreRecommendation } from '../../domain/ExploreContracts';
import {
  AppTypography,
  materialCardBorderColor,
  materialCardSurfaceColor,
  recommendationFallbackBackgroundColor,
  SkeletonBlock,
  ViewModelLoadState
} from 'anomiconbasic';
import { ExploreHeroAnchor } from './ExploreViewContracts';

const CARD_DISMISS_THRESHOLD: number = 88;
const CARD_DISMISS_VELOCITY: number = 800;
const CARD_LIFT_DISTANCE: number = 220;
const CARD_EXIT_DISTANCE: number = 520;
const RECOMMENDATION_CARD_HEIGHT: number = 340;
const RECOMMENDATION_STAGE_HEIGHT: number = 372;

@ObservedV2
class ExploreRecommendationRowState {
  readonly itemId: string;
  @Trace recommendation: ExploreRecommendation;
  @Trace depth: number;
  @Trace imageFailed: boolean = false;
  @Trace imageGeneration: number = 0;
  @Trace loadedSource: string = '';

  constructor(recommendation: ExploreRecommendation, depth: number = 4) {
    this.itemId = recommendation.entry.itemId;
    this.recommendation = recommendation;
    this.depth = depth;
  }
}

interface ExploreRecommendationImageParams {
  source: string;
  row: ExploreRecommendationRowState;
  rowGeneration: number;
  lifecycleGeneration: number;
}

/**
 * Stable archive-card skeleton shared by Explore and the product startup
 * overlay. Each placeholder owns its own shimmer; the product startup
 * hand-off can disable them so two independent animation phases never
 * cross-fade over one another.
 */
@ComponentV2
export struct ExploreRecommendationSkeleton {
  @Param animated: boolean = true;
  /** 0 renders only the stable card surface; 1 renders the complete skeleton. */
  @Param detailProgress: number = 1;

  private detailReveal(): number {
    return Math.max(0, Math.min(1, this.detailProgress));
  }

  /** Each placeholder owns its own shimmer and lifecycle through SkeletonBlock. */
  private skeletonAnimated(): boolean {
    return this.animated && this.detailReveal() > 0;
  }

  @Builder
  private backCard(scale: number, translateY: number, opacity: number) {
    Column() {}
      .width('100%')
      .height(RECOMMENDATION_CARD_HEIGHT)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .borderRadius(24)
      .scale({ x: scale, y: scale })
      .translate({ y: translateY })
      .opacity(opacity)
  }

  @Builder
  private imageSkeleton() {
    Stack({ alignContent: Alignment.Center }) {
      SkeletonBlock({ animated: this.skeletonAnimated(), radius: 0 })
        .width('100%')
        .height(176)

      SkeletonBlock({ animated: this.skeletonAnimated(), radius: 18 })
        .width(58)
        .height(58)
        .border({ width: 1, color: $r('sys.color.comp_divider') })
        .opacity(0.72)
    }
    .width('100%')
    .height(176)
  }

  @Builder
  private detailSkeleton() {
    Column({ space: 12 }) {
      Row({ space: 7 }) {
        SkeletonBlock({ animated: this.skeletonAnimated(), radius: 4 })
          .width(8)
          .height(8)
        SkeletonBlock({ animated: this.skeletonAnimated(), radius: 5 })
          .width(78)
          .height(9)
      }
      .height(9)

      SkeletonBlock({ animated: this.skeletonAnimated(), radius: 7 })
        .width('68%')
        .height(14)
      SkeletonBlock({ animated: this.skeletonAnimated(), radius: 5 })
        .width('92%')
        .height(9)
      SkeletonBlock({ animated: this.skeletonAnimated(), radius: 5 })
        .width('76%')
        .height(9)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
  }

  @Builder
  private frontCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.imageSkeleton()
        this.detailSkeleton()
      }
      .opacity(this.detailReveal())
      .translate({ y: (1 - this.detailReveal()) * 8 })
    }
    .width('100%')
    .height(RECOMMENDATION_CARD_HEIGHT)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .borderRadius(24)
    .clip(true)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      this.backCard(0.91, 28, 0.64 * this.detailReveal())
      this.backCard(0.955, 14, 0.82 * this.detailReveal())
      this.frontCard()
    }
    .width('100%')
    .height(RECOMMENDATION_STAGE_HEIGHT)
    .padding({ top: 4, bottom: 28 })
    .accessibilityText('正在准备今日推荐')
  }
}

/**
 * 单张推荐卡。depth=0 的顶卡可横向拖拽甩出；后两张只负责叠层预览。
 * 甩卡之外保留页面下方“再换一批”按钮，覆盖键盘、读屏与精细动作不便场景。
 */
@ComponentV2
struct ExploreRecommendationCard {
  @Require @Param row: ExploreRecommendationRowState;
  @Require @Param dragX: number;
  @Require @Param materialEnabled: boolean;

  private mounted: boolean = false;
  /** Invalidates callbacks from a card node after it leaves the visible deck. */
  private lifecycleGeneration: number = 0;

  private effectiveDepth(): number {
    if (this.row.depth === 0) {
      return 0;
    }
    return Math.max(0, this.row.depth - this.liftProgress());
  }

  private liftProgress(): number {
    return Math.min(1, Math.abs(this.dragX) / CARD_LIFT_DISTANCE);
  }

  private scaleOfDepth(): number {
    return 1 - this.effectiveDepth() * 0.045;
  }

  private translateYOfDepth(): number {
    return this.effectiveDepth() * 14;
  }

  private opacityOfDepth(): number {
    if (this.row.depth === 0) {
      return 1 - Math.min(0.22, Math.abs(this.dragX) / CARD_EXIT_DISTANCE);
    }
    if (this.row.depth === 3) {
      return 0.64 * this.liftProgress();
    }
    return 1 - this.effectiveDepth() * 0.18;
  }

  private rotation(): number {
    if (this.row.depth === 0) {
      return this.dragX / 24;
    }
    return 0;
  }

  private description(): string {
    if (this.row.recommendation.preview.description.length > 0) {
      return this.row.recommendation.preview.description;
    }
    return '收录自 SCP 中文主站。轻划切走卡片，继续调阅下一份档案。';
  }

  private previewSource(): string {
    const preview = this.row.recommendation.preview;
    if (preview.path.length > 0) {
      // Adapters may already provide a file URI.  Prefix only plain paths so
      // Image never receives the malformed `file://file://…` variant.
      return preview.path.startsWith('file://') ? preview.path : `file://${preview.path}`;
    }
    return preview.url;
  }

  private handleAppear(): void {
    this.mounted = true;
  }

  private handleDisAppear(): void {
    this.mounted = false;
    this.lifecycleGeneration++;
  }

  private isCurrentImage(params: ExploreRecommendationImageParams): boolean {
    return this.mounted && params.row === this.row &&
      params.rowGeneration === this.row.imageGeneration &&
      params.lifecycleGeneration === this.lifecycleGeneration &&
      params.source === this.previewSource() &&
      !this.row.recommendation.preview.failed;
  }

  private handleImageComplete(params: ExploreRecommendationImageParams): void {
    if (!this.isCurrentImage(params)) {
      return;
    }
    // Close the generation after the terminal callback so duplicate/late
    // callbacks from the same Image node cannot flip the row back to failure.
    this.row.imageGeneration++;
    this.row.imageFailed = false;
    this.row.loadedSource = params.source;
  }

  private handleImageError(params: ExploreRecommendationImageParams): void {
    if (!this.isCurrentImage(params)) {
      return;
    }
    // Keep the recommendation card usable even when the media host is
    // unavailable. The deck-level "再换一批" action remains batch retry.
    this.row.imageGeneration++;
    this.row.imageFailed = true;
    this.row.loadedSource = '';
  }

  private imageCompleteHandler(params: ExploreRecommendationImageParams): () => void {
    const captured: ExploreRecommendationImageParams = {
      source: params.source,
      row: params.row,
      rowGeneration: params.rowGeneration,
      lifecycleGeneration: params.lifecycleGeneration
    };
    return (): void => this.handleImageComplete(captured);
  }

  private imageErrorHandler(
    params: ExploreRecommendationImageParams
  ): (error: ImageError) => void {
    const captured: ExploreRecommendationImageParams = {
      source: params.source,
      row: params.row,
      rowGeneration: params.rowGeneration,
      lifecycleGeneration: params.lifecycleGeneration
    };
    return (_error: ImageError): void => this.handleImageError(captured);
  }

  @Builder
  private previewImage($$: ExploreRecommendationImageParams) {
    Stack({ alignContent: Alignment.Center }) {
      Image($$.source)
        .width('100%')
        .height(176)
        .objectFit(ImageFit.Cover)
        // Recommendation cards never display the source at full resolution;
        // let ImageKit decode to the measured card bounds to reduce memory and
        // texture upload cost while keeping the original URL/cache contract.
        .autoResize(true)
        // Snapshot the reactive builder proxy before delayed image events arrive.
        .onComplete(this.imageCompleteHandler($$))
        .onError(this.imageErrorHandler($$))

      if (this.row.loadedSource !== $$.source) {
        SkeletonBlock({ animated: this.row.depth === 0, radius: 0 })
          .width('100%')
          .height(176)
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height(176)
  }

  private imageHasFailed(): boolean {
    return this.row.imageFailed || this.row.recommendation.preview.failed;
  }

  @Builder
  private imageFallback() {
    Column({ space: 7 }) {
      SymbolGlyph(this.imageHasFailed() ? $r('sys.symbol.exclamationmark_circle') :
        $r('sys.symbol.doc_text'))
        .fontSize(42)
        .fontColor([$r('sys.color.icon_tertiary')])
      Text(this.imageHasFailed() ? '图片暂时无法显示' : '暂无预览图')
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
      if (this.imageHasFailed()) {
        Text('档案正文仍可打开')
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
      }
    }
    .width('100%')
    .height(176)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(recommendationFallbackBackgroundColor())
    .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
    .accessibilityText(this.imageHasFailed() ? '图片加载失败，档案正文仍可打开' : '暂无预览图')
  }

  @Builder
  private cardContent() {
    Column() {
      if (this.previewSource().length > 0 && !this.row.imageFailed &&
        !this.row.recommendation.preview.failed) {
        this.previewImage({
          source: this.previewSource(),
          row: this.row,
          rowGeneration: this.row.imageGeneration,
          lifecycleGeneration: this.lifecycleGeneration
        })
      } else {
        this.imageFallback()
      }

      Column({ space: 6 }) {
        Text(this.row.recommendation.entry.itemId)
          .fontSize(AppTypography.BODY_S)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_emphasize'))
        Text(this.row.recommendation.entry.title.length > 0 ?
          this.row.recommendation.entry.title : this.row.recommendation.entry.itemId)
          .fontSize(AppTypography.TITLE_S)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.description())
          .fontSize(AppTypography.BODY_S)
          .fontColor($r('sys.color.font_secondary'))
          .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 18, right: 18, top: 14, bottom: 18 })
    }
    .width('100%')
    .height(RECOMMENDATION_CARD_HEIGHT)
  }

  @Builder
  private card() {
    Column() {
      this.cardContent()
    }
    .width('100%')
    .height(RECOMMENDATION_CARD_HEIGHT)
    // 叠卡升层只改变位置和透明度，不切换材质。卡组仅挂载当前四层。
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_THICK : undefined)
    .border({ width: 1, color: materialCardBorderColor(this.materialEnabled) })
    .borderRadius(24)
    .clip(true)
    .scale({ x: this.scaleOfDepth(), y: this.scaleOfDepth() })
    .translate({
      x: this.row.depth === 0 ? this.dragX : 0,
      y: this.translateYOfDepth()
    })
    .rotate({ angle: this.rotation() })
    .opacity(this.opacityOfDepth())
    .hitTestBehavior(HitTestMode.None)
    .onAppear(() => this.handleAppear())
    .onDisAppear(() => this.handleDisAppear())
  }

  build() {
    this.card()
  }
}

/**
 * 推荐卡组拥有独立的 V2 状态边界。
 * 卡片只以档案 ID 为身份，depth 只是布局参数，升层时不会销毁并重新创建组件。
 */
@ComponentV2
export struct ExploreRecommendationDeck {
  @Require @Param recommendations: ExploreRecommendation[];
  @Require @Param currentIndex: number;
  @Require @Param deckVersion: number;
  @Require @Param loading: boolean;
  @Require @Param error: string;
  /**
   * The explicit screen state closes the first-frame gap between the ViewModel
   * being constructed and its initial request publishing `loading = true`.
   * An empty IDLE deck is still an initialization surface, not an error.
   */
  @Param status: ViewModelLoadState = ViewModelLoadState.IDLE;
  @Param refreshing: boolean = false;
  @Param skeletonAnimated: boolean = true;
  @Require @Param materialEnabled: boolean;
  @Event onOpen: (itemId: string, name: string) => void;
  @Event onDismiss: (deckVersion: number) => void;
  @Event onRefresh: () => void;
  @Event onHeroAnchorChange: (anchor: ExploreHeroAnchor) => void =
    (_anchor: ExploreHeroAnchor): void => {};

  @Local private dragX: number = 0;
  @Local private rows: ExploreRecommendationRowState[] = [];
  @Local private deckEnterScale: number = 1;
  @Local private deckEnterOpacity: number = 1;
  private suppressClick: boolean = false;
  private dismissing: boolean = false;
  private dragDeckVersion: number = -1;
  private lastAnimatedDeckVersion: number = -1;

  aboutToAppear(): void {
    this.publishRows();
    if (this.recommendations.length > 0) {
      this.lastAnimatedDeckVersion = this.deckVersion;
    }
  }

  @Monitor('recommendations')
  onRecommendationsChanged(): void {
    this.publishRows();
  }

  @Monitor('currentIndex')
  onCurrentIndexChanged(): void {
    this.publishDepths();
  }

  @Monitor('refreshing')
  onRefreshingChanged(): void {
    const uiContext = this.getUIContext();
    if (uiContext === undefined) {
      return;
    }
    if (this.refreshing) {
      uiContext.animateTo({
        duration: 180,
        curve: Curve.EaseOut
      }, (): void => {
        this.deckEnterScale = 0.97;
        this.deckEnterOpacity = 0.78;
      });
    } else if (this.deckVersion === this.lastAnimatedDeckVersion) {
      uiContext.animateTo({
        duration: 180,
        curve: Curve.EaseOut
      }, (): void => {
        this.deckEnterScale = 1;
        this.deckEnterOpacity = 1;
      });
    }
  }

  @Monitor('deckVersion')
  onDeckVersionChanged(): void {
    this.dragX = 0;
    if (!this.dismissing) {
      this.suppressClick = false;
    }
    if (this.recommendations.length > 0 && this.deckVersion !== this.lastAnimatedDeckVersion) {
      this.lastAnimatedDeckVersion = this.deckVersion;
      const uiContext = this.getUIContext();
      if (uiContext === undefined) {
        this.deckEnterScale = 1;
        this.deckEnterOpacity = 1;
        return;
      }
      this.deckEnterScale = 0.94;
      this.deckEnterOpacity = 0.65;
      uiContext.animateTo({
        curve: curves.springMotion(0.36, 0.82)
      }, (): void => {
        this.deckEnterScale = 1;
        this.deckEnterOpacity = 1;
      });
    }
  }

  private samePreview(before: ExploreRecommendation, after: ExploreRecommendation): boolean {
    return before.preview.path === after.preview.path &&
      before.preview.url === after.preview.url &&
      Math.abs(before.preview.aspect - after.preview.aspect) <= 0.01 &&
      before.preview.description === after.preview.description &&
      before.preview.fetchedAt === after.preview.fetchedAt &&
      before.preview.stale === after.preview.stale &&
      before.preview.error === after.preview.error;
  }

  private publishRows(): void {
    const next: ExploreRecommendationRowState[] = [];
    const currentById: Map<string, ExploreRecommendationRowState> = new Map();
    for (let rowIndex: number = 0; rowIndex < this.rows.length; rowIndex++) {
      currentById.set(this.rows[rowIndex].itemId, this.rows[rowIndex]);
    }
    for (let itemIndex: number = 0; itemIndex < this.recommendations.length; itemIndex++) {
      const recommendation = this.recommendations[itemIndex];
      let row: ExploreRecommendationRowState | undefined =
        currentById.get(recommendation.entry.itemId);
      if (row === undefined) {
        row = new ExploreRecommendationRowState(recommendation);
      } else {
        const previousPreview = row.recommendation.preview;
        const previewChanged = !this.samePreview(row.recommendation, recommendation);
        const imageSourceChanged = previousPreview.path !== recommendation.preview.path ||
          previousPreview.url !== recommendation.preview.url ||
          previousPreview.failed !== recommendation.preview.failed;
        if (previewChanged || row.recommendation.entry.title !== recommendation.entry.title) {
          row.recommendation = recommendation;
          if (imageSourceChanged) {
            row.imageGeneration++;
            row.imageFailed = false;
          }
        }
      }
      next.push(row);
    }
    this.rows = next;
    this.publishDepths();
  }

  private publishDepths(): void {
    if (this.rows.length === 0) {
      return;
    }
    const normalizedIndex = ((this.currentIndex % this.rows.length) + this.rows.length) % this.rows.length;
    for (let rowIndex: number = 0; rowIndex < this.rows.length; rowIndex++) {
      const relative = (rowIndex - normalizedIndex + this.rows.length) % this.rows.length;
      const nextDepth = relative < 4 ? relative : 4;
      if (this.rows[rowIndex].depth !== nextDepth) {
        this.rows[rowIndex].depth = nextDepth;
      }
    }
  }

  private recommendationAt(depth: number): ExploreRecommendationRowState | undefined {
    if (this.rows.length === 0 || depth >= this.rows.length) {
      return undefined;
    }
    return this.rows[(this.currentIndex + depth) % this.rows.length];
  }

  /** 按底层到顶层返回，保证后出现的顶牌位于 Stack 最上方。 */
  private visibleRecommendations(): ExploreRecommendationRowState[] {
    const visible: ExploreRecommendationRowState[] = [];
    for (let depth = 3; depth >= 0; depth--) {
      const row = this.recommendationAt(depth);
      if (row !== undefined) {
        visible.push(row);
      }
    }
    return visible;
  }

  private topRecommendation(): ExploreRecommendation | undefined {
    return this.recommendationAt(0)?.recommendation;
  }

  private dismiss(direction: number): void {
    if (this.dismissing) {
      return;
    }
    this.dismissing = true;
    this.suppressClick = true;
    const deckVersion = this.deckVersion;
    const uiContext = this.getUIContext();
    if (uiContext === undefined) {
      this.dragX = 0;
      this.onDismiss(deckVersion);
      this.dismissing = false;
      this.suppressClick = false;
      return;
    }
    uiContext.animateTo({
      duration: 200,
      curve: Curve.EaseOut,
      onFinish: () => {
        // 四层卡牌此时已到达下一索引的视觉位置，状态一起提交不会产生跳帧。
        this.dragX = 0;
        if (deckVersion === this.deckVersion) {
          this.onDismiss(deckVersion);
        }
        this.dismissing = false;
        this.suppressClick = false;
      }
    }, () => {
      this.dragX = direction * CARD_EXIT_DISTANCE;
    });
  }

  private settle(): void {
    const uiContext = this.getUIContext();
    if (uiContext === undefined) {
      this.dragX = 0;
      this.suppressClick = false;
      return;
    }
    uiContext.animateTo({
      curve: curves.springMotion(0.32, 0.78),
      onFinish: () => {
        this.suppressClick = false;
      }
    }, () => {
      this.dragX = 0;
    });
  }

  private openTopRecommendation(): void {
    const recommendation = this.topRecommendation();
    if (recommendation !== undefined && !this.suppressClick && !this.dismissing) {
      this.onOpen(recommendation.entry.itemId, recommendation.entry.title);
    }
  }

  private unavailableTitle(): string {
    if (this.refreshing) {
      return '正在调阅新一批档案…';
    }
    return this.error.length > 0 ? '暂无法连接档案库' : '今日暂未获取到推荐';
  }

  private unavailableDescription(): string {
    if (this.refreshing) {
      return '请稍候，正在从主站调阅档案';
    }
    return this.error.length > 0 ? this.error : '点按下方按钮，重新从主站调阅一组档案';
  }

  private unavailableAccessibilityText(): string {
    if (this.refreshing) {
      return '正在重新加载今日推荐';
    }
    return this.error.length > 0 ?
      `今日推荐加载失败，${this.error}` : '今日暂未获取到推荐';
  }

  private showSkeleton(): boolean {
    // IDLE is visible for one or more frames before activate() publishes the
    // request state. Treat that empty initialization window as loading so the
    // first frame cannot fall through to the retry/empty branch. A legitimate
    // empty READY response remains an explicit unavailable state.
    if (this.recommendations.length > 0) {
      return false;
    }
    return this.status === ViewModelLoadState.IDLE ||
      this.status === ViewModelLoadState.LOADING ||
      (this.status === ViewModelLoadState.REFRESHING &&
        (this.loading || this.refreshing));
  }

  private landingAccessibilityText(): string {
    const recommendation = this.topRecommendation();
    if (recommendation !== undefined) {
      return `今日推荐，${recommendation.entry.itemId}，${recommendation.entry.title}`;
    }
    if (this.showSkeleton()) {
      return '正在准备今日推荐';
    }
    return this.unavailableAccessibilityText();
  }

  private reportHeroArea(area: Area): void {
    const globalPosition = area.globalPosition;
    if (globalPosition === undefined || globalPosition.x === undefined ||
      globalPosition.y === undefined) {
      return;
    }
    const windowX = Number(globalPosition.x);
    const windowY = Number(globalPosition.y);
    const width = Number(area.width);
    const height = Number(area.height);
    if (!Number.isFinite(windowX) || !Number.isFinite(windowY) ||
      !Number.isFinite(width) || !Number.isFinite(height) ||
      width <= 0 || height <= 0) {
      return;
    }
    this.onHeroAnchorChange({
      windowX: windowX,
      windowY: windowY,
      width: width,
      height: height
    });
  }

  @Builder
  private unavailableState() {
    Column({ space: 16 }) {
      Column() {
        SymbolGlyph(this.error.length > 0 || this.refreshing ?
          $r('sys.symbol.exclamationmark_circle') : $r('sys.symbol.doc_text'))
          .fontSize(30)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .width(60)
      .height(60)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(30)

      Column({ space: 6 }) {
        Text(this.unavailableTitle())
          .fontSize(AppTypography.TITLE_S)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .textAlign(TextAlign.Center)
        Text(this.unavailableDescription())
          .fontSize(AppTypography.BODY_S)
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.error.length > 0 && !this.refreshing) {
          Text('网络恢复后，重试即可继续调阅')
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_tertiary'))
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')

      Button({ type: ButtonType.Capsule, stateEffect: false }) {
        Row({ space: 7 }) {
          if (this.refreshing) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color($r('sys.color.icon_on_primary'))
          } else {
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(17)
              .fontColor([$r('sys.color.icon_on_primary')])
          }
          Text(this.refreshing ? '正在重试' : '重试')
            .fontSize(AppTypography.BODY_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_on_primary'))
        }
        .justifyContent(FlexAlign.Center)
      }
      .width(148)
      .height(48)
      .backgroundColor($r('sys.color.comp_background_emphasize'))
      .enabled(!this.refreshing)
      .accessibilityText(this.refreshing ? '正在重新加载今日推荐' : '重新加载今日推荐')
      .onClick(() => this.onRefresh())
    }
    .width('100%')
    .height(340)
    .padding({ left: 28, right: 28, top: 24, bottom: 24 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(24)
    .accessibilityText(this.unavailableAccessibilityText())
  }

  /** A fixed landing stage keeps idle/loading/ready/error at one geometry. */
  @Builder
  private landingStage() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.showSkeleton()) {
        ExploreRecommendationSkeleton({ animated: this.skeletonAnimated })
      } else if (this.recommendations.length > 0) {
        Stack({ alignContent: Alignment.Top }) {
          ForEach(this.visibleRecommendations(), (row: ExploreRecommendationRowState) => {
            ExploreRecommendationCard({
              row: row,
              dragX: this.dragX,
              materialEnabled: this.materialEnabled
            })
          }, (row: ExploreRecommendationRowState) => row.itemId)
        }
        .width('100%')
        .scale({ x: this.deckEnterScale, y: this.deckEnterScale })
        .opacity(this.deckEnterOpacity)
      } else {
        Column() {
          this.unavailableState()
        }
        .width('100%')
        .height(RECOMMENDATION_STAGE_HEIGHT)
        .padding({ top: 4, bottom: 28 })
      }
    }
    .width('100%')
    .height(RECOMMENDATION_STAGE_HEIGHT)
    .padding(this.recommendations.length > 0 ? { top: 4, bottom: 28 } : 0)
    .accessibilityText(this.landingAccessibilityText())
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      this.reportHeroArea(newArea);
    })
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 5 })
        .onActionStart(() => {
          this.dragDeckVersion = this.recommendations.length > 1 ? this.deckVersion : -1;
          if (this.dragDeckVersion === this.deckVersion && !this.dismissing) {
            this.suppressClick = false;
          }
        })
        .onActionUpdate((event: GestureEvent) => {
          if (this.dragDeckVersion !== this.deckVersion || this.dismissing) {
            return;
          }
          this.dragX = event.offsetX;
          if (Math.abs(event.offsetX) > 8) {
            this.suppressClick = true;
          }
        })
        .onActionEnd((event: GestureEvent) => {
          if (this.dragDeckVersion !== this.deckVersion || this.dismissing) {
            return;
          }
          this.dragDeckVersion = -1;
          const fastSwipe = Math.abs(event.velocityX) >= CARD_DISMISS_VELOCITY;
          if (Math.abs(this.dragX) >= CARD_DISMISS_THRESHOLD || fastSwipe) {
            const direction = fastSwipe ? event.velocityX : this.dragX;
            this.dismiss(direction >= 0 ? 1 : -1);
          } else {
            this.settle();
          }
        })
        .onActionCancel(() => {
          if (this.dragDeckVersion === this.deckVersion && !this.dismissing) {
            this.settle();
          }
          this.dragDeckVersion = -1;
        })
    )
    .onClick(() => this.openTopRecommendation())
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 2 }) {
          Text('今日推荐')
            .fontSize(AppTypography.TITLE_S)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font'))
          Text('每日从主站档案库随机调阅一组条目')
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (this.recommendations.length > 0) {
          Text(`${this.currentIndex + 1} / ${this.recommendations.length}`)
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_tertiary'))
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.landingStage()

      // The row itself exists from the first build. Hidden keeps its measured
      // 48vp slot while removing paint and interaction until data is ready.
      Row({ space: 10 }) {
        if (this.error.length > 0) {
          SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
            .fontSize(18)
            .fontColor([$r('sys.color.icon_secondary')])
          Text(this.error)
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        } else {
          SymbolGlyph($r('sys.symbol.swipe'))
            .fontSize(18)
            .fontColor([$r('sys.color.icon_secondary')])
          Text('左右滑动切换，点按卡片查阅全文')
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_secondary'))
            .layoutWeight(1)
        }
        Button({ type: ButtonType.Circle, stateEffect: false }) {
          if (this.refreshing) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color($r('sys.color.icon_primary'))
          } else {
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(18)
              .fontColor([$r('sys.color.icon_primary')])
          }
        }
        .width(48)
        .height(48)
        .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
        .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_THICK : undefined)
        .border({ width: 0.5, color: materialCardBorderColor(this.materialEnabled) })
        .enabled(this.recommendations.length > 0 && !this.refreshing)
        .accessibilityText('再换一批推荐')
        .onClick(() => {
          if (this.recommendations.length > 0) {
            this.onRefresh();
          }
        })
      }
      .width('100%')
      .height(48)
      .alignItems(VerticalAlign.Center)
      .visibility(this.recommendations.length > 0 ? Visibility.Visible : Visibility.Hidden)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
