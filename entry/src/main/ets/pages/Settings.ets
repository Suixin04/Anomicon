import { VERSION_NAME } from "BuildProfile"

// 设置页面组件
@ComponentV2
export struct Settings {
  build() {
    Scroll() {
      Column({ space: 20 }) {
        // 页面标题
        Text('设置')
          .fontSize(25)
          .fontWeight(FontWeight.Medium)
          .fontColor('#fff')
          .margin({bottom: 40})
        Column({ space: 15 }) {
          Row({space: 10}) {
            Image($r("app.media.circle_alert"))
              .width(18)
            Text('关于应用')
              .fontSize(16)
              .fontColor('#fff')
              .fontWeight(FontWeight.Bold)
          }
          .width('100%')
          .margin({bottom: 10})
          // 应用版本信息
          Row() {
            Text('应用版本:')
              .fontColor('#a0a0a0')
              .fontSize(14)
            Text(VERSION_NAME)
              .fontColor('#fff')
              .fontSize(14)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          // 数据来源信息
          Row() {
            Text('数据来源:')
              .fontColor('#a0a0a0')
              .fontSize(14)
            Text('SCP基金会 Wiki')
              .fontColor('#fff')
              .fontSize(14)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          // 开发者信息
          Row() {
            Text('开发者')
              .fontColor('#a0a0a0')
              .fontSize(14)
            Text('祟芯')
              .fontColor('#fff')
              .fontSize(14)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .border({width: {bottom: 0.5}, color: '#a0a0a0'})
          .padding({bottom: 10})
          // 版权声明
          Row() {
            Text('本应用所有SCP内容均来自SCP基金会官方Wiki， 遵循创作共用协议 (CC BY-SA 3.0)。 SCP基金会是一个创作共同体项目。')
              .fontSize(12)
              .fontColor('#a0a0a0')
          }
          .width('100%')
        }
        .border({width: 0.5, color: '#ee717182', radius: 10})
        .width('100%')
        .backgroundColor('#1e1e1e')
        .justifyContent(FlexAlign.Start)
        .padding(25)
      }
      .padding({left: 25, right: 25})
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .height('100%')
      .width('100%')
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .height('100%')
    .width('100%')
  }
}