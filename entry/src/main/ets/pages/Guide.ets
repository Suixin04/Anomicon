import { ImageWithLoading, RandomNum, SCP, SCPSource } from "../utils/types"
import { AppStorageV2 } from "@kit.ArkUI"
import { scpApi } from "../utils/ScpApi"
import { SkeletonScreen, RecommendationSkeleton } from "../components/SkeletonScreen"

// 系列状态类
@ObservedV2
class SeriesState {
  @Trace value: number = 0
}

// 标题构建器
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

// 自定义按钮组件
@ComponentV2
struct CustomButton {
  @Param text: string = ''
  @Param isSelected: boolean = false
  
  build() {
    Button(this.text, {type: ButtonType.Normal})
      .fontSize(14)
      .fontColor(this.isSelected ? '#000' : '#fff')
      .backgroundColor(this.isSelected ? '#ff4444' : '#10717182')
      .border({radius: 8, width: this.isSelected ? 0 : 0.5, color: '#ee717182'})
      .padding({top: 8, bottom: 8, left: 13, right: 13})
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
  // 搜索结果列表
  @Local private searchResults: SCP[] = []
  // 搜索关键词
  @Local private keyword: string = ''

  // 分页状态变量
  @Local private currentPage: number = 1
  @Local private isLoading: boolean = false
  @Local private hasMore: boolean = true
  @Local private isRefreshing: boolean = false
  @Local private isSearching: boolean = false
  @Local private loadError: boolean = false
  @Local private selectedSeries: number = 0 // 0表示全部，1-9表示对应系列
  @Local private seriesState: SeriesState = new SeriesState() // 使用对象包装确保UI更新
  private searchTimeout: number | null = null

  // 计算过滤后的SCP列表
  private get filteredScpList(): SCP[] {
    let baseList: SCP[] = []
    
    if (this.keyword && this.keyword.trim() !== '') {
      // 搜索模式下返回API搜索结果
      baseList = this.searchResults
    } else {
      // 非搜索模式下使用本地列表
      baseList = this.scpList
    }
    
    // 如果选择了特定系列，进行系列筛选
    if (this.seriesState.value > 0) {
      return baseList.filter(scp => {
        const scpNumber = parseInt(scp.number.replace('SCP-', ''))
        const seriesStart = (this.seriesState.value - 1) * 1000 + 1
        const seriesEnd = this.seriesState.value * 1000
        return scpNumber >= seriesStart && scpNumber <= seriesEnd
      })
    }
    
    return baseList
  }
  
  // 判断是否为搜索模式
  private get isSearchMode(): boolean {
    return this.keyword.trim() !== ''
  }

  // 每页加载的数据量
  private readonly pageSize: number = 20

  // 推荐项 getter（避免在 UI 语法中声明 const）
  private get recommendedScp(): SCP | null {
    if (this.scpList.length === 0) return null;
    const idx = this.getDailyRecommendedIndex();
    if (idx < 0 || idx >= this.scpList.length) return null;
    return this.scpList[idx];
  }

  // 根据当前日期生成固定的推荐索引
  private getDailyRecommendedIndex(): number {
    if (this.scpList.length === 0) return 0;
    
    // 获取当前日期的年月日
    const today = new Date();
    const year = today.getFullYear();
    const month = today.getMonth() + 1; // getMonth() 返回 0-11，需要加1
    const day = today.getDate();
    
    // 使用年月日组合作为种子生成固定索引
    const seed = year * 10000 + month * 100 + day;
    const index = seed % this.scpList.length;
    
    return index;
  }

  // 组件即将显示时的处理函数
  async aboutToAppear(): Promise<void> {
    // 立即设置加载状态，确保骨架屏能够及时显示
    this.isLoading = true
    this.loadError = false
    
    // 检查API服务器健康状态
    const isHealthy = await scpApi.checkHealth()
    if (!isHealthy) {
      console.error('[ERROR] API服务器连接失败，请确保服务器正在运行')
    } else {
      console.log('[INFO] API服务器连接正常')
    }
    
    await this.loadInitialData()
  }

  // 加载初始数据
  private async loadInitialData(): Promise<void> {
    try {
      // 根据当前选择的系列加载数据
      const series = this.seriesState.value > 0 ? this.seriesState.value : undefined
      const list = await scpApi.getScpList(this.pageSize, 1, series)
      
      if (list.length > 0) {
        this.scpList = list
        this.currentPage = 1
        this.hasMore = list.length === this.pageSize
        // 每日推荐现在基于日期固定，无需设置随机索引
        // 更新数据源（只调用一次）
        this.updateDataSource()
        this.isLoading = false
      } else {
        console.error('未能从API获取到SCP列表')
        this.hasMore = false
        this.loadError = true
        this.isLoading = false
      }
    } catch (error) {
      console.error('加载初始数据失败:', error)
      this.hasMore = false
      this.loadError = true
      // 保持isLoading为true以继续显示骨架屏，或者可以显示错误状态
    }
  }

  // 下拉刷新
  private async onRefresh(): Promise<void> {
    this.isRefreshing = true
    try {
      if (this.isSearchMode) {
        // 搜索模式下的刷新
        await this.performSearch(this.keyword)
      } else {
        // 普通模式下的刷新
        this.currentPage = 1
        this.hasMore = true
        const list = await scpApi.getScpList(this.pageSize, 1, this.seriesState.value > 0 ? this.seriesState.value : undefined)
        if (list.length > 0) {
          this.scpList = list
          this.hasMore = list.length === this.pageSize
          // 更新数据源（只调用一次）
          this.updateDataSource()
          // 推荐项目现在基于日期固定，无需更新随机索引
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
      const newList = await scpApi.getScpList(this.pageSize, nextPage, this.seriesState.value > 0 ? this.seriesState.value : undefined)
      
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

  // 新增：系列切换时仅更新懒加载列表的数据
  private async loadSeriesData(): Promise<void> {
    try {
      const series = this.seriesState.value > 0 ? this.seriesState.value : undefined
      const list = await scpApi.getScpList(this.pageSize, 1, series)
      // 不清空列表与不切换全局 isLoading，避免顶层骨架/整页刷新
      this.scpList = list
      this.currentPage = 1
      this.hasMore = list.length === this.pageSize
      // 推荐项目现在基于日期固定，无需更新随机索引
      // 只更新懒加载数据源
      this.updateDataSource()
    } catch (e) {
      console.error('切换系列加载失败:', e)
    }
  }

  // 带防抖的搜索方法
  private debouncedSearch(keyword: string): void {
    // 清除之前的定时器
    if (this.searchTimeout !== null) {
      clearTimeout(this.searchTimeout)
    }

    // 设置新的定时器
    this.searchTimeout = setTimeout(() => {
      this.performSearch(keyword)
    }, 500) // 500ms 防抖延迟
  }

  // 执行API搜索
  private async performSearch(keyword: string): Promise<void> {
    if (!keyword || keyword.trim() === '') {
      this.searchResults = []
      this.updateDataSource()
      return
    }

    this.isSearching = true
    try {
      const results = await scpApi.searchScp(keyword.trim(), 50, this.seriesState.value > 0 ? this.seriesState.value : undefined)
      this.searchResults = results
    } catch (error) {
      console.error('搜索失败:', error)
      this.searchResults = []
    } finally {
      this.isSearching = false
      this.updateDataSource()
    }
  }

  // 更新数据源
  private updateDataSource(): void {
    const filteredData = this.filteredScpList
    this.data.setData(filteredData)
    
    // 搜索模式下不支持分页加载
    if (this.isSearchMode) {
      this.hasMore = false
    } else {
      // 非搜索模式下恢复分页状态
      this.hasMore = this.scpList.length >= this.currentPage * this.pageSize
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
            .onChange((v: string) => {
              this.keyword = v
              // 使用防抖搜索
              this.debouncedSearch(v)
            })
            .onSubmit(() => {
              // 提交时立即执行搜索
              this.performSearch(this.keyword)
            })
        }
        .width('100%')

        // 初始加载错误状态
        if (this.loadError && this.scpList.length === 0 && !this.isSearchMode) {
          ListItem() {
            Column({ space: 15 }) {
              Text('加载失败')
                .fontSize(18)
                .fontColor('#ff4444')
                .fontWeight(FontWeight.Medium)
              
              Text('无法连接到服务器，请检查网络连接或稍后重试')
                .fontSize(14)
                .fontColor('#a0a0a0')
                .textAlign(TextAlign.Center)
                .maxLines(2)
              
              Button('重试')
                .fontSize(16)
                .fontColor('#fff')
                .backgroundColor('#ff4444')
                .borderRadius(8)
                .padding({ left: 30, right: 30, top: 10, bottom: 10 })
                .onClick(() => {
                  this.loadError = false
                  this.loadInitialData()
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 50 })
          }
        }

        // 今日推荐区域
        if (!this.isSearchMode) {
          ListItem() {
            if (this.isLoading && !this.recommendedScp) {
              // 显示推荐区域骨架屏
              RecommendationSkeleton({ visible: true })
            } else {
              // 显示实际推荐内容
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
                  ImageWithLoading({src: this.recommendedScp?.image, imgWidth: 80, imgHeight: 80, imgRadius: {topLeft: 8, topRight: 8, bottomLeft: 8, bottomRight: 8}})
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
        }

        if (!this.isSearchMode) {
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
        }

        ListItem() {
          Scroll() {
            Row({ space: 10 }) {
              Row() {
                CustomButton({ text: '全部', isSelected: this.seriesState.value === 0 })
              }
              .onClick(async () => {
                  this.seriesState.value = 0
                  // 退出搜索模式
                  this.keyword = ''
                  // 在后台加载新系列数据
                  await this.loadSeriesData()
                })
              
              ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9], (series: number) => {
                Row() {
                  CustomButton({ text: `Series ${series}`, isSelected: this.seriesState.value === series })
                }
                .onClick(async () => {
                  this.seriesState.value = series
                  // 退出搜索模式
                  this.keyword = ''
                  // 在后台加载新系列数据，仅更新懒加载组件
                  await this.loadSeriesData()
                })
              }, (series: number) => series.toString())
            }
            .padding({ left: 5, right: 5 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
        }

        ListItem() {
          title_cus({fixText: 'SCP档案', varText: `已加载 ${this.data.totalCount()} 个项目`})
        }

        // 初始加载时显示骨架屏
        if (this.isLoading && this.scpList.length === 0 && !this.isSearchMode && !this.loadError) {
          ListItem() {
            SkeletonScreen({ visible: true, itemCount: 5 })
          }
        }

        LazyForEach(this.data, (item: SCP) => {
          ListItem() {
            Column({space: 10}) {
              Stack({alignContent: Alignment.TopEnd}) {
                ImageWithLoading({src: item.image, imgWidth: '100%', imgHeight: 128, imgRadius: {topLeft: 10, topRight: 10}})
                Text(item.objectClass)
                  .margin({top: 10, right: 10})
                  .border({radius: 5, width: 0.8, color: '#ee717182'})
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#fff')
                  .fontSize(12)
                  .padding({top: 3, bottom: 3, left: 6, right: 6})
              }
              .borderRadius(10)
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
        }, (item: SCP) => item.id)

        // 搜索状态指示器
        if (this.isSearching) {
          ListItem() {
            Row({ space: 10 }) {
              LoadingProgress()
                .width(20)
                .height(20)
              Text('搜索中...')
                .fontSize(14)
                .fontColor('#a0a0a0')
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding(20)
          }
        }

        // 搜索无结果提示
        if (this.isSearchMode && !this.isSearching && this.filteredScpList.length === 0) {
          ListItem() {
            Text('没有找到匹配的SCP，试试其他关键词。')
              .fontSize(14)
              .fontColor('#a0a0a0')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(20)
          }
        }

        // 加载状态指示器
        if (this.isLoading && !this.isRefreshing && !this.isSearchMode) {
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
