import { ScpContentBlock } from '../../domain/ScpDocument';
import {
  AppMotion,
  AppTypography,
  ImagePreviewActions,
  isReduceMotionEnabled,
  pressAnimation,
  windowAvoidTop
} from 'anomiconbasic';

/** 单页图片：由原生 Scroll 负责双指缩放、边界约束与缩放后拖动。 */
@ComponentV2
struct ScpPreviewPage {
  @Require @Param url: string;
  @Require @Param actions: ImagePreviewActions;
  @Event onBrowserOpen: (url: string) => void;
  @Event onZoomedChange: (zoomed: boolean) => void;

  @Local private resolvedUrl: string = '';
  @Local private loading: boolean = true;
  @Local private failed: boolean = false;
  @Local private zoomScale: number = 1;
  /** Ignore image callbacks from a page that has already been reused. */
  private loadEpoch: number = 0;
  /** Preserve the requested URL for the failure-state browser action. */
  private browserUrl: string = '';

  private readonly imageScroller: Scroller = new Scroller();
  private viewportWidth: number = 0;
  private viewportHeight: number = 0;

  aboutToAppear(): void {
    this.loadImage();
  }

  @Monitor('url')
  onUrlChange(): void {
    this.loadImage();
  }

  private loadImage(): void {
    this.loadEpoch += 1;
    const requestedUrl = this.url.trim();
    this.browserUrl = requestedUrl;
    try {
      this.resolvedUrl = this.actions.resolveUrl(requestedUrl);
      this.browserUrl = this.resolvedUrl;
      this.loading = true;
      this.failed = false;
      this.resetZoom();
    } catch (error) {
      this.resolvedUrl = '';
      this.loading = false;
      this.failed = true;
      this.resetZoom();
      console.warn(`Reject preview image URL: ${error instanceof Error ? error.message : 'unknown error'}`);
    }
  }

  private onImageComplete(epoch: number): () => void {
    return (): void => {
      if (epoch === this.loadEpoch) {
        this.loading = false;
      }
    };
  }

  private onImageError(epoch: number): (error: ImageError) => void {
    return (error: ImageError): void => {
      if (epoch !== this.loadEpoch) {
        return;
      }
      console.warn(`ArkUI preview image failed: ${error.message}; url=${this.resolvedUrl}`);
      this.loading = false;
      this.failed = true;
    };
  }

  private resetZoom(animated: boolean = false): void {
    this.imageScroller.scrollTo({
      xOffset: 0,
      yOffset: 0,
      animation: animated,
      canOverScroll: false
    });
    if (animated) {
      this.getUIContext().animateTo(AppMotion.springAnimateParam(true), (): void => {
        this.zoomScale = 1;
      });
    } else {
      this.zoomScale = 1;
    }
    this.onZoomedChange(false);
  }

  private toggleZoom(): void {
    if (this.zoomScale > 1) {
      this.resetZoom(true);
      return;
    }
    const targetScale: number = 2.5;
    // Native pinch zoom preserves its focal point automatically. Mirror that behavior for double tap.
    this.imageScroller.scrollTo({
      xOffset: this.viewportWidth * (targetScale - 1) / 2,
      yOffset: this.viewportHeight * (targetScale - 1) / 2,
      animation: !isReduceMotionEnabled(),
      canOverScroll: true
    });
    this.getUIContext().animateTo(AppMotion.springAnimateParam(true), (): void => {
      this.zoomScale = targetScale;
    });
    this.onZoomedChange(true);
  }

  build() {
    if (this.failed) {
      Column({ space: 12 }) {
        Text('图片加载失败')
          .fontSize(14)
          .fontColor('#CCFFFFFF')
        Row({ space: 12 }) {
          Button('重试', { stateEffect: false })
            .fontSize(12)
            .height(32)
            .onClick(() => this.loadImage())
          Button('浏览器打开', { stateEffect: false })
            .fontSize(12)
            .height(32)
            .onClick(() => this.onBrowserOpen(this.browserUrl))
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Stack() {
        Scroll(this.imageScroller) {
          Image(this.resolvedUrl)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .autoResize(true)
            .onComplete(this.onImageComplete(this.loadEpoch))
            .onError(this.onImageError(this.loadEpoch))
        }
          .width('100%')
          .height('100%')
          .scrollable(ScrollDirection.FREE)
          .scrollBar(BarState.Off)
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            const width = Number(newArea.width);
            const height = Number(newArea.height);
            this.viewportWidth = Number.isFinite(width) ? width : 0;
            this.viewportHeight = Number.isFinite(height) ? height : 0;
          })
          .minZoomScale(1)
          .maxZoomScale(4)
          .zoomScale(this.zoomScale)
          .enableBouncesZoom(false)
          // 1× 时把单指横滑交给 Swiper；原生双指缩放识别器不受此开关影响。
          .enableScrollInteraction(this.zoomScale > 1.001)
          .onGestureRecognizerJudgeBegin((_event: BaseGestureEvent, current: GestureRecognizer) => {
            if (this.zoomScale <= 1.001 && current.isBuiltIn() &&
              current.getType() === GestureControl.GestureType.PAN_GESTURE) {
              return GestureJudgeResult.REJECT;
            }
            return GestureJudgeResult.CONTINUE;
          }, true)
          .onDidZoom((scale: number) => {
            if (!Number.isFinite(scale)) {
              return;
            }
            this.zoomScale = Math.max(1, Math.min(4, scale));
            this.onZoomedChange(this.zoomScale > 1.001);
          })
          .onZoomStart(() => {
            this.onZoomedChange(true);
          })
          .onZoomStop(() => {
            this.onZoomedChange(this.zoomScale > 1.001);
          })

        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color('#66FFFFFF')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .hitTestBehavior(HitTestMode.None)
        }

      }
      .width('100%')
      .height('100%')
      .parallelGesture(
        TapGesture({ count: 2 })
          .onAction(() => {
            this.toggleZoom();
          })
      )
    }
  }
}

/**
 * 全屏图片预览器：黑底 Swiper 翻页 + 页码 + 保存到相册 + 底部图注。
 * 缩放中的页面会禁用 Swiper 翻页，手势让位给拖动。
 */
@ComponentV2
export struct ScpImagePreviewer {
  @Require @Param images: ScpContentBlock[];
  @Require @Param initialIndex: number;
  @Require @Param actions: ImagePreviewActions;
  @Param materialEnabled: boolean = true;
  @Event onClose: () => void;
  @Event onIndexChange: (index: number) => void;
  /** Product-owned system notice/effect boundary. */
  @Event onNotice: (message: string) => void;

  @Local private currentIndex: number = 0;
  @Local private zoomed: boolean = false;

  private readonly previewController: SwiperController = new SwiperController();
  private savePending: boolean = false;

  private normalizedIndex(index: number): number {
    if (this.images.length === 0 || !Number.isFinite(index)) {
      return 0;
    }
    return Math.max(0, Math.min(Math.floor(index), this.images.length - 1));
  }

  aboutToAppear(): void {
    this.currentIndex = this.normalizedIndex(this.initialIndex);
  }

  @Monitor('images')
  onImagesChange(): void {
    if (this.images.length === 0) {
      this.currentIndex = 0;
      this.zoomed = false;
      return;
    }
    const nextIndex = this.normalizedIndex(this.currentIndex);
    if (nextIndex !== this.currentIndex) {
      this.currentIndex = nextIndex;
      this.previewController.changeIndex(nextIndex, false);
      this.onIndexChange(nextIndex);
    }
  }

  private async saveCurrent(): Promise<void> {
    if (this.savePending || this.images.length === 0) {
      return;
    }
    const image = this.images[this.normalizedIndex(this.currentIndex)];
    if (image === undefined || image.source.trim().length === 0) {
      this.onNotice('图片地址无效');
      return;
    }
    this.savePending = true;
    let saved: boolean = false;
    let failureNotified: boolean = false;
    try {
      saved = await this.actions.save(image.source);
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知错误';
      console.warn(`Save image failed: ${message}`);
      this.onNotice('保存失败，请稍后重试');
      failureNotified = true;
    } finally {
      this.savePending = false;
    }
    if (saved) {
      this.onNotice('已保存到相册');
    } else if (!failureNotified) {
      // The platform adapter deliberately maps cancellation and capability
      // failures to false; keep that result visible instead of ending silently.
      this.onNotice('保存未完成');
    }
  }

  private async openInBrowser(url: string = ''): Promise<void> {
    if (this.images.length === 0) {
      return;
    }
    const image = this.images[this.normalizedIndex(this.currentIndex)];
    const target = url.trim().length > 0 ? url : (image?.source ?? '');
    if (target.trim().length === 0) {
      this.onNotice('图片地址无效');
      return;
    }
    try {
      await this.actions.open(target);
    } catch (error) {
      this.onNotice('无法打开浏览器');
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')

      Swiper(this.previewController) {
        Repeat<ScpContentBlock>(this.images)
          .each((row: RepeatItem<ScpContentBlock>) => {
            ScpPreviewPage({
              url: row.item.source,
              actions: this.actions,
              onBrowserOpen: (url: string) => this.openInBrowser(url),
              onZoomedChange: (zoomed: boolean) => {
                this.zoomed = zoomed;
              }
            })
          })
          .key((image: ScpContentBlock) => image.key)
      }
      .width('100%')
      .height('100%')
      .index(this.normalizedIndex(this.currentIndex))
      .loop(false)
      .indicator(false)
      // 缩放状态下滑动让位给拖动，禁掉翻页。
      .disableSwipe(this.zoomed)
      .onChange((index: number) => {
        this.currentIndex = index;
        this.zoomed = false;
        this.onIndexChange(index);
      })

      // 顶部操作栏
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: false }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor(['#FFFFFF'])
        }
        .width(40)
        .height(40)
        .backgroundColor(this.materialEnabled ? '#66181E28' : '#A6181E28')
        .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_THIN : undefined)
        .border({ width: 0.5, color: '#33FFFFFF' })
        .animation(pressAnimation())
        .onClick(() => this.onClose())

        Blank()

        Text(`${this.currentIndex + 1} / ${this.images.length}`)
          .fontSize(AppTypography.SUBTITLE_S)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')

        Blank()

        Button('保存', { stateEffect: false })
          .fontSize(AppTypography.SUBTITLE_S)
          .height(36)
          .backgroundColor(this.materialEnabled ? '#66181E28' : '#A6181E28')
          .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_THIN : undefined)
          .border({ width: 0.5, color: '#33FFFFFF' })
          .fontColor('#FFFFFF')
          .onClick(() => this.saveCurrent())
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      // 预览打开时宿主页已隐藏标题栏，控件避开实时状态栏高度布局。
      .margin({ top: windowAvoidTop() + 8 })

      // 底部图注：铺满高度的容器底部对齐。
      Column() {
        if (this.images.length > 0 && this.currentIndex >= 0 &&
          this.currentIndex < this.images.length &&
          this.images[this.currentIndex].caption.length > 0) {
          Text(this.images[this.currentIndex].caption)
            .fontSize(AppTypography.BODY_S)
            .fontColor('#CCFFFFFF')
            .textAlign(TextAlign.Center)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .padding({ left: 24, right: 24 })
            .margin({ bottom: 56 })
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
  }
}
