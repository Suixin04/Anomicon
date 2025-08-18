import { ImageWithLoading, RandomNum, SCP, SCPSource } from "../utils/types"
import { AppStorageV2 } from "@kit.ArkUI"
import { scpApi } from "../utils/ScpApi"

// 标题构建器
// @Builder
@ComponentV2
struct title_cus {
  @Param fixText: string = 'SCP档案'
  @Param varText: string = '已加载 0 个项目'
  build() {
    Row() {
      Text(this.fixText)
        .fontSize(18)
        .fontColor('#fff')
      Text(this.varText)
        .fontSize(14)
        .fontColor('#fff')
    }
    .padding({top: 10})
    .justifyContent(FlexAlign.SpaceBetween)
    .width('100%')
  }
}

// SCP图鉴页面组件
@ComponentV2
export struct Guide {
  // 导航路径栈，用于页面跳转
  @Local pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, 'navStack', () => new NavPathStack())!
  // 随机数，用于生成每日推荐SCP项目
  @Local randomIdx: RandomNum = AppStorageV2.connect(RandomNum, 'dailyRand', () => new RandomNum())!

  // SCP数据源
  @Local private data: SCPSource = new SCPSource()
  // 本地缓存的当前列表
  @Local private scpList: SCP[] = []
  // 搜索关键词
  @Local private keyword: string = ''

  // 分页状态变量
  @Local private currentPage: number = 1
  @Local private isLoading: boolean = false
  @Local private hasMore: boolean = true
  @Local private isRefreshing: boolean = false
  @Local private isSearchMode: boolean = false

  // 每页加载的数据量
  private readonly pageSize: number = 20

  // 推荐项 getter（避免在 UI 语法中声明 const）
  private get recommendedScp(): SCP | null {
    if (this.scpList.length === 0) return null;
    const idx = this.randomIdx.getNum();
    if (idx < 0 || idx >= this.scpList.length) return null;
    return this.scpList[idx];
  }

  // 组件即将显示时的处理函数
  async aboutToAppear(): Promise<void> {
    await this.loadInitialData()
  }

  // 加载初始数据
  private async loadInitialData(): Promise<void> {
    console.log('[DEBUG] 开始加载初始数据...')
    this.isLoading = true
    try {
      const list = await scpApi.getScpList(this.pageSize, 1)
      console.log('[DEBUG] API 返回数据:', list.length, '条')
      
      if (list.length > 0) {
        console.log('[DEBUG] 第一条数据:', JSON.stringify(list[0]))
        this.scpList = list
        this.currentPage = 1
        this.hasMore = list.length === this.pageSize
        // 初始化每日推荐随机索引
        this.randomIdx.setNum(Math.floor(Math.random() * this.scpList.length))
        // 重新创建数据源
        this.data.setData(this.scpList)
        console.log('[DEBUG] 数据源总数:', this.data.totalCount())
      } else {
        console.error('未能从API获取到SCP列表')
        this.hasMore = false
      }
    } catch (error) {
      console.error('加载初始数据失败:', error)
      this.hasMore = false
    } finally {
      this.isLoading = false
      console.log('[DEBUG] 加载完成，isLoading:', this.isLoading, '数据源总数:', this.data.totalCount())
    }
  }

  // 下拉刷新
  private async onRefresh(): Promise<void> {
    this.isRefreshing = true
    try {
      if (this.isSearchMode) {
        // 搜索模式下的刷新
        await this.doSearch()
      } else {
        // 普通模式下的刷新
        this.currentPage = 1
        this.hasMore = true
        const list = await scpApi.getScpList(this.pageSize, 1)
        if (list.length > 0) {
          this.scpList = list
          this.hasMore = list.length === this.pageSize
          // 重新创建数据源
          this.data.setData(this.scpList)
          // 更新推荐项目
          this.randomIdx.setNum(Math.floor(Math.random() * this.scpList.length))
        }
      }
    } catch (error) {
      console.error('刷新失败:', error)
    } finally {
      this.isRefreshing = false
    }
  }

  // 加载更多数据
  private async loadMoreData(): Promise<void> {
    if (this.isLoading || !this.hasMore || this.isSearchMode) {
      return
    }

    this.isLoading = true
    try {
      const nextPage = this.currentPage + 1
      const newList = await scpApi.getScpList(this.pageSize, nextPage)
      
      if (newList.length > 0) {
        // 追加新数据到现有列表
        this.scpList = [...this.scpList, ...newList]
        this.currentPage = nextPage
        this.hasMore = newList.length === this.pageSize
        
        // 将新数据添加到数据源
        newList.forEach(item => this.data.pushData(item))
      } else {
        this.hasMore = false
      }
    } catch (error) {
      console.error('加载更多数据失败:', error)
    } finally {
      this.isLoading = false
    }
  }

  // 执行搜索
  private async doSearch(): Promise<void> {
    if (!this.keyword || this.keyword.trim() === '') {
      // 还原为初始列表
      this.isSearchMode = false
      this.currentPage = 1
      this.hasMore = true
      this.data.setData(this.scpList)
      return
    }

    this.isSearchMode = true
    this.isLoading = true
    try {
      // 搜索模式下，每次搜索获取更多结果
      const res = await scpApi.searchScp(this.keyword.trim(), 100)
      // 使用新的数据源以触发 LazyForEach 刷新
      this.data.setData(res)
      this.hasMore = false // 搜索结果不支持分页加载
    } catch (error) {
      console.error('搜索失败:', error)
    } finally {
      this.isLoading = false
    }
  }

  // 滚动事件处理
  private onScrollIndex(first: number, last: number, center: number): void {
    // 当滚动到接近底部时加载更多数据
    const totalCount = this.data.totalCount()
    if (totalCount > 0 && last >= totalCount - 3) {
      this.loadMoreData()
    }
  }

  // 自定义按钮构建器
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

  build() {
    Refresh({ refreshing: this.isRefreshing }) {
      List({space: 20}) {
        ListItem() {
          Text('SCP 基金会')
            .fontSize(25)
            .fontWeight(FontWeight.Medium)
            .fontColor('#fff')
        }
        .width('100%')

        // 搜索框
        ListItem() {
          Search({ placeholder: '搜索SCP编号、名称或描述…' })
            .searchIcon({ src: $r('app.media.search') })
            .placeholderColor(Color.Gray)
            .placeholderFont({ size: 16, weight: FontWeight.Normal })
            .textFont({ size: 16, weight: FontWeight.Normal })
            .fontColor('#fff')
            .backgroundColor('#10717182')
            .border({ color: '#ee717182', width: 0.5 })
            .width('95%')
            .height(35)
            .borderRadius(8)
            .onChange((v: string) => this.keyword = v)
            .onSubmit(async () => await this.doSearch())
        }

        // 今日推荐区域
        if (this.scpList.length > 0 && !this.isSearchMode) {
          ListItem() {
            Column({ space: 15 }) {
              Row({ space: 10 }) {
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
              .padding({ bottom: 15, top: 10 })

              Row({ space: 15 }) {
                ImageWithLoading({src: this.recommendedScp?.image, imgWidth: 80, imgHeight: 80, imgRadius: 8})
                Column({ space: 10 }) {
                  Row({ space: 8 }) {
                    Text(this.recommendedScp?.number ?? '')
                      .fontColor('#ff4444')
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                    Text(this.recommendedScp?.objectClass ?? '')
                    .border({ radius: 5, width: 0.8, color: '#ee717182' })
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#fff')
                    .fontSize(12)
                    .padding({
                      top: 3,
                      bottom: 3,
                      left: 6,
                      right: 6
                    })
                  }
                  Text(this.recommendedScp?.title ?? '')
                    .fontColor('#fff')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                  Text(this.recommendedScp?.description ?? '')
                    .fontColor('#a0a0a0')
                    .fontSize(14)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .alignItems(VerticalAlign.Top)
              .width('100%')
              .padding({ bottom: 10, left: 10, right: 10 })
              .onClick(() => {
                const rec = this.recommendedScp;
                if (rec) this.pathStack.pushPathByName('scpObjDetail', rec, false)
              })
            }
            .margin({ top: 10 })
            .padding(15)
            .width('100%')
            .backgroundColor('#22ff4444')
            .border({ radius: 10, width: 0.5, color: '#ee717182' })
          }
        }

        ListItem() {
          Row({ space: 10 }) {
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
          .padding({ top: 10, bottom: 10 })
          .onClick(() => {
            if (this.scpList.length > 0) {
              const randomIndex = Math.floor(Math.random() * this.scpList.length);
              this.pathStack.pushPathByName('scpObjDetail', this.scpList[randomIndex], false);
            }
          })
        }

        ListItem() {
          Row({ space: 10 }) {
            this.cusButton('全部', true)
            this.cusButton('Series 1', false)
          }
          .width('100%')
        }

        ListItem() {
          title_cus({fixText: 'SCP档案', varText: `已加载 ${this.data.totalCount()} 个项目`})
        }

        LazyForEach(this.data, (item: SCP) => {
          ListItem() {
            Column({space: 10}) {
              Stack({alignContent: Alignment.TopEnd}) {
                ImageWithLoading({src: item.image, imgWidth: '100%', imgHeight: 128, imgRadius: 0})
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
                    if (index <= 3) {
                      Text(index < 3 ? tag : `+${item.tags.length-3}`)
                        .backgroundColor('#ff282525')
                        .borderRadius(6)
                        .fontColor('#fff')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .padding({left: 12, right: 12, top: 5, bottom: 5})
                    }
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
            .onClick(() => {
              this.pathStack.pushPathByName('scpObjDetail', item, false)
            })
          }
        }, (item: string) => item)

        // 加载状态指示器
        if (this.isLoading && !this.isRefreshing) {
          ListItem() {
            Row({ space: 10 }) {
              LoadingProgress()
                .width(20)
                .height(20)
              Text('加载中...')
                .fontSize(14)
                .fontColor('#a0a0a0')
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding(20)
          }
        }

        // 没有更多数据提示
        if (!this.hasMore && this.data.totalCount() > 0 && !this.isSearchMode) {
          ListItem() {
            Text('已加载全部数据')
              .fontSize(14)
              .fontColor('#a0a0a0')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(20)
          }
        }
      }
      .scrollBar(BarState.Off)
      .height('100%')
      .width('100%')
      .padding({left: 25, right: 25})
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .width('100%')
      .onScrollIndex((first: number, last: number, center: number) => {
        this.onScrollIndex(first, last, center)
      })
    }
    .onRefreshing(() => {
      this.onRefresh()
    })
    // .refreshOffset(64) // removed to ensure compatibility
    // .pullToRefresh(true) // removed to ensure compatibility
  }
}