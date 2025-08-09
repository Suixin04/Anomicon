import { Favourite } from "./Favourite"
import { Guide } from "./Guide"
import { Settings } from "./Settings"
import { Story } from "./Story"
import { AppStorageV2, curves } from "@kit.ArkUI"
import { RandomNum, TabClass } from "../utils/types"
import { mockSCPs } from "../data/mockData"

@Builder
export function homepageBuilder() {
  Homepage()
}

@Entry
@ComponentV2
struct Homepage {
  pathStack: NavPathStack = new NavPathStack();
  @Local iconSize: number = 24
  @Local currentIdx: number = 0

  @Local randomIdx: RandomNum = AppStorageV2.connect(RandomNum, 'dailyRand', () => new RandomNum())!

  tabInfo: TabClass[] = [
    { icon: $r('app.media.house'), icon_em: $r('app.media.house_em'), text: '图鉴' },
    { icon: $r('app.media.book'), icon_em: $r('app.media.book_em'), text: '故事' },
    { icon: $r('app.media.heart'), icon_em: $r('app.media.heart_em'), text: '收藏' },
    { icon: $r('app.media.settings'), icon_em: $r('app.media.settings_em'), text: '设置' },
  ]

  @Builder
  tabBuilder(item: TabClass, index: number) {
    Column({ space: 4 }) {
      if (this.currentIdx == index) {
        Image(item.icon)
          .width(index == this.currentIdx ? 26.4 : 24)
          .height(index == this.currentIdx ? 26.4 : 24)
          .fillColor('#ff4444')
      } else {
        Image(item.icon_em)
          .width(index == this.currentIdx ? 26.4 : 24)
          .height(index == this.currentIdx ? 26.4 : 24)
      }
      Text(item.text)
        .fontSize(12)
        .fontColor(this.currentIdx == index ? '#ff4444' : '#a0a0a0')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    NavDestination() {
      RelativeContainer() {
        Tabs({ barPosition: BarPosition.End }) {
          ForEach(this.tabInfo, (item: TabClass, index: number) => {
            TabContent() {
              if (index == 0) {
                Guide()
              } else if (index == 1) {
                Story()
              } else if (index == 2) {
                Favourite()
              } else if (index == 3) {
                Settings()
              }
            }
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
            .height('100%')
            .backgroundColor('#121212')
            .tabBar(this.tabBuilder(item, index))
            .linearGradient({
              colors: [
                [0x1fff4444, 0.0],
                [0x01ff4444, 0.25],
                [0x121212, 0.25],
              ]
            })
          })
        }
        .height('100%')
        .backgroundColor('#1e1e1e')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])
        .onChange((index: number) => {
          this.getUIContext()?.animateTo({ curve: curves.springMotion() }, () => {
            if (index === 0) {this.randomIdx.setNum(Math.floor(Math.random() * mockSCPs.length)); console.log(this.randomIdx.getNum().toString())}
            this.currentIdx = index
          })
        })
        .animationMode(AnimationMode.NO_ANIMATION)
      }
    }
    // .title('SCP基金会')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}
