import { FontSizeManager } from "utils"

/**
 * 错误状态组件 - 显示加载失败时的错误信息和重试按钮
 * @param onRetry 重试操作回调函数
 */
@ComponentV2
export struct ErrorStateView {
  @Param onRetry: () => void = () => {
  }

  build() {
    Column({ space: 15 }) {
      Image($r("app.media.wifi_off"))
        .width(48)
        .height(48)
        .margin({ bottom: 20 })

      Text('加载失败')
        .fontSize(FontSizeManager.getScaledFontSize(18))
        .fontColor($r('app.color.primary_color'))
        .fontWeight(FontWeight.Medium)

      Text('无法连接到服务器，请检查网络连接或稍后重试')
        .fontSize(FontSizeManager.getScaledFontSize(14))
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .maxLines(2)

      Button('重试')
        .fontSize(FontSizeManager.getScaledFontSize(16))
        .fontColor($r('app.color.background_primary'))
        .backgroundColor($r('app.color.primary_color'))
        .borderRadius(8)
        // .padding({ left: 30, right: 30, top: 10, bottom: 10 })
        .width('70%')
        .onClick(this.onRetry)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}