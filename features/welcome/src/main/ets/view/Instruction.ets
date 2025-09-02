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
        .fontColor($r('app.color.primary_color'))
      Text(subtitle)
        .fontSize(12)
        .fontColor($r('app.color.text_tertiary'))
    }
  }
  @Local offsetY: number = 0;

  build() {
    Column({ space: 20 }) {
      Stack() {
        Image($r('app.media.book_open_check'))
          .width(34)
          .height(34)
      }
      .width(60)
      .height(60)
      .backgroundColor('#3698d9')
      .borderRadius(30)
      .padding(13)
      .translate({ x: 0, y: this.offsetY })
      .animation({
        duration: 2000,
        curve: Curve.Smooth,
        iterations: -1,
        playMode: PlayMode.Alternate
      })
      this.titleBuilder('考试说明', '请仔细阅读以下规则和要求')
      
      // 重要提醒
      Row({ space: 10 }) {
        Column() {
          Image($r('app.media.triangle_alert'))
            .width(12)
        }
        Column({ space: 5 }) {
          Text('重要提醒').fontColor('#ef4444').fontSize(12).fontWeight(FontWeight.Bold)
          Text('您即将进入SCP基金会数据库。为确保您具备必要的基础知识，需要通过准入考试（80分及格）。考试不通过将无法进入应用。').fontColor('#ef4444').fontSize(12).textAlign(TextAlign.JUSTIFY)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({left: 10, right: 10, top: 10, bottom: 10})
      .backgroundColor('#10ef4444')
      .border({ width: 1, color: '#20ef4444', radius: 8 })

      // 滚动区域包含考试规则
      Scroll() {
        Column({ space: 15 }) {
          // 考试基本信息
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Column() {
                Image($r('app.media.clock'))
                  .width(14)
              }
              Column({ space: 5 }) {
                Text('考试基本信息').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#3698d9')
                Column({ space: 5 }) {
                  Text('• 题目数量：10道选择题').fontSize(11).fontColor($r('app.color.text_tertiary'))
                  Text('• 考试时间：5分钟').fontSize(11).fontColor($r('app.color.text_tertiary'))
                  Text('• 及格分数：80分（答对8题）').fontSize(11).fontColor($r('app.color.text_tertiary'))
                  Text('• 题目类型：单选题，每题10分').fontSize(11).fontColor($r('app.color.text_tertiary'))
                }.alignItems(HorizontalAlign.Start)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.alignItems(VerticalAlign.Top)
          }
          .padding({left: 10, right: 10, top: 10, bottom: 10})
          .width('100%')
          .backgroundColor('#101e1e1e')
          .border({ width: $r('app.float.border_width_normal'),
            radius: $r('app.float.border_radius_md'),
            color: '#3698d9' })

          // 考试规则
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Column() {
                Image($r('app.media.book_open'))
                  .width(14)
              }
              Column({ space: 5 }) {
                Text('考试规则').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#3698d9')
                Column({ space: 5 }) {
                  Text('• 考试开始后计时器将自动启动，请注意时间管理').fontSize(11).fontColor($r('app.color.text_tertiary'))
                  Text('• 可以在题目间自由切换，支持修改已选答案').fontSize(11).fontColor($r('app.color.text_tertiary'))
                  Text('• 时间到达或主动提交后，考试立即结束').fontSize(11).fontColor($r('app.color.text_tertiary'))
                  Text('• 考试过程中请勿退出应用，否则视为放弃考试').fontSize(11).fontColor($r('app.color.text_tertiary'))
                  Text('• 考试结果将立即显示，不通过可重新考试').fontSize(11).fontColor($r('app.color.text_tertiary'))
                }.alignItems(HorizontalAlign.Start)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.alignItems(VerticalAlign.Top)
          }
          .padding({left: 10, right: 10, top: 10, bottom: 10})
          .width('100%')
          .backgroundColor('#101e1e1e')
          .border({ width: $r('app.float.border_width_normal'),
            radius: $r('app.float.border_radius_md'),
            color: '#3698d9' })

          // 考试内容范围
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Column() {
                Image($r('app.media.file_text'))
                  .width(14)
              }
              Column({ space: 5 }) {
                Text('考试内容范围').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#3698d9')
                Column({ space: 5 }) {
                  Text('• SCP基金会的基本概念和使命').fontSize(11).fontColor($r('app.color.text_tertiary'))
                  Text('• 收容等级系统（Safe、Euclid、Keter、Thaumiel）').fontSize(11).fontColor($r('app.color.text_tertiary'))
                  Text('• 基金会的重要术语和概念').fontSize(11).fontColor($r('app.color.text_tertiary'))
                  Text('• SCP编号格式和文档结构').fontSize(11).fontColor($r('app.color.text_tertiary'))
                  Text('• 基金会的保密性和收容原则').fontSize(11).fontColor($r('app.color.text_tertiary'))
                }.alignItems(HorizontalAlign.Start)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.alignItems(VerticalAlign.Top)
          }
          .padding({left: 10, right: 10, top: 10, bottom: 10})
          .width('100%')
          .backgroundColor('#101e1e1e')
          .border({ width: $r('app.float.border_width_normal'),
            radius: $r('app.float.border_radius_md'),
            color: '#3698d9' })

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
                  Text('• 建议先仔细学习基础知识部分的内容').fontSize(11).fontColor($r('app.color.text_tertiary'))
                  Text('• 考试题目基于前面学习的知识点').fontSize(11).fontColor($r('app.color.text_tertiary'))
                  Text('• 保持冷静，合理分配答题时间').fontSize(11).fontColor($r('app.color.text_tertiary'))
                  Text('• 不确定的题目可以先跳过，最后再回来作答').fontSize(11).fontColor($r('app.color.text_tertiary'))
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

      Button('开始考试', { type: ButtonType.Normal })
        .fontSize(FontSizeManager.getScaledFontSize(15))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.background_primary'))
        .backgroundColor('#3698d9')
        .border({ radius: 8, width: 0, color: $r('app.color.border_primary') })
        .onClick(() => this.swiperController?.showNext())
        .borderRadius(8)
        .width('100%')
        .padding({ top: 10, bottom: 10 })
    }
    .onAppear(() => {
      this.offsetY = -10
    }).padding({top: 20, bottom: 20, left: 20, right: 20})
    .width('80%')
    .height('95%')
  }
}