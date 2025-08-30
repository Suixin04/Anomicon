import { curves } from '@kit.ArkUI'
import { FontSizeManager, Tale, VibrationUtils } from 'utils'

@ComponentV2
export struct StoryCardView {
  @Param @Require item: Tale
  @Local private scaleValue: number = 1.0

  @Param onCardClick: (item: Tale) => void = () => {
  }

  build() {
    Column({ space: 15 }) {
      // 故事标题
      Text(this.item.title)
        .fontColor($r('app.color.text_primary'))
        .fontSize(FontSizeManager.getScaledFontSize(18))
        .width('100%')
        .fontWeight(FontWeight.Bold)
      // 作者和发布日期信息
      Text('作者: ' + this.item.author + ' • ' + this.item.datePublished)
        .width('100%')
        .fontColor($r('app.color.text_secondary'))
        .fontSize(FontSizeManager.getScaledFontSize(14))
        .margin({ bottom: 10 })
      // 故事内容摘要
      Text(this.item.content.replace(/\n/g, ''))
        .width('100%')
        .fontColor($r('app.color.text_secondary'))
        .fontSize(FontSizeManager.getScaledFontSize(14))
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      // 标签列表
      Row({ space: 8 }) {
        ForEach(this.item.tags, (tag: string, index: number) => {
          if (index <= 3) {
            Text(index < 3 ? tag : `+${this.item.tags.length - 3}`)
              .backgroundColor($r('app.color.background_tertiary'))
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

      // 相关SCP项目列表
      if (this.item.relatedSCPs.length) {
        Row() {
          Text('相关SCP: ')
            .fontColor($r('app.color.text_secondary'))
            .fontSize(FontSizeManager.getScaledFontSize(12))
          ForEach(this.item.relatedSCPs, (scp: string, index: number) => {
            Text(index < this.item.relatedSCPs.length - 1 ? `${scp}、` : scp)
              .fontColor($r('app.color.text_secondary'))
              .fontSize(FontSizeManager.getScaledFontSize(12))
          })
        }
        .width('100%')
      }
    }
    .border({ width: 0.5, color: $r('app.color.border_primary'), radius: 10 })
    .width('100%')
    .backgroundColor($r('app.color.background_secondary'))
    .justifyContent(FlexAlign.Start)
    .padding({
      left: 20,
      right: 20,
      top: 30,
      bottom: 30
    })
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
      // 添加轻触振动反馈
      VibrationUtils.lightTap()
      this.onCardClick(this.item)
    })
  }
}