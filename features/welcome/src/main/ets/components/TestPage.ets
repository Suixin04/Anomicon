/*
 * 测试页面
 * 用于验证WelcomePage组件是否正常工作
 */

@Component
export struct TestPage {
  build() {
    Column() {
      Text('WelcomePage测试页面')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ffffff')
        .margin({ bottom: 20 })
      
      Text('如果能看到这个页面，说明WelcomePage组件已正确集成到应用中。')
        .fontSize(16)
        .fontColor('#cccccc')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#1e1e1e')
  }
}