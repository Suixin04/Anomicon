import { SearchBarView, StoryCardView, SubtitleView, Title } from "uicomponents"
import { SCP, Tale } from "utils"
import { mockTales } from "../data/Data"
import { ObjDetailPage } from "./ObjDetailPage"
import { TaleDetailPage } from "./TaleDetailPage"
import { PromptAction } from "@kit.ArkUI"

@ComponentV2
export struct TalePage {
  /** 导航路径栈，用于页面间的导航管理 */
  @Consumer('pageStack')pageStack: NavPathStack = new NavPathStack()
  /** 滚动控制器 */
  private scroller: Scroller = new Scroller()
  /** 当前搜索关键词 */
  @Local private keyword: string = ''

  private promptAction: PromptAction | undefined;
  aboutToAppear() {
    // 获取当前 UI 上下文的 PromptAction 实例
    this.promptAction = this.getUIContext().getPromptAction();
    this.promptAction.showToast({
      message: '开发中，敬请期待…'
    })
  }

  build() {
    Column() {
      Title({ str: "故事与文档", scroller: this.scroller })

      Scroll(this.scroller) {
        Column({ space: 20 }) {
          // 故事搜索框
          Row() {
            SearchBarView({
              placeStr: '搜索故事标题、作者或内容…',
              keyword: this.keyword,
              onSearchChange: (value: string) => {
                this.keyword = value
              },
              onSearchSubmit: () => {
                // 搜索提交逻辑
              }
            })
          }

          // 外围文档分类标题
          SubtitleView({ fixText: '外围文档', varText: `${mockTales.length} 个故事` })

          // 故事列表 - 遍历显示所有故事卡片
          ForEach(mockTales, (item: Tale, index: number) => {
            StoryCardView({
              item: item, onCardClick: (tale: Tale) => {
                // 点击故事卡片跳转到详情页面
                this.pageStack.pushPathByName('taleDetailPage', tale, false)
              }
            })
          })
        }
        .padding({ left: 25, right: 25, bottom: 25 })
        .width('100%')
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')
    }
  }
}