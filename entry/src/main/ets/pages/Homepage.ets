import { Favourite } from "./Favourite"
import { Guide } from "./Guide"
import { Settings } from "./Settings"
import { Story } from "./Story"
import { AppStorageV2, curves } from "@kit.ArkUI"
import { RandomNum, TabClass } from "../utils/types"

// 主页构建器
@Builder
export function homepageBuilder() {
  Homepage()
}

// 应用主页组件
@Entry
@ComponentV2
struct Homepage {
  // 导航路径栈，用于页面间导航
  pathStack: NavPathStack = new NavPathStack();
  // 图标大小
  @Local iconSize: number = 24
  // 当前选中的标签索引
  @Local currentIdx: number = 0

  // 随机数，用于生成每日推荐SCP项目
  @Local randomIdx: RandomNum = AppStorageV2.connect(RandomNum, 'dailyRand', () => new RandomNum())!

  // 底部标签栏信息配置
  tabInfo: TabClass[] = [
    { icon: $r('app.media.house'), icon_em: $r('app.media.house_em'), text: '图鉴' },
    { icon: $r('app.media.book'), icon_em: $r('app.media.book_em'), text: '故事' },
    { icon: $r('app.media.heart'), icon_em: $r('app.media.heart_em'), text: '收藏' },
    { icon: $r('app.media.settings'), icon_em: $r('app.media.settings_em'), text: '设置' },
  ]

  // 标签栏构建器
  @Builder
  tabBuilder(item: TabClass, index: number) {
    Column({ space: 4 }) {
      // 根据当前选中状态显示不同图标和大小
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
      // 标签文字，选中时显示红色，未选中时显示灰色
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
        // 底部标签导航栏
        Tabs({ barPosition: BarPosition.End }) {
          // 遍历标签信息，创建标签页
          ForEach(this.tabInfo, (item: TabClass, index: number) => {
            TabContent() {
              // 根据标签索引显示对应页面内容
              if (index == 0) {
                // 图鉴页面
                Guide()
              } else if (index == 1) {
                // 故事页面
                Story()
              } else if (index == 2) {
                // 收藏页面
                Favourite()
              } else if (index == 3) {
                // 设置页面
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
        // 标签切换时的回调处理
        .onChange((index: number) => {
          this.getUIContext()?.animateTo({ curve: curves.springMotion() }, () => {
            this.currentIdx = index
          })
        })
        .animationMode(AnimationMode.NO_ANIMATION)
      }
    }
    // 页面准备就绪时的回调处理
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}