import { FontSizeManager } from "utils"

/**
 * 状态指示器组件 - 显示各种加载和状态信息
 * @param type 状态类型：loading/searching/noResults/noMore
 * @param message 状态描述信息
 */
@ComponentV2
export struct StatusIndicatorView {
  @Param type: 'loading' | 'searching' | 'noResults' | 'noMore' = 'loading'
  @Param message: string = ''

  build() {
    if (this.type === 'loading' || this.type === 'searching') {
      Row({ space: 10 }) {
        LoadingProgress()
          .width(20)
          .height(20)
        Text(this.message)
          .fontSize(FontSizeManager.getScaledFontSize(14))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(20)
    } else {
      Text(this.message)
        .fontSize(FontSizeManager.getScaledFontSize(14))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding(20)
    }
  }
}