import { VERSION_NAME } from "BuildProfile"

// 设置页面组件
@ComponentV2
export struct Settings {
  build() {
    // 创建可滚动的页面布局
    Scroll() {
      // 主要内容容器，设置整体间距
      Column({ space: 20 }) {
        // 页面标题
        Text('设置')
          .fontSize(25)
          .fontWeight(FontWeight.Medium)
          .fontColor('#fff')
          .margin({bottom: 40}) // 标题底部边距
        
        // 设置项容器，设置内部元素间距
        Column({ space: 15 }) {
          // 关于应用设置项
          Row({space: 10}) {
            // 警告图标
            Image($r("app.media.circle_alert"))
              .width(18)
            // 标题文本
            Text('关于应用')
              .fontSize(16)
              .fontColor('#fff')
              .fontWeight(FontWeight.Bold)
          }
          .width('100%') // 设置项宽度
          .margin({bottom: 10}) // 底部边距
        
          // 应用版本信息
          Row() {
            // 版本标签
            Text('应用版本:')
              .fontColor('#a0a0a0')
              .fontSize(14)
            // 版本号
            Text(VERSION_NAME)
              .fontColor('#fff')
              .fontSize(14)
          }
          .width('100%') // 版本信息宽度
          .justifyContent(FlexAlign.SpaceBetween) // 两端对齐
        
          // 数据来源信息
          Row() {
            // 数据来源标签
            Text('数据来源:')
              .fontColor('#a0a0a0')
              .fontSize(14)
            // 数据来源名称
            Text('SCP基金会 Wiki')
              .fontColor('#fff')
              .fontSize(14)
          }
          .width('100%') // 数据来源宽度
          .justifyContent(FlexAlign.SpaceBetween) // 两端对齐
        
          // 开发者信息
          Row() {
            // 开发者标签
            Text('开发者')
              .fontColor('#a0a0a0')
              .fontSize(14)
            // 开发者姓名
            Text('祟芯')
              .fontColor('#fff')
              .fontSize(14)
          }
          .width('100%') // 开发者信息宽度
          .justifyContent(FlexAlign.SpaceBetween) // 两端对齐
          .border({width: {bottom: 0.5}, color: '#a0a0a0'}) // 底部边框
          .padding({bottom: 10}) // 底部内边距
        
          // 版权声明
          Row() {
            // 版权声明文本
            Text('本应用所有SCP内容均来自SCP基金会官方Wiki， 遵循创作共用协议 (CC BY-SA 3.0)。 SCP基金会是一个创作共同体项目。')
              .fontSize(12)
              .fontColor('#a0a0a0')
          }
          .width('100%') // 版权声明宽度
        }
        // 容器样式设置
        .border({width: 0.5, color: '#ee717182', radius: 10}) // 边框
        .width('100%') // 宽度
        .backgroundColor('#1e1e1e') // 背景色
        .justifyContent(FlexAlign.Start) // 内容顶部对齐
        .padding(25) // 内边距
      }
      // 页面布局样式设置
      .padding({left: 25, right: 25}) // 左右边距
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP]) // 扩展安全区域
      .height('100%') // 高度
      .width('100%') // 宽度
    }
    // 滚动设置
    .scrollable(ScrollDirection.Vertical) // 垂直滚动
    .scrollBar(BarState.Off) // 关闭滚动条
    .height('100%') // 高度
    .width('100%') // 宽度
  }
}