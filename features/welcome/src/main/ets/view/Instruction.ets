import { FontSizeManager } from "utils"

@ComponentV2
@Preview
export struct Instruction {
  @Consumer('sc')swiperController?: SwiperController
  @Builder
  titleBuilder(title: string, subtitle: string){
    Column({ space: 10 }) {
      Text(title)
        .fontSize(20)
        .fontColor('#F26E16')
        .fontWeight(FontWeight.Bold)
      Text(subtitle)
        .fontSize(12)
        .fontColor($r('app.color.text_tertiary'))
    }
  }

  @Local animateFlag: boolean = false

  build() {
    Column({ space: 20 }) {
      Stack() {
        Image($r('app.media.triangle_alert'))
          .width(34)
          .height(34)
      }
      .width(60)
      .height(60)
      .linearGradient({
        angle: 135,
        colors: [
          ['#ffff703e', 0.135],
          ['#ffcb4516', 1.0],
        ]
      })
      .borderRadius(30)
      .padding(13)
      .opacity(this.animateFlag ? 0.7 : 1)
      .animation({
        duration: 2000,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate
      }).onAppear(() => {
        this.animateFlag = !this.animateFlag
      })
      this.titleBuilder('准入考试说明', '请仔细阅读以下规则和要求')

      // 滚动区域包含考试规则
      Scroll() {
        Column({ space: 15 }) {
          // 重要提醒
          Row({ space: 10 }) {
            Column() {
              Image($r('app.media.clock'))
                .width(12)
            }
            Column({ space: 5 }) {
              Text('考试时间').fontColor('#FB6832').fontSize(12).fontWeight(FontWeight.Bold)
              Text('5分钟内完成10道选择题，每题10分，总分100分，80分及格。').fontColor('#FB6832').fontSize(12).textAlign(TextAlign.JUSTIFY)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding({left: 10, right: 10, top: 10, bottom: 10})
          .backgroundColor('#10ef4444')
          .border({ width: 1, color: '#20ef4444', radius: 8 })

          // 考试规则
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Column() {
                Image($r('app.media.exam'))
                  .width(14)
              }
              Column({ space: 5 }) {
                Text('考试规则').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#F26E16')
                Column({ space: 5 }) {
                  Text('• 题目数量：10道单选题，涵盖SCP基金会基础知识').fontSize(11).fontColor($r('app.color.text_primary'))
                  Text('• 考试时长：5分钟，时间到自动提交').fontSize(11).fontColor($r('app.color.text_primary'))
                  Text('• 及格分数：80分（含）以上方可进入应用').fontSize(11).fontColor($r('app.color.text_primary'))
                  Text('• 答题方式：可以自由切换题目，建议先完成会做的题目').fontSize(11).fontColor($r('app.color.text_primary'))
                  Text('• 考试机会：考试失败将无法进入应用，请认真对待').fontSize(11).fontColor($r('app.color.text_primary'))
                }.alignItems(HorizontalAlign.Start)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.alignItems(VerticalAlign.Top)
          }
          .padding({left: 10, right: 10, top: 10, bottom: 10})
          .width('100%')
          .backgroundColor('#101e1e1e')
          .border({ width: $r('app.float.border_width_normal'),
            radius: $r('app.float.border_radius_md'),
            color: '#a9ff9e5b' })

          // 温馨提示
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Column() {
                Image($r('app.media.lightbulb'))
                  .width(14)
              }
              Column({ space: 5 }) {
                Text('温馨提示').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#22c55e')
                Column({ space: 5 }) {
                  Text('• 建议先仔细学习基础知识部分的内容').fontSize(11).fontColor($r('app.color.text_primary'))
                  Text('• 考试题目基于前面学习的知识点').fontSize(11).fontColor($r('app.color.text_primary'))
                  Text('• 如果未达到80分，将无法使用本应用。').fontSize(11).fontColor($r('app.color.text_primary'))
                }.alignItems(HorizontalAlign.Start)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.alignItems(VerticalAlign.Top)
          }
          .padding({left: 10, right: 10, top: 10, bottom: 10})
          .width('100%')
          .backgroundColor('#1022c55e')
          .border({ width: 1, color: '#2022c55e', radius: 8 })
        }
      }
      .height(280)
      .width('100%')
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
      .layoutWeight(1)

      Button('开始考试', { type: ButtonType.Normal })
        .fontSize(FontSizeManager.getScaledFontSize(15))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.background_primary'))
        .backgroundColor('#F26E16')
        .border({ radius: 8, width: 0, color: $r('app.color.border_primary') })
        .onClick(() => {
          this.swiperController?.showNext()

        })
        .borderRadius(8)
        .width('100%')
        .padding({ top: 10, bottom: 10 })

      Divider()
        .margin({left: -20, right: -20, bottom: 10})
    }
    .padding({top: 20, bottom: 20, left: 20, right: 20})
    .width('80%')
    .height('95%')
  }
}