import { ImageWithLoadingView } from './ImageWithLoading'
import { curves } from '@kit.ArkUI'
import { FontSizeManager, getColorsByClass, SCP, VibrationUtils } from 'utils'

/**
 * SCP卡片组件 - 展示单个SCP项目的信息卡片
 * @param item SCP项目数据
 * @param onCardClick 卡片点击回调函数
 */
@ComponentV2
export struct ScpCardView {
  @Param @Require item: SCP
  @Local private scaleValue: number = 1.0

  @Param onCardClick: (item: SCP) => void = () => {
  }

  build() {
    Column({ space: 10 }) {
      ImageWithLoadingView({
        src: this.item.image,
        imgWidth: '100%',
        imgHeight: 128,
        imgRadius: { topLeft: 10, topRight: 10 }
      })
        .width('100%')

      Column({ space: 15 }) {
        Row({ space: 10 }) {
          Text(this.item.number)
            .fontColor($r('app.color.primary_color'))
            .fontSize(FontSizeManager.getScaledFontSize(14))
            .fontWeight(FontWeight.Bold)
          Text(`Series ${this.item.series.toString()}`)
            .fontColor($r('app.color.text_secondary'))
            .fontSize(FontSizeManager.getScaledFontSize(12))
          Blank()
            .layoutWeight(1)
          Text(this.item.objectClass)
          // .margin({top: 10, right: 10})
            .border({ radius: 5, width: 0.8, color: getColorsByClass(this.item.objectClass).borderColor })
            .fontWeight(FontWeight.Bold)
            .fontColor(getColorsByClass(this.item.objectClass).textColor)
            .backgroundColor(getColorsByClass(this.item.objectClass).backgroundColor)
            .fontSize(FontSizeManager.getScaledFontSize(12))
            .padding({
              top: 3,
              bottom: 3,
              left: 6,
              right: 6
            })
        }
        .width('100%')

        Text(this.item.title)
          .fontColor($r('app.color.text_primary'))
          .fontSize(FontSizeManager.getScaledFontSize(18))
          .width('100%')
          .fontWeight(FontWeight.Bold)

        Text(this.item.description)
          .width('100%')
          .fontColor($r('app.color.text_secondary'))
          .fontSize(FontSizeManager.getScaledFontSize(14))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 8 }) {
          ForEach(this.item.tags, (tag: string, index: number) => {
            if (index <= 3) {
              Text(index < 3 ? tag : `+${this.item.tags.length - 3}`)
                .backgroundColor($r('app.color.tag_bg'))
                .borderRadius(6)
                .fontColor($r('app.color.text_primary'))
                .fontSize(FontSizeManager.getScaledFontSize(14))
                .fontWeight(FontWeight.Bold)
                .padding({
                  left: 12,
                  right: 12,
                  top: 5,
                  bottom: 5
                })
            }
          })
        }.width('100%')
      }
      .width('100%')
      .padding({
        left: 20,
        right: 20,
        top: 30,
        bottom: 30
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.background_secondary'))
    .justifyContent(FlexAlign.Start)
    .border({ radius: 10, width: 0.5, color: $r('app.color.border_primary') })
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
    .onClick(() => {
      VibrationUtils.lightTap()
      this.onCardClick(this.item)
    })
  }
}