import { AppStorageV2 } from "@kit.ArkUI"

@ComponentV2
export struct Favourite {
  @Local pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, 'navStack', () => new NavPathStack())!

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Text('我的收藏')
          .fontSize(25)
          .fontWeight(FontWeight.Medium)
          .fontColor('#fff')
          .margin({bottom: 40})

        Column({ space: 15 }) {
          Text('💝')
            .fontSize(50)
          Text('暂无收藏')
            .fontSize(18)
            .fontColor('#fff')
            .fontWeight(FontWeight.Bold)
          Text('浏览SCP档案并点击❤️来添加到收藏夹')
            .fontSize(14)
            .fontColor('#a0a0a0')
        }
        .border({width: 0.5, color: '#ee717182', radius: 10})
        .width('100%')
        .backgroundColor('#1e1e1e')
        .padding({left: 20, right: 20, top: 50, bottom: 50})
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