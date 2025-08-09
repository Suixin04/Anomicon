import { mockTales } from "../data/mockData"
import { Tale } from "../utils/types"
import { AppStorageV2 } from "@kit.ArkUI"

@ComponentV2
export struct Story {
  @Local pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, 'navStack', () => new NavPathStack())!

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
      Column({ space: 20 }) {
        Text('故事与文档')
          .fontSize(25)
          .fontWeight(FontWeight.Medium)
          .fontColor('#fff')
        Search({ placeholder: '搜索故事标题、作者或内容…' })
          .searchIcon({ src: $r('app.media.search') })
          .placeholderColor(Color.Gray)
          .placeholderFont({ size: 16, weight: FontWeight.Normal })
          .textFont({ size: 16, weight: FontWeight.Normal })
          .backgroundColor('#10717182')
          .border({ color: '#ee717182', width: 0.5 })
          .width('95%')
          .height(35)
          .borderRadius(8)
          .onSubmit(() => console.log('Searching'))

        this.title('外围文档', `${mockTales.length} 个故事`)

        ForEach(mockTales, (item: Tale, index: number) => {
          Column({ space: 15 }) {
            Text(item.title)
              .fontColor('#fff')
              .fontSize(18)
              .width('100%')
              .fontWeight(FontWeight.Bold)
            Text('作者: ' + item.author + ' • ' + item.datePublished)
              .width('100%')
              .fontColor('#a0a0a0')
              .fontSize(14)
              .margin({bottom: 10})
            Text(item.content.replace(/\n/g, ''))
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
            if (item.relatedSCPs.length) {
              Row() {
                Text('相关SCP: ')
                  .fontColor('#a0a0a0')
                  .fontSize(12)
                ForEach(item.relatedSCPs, (scp: string, index: number) => {
                  Text(index < item.relatedSCPs.length-1 ? `${scp}、` : scp)
                    .fontColor('#a0a0a0')
                    .fontSize(12)
                })
              }
              .width('100%')
            }
          }
          .border({width: 0.5, color: '#ee717182', radius: 10})
          .width('100%')
          .backgroundColor('#1e1e1e')
          .justifyContent(FlexAlign.Start)
          .padding({left: 20, right: 20, top: 30, bottom: 30})
          .onClick(() => {
            this.pathStack.pushPathByName('scpDocDetail', null, false)
          })
        })
      }
      .padding({left: 25, right: 25})
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .width('100%')
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .height('100%')
    .width('100%')
  }
}