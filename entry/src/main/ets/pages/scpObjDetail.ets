import { mockSCPs } from "../data/mockData";
import { CollapsibleCard } from "../utils/CollapsibleCard";

// SCP对象详情页面构建器
@Builder
export function ObjBuilder() {
  scpObjDetail()
}

// 自定义标题构建器
@Builder
function cusTitle() {
  Column({space: 10}){
    Row({space: 8}) {
      // SCP编号
      Text(mockSCPs[0].number)
        .fontColor('#ff4444')
        .fontSize(14)
        .fontWeight(FontWeight.Normal)
      // SCP项目等级
      Text(mockSCPs[0].objectClass)
        .border({radius: 5, width: 0.8, color: '#ee717182'})
        .fontWeight(FontWeight.Bold)
        .fontColor('#fff')
        .fontSize(12)
        .padding({top: 3, bottom: 3, left: 6, right: 6})
    }
    .width('100%')
    // SCP标题
    Text(mockSCPs[0].title)
      .fontColor('#fff')
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
  }
  .margin({left: 10})
  .alignItems(HorizontalAlign.Start)
  .height('100%')
}

// SCP对象详情页面组件
@Entry
@ComponentV2
@Preview
struct scpObjDetail {
  // 导航路径栈
  pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Scroll() {
        Column({space: 20}) {
          Column({ space: 15 }) {
            // SCP项目图片
            Image(mockSCPs[0].image)
              .objectFit(ImageFit.Cover)
              .border({width: 0.5, color: '#ee717182', radius: 10})
          }
          .height(200)
          .width('100%')
          // 项目信息网格布局
          GridRow({columns: 2}) {
            GridCol() {
              Column() {
                Row() {
                  Text('项目等级:')
                    .fontSize(14)
                    .fontColor('#a0a0a0')
                }.width('100%')
                Row() {
                  Text(mockSCPs[0].objectClass)
                    .margin({top: 5})
                    .border({radius: 5, width: 0.8, color: '#ee717182'})
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#fff')
                    .fontSize(12)
                    .padding({top: 3, bottom: 3, left: 6, right: 6})
                }
                .width('100%')
              }
              .width('100%')
            }
            GridCol({ span: 1 }) {
              Column() {
                Row() {
                  Text('系列:')
                    .fontSize(14)
                    .fontColor('#a0a0a0')
                }.width('100%')
                Row() {
                  Text(`Series ${mockSCPs[0].series.toString()}`)
                    .margin({top: 5})
                    .fontColor('#fff')
                }
                .width('100%')
              }
              .width('100%')
            }
            GridCol({ span: 1 }) {
              Column() {
                Row() {
                  Text('添加日期:')
                    .margin({top: 15})
                    .fontSize(14)
                    .fontColor('#a0a0a0')
                }.width('100%')
                Row() {
                  Text(mockSCPs[0].dateAdded)
                    .fontSize(14)
                    .margin({top: 5})
                    .fontColor('#fff')
                }
                .width('100%')
              }
              .width('100%')
            }
            GridCol({ span: 1 }) {
              Column() {
                Row() {
                  Text('标签:')
                    .margin({top: 15})
                    .fontSize(14)
                    .fontColor('#a0a0a0')
                }.width('100%')
                // 标签列表
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(mockSCPs[0].tags, (tag: string, index: number) => {
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
              }
              .width('100%')
            }
          }
          .border({width: 0.5, color: '#ee717182', radius: 10})
          .width('100%')
          .backgroundColor('#1e1e1e')
          .padding(25)

          // 可折叠的信息卡片
          CollapsibleCard({title: '项目描述', content: mockSCPs[0].description})
          CollapsibleCard({title: '特殊收容措施', content: mockSCPs[0].containmentProcedures})
          CollapsibleCard({title: '附录', content: mockSCPs[0].addendum})
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
    // 页面菜单
    .menus([
      {
        value: '分享',
        icon: ($r('app.media.heart_em')),
        action: () => {
          console.info('分享按钮点击');
        }
      },
      {
        value: '收藏',
        icon: ($r("app.media.share")),
        action: () => {
          console.info('收藏按钮点击');
        }
      }
    ])
    // 页面准备就绪时的回调处理
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;})
  }
}