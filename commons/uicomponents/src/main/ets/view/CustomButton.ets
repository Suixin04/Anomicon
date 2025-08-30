import { FontSizeManager } from "utils"

/**
 * 自定义按钮组件 - 用于系列选择等场景
 * @param text 按钮显示文本
 * @param isSelected 是否为选中状态
 */
@ComponentV2
export struct CustomButtonView {
  @Param text: string = ''
  @Param isSelected: boolean = false

  build() {
    Button(this.text, { type: ButtonType.Normal })
      .fontSize(FontSizeManager.getScaledFontSize(15))
      .fontWeight(this.isSelected ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.isSelected ? $r('app.color.background_primary') : $r('app.color.text_primary'))
      .backgroundColor(this.isSelected ? $r('app.color.primary_color') : $r('app.color.overlay_light'))
      .border({ radius: 8, width: this.isSelected ? 0 : 0.5, color: $r('app.color.border_primary') })
    // .padding({top: 2, bottom: 2, left: 12, right: 12})
  }
}