import { FontSizeManager } from "utils"

/**
 * 标题组件 - 显示固定文本和动态统计信息
 * @param fixText 固定标题文本
 * @param varText 动态变化的统计文本
 */
@ComponentV2
export struct SubtitleView {
  @Param fixText: string = 'SCP档案'
  @Param varText: string = '无项目'

  build() {
    Row() {
      Text(this.fixText)
        .fontSize(FontSizeManager.getScaledFontSize(18))
        .fontColor($r('app.color.text_primary'))
      Text(this.varText)
        .fontSize(FontSizeManager.getScaledFontSize(14))
        .fontColor($r('app.color.text_primary'))
    }
    .padding({ top: 10 })
    .justifyContent(FlexAlign.SpaceBetween)
    .width('100%')
  }
}