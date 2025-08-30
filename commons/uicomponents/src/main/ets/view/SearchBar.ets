import { FontSizeManager } from "utils"

/**
 * 搜索框组件 - 提供SCP项目搜索功能
 * @param keyword 当前搜索关键词
 * @param onSearchChange 搜索内容变化回调
 * @param onSearchSubmit 搜索提交回调
 */
@ComponentV2
export struct SearchBarView {
  @Param placeStr: string = ''
  @Param keyword: string = ''
  @Param onSearchChange: (value: string) => void = () => {
  }
  @Param onSearchSubmit: () => void = () => {
  }

  build() {
    Search({ placeholder: this.placeStr })
      .placeholderColor(Color.Gray)
      .placeholderFont({ size: FontSizeManager.getScaledFontSize(16), weight: FontWeight.Normal })
      .textFont({ size: FontSizeManager.getScaledFontSize(16), weight: FontWeight.Normal })
      .fontColor($r('app.color.text_primary'))
      .backgroundColor($r('app.color.overlay_light'))
      .border({ color: $r('app.color.border_primary'), width: 0.5, radius: 8 })
      .width('95%')
      .height(35)
      .onChange(this.onSearchChange)
      .onSubmit(this.onSearchSubmit)
  }
}