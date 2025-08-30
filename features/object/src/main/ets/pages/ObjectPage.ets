import { ObjDetailPage } from "./ObjDetailPage"
import { AppStorageV2 } from "@kit.ArkUI"
import { FontSizeData, FontSizeManager, RandomNum, SCP, scpApi, ScpListResponse, SCPSource, SeriesState,
  VibrationUtils } from "utils"
import CommonConstants from "utils/src/main/ets/constants/CommonConstants"
import { ErrorStateView, RandomExploreView, RecommendationView,
  ScpCardView,
  SearchBarView,
  SeriesSelectionView,
  SkeletonScreen,
  StatusIndicatorView,
  SubtitleView,
  Title } from "uicomponents"

@ComponentV2
export struct ObjectPage {
  /** 导航路径栈，用于页面间的跳转管理 */
  @Consumer('pageStack')pageStack: NavPathStack = new NavPathStack()
  /** 随机数生成器，用于生成每日推荐SCP项目 */
  @Local randomIdx: RandomNum = AppStorageV2.connect(RandomNum, 'dailyRand', () => new RandomNum())!
  /** 全局字体大小 */
  @Local fontSizeData: FontSizeData =
    AppStorageV2.connect(FontSizeData, 'globalFontSize', () => new FontSizeData(CommonConstants.SET_SIZE_NORMAL))!
  /** SCP数据源管理器，用于LazyForEach渲染 */
  @Local private data: SCPSource = new SCPSource()
  /** 本地缓存的SCP项目列表 */
  @Local private scpList: SCP[] = []
  /** 每日推荐的SCP项目 */
  @Local private dailyRecommendedScp: SCP | null = null
  /** 搜索结果列表 */
  @Local private searchResults: SCP[] = []
  /** 当前搜索关键词 */
  @Local private keyword: string = ''
  /** 当前页码 */
  @Local private currentPage: number = 1
  /** 是否正在加载数据 */
  @Local private isLoading: boolean = false
  /** 是否还有更多数据可加载 */
  @Local private hasMore: boolean = true
  /** 是否正在执行下拉刷新 */
  @Local private isRefreshing: boolean = false
  /** 是否正在执行搜索操作 */
  @Local private isSearching: boolean = false
  /** 是否发生加载错误 */
  @Local private loadError: boolean = false
  /** 系列状态管理对象，确保UI正确更新 */
  @Local private seriesState: SeriesState = new SeriesState()
  /** 数据总数量 */
  @Local private totalCount: number = 0
  /** 搜索防抖定时器 */
  private searchTimeout: number | null = null
  /** 滚动控制器 */
  private scroller: Scroller = new Scroller()
  /** 每页加载的数据量 */
  private readonly pageSize: number = 20

  /**
   * 计算过滤后的SCP列表
   * 根据搜索状态和系列筛选条件返回相应的数据列表
   */
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

  /**
   * 判断当前是否处于搜索模式
   */
  private get isSearchMode(): boolean {
    return this.keyword.trim() !== ''
  }

  /**
   * 获取推荐的SCP项目
   * 避免在UI构建语法中直接声明const变量
   */
  private get recommendedScp(): SCP | null {
    return this.dailyRecommendedScp;
  }

  /**
   * 组件生命周期 - 即将显示时的初始化处理
   * 检查API健康状态并并行加载初始数据和每日推荐
   */
  async aboutToAppear(): Promise<void> {
    // 初始化字体大小管理器
    await FontSizeManager.initialize(getContext(this))

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

    // 并行加载初始数据和每日推荐
    await Promise.all([
      this.loadInitialData(),
      this.loadDailyRecommendation()
    ])
  }

  build() {
    Column() {
      Title({ str: "怪谈目录", scroller: this.scroller })

      Refresh({ refreshing: this.isRefreshing }) {
        // 初始加载错误状态
        if (this.loadError && this.scpList.length === 0 && !this.isSearchMode) {
          ErrorStateView({
            onRetry: () => {
              this.isLoading = true
              this.loadError = false
              this.loadInitialData()
            }
          })
        } else {
          Scroll(this.scroller) {
            Column({ space: 20 }) {
              // 搜索框
              Row() {
                SearchBarView({
                  placeStr: '搜索 SCP 编号、名称或描述…',
                  keyword: this.keyword,
                  onSearchChange: (v: string) => {
                    this.keyword = v
                    this.debouncedSearch(v)
                  },
                  onSearchSubmit: () => {
                    this.performSearch(this.keyword)
                  }
                })
              }
              .padding({ left: 25, right: 25 })

              // 今日推荐区域
              if (!this.isSearchMode) {
                Row() {
                  RecommendationView({
                    recommendedScp: this.recommendedScp,
                    isLoading: this.isLoading,
                    onRecommendationClick: (scp: SCP) => {
                      this.pageStack.pushPathByName('objDetailPage', scp, false)
                    }
                  })
                }
                .padding({ left: 25, right: 25 })
                .width('100%')
              }

              // 随机探索按钮
              if (!this.isSearchMode) {
                Row() {
                  RandomExploreView({
                    onRandomExplore: async () => {
                      // 生成1-8999范围内的随机数
                      const randomId = Math.floor(Math.random() * 8999) + 1

                      try {
                        // 通过API获取随机SCP详情
                        const randomScp = await scpApi.getScpDetail(randomId.toString())
                        if (randomScp) {
                          this.pageStack.pushPathByName('objDetailPage', randomScp, false)
                        } else {
                          // 如果API获取失败，尝试从当前列表中随机选择作为降级处理
                          if (this.scpList.length > 0) {
                            const randomIndex = Math.floor(Math.random() * this.scpList.length)
                            this.pageStack.pushPathByName('objDetailPage', this.scpList[randomIndex], false)
                          }
                        }
                      } catch (error) {
                        console.error('随机探索失败:', error)
                        // 发生错误时降级到本地列表随机选择
                        if (this.scpList.length > 0) {
                          const randomIndex = Math.floor(Math.random() * this.scpList.length)
                          this.pageStack.pushPathByName('objDetailPage', this.scpList[randomIndex], false)
                        }
                      }
                    }
                  })
                }
                .padding({ left: 25, right: 25 })
                .width('100%')
              }

              // 系列选择组件
              SeriesSelectionView({
                selectedSeries: this.seriesState.value,
                onSeriesSelect: async (series: number) => {
                  this.seriesState.value = series

                  // 在搜索模式下，系列选择仅作为过滤器，不清空搜索关键词
                  if (this.isSearchMode) {
                    // 搜索模式下只更新数据源以应用系列过滤
                    this.updateDataSource()
                  } else {
                    // 非搜索模式下清空搜索关键词并重新加载数据
                    this.keyword = ''
                    await this.loadSeriesData()
                  }
                }
              })

              // 档案标题
              Row() {
                SubtitleView({
                  fixText: 'SCP档案',
                  varText: `${this.totalCount} 个项目`
                })
              }
              .padding({ left: 25, right: 25 })
              .width('100%')

              // 初始加载时显示骨架屏
              if (this.isLoading && this.scpList.length === 0 && !this.isSearchMode && !this.loadError) {
                Row() {
                  SkeletonScreen({ visible: true, itemCount: 5 })
                }
                .padding({ left: 25, right: 25 })
                .width('100%')
              }

              // 搜索状态指示器
              if (this.isSearching) {
                Row() {
                  StatusIndicatorView({
                    type: 'searching',
                    message: '搜索中...'
                  })
                }
                .padding({ left: 25, right: 25 })
                .width('100%')
              }

              // 搜索无结果提示
              if (this.isSearchMode && !this.isSearching && this.filteredScpList.length === 0) {
                Row() {
                  StatusIndicatorView({
                    type: 'noResults',
                    message: '没有找到匹配的SCP，试试其他关键词。'
                  })
                }
                .padding({ left: 25, right: 25 })
                .width('100%')
              }

              // SCP列表
              LazyForEach(this.data, (item: SCP) => {
                Row() {
                  ScpCardView({
                    item: item,
                    onCardClick: (clickedItem: SCP) => {
                      this.pageStack.pushPathByName('objDetailPage', clickedItem, false)
                    }
                  })
                }
                .padding({ left: 25, right: 25 })
                .width('100%')
              }, (item: SCP) => item.id)

              // 加载状态指示器
              if (this.isLoading && !this.isRefreshing && !this.isSearchMode) {
                Row() {
                  StatusIndicatorView({
                    type: 'loading',
                    message: '加载中...'
                  })
                }
                .padding({ left: 25, right: 25 })
                .width('100%')
              }

              // 没有更多数据提示
              if (!this.hasMore && this.data.totalCount() > 0 && !this.isSearchMode) {
                Row() {
                  StatusIndicatorView({
                    type: 'noMore',
                    message: '已加载全部数据'
                  })
                }
                .padding({ left: 25, right: 25 })
                .width('100%')
              }
            }
            .padding({ bottom: 25 })
            .width('100%')
          }
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Off)
          .onScrollEdge((side: Edge) => {
            if (side === Edge.Bottom) {
              this.loadMoreData()
            }
          })
          .layoutWeight(1)
          .width('100%')
        }
      }
      .onRefreshing(() => {
        this.onRefresh()
      })
    }
    .height('100%')
    .width('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  /**
   * 根据当前日期生成固定的每日推荐ID
   * 确保同一天内推荐的SCP项目保持一致
   */
  private getDailyRecommendedId(): number {
    // 获取当前日期的年月日
    const today = new Date();
    const year = today.getFullYear();
    const month = today.getMonth() + 1; // getMonth() 返回 0-11，需要加1
    const day = today.getDate();

    // 使用年月日组合作为种子生成固定ID（1-9999范围）
    const seed = year * 10000 + month * 100 + day;
    const id = (seed % 8999) + 1; // 确保在1-9999范围内

    return id;
  }

  /**
   * 加载每日推荐SCP项目
   * 如果推荐的SCP不存在，会自动尝试其他随机项目
   */
  private async loadDailyRecommendation(): Promise<void> {
    try {
      let recommendedId = this.getDailyRecommendedId();
      let attempts = 0;
      const maxAttempts = 10; // 最多尝试10次

      while (attempts < maxAttempts) {
        try {
          const scpDetail = await scpApi.getScpDetail(`SCP-${recommendedId.toString().padStart(3, '0')}`);
          if (scpDetail) {
            this.dailyRecommendedScp = scpDetail;
            return;
          }
        } catch (error) {
          console.log(`SCP-${recommendedId.toString().padStart(3, '0')} 不存在，尝试下一个`);
        }

        // 如果当前ID对应的SCP不存在，生成新的随机ID
        recommendedId = Math.floor(Math.random() * 9999) + 1;
        attempts++;
      }

      console.warn('无法找到有效的每日推荐SCP');
      this.dailyRecommendedScp = null;
    } catch (error) {
      console.error('加载每日推荐失败:', error);
      this.dailyRecommendedScp = null;
    }
  }

  /**
   * 加载初始数据
   * 根据当前选择的系列加载第一页数据
   */
  private async loadInitialData(): Promise<void> {
    try {
      // 根据当前选择的系列加载数据
      const series = this.seriesState.value > 0 ? this.seriesState.value : undefined
      const response: ScpListResponse = await scpApi.getScpList(this.pageSize, 1, series)

      if (response.data.length > 0) {
        this.scpList = response.data
        this.totalCount = response.total
        this.currentPage = 1
        this.hasMore = response.data.length === this.pageSize
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

  /**
   * 下拉刷新处理
   * 根据当前模式（搜索/普通）执行相应的刷新操作
   */
  private async onRefresh(): Promise<void> {
    // 刷新开始时的振动反馈
    VibrationUtils.refreshStart()

    this.isRefreshing = true
    try {
      if (this.isSearchMode) {
        // 搜索模式下的刷新
        await this.performSearch(this.keyword)
      } else {
        // 普通模式下的刷新
        this.currentPage = 1
        this.hasMore = true
        const response: ScpListResponse =
          await scpApi.getScpList(this.pageSize, 1, this.seriesState.value > 0 ? this.seriesState.value : undefined)
        if (response.data.length > 0) {
          this.scpList = response.data
          this.totalCount = response.total
          this.hasMore = response.data.length === this.pageSize
          // 更新数据源（只调用一次）
          this.updateDataSource()
        }
      }

      // 刷新成功完成时的振动反馈
      VibrationUtils.refreshComplete()
    } catch (error) {
      console.error('刷新失败:', error)
      // 刷新失败时的警告振动
      VibrationUtils.warningFeedback()
    } finally {
      this.isRefreshing = false
    }
  }

  /**
   * 加载更多数据（分页加载）
   * 仅在非搜索模式下有效
   */
  private async loadMoreData(): Promise<void> {
    if (this.isLoading || !this.hasMore || this.isSearchMode) {
      return
    }

    this.isLoading = true
    try {
      const nextPage = this.currentPage + 1
      const response: ScpListResponse = await scpApi.getScpList(this.pageSize, nextPage,
        this.seriesState.value > 0 ? this.seriesState.value : undefined)

      if (response.data.length > 0) {
        // 追加新数据到现有列表
        this.scpList = [...this.scpList, ...response.data]
        this.totalCount = response.total
        this.currentPage = nextPage
        this.hasMore = response.data.length === this.pageSize

        // 将新数据添加到数据源
        response.data.forEach(item => this.data.pushData(item))
      } else {
        this.hasMore = false
      }
    } catch (error) {
      console.error('加载更多数据失败:', error)
    } finally {
      this.isLoading = false
    }
  }

  /**
   * 系列切换时的数据加载
   * 避免全页面刷新，仅更新列表数据
   */
  private async loadSeriesData(): Promise<void> {
    try {
      const series = this.seriesState.value > 0 ? this.seriesState.value : undefined
      const response: ScpListResponse = await scpApi.getScpList(this.pageSize, 1, series)
      // 不清空列表与不切换全局 isLoading，避免顶层骨架/整页刷新
      this.scpList = response.data
      this.totalCount = response.total
      this.currentPage = 1
      this.hasMore = response.data.length === this.pageSize
      // 只更新懒加载数据源
      this.updateDataSource()
    } catch (e) {
      console.error('切换系列加载失败:', e)
    }
  }

  /**
   * 带防抖的搜索方法
   * 避免频繁的API调用，提升用户体验
   */
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

  /**
   * 执行API搜索操作
   * @param keyword 搜索关键词
   */
  private async performSearch(keyword: string): Promise<void> {
    if (!keyword || keyword.trim() === '') {
      this.searchResults = []
      this.updateDataSource()
      return
    }

    this.isSearching = true
    try {
      const results =
        await scpApi.searchScp(keyword.trim(), 50, this.seriesState.value > 0 ? this.seriesState.value : undefined)
      this.searchResults = results
    } catch (error) {
      console.error('搜索失败:', error)
      this.searchResults = []
    } finally {
      this.isSearching = false
      this.updateDataSource()
    }
  }

  /**
   * 更新LazyForEach数据源
   * 根据当前筛选条件更新显示的数据列表
   */
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
}