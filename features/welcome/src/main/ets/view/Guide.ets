import { FontSizeManager } from "utils"

@ComponentV2
export struct Guide {
  @Consumer('sc')swiperController?: SwiperController
  @Builder
  titleBuilder(title: string, subtitle: string){
    Column({ space: 10 }) {
      Text(title)
        .fontSize(20)
        .fontColor($r('app.color.primary_color'))
        .fontWeight(FontWeight.Bold)
      Text(subtitle)
        .fontSize(12)
        .fontColor($r('app.color.text_tertiary'))
    }
  }
  @Local offsetY: number = 0;

  build() {
    Column({ space: 20 }) {
      Stack() {
        Image($r('app.media.shield'))
          .width(34)
          .height(34)
      }
      .width(60)
      .height(60)
      // .backgroundColor($r('app.color.primary_color'))
      .linearGradient({
        angle: 135,
        colors: [
          ['#F23A16', 0.135],
          ['#fffa905a', 1.0],
        ]
      })
      .borderRadius(30)
      .padding(13)
      .translate({ x: 0, y: this.offsetY })
      .animation({
        duration: 2000,
        curve: Curve.Smooth,
        iterations: -1,
        playMode: PlayMode.Alternate
      })
      this.titleBuilder('欢迎来到「格异录」', '准入考试系统')
      Row({ space: 10 }) {
        Column() {
          Image($r('app.media.triangle_alert'))
            .width(12)
        }
        Column({ space: 5 }) {
          Text('注意：').fontColor($r('app.color.primary_color')).fontSize(12)
          Text('您即将进入SCP基金会数据库。为确保您具备必要的基础知识，需要通过准入考试（80分及格）。').fontColor($r('app.color.primary_color')).fontSize(12).textAlign(TextAlign.JUSTIFY)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({left: 10, right: 10, top: 10, bottom: 10})
      // .backgroundColor($r('app.color.background_secondary'))
      .backgroundColor('#10ff4444')
      .border({ width: $r('app.float.border_width_normal'),
                radius: $r('app.float.border_radius_md'),
                color: $r('app.color.primary_color') })
      Column({ space: 10 }) {
        Column() {
          Row({ space: 10 }) {
            Column() {
              Image($r('app.media.book_open'))
                .width(14)
            }
            Column({ space: 5 }) {
              Text('考试流程').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
              Text('• 第一步：学习SCP基金会基础知识\n' +
                '• 第二步：了解考试说明和规则\n' +
                '• 第三步：参加正式考试（10道题，限时5分钟）\n' +
                '• 第四步：查看考试结果').fontColor($r('app.color.text_tertiary')).fontSize(12).textAlign(TextAlign.JUSTIFY)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.alignItems(VerticalAlign.Top)
        }.borderWidth({ bottom: 1 }).borderColor('#131f1f1f').padding({bottom: 10})
        Column() {
          Row({ space: 10 }) {
            Column() {
              Image($r('app.media.book_alert'))
                .width(14)
            }
            Column({ space: 5 }) {
              Text('重要提醒').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
              Text('SCP基金会是虚构的创意写作项目，所有内容均为文学创作。 本考试旨在确保您理解基本概念，能够更好地欣赏相关内容。').fontColor($r('app.color.text_tertiary')).fontSize(12).textAlign(TextAlign.JUSTIFY)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.alignItems(VerticalAlign.Top)
        }
      }
      .layoutWeight(1)
      .padding({left: 10, right: 10, top: 10, bottom: 10})
      .width('100%')
      .backgroundColor('#101e1e1e')
      .border({ width: $r('app.float.border_width_normal'),
        radius: $r('app.float.border_radius_md'),
        color: $r('app.color.primary_color') })

      Button('开始学习', { type: ButtonType.Normal })
        .fontSize(FontSizeManager.getScaledFontSize(15))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.background_primary'))
        .backgroundColor($r('app.color.primary_color'))
        .border({ radius: 8, width: 0, color: $r('app.color.border_primary') })
        .onClick(() => this.swiperController?.showNext())
        .backgroundColor($r('app.color.primary_color'))
        .borderRadius(8)
        .width('100%')
        .padding({ top: 10, bottom: 10 })
      Divider()
        .margin({left: -20, right: -20, bottom: 10})
    }
    .onAppear(() => {
      this.offsetY = -10
    }).padding({top: 20, bottom: 20, left: 20, right: 20})
    .width('80%')
    .height('95%')
  }
}