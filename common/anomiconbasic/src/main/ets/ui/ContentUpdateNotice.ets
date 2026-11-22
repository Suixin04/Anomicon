import { AppTypography } from '../foundation/AppTypography';

/** Non-blocking status for content that remains available during an update. */
@ComponentV2
export struct ContentUpdateNotice {
  @Require @Param message: string;
  @Param updating: boolean = false;
  @Param updatingMessage: string = '正在更新';
  @Event onRetry: () => void;

  build() {
    Row({ space: 8 }) {
      if (this.updating) {
        LoadingProgress()
          .width(16)
          .height(16)
          .color($r('sys.color.icon_secondary'))
      } else {
        SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
          .fontSize(16)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      Text(this.updating ? this.updatingMessage : this.message)
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
      if (!this.updating) {
        Button('重试', { stateEffect: false })
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_emphasize'))
          .backgroundColor(Color.Transparent)
          .constraintSize({ minHeight: 44, minWidth: 48 })
          .onClick(() => this.onRetry())
      }
    }
    .width('100%')
    .padding({ left: 12, right: 8, top: 4, bottom: 4 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(12)
  }
}
