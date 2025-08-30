import { FontSizeManager, roll2top, VibrationUtils } from "utils"

/**
 * 页面标题组件 - 显示应用主标题
 */
@ComponentV2
export struct Title {
  @Param str: string = ''
  @Param @Require scroller: Scroller

  build() {
    // 页面标题（独立于滚动区域）
    Row() {
      Blank()
      Text(this.str)
        .fontSize(FontSizeManager.getScaledFontSize(25))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Blank()
    }
    .margin({ bottom: 20 })
    .gesture(
      TapGesture({ count: 2 })
        .onAction(() => {
          // 双击标题滚动到顶部
          roll2top(this.scroller)
          // 添加振动反馈
          VibrationUtils.lightTap()
        })
    )
  }
}