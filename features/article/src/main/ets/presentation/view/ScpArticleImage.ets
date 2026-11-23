import { ExternalUrlPolicy, SkeletonBlock } from 'anomiconbasic';

/**
 * 文章配图组件：直接使用 ArkUI Image 的网络图片管线。
 * 加载中显示占位；失败时显示错误占位。
 * 点按图片触发全屏预览（onOpen）；失败态的浏览器按钮走 onOpenInBrowser。
 */
@ComponentV2
export struct ScpArticleImage {
  @Require @Param url: string;
  @Event onOpen: () => void;
  @Event onOpenInBrowser: (url: string) => void;

  @Local private resolvedUrl: string = '';
  @Local private loading: boolean = true;
  @Local private failed: boolean = false;
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
      .height(240)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(10)
    } else {
      Stack() {
        Image(this.resolvedUrl)
          .width('100%')
          .objectFit(ImageFit.Contain)
          .autoResize(true)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(10)
          .opacity(this.loading ? 0 : 1)
          .animation({ duration: 180, curve: Curve.EaseOut })
          .onComplete(this.onImageComplete(this.loadEpoch))
          .onError(this.onImageError(this.loadEpoch))
          .onClick(() => this.onOpen())

        if (this.loading) {
          SkeletonBlock({ animated: true, radius: 10 })
            .width('100%')
            .height(240)
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .width('100%')
    }
  }
}
