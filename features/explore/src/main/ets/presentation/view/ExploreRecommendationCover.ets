import { AppTypography, recommendationFallbackBackgroundColor, SkeletonBlock } from 'anomiconbasic';

enum CoverState {
  LOADING,
  READY,
  FAILED
}

/** The deck keys this component by image URI. A late callback belongs to its own cover. */
@ComponentV2
export struct ExploreRecommendationCover {
  @Require @Param source: string;
  @Require @Param previewFailed: boolean;
  @Require @Param animated: boolean;
  @Require @Param horizontal: boolean;
  @Local private state: CoverState = CoverState.LOADING;

  private failed(): boolean {
    return this.previewFailed || this.state === CoverState.FAILED;
  }

  @Builder
  private fallback() {
    Column({ space: 7 }) {
      SymbolGlyph(this.failed() ? $r('sys.symbol.exclamationmark_circle') : $r('sys.symbol.doc_text'))
        .fontSize(42)
        .fontColor([$r('sys.color.icon_tertiary')])
      Text(this.failed() ? '图片暂时无法显示' : '暂无预览图')
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
      if (this.failed()) {
        Text('档案正文仍可打开')
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(recommendationFallbackBackgroundColor())
    .border({
      width: this.horizontal ? { right: 0.5 } : { bottom: 0.5 },
      color: $r('sys.color.comp_divider')
    })
    .accessibilityText(this.failed() ? '图片加载失败，档案正文仍可打开' : '暂无预览图')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.source.length === 0 || this.state === CoverState.FAILED) {
        this.fallback()
      } else {
        if (this.state === CoverState.LOADING) {
          SkeletonBlock({ animated: this.animated, radius: 0 })
            .width('100%')
            .height('100%')
            .hitTestBehavior(HitTestMode.None)
        }
        Image(this.source)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .autoResize(true)
          .opacity(this.state === CoverState.READY ? 1 : 0)
          .onComplete((event) => {
            // Status 0 supplies metadata. Status 1 has pixels ready to display.
            if (event?.loadingStatus === 1 && this.state === CoverState.LOADING) {
              this.state = CoverState.READY;
            }
          })
          .onError(() => {
            if (this.state === CoverState.LOADING) {
              this.state = CoverState.FAILED;
            }
          })
      }
    }
    .width(this.horizontal ? '44%' : '100%')
    .height(this.horizontal ? '100%' : 176)
  }
}
