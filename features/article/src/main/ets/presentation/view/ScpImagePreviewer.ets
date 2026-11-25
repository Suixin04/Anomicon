import { ScpContentBlock } from '../../domain/ScpDocument';
import { ImagePreviewGeometry, PreviewPoint, PreviewTransform } from './ImagePreviewGeometry';
import {
  AppMotion,
  AppTypography,
  ExternalUrlPolicy,
  ImagePreviewActions,
  pressAnimation,
  windowAvoidTop
} from 'anomiconbasic';

interface PreviewSourceSize {
  width: number;
  height: number;
}

/** 手势绑定在固定视口上，只对图片本身作缩放和平移。 */
@ComponentV2
struct ScpPreviewPage {
  @Require @Param url: string;
  @Require @Param actions: ImagePreviewActions;
  @Event onBrowserOpen: (url: string) => void;
  @Event onZoomedChange: (zoomed: boolean) => void;

  @Local private resolvedUrl: string = '';
  @Local private loading: boolean = true;
  @Local private failed: boolean = false;
  @Local private photo: PreviewTransform = { scale: 1, x: 0, y: 0 };
  /** Ignore image callbacks from a page that has already been reused. */
  private loadEpoch: number = 0;
  /** Preserve the requested URL for the failure-state browser action. */
  private browserUrl: string = '';

  private readonly geometry: ImagePreviewGeometry = new ImagePreviewGeometry();
  private gestureStart: PreviewTransform = { scale: 1, x: 0, y: 0 };
  private pinchStart: PreviewPoint = { x: 0, y: 0 };
  private pinching: boolean = false;

  aboutToAppear(): void {
    this.loadImage();
  }

  @Monitor('url')
  onUrlChange(): void {
    this.loadImage();
  }

  private loadImage(): void {
    this.loadEpoch += 1;
    this.pinching = false;
    this.photo = { scale: 1, x: 0, y: 0 };
    this.onZoomedChange(false);
    const requestedUrl = this.url.replace(/[\r\n\t]/g, '').trim();
    this.browserUrl = requestedUrl;
    try {
      this.browserUrl = ExternalUrlPolicy.resolveImageHttps(requestedUrl);
    } catch (_urlError) {
      this.browserUrl = requestedUrl;
    }
    try {
      this.resolvedUrl = this.actions.resolveUrl(requestedUrl);
      this.loading = true;
      this.failed = false;
    } catch (error) {
      this.resolvedUrl = '';
      this.loading = false;
      this.failed = true;
      console.warn(`Reject preview image URL: ${error instanceof Error ? error.message : 'unknown error'}`);
    }
  }

  private onImageComplete(epoch: number): (size?: PreviewSourceSize) => void {
    return (size?: PreviewSourceSize): void => {
      if (epoch === this.loadEpoch && size && size.width > 0 && size.height > 0) {
        this.geometry.imageRatio = size.width / size.height;
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

  private pinchCenter(event: GestureEvent): PreviewPoint {
    const fingers = event.fingerInfos;
    if (fingers && fingers.length === 2) {
      return { x: (fingers[0].localX + fingers[1].localX) / 2, y: (fingers[0].localY + fingers[1].localY) / 2 };
    }
    return { x: event.pinchCenterX, y: event.pinchCenterY };
  }

  private beginPinch(event: GestureEvent): void {
    this.pinching = true;
    this.gestureStart = this.photo;
    this.pinchStart = this.pinchCenter(event);
    this.onZoomedChange(true);
  }

  private endPinch(): void {
    this.pinching = false;
    this.onZoomedChange(this.photo.scale > 1);
  }

  private toggleZoom(point: PreviewPoint): void {
    const target = this.photo.scale > 1 ? 1 : 2.5;
    const next = this.geometry.zoom(this.photo, target, point, point);
    this.onZoomedChange(target > 1);
    this.getUIContext().animateTo(AppMotion.microAnimateParam(), (): void => {
      this.photo = next;
    });
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
        Image(this.resolvedUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .autoResize(true)
          .scale({ x: this.photo.scale, y: this.photo.scale })
          .translate({ x: this.photo.x, y: this.photo.y })
          .onComplete(this.onImageComplete(this.loadEpoch))
          .onError(this.onImageError(this.loadEpoch))

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
      .clip(true)
      .onSizeChange((_old: SizeOptions, size: SizeOptions) => {
        this.geometry.width = Number(size.width);
        this.geometry.height = Number(size.height);
        this.photo = this.geometry.pan(this.photo.scale, this.photo.x, this.photo.y);
      })
      .gesture(GestureGroup(GestureMode.Parallel,
        PinchGesture({ fingers: 2, distance: 2 })
          .onActionStart((event: GestureEvent) => this.beginPinch(event))
          .onActionUpdate((event: GestureEvent) => {
            this.photo = this.geometry.zoom(this.gestureStart, this.gestureStart.scale * event.scale,
              this.pinchStart, this.pinchCenter(event));
          })
          .onActionEnd(() => this.endPinch())
          .onActionCancel(() => this.endPinch()),
        PanGesture({ fingers: 1, isFingerCountLimited: true, distance: 5 })
          .tag('previewPan')
          .onActionStart(() => { this.gestureStart = this.photo; })
          .onActionUpdate((event: GestureEvent) => {
            if (!this.pinching) {
              this.photo = this.geometry.pan(this.photo.scale,
                this.gestureStart.x + event.offsetX, this.gestureStart.y + event.offsetY);
            }
          }),
        TapGesture({ count: 2, fingers: 1, isFingerCountLimited: true, distanceThreshold: 10 })
          .onAction((event: GestureEvent) => {
            if (event.tapLocation) {
              this.toggleZoom({ x: event.tapLocation.x, y: event.tapLocation.y });
            }
          })
      ))
      .onGestureRecognizerJudgeBegin((_event: BaseGestureEvent, current: GestureRecognizer) => {
        if (this.loading || (current.getTag() === 'previewPan' && (this.pinching || this.photo.scale === 1))) {
          return GestureJudgeResult.REJECT;
        }
        return GestureJudgeResult.CONTINUE;
      })
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
                if (row.item.key === this.images[this.currentIndex]?.key) {
                  this.zoomed = zoomed;
                }
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
