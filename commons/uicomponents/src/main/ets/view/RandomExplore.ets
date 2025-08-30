import { curves } from '@kit.ArkUI'
import { FontSizeManager } from 'utils'

/**
 * 随机探索按钮组件 - 提供随机浏览SCP项目的功能
 * @param onRandomExplore 随机探索操作回调函数
 */
@ComponentV2
export struct RandomExploreView {
  @Local private scaleValue: number = 1.0

  @Param onRandomExplore: () => void = () => {
  }

  build() {
    Row({ space: 10 }) {
      Image($r('app.media.shuffle'))
        .width(15)
      Text('随机探索 SCP')
        .fontSize(FontSizeManager.getScaledFontSize(15))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.background_primary'))
    }
    .backgroundColor($r('app.color.primary_color'))
    .borderRadius(8)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 10, bottom: 10 })
    .scale({ x: this.scaleValue, y: this.scaleValue })
    .animation({
      duration: 150,
      curve: Curve.EaseOut
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        animateTo({
          duration: 150,
          curve: Curve.EaseOut
        }, () => {
          this.scaleValue = 0.98
        })
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        animateTo({
          duration: 200,
          curve: curves.springMotion(0.6, 0.8)
        }, () => {
          this.scaleValue = 1.0
        })
      }
    })
    .onClick(this.onRandomExplore)
  }
}