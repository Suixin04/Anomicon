import { mockSCPs } from "../data/mockData"
import { RandomNum, SCP } from "../utils/types"
import { AppStorageV2 } from "@kit.ArkUI"

@ComponentV2
export struct Guide {
  @Local pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, 'navStack', () => new NavPathStack())!
  @Local randomIdx: RandomNum = AppStorageV2.connect(RandomNum, 'dailyRand', () => new RandomNum())!

  @Builder
  cusButton (text:string, isSelected: boolean, image?:ResourceStr | string) {
    Row({space: 10}) {
      if (image) {
        Image(image)
          .width(14)
      }
      Text(text)
        .fontSize(14)
        .fontColor(isSelected ? '#000' : '#fff')
    }
    .backgroundColor(isSelected? '#ff4444' : '#10717182')
    .border({radius: 8, width: isSelected ? 0 : 0.5, color: '#ee717182'})
    .justifyContent(FlexAlign.Center)
    .padding({top: 8, bottom: 8, left: 13, right: 13})
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  title (fixText: string, varText: string) {
    Row() {
      Text(fixText)
        .fontSize(18)
        .fontColor('#fff')
      Text(varText)
        .fontSize(14)
        .fontColor('#fff')
    }
    .padding({top: 10})
    .justifyContent(FlexAlign.SpaceBetween)
    .width('100%')
  }

  build() {
    Scroll() {
      Column({space: 20}) {
        Text('SCP 基金会')
          .fontSize(25)
          .fontWeight(FontWeight.Medium)
          .fontColor('#fff')
        Search({placeholder: '搜索SCP编号、名称或描述…'})
          .searchIcon({src: $r('app.media.search')})
          .placeholderColor(Color.Gray)
          .placeholderFont({ size: 16, weight: FontWeight.Normal })
          .textFont({ size: 16, weight: FontWeight.Normal })
          .backgroundColor('#10717182')
          .border({color: '#ee717182', width: 0.5})
          .width('95%')
          .height(35)
          .borderRadius(8)
          .onSubmit(() => console.log('Searching'))

        // 今日推荐
        Column({space: 15}) {
          Row({space: 10}) {
            Image($r('app.media.star'))
              .fillColor('#ffddb333')
              .width(20)
            Text('今日推荐 SCP')
              .fontSize(18)
              .fontColor('#fff')
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .padding({bottom: 15, top: 10})
          // this.dailyCard(mockSCPs[this.randomIdx.getNum()])  // 不刷新！无法追踪内部状态！
          // dailyCard
          // TODO: 详情页跳转
          Row({space: 15}) {
            Image(mockSCPs[this.randomIdx.getNum()].image)
              .width(80)
              .height(80)
              .borderRadius(8)
            // .height()
            Column({space: 10}) {
              Row({space: 8}) {
                Text(mockSCPs[this.randomIdx.getNum()].number)
                  .fontColor('#ff4444')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                Text(mockSCPs[this.randomIdx.getNum()].objectClass)
                  .border({radius: 5, width: 0.8, color: '#ee717182'})
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#fff')
                  .fontSize(12)
                  .padding({top: 3, bottom: 3, left: 6, right: 6})
              }
              Text(mockSCPs[this.randomIdx.getNum()].title)
                .fontColor('#fff')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
              Text(mockSCPs[this.randomIdx.getNum()].description)
                .fontColor('#a0a0a0')
                .fontSize(14)
                .maxLines(2)
                .textOverflow({overflow: TextOverflow.Ellipsis})
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .alignItems(VerticalAlign.Top)
          .width('100%')
          // .onClick(() => console.log('random SCP_objs'))
          .padding({ bottom: 10 , left: 10, right: 10})
          .onClick(() => {
            this.pathStack.pushPathByName('scpObjDetail', null, false)
          })
        }
        .margin({top: 10})
        .padding(15)
        .width('100%')
        .backgroundColor('#22ff4444')
        .border({radius: 10, width: 0.5, color: '#ee717182'})

        // 随机访问
        // TODO: 详情页跳转
        Row({space: 10}) {
          Image($r('app.media.shuffle'))
            .width(14)
          Text('随机探索 SCP')
            .fontSize(14)
            .fontColor('#000')
        }
        .backgroundColor('#ff4444')
        .borderRadius(8)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({top: 10, bottom: 10})

        // 系列按钮
        Row({space: 10}) {
          this.cusButton('全部', true)
          this.cusButton('Series 1', false)
        }
        .width('100%')
        this.title('SCP档案', `${mockSCPs.length} 个项目`)

        ForEach(mockSCPs, (item: SCP, index: number) => {
          Column({space: 10}) {
            Stack({alignContent: Alignment.TopEnd}) {
              Image(item.image)
                .width('100%')
                .height(128)
                .objectFit(ImageFit.Cover)
              Text(item.objectClass)
                .margin({top: 10, right: 10})
                .border({radius: 5, width: 0.8, color: '#ee717182'})
                .fontWeight(FontWeight.Bold)
                .fontColor('#fff')
                .fontSize(12)
                .padding({top: 3, bottom: 3, left: 6, right: 6})
            }
            .width('100%')
            Column({space: 15}) {
              Row({space: 5}) {
                Text(item.number)
                  .fontColor('#ff4444')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                Text(`Series ${item.series.toString()}`)
                  .fontColor('#a0a0a0')
                  .fontSize(12)
              }
              .width('100%')
              Text(item.title)
                .fontColor('#fff')
                .fontSize(18)
                .width('100%')
                .fontWeight(FontWeight.Bold)
              Text(item.description)
                .width('100%')
                .fontColor('#a0a0a0')
                .fontSize(14)
                .maxLines(3)
                .textOverflow({overflow: TextOverflow.Ellipsis})
              Row({space: 8}) {
                ForEach(item.tags, (tag: string, index: number) => {
                  Text(index < 3 ? tag : `+${item.tags.length-3}`)
                    .backgroundColor('#ff282525')
                    .borderRadius(6)
                    .fontColor('#fff')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .padding({left: 12, right: 12, top: 5, bottom: 5})
                })
              }.width('100%')
            }
            .width('100%')
            .padding({left: 20, right: 20, top: 30, bottom: 30})
          }
          .width('100%')
          .backgroundColor('#1e1e1e')
          .justifyContent(FlexAlign.Start)
          .border({radius: 10, width: 0.5, color: '#ee717182'})
        })
      }
      .padding({left: 25, right: 25})
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .width('100%')
      // .height('100%')
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .height('100%')
    .width('100%')
  }
}