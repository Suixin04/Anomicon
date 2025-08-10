import { mockSCPs, mockTales } from "../data/mockData";

// SCP文档详情页面构建器
@Builder
export function DocBuilder() {
  scpDocDetail()
}

// 自定义标题构建器
@Builder
function cusTitle() {
  Column({space: 10}){
    // 文档标题
    Text(mockTales[0].title)
      .fontColor('#fff')
      .fontSize(18)
      .width('100%')
      .fontWeight(FontWeight.Bold)
    // 作者和发布日期信息
    Text('作者: ' + mockTales[0].author + ' • ' + mockTales[0].datePublished)
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
  // 导航路径栈
  pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Scroll() {
        Column({space: 20}) {
          Column({ space: 15 }) {
            // 文档内容
            Text(mockTales[0].content)
              .fontSize(14)
              .fontColor('#fff')
          }
          .border({width: 0.5, color: '#ee717182', radius: 10})
          .width('100%')
          .backgroundColor('#1e1e1e')
          .justifyContent(FlexAlign.Start)
          .padding({left: 20, right: 20, top: 30, bottom: 30})
          Column({ space: 5 }) {
            Row() {
              Text('标签:')
                .fontSize(14)
                .fontColor('#a0a0a0')
            }
            .width('100%')
            // 标签列表
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(mockTales[0].tags, (tag: string, index: number) => {
                Text(tag)
                  .backgroundColor('#ff282525')
                  .borderRadius(6)
                  .fontColor('#fff')
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .padding({left: 6, right: 6, top: 5, bottom: 5})
                  .margin({right: 3, bottom: 3})
              })
            }
            .width('100%')
            .margin({bottom: 10})
            Row() {
              Text('相关SCP:')
                .fontSize(14)
                .fontColor('#a0a0a0')
            }
            .width('100%')
            // 相关SCP项目列表
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(mockTales[1].relatedSCPs, (scp: string, index: number) => {
                Row({space: 5}) {
                  Text(scp)
                    .fontColor('#fff')
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                  Image($r('app.media.outer_link'))
                    .width(12)
                }
                .backgroundColor('#ff282525')
                .borderRadius(6)
                .padding({left: 6, right: 6, top: 5, bottom: 5})
                .margin({right: 3, bottom: 3})
              })
            }
            .width('100%')
          }
          .border({width: 0.5, color: '#ee717182', radius: 10})
          .width('100%')
          .backgroundColor('#1e1e1e')
          .justifyContent(FlexAlign.Start)
          .padding({left: 20, right: 20, top: 30, bottom: 30})
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
    .title(cusTitle)
    .backgroundColor('#121212')
    .backButtonIcon($r("app.media.arrow_left"))
    // 页面准备就绪时的回调处理
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;})
  }
}