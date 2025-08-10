import { mockSCPs } from "../data/Data";
import { CollapsibleCard } from "../utils/CollapsibleCard";
import { ImageWithLoading, SCP } from "../utils/types";

// SCP对象详情页面构建器
@Builder
export function ObjBuilder() {
  scpObjDetail()
}

// 自定义标题构建器
@Builder
function cusTitle(scp: SCP) {
  Column({space: 10}){
    Row({space: 8}) {
      // SCP编号
      Text(scp.number)
        .fontColor('#ff4444')
        .fontSize(14)
        .fontWeight(FontWeight.Normal)
      // SCP项目等级
      Text(scp.objectClass)
        .border({radius: 5, width: 0.8, color: '#ee717182'})
        .fontWeight(FontWeight.Bold)
        .fontColor('#fff')
        .fontSize(12)
        .padding({top: 3, bottom: 3, left: 6, right: 6})
    }
    .width('100%')
    // SCP标题
    Text(scp.title)
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
  // 当前显示的SCP项目
  @Local scpItem: SCP = mockSCPs[0];

  build() {
    NavDestination() {
      Scroll() {
        Column({space: 20}) {
          Column({ space: 15 }) {
            // SCP项目图片
            // Image(this.scpItem.image)
            //   .objectFit(ImageFit.Cover)
            //   .border({width: 0.5, color: '#ee717182', radius: 10})
            ImageWithLoading({src: this.scpItem.image, imgWidth: '100%', imgHeight: '100%', imgRadius: 0})
          }
          .height(200)
          .width('100%')
          .border({width: 0.5, color: '#ee717182', radius: 10})
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
                  Text(this.scpItem.objectClass)
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
                  Text(`Series ${this.scpItem.series.toString()}`)
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
                  Text(this.scpItem.dateAdded)
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
                  ForEach(this.scpItem.tags, (tag: string, index: number) => {
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
          CollapsibleCard({title: '项目描述', content: this.scpItem.description})
          CollapsibleCard({title: '特殊收容措施', content: this.scpItem.containmentProcedures})
          if (this.scpItem.addendum) {
            CollapsibleCard({title: '附录', content: this.scpItem.addendum})
          }
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
    .title(cusTitle(this.scpItem))
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
      this.pathStack = context.pathStack;
      // 获取传递的参数
      const param = context.pathInfo.param as SCP;
      if (param) {
        this.scpItem = param;
      }
    })
  }
}