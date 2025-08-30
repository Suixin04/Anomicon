import { AppStorageV2, curves } from '@kit.ArkUI'
import { Favourite } from 'favourite'
import { ObjDetailPage, ObjectPage } from 'object'
import { Settings } from 'setting'
import { TaleDetailPage, TalePage } from 'tale'
import { FontSizeManager, RandomNum, SCP, TabClass, Tale, VibrationUtils } from 'utils'

@Entry
@ComponentV2
struct Index {
  @Provider('pageStack')pageStack: NavPathStack = new NavPathStack()

  @Builder
  Router(name: string, param?: SCP | Tale) {
    if (name === 'taleDetailPage') {
      TaleDetailPage()
    } else if (name === 'objDetailPage') {
      ObjDetailPage()
    } else if (name === 'homePage') {
      HomePage()
    }
  }

    build() {
      Navigation(this.pageStack) {}
      .navDestination(this.Router)
      .hideNavBar(true)
      .onAppear(() => {
        this.pageStack.replacePathByName('homePage', null, false)
      })
    }
  }

@ComponentV2
struct HomePage {
  @Local iconSize: number = 24
  @Local currentIdx: number = 0
  @Local randomIdx: RandomNum = AppStorageV2.connect(RandomNum, 'dailyRand', () => new RandomNum())!
  tabInfo: TabClass[] = [
    { icon: $r('app.media.house'), icon_em: $r('app.media.house_em'), text: '图鉴' },
    { icon: $r('app.media.book'), icon_em: $r('app.media.book_em'), text: '故事' },
    { icon: $r('app.media.heart_svg'), icon_em: $r('app.media.heart_em'), text: '收藏' },
    { icon: $r('app.media.settings'), icon_em: $r('app.media.settings_em'), text: '设置' },
  ]

  /**
   * 标签构建器 - 构建底部导航栏的单个标签项
   * @param item 标签配置信息
   * @param index 标签索引
   */
  @Builder
  tabBuilder(item: TabClass, index: number) {
    Column({ space: 4 }) {
      // 根据当前选中状态显示不同图标和大小
      if (this.currentIdx == index) {
        Image(item.icon)
          .width(index == this.currentIdx ? 26.4 : 24)
          .height(index == this.currentIdx ? 26.4 : 24)
          .fillColor($r('app.color.primary_color'))
      } else {
        Image(item.icon_em)
          .width(index == this.currentIdx ? 26.4 : 24)
          .height(index == this.currentIdx ? 26.4 : 24)
      }
      // 标签文字，选中时显示红色，未选中时显示灰色
      Text(item.text)
        .fontSize(FontSizeManager.getScaledFontSize(12))
        .fontColor(this.currentIdx == index ? $r('app.color.primary_color') : $r('app.color.text_secondary'))
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
                ObjectPage()
              } else if (index == 1) {
                TalePage()
              } else if (index == 2) {
                Favourite()
              } else if (index == 3) {
                Settings()
              }
            }
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
            .height('100%')
            .backgroundColor($r('app.color.background_primary'))
            .linearGradient({
              direction: GradientDirection.Bottom,
              colors: [
                [$r('app.color.gradient_start'), 0.0],
                [$r('app.color.gradient_mid'), 0.3],
                [$r('app.color.gradient_end'), 0.3]
              ]
            })
            .tabBar(this.tabBuilder(item, index))
          })
        }
        .divider({
          strokeWidth: 1,
          color: $r('app.color.border_secondary'),
        })
        .height('100%')
        .backgroundColor($r('app.color.background_secondary'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])
        .onChange((index: number) => {
          VibrationUtils.lightTap()
          this.getUIContext()?.animateTo({ curve: curves.springMotion() }, () => {
            this.currentIdx = index
          })
        })
        .animationMode(AnimationMode.NO_ANIMATION)
      }
    }
    .hideTitleBar(true)
    // .onReady((context: NavDestinationContext) => {
    //   this.pathStack = context.pathStack;
    // })
  }
}