import { AppTypography } from 'anomiconbasic';
import { ArticleWebSurface } from '../adapter/ArticleWebSurface';

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
  @Event onCurrentUrlChange: (url: string) => void = () => {};
  @Event onReadingInput: () => void = () => {};
  @Event onSwitchToNative: () => void = () => {};

  @Local private loadProgress: number = 0;
  @Local private loadError: string = '';
  @Local private retryEpoch: number = 0;

  build() {
    Column() {
      Stack({ alignContent: Alignment.Top }) {
        ArticleWebSurface({
          url: this.url,
          baseArticleUrl: this.baseArticleUrl,
          reloadEpoch: this.reloadEpoch + this.retryEpoch,
          backEpoch: this.backEpoch,
          onOpenArticleLink: this.onOpenArticleLink,
          onOpenExternalUrl: this.onOpenExternalUrl,
          onCanGoBackChange: this.onCanGoBackChange,
          onCurrentUrlChange: this.onCurrentUrlChange,
          onReadingInput: this.onReadingInput,
          onLoadBegin: (progress: number): void => {
            this.loadError = '';
            this.loadProgress = progress;
          },
          onLoadProgress: (progress: number): void => { this.loadProgress = progress; },
          onLoadError: (message: string): void => { this.loadError = message; }
        })

        if (this.loadProgress < 100 && this.loadError.length === 0) {
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
                .onClick((): void => { this.retryEpoch++; })
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
