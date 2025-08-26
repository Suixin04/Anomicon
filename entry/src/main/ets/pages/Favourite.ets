import { AppStorageV2 } from "@kit.ArkUI"
import { FavoriteService } from '../common/service/FavoriteService'
import { FavoriteItem } from '../viewmodel/FavoriteItem'
import { promptAction } from '@kit.ArkUI'
import { SCP, Tale } from '../utils/types'

// 收藏页面组件
@ComponentV2
export struct Favourite {
  // 导航路径栈，用于页面跳转
  @Local pathStack: NavPathStack = AppStorageV2.connect(NavPathStack, 'navStack', () => new NavPathStack())!
  // 收藏列表
  @Local favoriteItems: FavoriteItem[] = []
  // 加载状态
  @Local isLoading: boolean = true
  // 当前选择的类型过滤器
  @Local selectedType: string = 'ALL' // 'ALL', 'SCP', 'TALE'

  // 取消收藏变更订阅的函数
  private unsubscribeFavoriteChange?: () => void;

  // 页面即将显示：初始化服务并订阅收藏变更
  async aboutToAppear(): Promise<void> {
    // 确保服务已初始化
    await FavoriteService.initialize(getContext(this));
    // 初始化完成后加载数据
    await this.loadFavorites();
    // 防止重复订阅
    this.unsubscribeFavoriteChange?.();
    this.unsubscribeFavoriteChange = FavoriteService.getInstance().addChangeListener(() => {
      // 任意页面收藏状态变更时，刷新当前列表
      this.loadFavorites();
    });
  }

  // 页面将被销毁：取消订阅，避免内存泄漏
  aboutToBeDeleted(): void {
    this.unsubscribeFavoriteChange?.();
    this.unsubscribeFavoriteChange = undefined;
  }

  // 加载收藏列表
  private async loadFavorites(): Promise<void> {
    this.isLoading = true;
    try {
      const service = FavoriteService.getInstance();
      if (this.selectedType === 'ALL') {
        this.favoriteItems = await service.getAllFavorites();
      } else {
        this.favoriteItems = await service.getFavoritesByType(this.selectedType);
      }
    } catch (error) {
      console.error('加载收藏列表失败:', error);
      promptAction.showToast({
        message: '加载收藏列表失败'
      });
    } finally {
      this.isLoading = false;
    }
  }

  // 删除收藏项
  private async removeFavorite(item: FavoriteItem): Promise<void> {
    try {
      const service = FavoriteService.getInstance();
      const success = await service.removeFromFavorites(item.scpId);
      if (success) {
        // 从列表中移除
        const index = this.favoriteItems.findIndex(fav => fav.id === item.id);
        if (index !== -1) {
          this.favoriteItems.splice(index, 1);
        }
        promptAction.showToast({
          message: '已取消收藏'
        });
      } else {
        promptAction.showToast({
          message: '取消收藏失败'
        });
      }
    } catch (error) {
      console.error('删除收藏失败:', error);
      promptAction.showToast({
        message: '取消收藏失败'
      });
    }
  }

  // 导航到详情页
  private navigateToDetail(item: FavoriteItem): void {
    if (item.type === 'SCP') {
      // 构造SCP对象
      const scpItem: SCP = {
        id: item.scpId,
        number: item.scpId,
        title: item.title,
        objectClass: item.objectClass || '',
        description: item.description,
        containmentProcedures: '',
        series: 1,
        dateAdded: new Date().toISOString(),
        image: item.imageUrl,
        tags: [],
        isFavorited: true
      };
      this.pathStack.pushPathByName('scpObjDetail', scpItem, (_popInfo) => {
        this.loadFavorites();
      });
    } else if (item.type === 'TALE') {
      // 构造Tale对象
      const taleItem: Tale = {
        id: item.scpId,
        title: item.title,
        author: '',
        content: item.description,
        datePublished: new Date().toISOString(),
        tags: [],
        relatedSCPs: []
      };
      this.pathStack.pushPathByName('scpDocDetail', taleItem, (_popInfo) => {
        this.loadFavorites();
      });
    }
  }

  // 构建收藏项UI
  @Builder
  private buildFavoriteItem(item: FavoriteItem) {
    Row({ space: 15 }) {
      // 图片或图标
      if (item.imageUrl) {
        Image(item.imageUrl)
          .width(60)
          .height(60)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
      } else {
        Column() {
          Text(item.type === 'SCP' ? '📋' : '📖')
            .fontSize(24)
        }
        .width(60)
        .height(60)
        .backgroundColor('#333')
        .borderRadius(8)
        .justifyContent(FlexAlign.Center)
      }

      // 内容信息
      Column({ space: 5 }) {
        // 标题
        Text(item.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fff')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)

        // 类型和等级
        Row({ space: 10 }) {
          Text(item.type === 'SCP' ? 'SCP项目' : '故事文档')
            .fontSize(12)
            .fontColor('#ff6b35')
            .backgroundColor('#ff6b3520')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(4)

          if (item.objectClass) {
            Text(item.objectClass)
              .fontSize(12)
              .fontColor('#a0a0a0')
              .backgroundColor('#333')
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(4)
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)

        // 描述
        if (item.description) {
          Text(item.description)
            .fontSize(14)
            .fontColor('#a0a0a0')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
        }

        // 收藏时间
        Text(`收藏于 ${new Date(item.dateAdded).toLocaleDateString()}`)
          .fontSize(12)
          .fontColor('#666')
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 操作按钮
      Column({ space: 10 }) {
        Button() {
          Image($r('app.media.heart_em'))
            .width(20)
            .height(20)
            .fillColor('#ff6b35')
        }
        .width(40)
        .height(40)
        .backgroundColor('#333')
        .borderRadius(20)
        .onClick(() => {
          this.removeFavorite(item);
        })
      }
    }
    .width('100%')
    .padding(15)
    .backgroundColor('#1e1e1e')
    .borderRadius(10)
    .border({ width: 0.5, color: '#ee717182' })
    .onClick(() => {
      this.navigateToDetail(item);
    })
  }

  // 页面显示时的生命周期方法
  async onPageShow(): Promise<void> {
    console.info('Favourite页面显示，刷新收藏数据');
    // 确保服务已初始化（应对应用冷启动情况）
    await FavoriteService.initialize(getContext(this));
    // 页面每次显示时都刷新数据，包括应用重新进入前台
    await this.loadFavorites();
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        // 页面标题
        Text('我的收藏')
          .fontSize(25)
          .fontWeight(FontWeight.Medium)
          .fontColor('#fff')
          .margin({bottom: 20})

        // 类型过滤器
        Row({ space: 10 }) {
          Text('全部')
            .backgroundColor(this.selectedType === 'ALL' ? '#ff4444' : '#10717182')
            .fontColor(this.selectedType === 'ALL' ? '#000' : '#fff')
            .fontSize(14)
            .border({radius: 8, width: this.selectedType === 'ALL' ? 0 : 0.5, color: '#ee717182'})
            .padding({ left: 13, right: 13, top: 8, bottom: 8 })
            .onClick(() => {
              this.selectedType = 'ALL';
              this.loadFavorites();
            })
          Text('SCP项目')
            .backgroundColor(this.selectedType === 'SCP' ? '#ff4444' : '#10717182')
            .fontColor(this.selectedType === 'SCP' ? '#000' : '#fff')
            .fontSize(14)
            .border({radius: 8, width: this.selectedType === 'SCP' ? 0 : 0.5, color: '#ee717182'})
            .padding({ left: 13, right: 13, top: 8, bottom: 8 })
            .onClick(() => {
              this.selectedType = 'SCP';
              this.loadFavorites();
            })
          Text('故事文档')
            .backgroundColor(this.selectedType === 'TALE' ? '#ff4444' : '#10717182')
            .fontColor(this.selectedType === 'TALE' ? '#000' : '#fff')
            .fontSize(14)
            .border({radius: 8, width: this.selectedType === 'TALE' ? 0 : 0.5, color: '#ee717182'})
            .padding({ left: 13, right: 13, top: 8, bottom: 8 })
            .onClick(() => {
              this.selectedType = 'TALE';
              this.loadFavorites();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({bottom: 20})

        // 加载状态
        if (this.isLoading) {
          Column({ space: 15 }) {
            LoadingProgress()
              .width(50)
              .height(50)
              .color('#ff6b35')
            Text('加载中...')
              .fontSize(16)
              .fontColor('#a0a0a0')
          }
          .width('100%')
          .height(200)
          .justifyContent(FlexAlign.Center)
        }
        // 收藏列表
        else if (this.favoriteItems.length > 0) {
          Column({ space: 15 }) {
            ForEach(this.favoriteItems, (item: FavoriteItem) => {
              this.buildFavoriteItem(item)
            })
          }
          .width('100%')
        }
        // 空收藏提示
        else {
          Column({ space: 15 }) {
            Text('💝')
              .fontSize(50)
            Text('暂无收藏')
              .fontSize(18)
              .fontColor('#fff')
              .fontWeight(FontWeight.Bold)
            Text('浏览SCP档案并点击❤️来添加到收藏夹')
              .fontSize(14)
              .fontColor('#a0a0a0')
          }
          .border({width: 0.5, color: '#ee717182', radius: 10})
          .width('100%')
          .backgroundColor('#1e1e1e')
          .padding({left: 20, right: 20, top: 50, bottom: 50})
        }
      }
      .padding({left: 25, right: 25})
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .height('100%')
      .width('100%')
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .height('100%')
    .width('100%')
    .onAppear(async () => {
      // 页面出现时确保服务已初始化
      await FavoriteService.initialize(getContext(this));
      // 加载数据
      await this.loadFavorites();
    })
  }
}