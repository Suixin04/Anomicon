import { AppMotion, ExternalUrlPolicy, SkeletonBlock } from 'anomiconbasic';

/**
 * 文章配图组件：直接使用 ArkUI Image 的网络图片管线。
 * 加载中显示占位；失败时显示错误占位。
 * 点按图片触发全屏预览（onOpen）；失败态的浏览器按钮走 onOpenInBrowser。
 */
@ComponentV2
export struct ScpArticleImage {
  @Require @Param url: string;
  @Param preferredWidth: number = 0;
  @Param inlineMode: boolean = false;
  @Event onOpen: () => void;
  @Event onOpenInBrowser: (url: string) => void;

  @Local private resolvedUrl: string = '';
  @Local private loading: boolean = true;
  @Local private failed: boolean = false;
  @Local private intrinsicWidth: number = 0;
  @Local private intrinsicHeight: number = 0;
  /** Ignore Image callbacks belonging to a URL that has already changed. */
  private loadEpoch: number = 0;
  /** Keep the last safe/raw request for the failure-state browser action. */
  private browserUrl: string = '';

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
    this.intrinsicWidth = 0;
    this.intrinsicHeight = 0;
    try {
      this.resolvedUrl = ExternalUrlPolicy.resolveImageHttps(requestedUrl);
      this.browserUrl = this.resolvedUrl;
      this.loading = true;
      this.failed = false;
    } catch (error) {
      this.resolvedUrl = '';
      this.loading = false;
      this.failed = true;
      console.warn(`Reject article image URL: ${error instanceof Error ? error.message : 'unknown error'}`);
    }
  }

  private inlineDisplayWidth(): number | string {
    if (!this.inlineMode) {
      return '100%';
    }
    if (this.preferredWidth > 0) {
      return Math.max(48, Math.min(560, this.preferredWidth));
    }
    if (this.intrinsicWidth > 0 && this.intrinsicWidth < 900) {
      return Math.min(560, Math.max(64, Math.round(this.intrinsicWidth / 2)));
    }
    return '100%';
  }

  private skeletonHeight(): number {
    if (!this.inlineMode) {
      return 240;
    }
    if (this.preferredWidth > 0 && this.preferredWidth < 200) {
      return 120;
    }
    return 200;
  }

  private onImageComplete(epoch: number): (width: number, height: number) => void {
    return (width: number, height: number): void => {
      if (epoch === this.loadEpoch) {
        if (width > 0) {
          this.intrinsicWidth = width;
        }
        if (height > 0) {
          this.intrinsicHeight = height;
        }
        this.loading = false;
      }
    };
  }

  private onImageError(epoch: number): (error: ImageError) => void {
    return (error: ImageError): void => {
      if (epoch !== this.loadEpoch) {
        return;
      }
      console.warn(`ArkUI article image failed: ${error.message}; url=${this.resolvedUrl}`);
      this.loading = false;
      this.failed = true;
    };
  }

  build() {
    if (this.failed) {
      Column({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
          .fontSize(26)
          .fontColor([$r('sys.color.icon_secondary')])
        Text('图片加载失败')
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
        Row({ space: 10 }) {
          Button('重试', { stateEffect: false })
            .fontSize(12)
            .height(30)
            .onClick(() => this.loadImage())
          Button('浏览器打开', { stateEffect: false })
            .fontSize(12)
            .height(30)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .fontColor($r('sys.color.font'))
            .onClick(() => this.onOpenInBrowser(this.browserUrl))
        }
      }
      .width('100%')
      .height(this.skeletonHeight())
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(10)
    } else {
      Stack({ alignContent: Alignment.Center }) {
        Image(this.resolvedUrl)
          .width(this.inlineDisplayWidth())
          .constraintSize(this.inlineMode ? { maxWidth: '100%', maxHeight: 460 } : { maxWidth: '100%' })
          .objectFit(ImageFit.Contain)
          .autoResize(true)
          .backgroundColor(this.inlineMode && !this.loading ? Color.Transparent : $r('sys.color.comp_background_primary'))
          .borderRadius(this.inlineMode ? 8 : 10)
          .opacity(this.loading ? 0 : 1)
          .animation(AppMotion.microAnimateParam())
          .onComplete((event) => {
            const w = event?.loadingStatus === 1 ? (event?.width ?? 0) : 0;
            const h = event?.loadingStatus === 1 ? (event?.height ?? 0) : 0;
            this.onImageComplete(this.loadEpoch)(w, h);
          })
          .onError(this.onImageError(this.loadEpoch))
          .onClick(() => this.onOpen())

        if (this.loading) {
          SkeletonBlock({ animated: true, radius: 10 })
            .width(this.preferredWidth > 0 ? this.inlineDisplayWidth() : '100%')
            .constraintSize({ maxWidth: '100%' })
            .height(this.skeletonHeight())
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .width('100%')
    }
  }
}
