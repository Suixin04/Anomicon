import { FontSizeManager } from "utils"

@ComponentV2
export struct Knowledge {
  @Consumer('sc')swiperController?: SwiperController
  @Builder
  titleBuilder(title: string, subtitle: string){
    Column({ space: 10 }) {
      Text(title)
        .fontSize(20)
        .fontColor('#16B0F2')
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
        Image($r('app.media.book_open_check'))
          .width(34)
          .height(34)
      }
      .width(60)
      .height(60)
      // .backgroundColor('#16B0F2')
      .linearGradient({
        angle: 135,
        colors: [
          ['#16B0F2', 0.135],
          ['#ff7cd5ff', 1.0],
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
      this.titleBuilder('基础知识', '请仔细阅读以下内容，考试会涉及这些知识点')
      
      // 滚动区域包含知识内容
      Scroll() {
        Column({ space: 15 }) {
          // 基金会简介
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Column() {
                Image($r('app.media.shield_blue'))
                  .width(14)
              }
              Column({ space: 5 }) {
                Text('基金会简介').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#16B0F2')
                Text('SCP基金会是一个虚构的秘密组织，其使命是收容（Secure）、控制（Contain）、保护（Protect）世界上的异常现象、实体和物品。基金会致力于保护人类免受超自然威胁，同时维护社会正常秩序。')
                  .fontColor($r('app.color.text_primary')).fontSize(12).textAlign(TextAlign.JUSTIFY)
                Text('重要：SCP基金会完全是虚构的创意写作项目，所有内容都是文学创作，与现实世界无任何关联。')
                  .fontColor($r('app.color.primary_color')).fontSize(12).textAlign(TextAlign.JUSTIFY).padding({top: 10})
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.alignItems(VerticalAlign.Top)
          }
          .padding({left: 10, right: 10, top: 10, bottom: 10})
          .width('100%')
          .backgroundColor('#101e1e1e')
          .border({ width: $r('app.float.border_width_normal'),
            radius: $r('app.float.border_radius_md'),
            color: '#16B0F2' })

          // 收容等级系统
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Column() {
                Image($r('app.media.lock'))
                  .width(14)
              }
              Column({ space: 5 }) {
                Text('收容等级系统').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#16B0F2')
                Column({ space: 8 }) {
                  // Safe级
                  Row({ space: 8 }) {
                    Circle({ width: 12, height: 12 })
                      .fill('#22c55e')
                    Column({ space: 2 }) {
                      Text('Safe级').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#22c55e')
                      Text('容易理解和收容的异常。Safe不等于无害，而是表示可预测且容易控制。')
                        .fontSize(11).fontColor($r('app.color.text_primary'))
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  }.alignItems(VerticalAlign.Top)
                  .padding(8)
                  .backgroundColor('#1022c55e')
                  .border({ width: 1, color: '#2022c55e', radius: 6 })

                  // Euclid级
                  Row({ space: 8 }) {
                    Circle({ width: 12, height: 12 })
                      .fill('#eab308')
                    Column({ space: 2 }) {
                      Text('Euclid级').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#eab308')
                      Text('需要复杂程序来维持收容的异常。行为模式不完全可预测，需要更多资源监控。')
                        .fontSize(11).fontColor($r('app.color.text_primary'))
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  }.alignItems(VerticalAlign.Top)
                  .padding(8)
                  .backgroundColor('#10eab308')
                  .border({ width: 1, color: '#20eab308', radius: 6 })

                  // Keter级
                  Row({ space: 8 }) {
                    Circle({ width: 12, height: 12 })
                      .fill('#ef4444')
                    Column({ space: 2 }) {
                      Text('Keter级').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#ef4444')
                      Text('极难收容且高度危险的异常。对人类文明构成严重威胁，需要最高级别的安全措施。')
                        .fontSize(11).fontColor($r('app.color.text_primary'))
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  }.alignItems(VerticalAlign.Top)
                  .padding(8)
                  .backgroundColor('#10ef4444')
                  .border({ width: 1, color: '#20ef4444', radius: 6 })

                  // Thaumiel级
                  Row({ space: 8 }) {
                    Circle({ width: 12, height: 12 })
                      .fill('#3b82f6')
                    Column({ space: 2 }) {
                      Text('Thaumiel级').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#3b82f6')
                      Text('被基金会用来收容或对抗其他异常的特殊异常。对基金会有益的异常。')
                        .fontSize(11).fontColor($r('app.color.text_primary'))
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  }.alignItems(VerticalAlign.Top)
                  .padding(8)
                  .backgroundColor('#103b82f6')
                  .border({ width: 1, color: '#203b82f6', radius: 6 })
                }
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.alignItems(VerticalAlign.Top)
          }
          .padding({left: 10, right: 10, top: 10, bottom: 10})
          .width('100%')
          .backgroundColor('#101e1e1e')
          .border({ width: $r('app.float.border_width_normal'),
            radius: $r('app.float.border_radius_md'),
            color: '#3698d9' })

          // 重要概念
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Column() {
                Image($r('app.media.file_text'))
                  .width(14)
              }
              Column({ space: 5 }) {
                Text('重要概念').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#16B0F2')
                Column({ space: 5 }) {
                  Text('• 异常：违反已知科学定律和人类理解的现象、实体或物品')
                    .fontSize(11).fontColor($r('app.color.text_primary'))
                  Text('• SCP编号：通常为SCP-XXX格式，其中XXX是2-4位数字')
                    .fontSize(11).fontColor($r('app.color.text_primary'))
                  Text('• 交叉引用：文档中提到的其他相关SCP异常')
                    .fontSize(11).fontColor($r('app.color.text_primary'))
                  Text('• 保密性：基金会必须保持秘密以维护社会稳定')
                    .fontSize(11).fontColor($r('app.color.text_primary'))
                  Text('• 收容失效：异常脱离收容状态，可能对外界造成威胁')
                    .fontSize(11).fontColor($r('app.color.text_primary'))
                }.alignItems(HorizontalAlign.Start)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.alignItems(VerticalAlign.Top)
          }
          .padding({left: 10, right: 10, top: 10, bottom: 10})
          .width('100%')
          .backgroundColor('#101e1e1e')
          .border({ width: $r('app.float.border_width_normal'),
            radius: $r('app.float.border_radius_md'),
            color: '#16B0F2' })
        }
      }
      // .height(300)
      .layoutWeight(1)
      .width('100%')
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)

      Button('我已理解，继续下一步', { type: ButtonType.Normal })
        .fontSize(FontSizeManager.getScaledFontSize(15))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.background_primary'))
        .backgroundColor($r('app.color.primary_color'))
        .border({ radius: 8, width: 0, color: $r('app.color.border_primary') })
        .onClick(() => this.swiperController?.showNext())
        .backgroundColor('#16B0F2')
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