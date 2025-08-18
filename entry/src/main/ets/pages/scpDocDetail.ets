import { mockSCPs, mockTales } from "../data/Data";
import { Tale } from "../utils/types";
import { CollapsibleCard } from "../utils/CollapsibleCard";

// SCP文档详情页面构建器
@Builder
export function DocBuilder() {
  scpDocDetail()
}

// 自定义标题构建器
@Builder
function cusTitle(tale: Tale) {
  Column({space: 10}){
    // 文档标题
    Text(tale.title)
      .fontColor('#fff')
      .fontSize(18)
      .width('100%')
      .fontWeight(FontWeight.Bold)
    // 作者和发布日期信息
    Text('作者: ' + tale.author + ' • ' + tale.datePublished)
      .width('100%')
      .fontColor('#a0a0a0')
      .fontSize(14)
      .margin({bottom: 10})
    }
    .width('100%')
    .margin({left: 10})
    .alignItems(HorizontalAlign.Start)
    .height('100%')
}

// SCP文档详情页面组件
@Entry
@ComponentV2
struct scpDocDetail {
  // 导航路径栈，用于页面导航
  pathStack: NavPathStack = new NavPathStack();
  // 当前显示的故事对象，默认为第一个故事
  @Local tale: Tale = mockTales[0];

  // 构建标签和相关信息的内容
  private buildTagsAndRelatedContent(): string[] {
    const content: string[] = [];
    
    // 添加标签信息
    if (this.tale.tags && this.tale.tags.length > 0) {
      content.push('标签: ' + this.tale.tags.join(', '));
    }
    
    // 添加相关SCP信息
    if (this.tale.relatedSCPs && this.tale.relatedSCPs.length > 0) {
      content.push('相关SCP: ' + this.tale.relatedSCPs.join(', '));
    }
    
    return content;
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({space: 20}) {
          // 使用CollapsibleCard显示文档内容
          CollapsibleCard({title: '文档内容', content: this.tale.content})
          // 使用CollapsibleCard显示标签和相关信息
          CollapsibleCard({
            title: '标签与相关信息',
            content: this.buildTagsAndRelatedContent()
          })
        }
        .padding({left: 25, right: 25, top: 25})
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
        .width('100%')
      }
      .border({width: {top: 0.5}, color: '#ee717182'})
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
    }
    .title(cusTitle(this.tale))
    .backgroundColor('#121212')
    .backButtonIcon($r("app.media.arrow_left"))
    // 页面准备就绪时的回调处理
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      // 获取传递的参数
      const param = context.pathInfo.param as Tale
      if (param) {
        this.tale = param
      }
    })
  }
}