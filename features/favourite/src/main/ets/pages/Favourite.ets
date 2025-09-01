import { AppStorageV2, PromptAction, promptAction } from "@kit.ArkUI"
import { FavoriteItem, FavoriteService, FontSizeManager, getColorsByClass, SCP,
  scpApi,
  Tale, VibrationUtils } from "utils"
import { CustomButtonView, Title } from "uicomponents"

@ComponentV2
export struct Favourite {
  /** 导航路径栈，用于页面间的导航管理 */
  @Consumer('pageStack')pageStack?: NavPathStack
  /** 收藏项目列表，包含SCP项目和故事 */
  @Local favoriteItems: FavoriteItem[] = []
  /** 数据加载状态 */
  @Local isLoading: boolean = true
  /** 当前选择的类型过滤器：'ALL'(全部)、'SCP'(SCP项目)、'TALE'(故事) */
  @Local selectedType: string = 'ALL' // 'ALL', 'SCP', 'TALE'
  /** 滚动控制器 */
  private scroller: Scroller = new Scroller()
  /** 取消收藏变更订阅的函数，用于避免内存泄漏 */
  private unsubscribeFavoriteChange?: () => void;

  private promptAction: PromptAction | undefined;

  /**
   * 页面即将显示生命周期方法
   * 初始化收藏服务并订阅收藏变更事件
   */
  async aboutToAppear(): Promise<void> {
    // 获取当前 UI 上下文的 PromptAction 实例
    this.promptAction = this.getUIContext().getPromptAction();
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

  /**
   * 页面将被销毁生命周期方法
   * 取消订阅收藏变更事件，避免内存泄漏
   */
  aboutToBeDeleted(): void {
    this.unsubscribeFavoriteChange?.();
    this.unsubscribeFavoriteChange = undefined;
  }

  /**
   * 页面显示时的生命周期方法
   * 确保服务已初始化并刷新收藏数据
   */
  async onPageShow(): Promise<void> {
    console.info('Favourite页面显示，刷新收藏数据');
    // 确保服务已初始化（应对应用冷启动情况）
    await FavoriteService.initialize(getContext(this));
    // 页面每次显示时都刷新数据，包括应用重新进入前台
    await this.loadFavorites();
  }

  build() {
    Column() {
      Title({ str: "我的收藏", scroller: this.scroller })

      Scroll(this.scroller) {
        Column({ space: 20 }) {

          // 类型过滤器
          Row({ space: 10 }) {
            CustomButtonView({ text: '全部', isSelected: this.selectedType === 'ALL' ? true : false })
              .onClick(() => {
                VibrationUtils.lightTap()
                this.selectedType = 'ALL';
                this.loadFavorites();
              })
            CustomButtonView({ text: 'SCP项目', isSelected: this.selectedType === 'SCP' ? true : false })
              .onClick(() => {
                VibrationUtils.lightTap()
                this.selectedType = 'SCP';
                this.loadFavorites();
              })
            CustomButtonView({ text: '故事文档', isSelected: this.selectedType === 'TALE' ? true : false })
              .onClick(() => {
                VibrationUtils.lightTap()
                this.selectedType = 'TALE';
                this.loadFavorites();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .margin({ bottom: 20 })

          // 加载状态
          if (this.isLoading) {
            Column({ space: 15 }) {
              LoadingProgress()
                .width(50)
                .height(50)
                .color($r('app.color.tag_orange_text'))
              Text('加载中...')
                .fontSize(FontSizeManager.getScaledFontSize(16))
                .fontColor($r('app.color.text_secondary'))
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
                .fontSize(FontSizeManager.getScaledFontSize(50))
              Text('暂无收藏')
                .fontSize(FontSizeManager.getScaledFontSize(18))
                .fontColor($r('app.color.text_primary'))
                .fontWeight(FontWeight.Bold)
              Text('浏览SCP档案并点击❤️来添加到收藏夹')
                .fontSize(FontSizeManager.getScaledFontSize(14))
                .fontColor($r('app.color.text_secondary'))
            }
            .border({ width: 0.5, color: $r('app.color.border_primary'), radius: 10 })
            .width('100%')
            .backgroundColor($r('app.color.background_secondary'))
            .padding({
              left: 20,
              right: 20,
              top: 50,
              bottom: 50
            })
          }
        }
        .padding({ left: 25, right: 25, bottom: 25 })
        .width('100%')
        // .height('100%')
      }
      .align(Alignment.Top)
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')
      .onAppear(async () => {
        // 页面出现时确保服务已初始化
        await FavoriteService.initialize(getContext(this));
        // 加载数据
        await this.loadFavorites();
      })
    }
    // .height('100%')
    .width('100%')
  }

  /**
   * 加载收藏列表数据
   * 根据当前选择的类型过滤器从收藏服务中获取相应的收藏项目
   */
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
      this.promptAction?.showToast({
        message: '加载收藏列表失败'
      });
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 删除收藏项
   * @param item 要删除的收藏项
   */
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
        this.promptAction?.showToast({
          message: '已取消收藏'
        });
      } else {
        this.promptAction?.showToast({
          message: '取消收藏失败'
        });
      }
    } catch (error) {
      console.error('删除收藏失败:', error);
      this.promptAction?.showToast({
        message: '取消收藏失败'
      });
    }
  }

  /**
   * 导航到详情页面
   * 根据项目类型跳转到相应的详情页
   * @param item 要查看详情的收藏项目
   */
  private async navigateToDetail(item: FavoriteItem): Promise<void> {
    if (item.type === 'SCP') {
      // 构造SCP对象
      const instance = await scpApi.getScpDetail(item.scpId)
      this.pageStack!.pushPathByName('objDetailPage', instance, false);
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
      this.pageStack!.pushPathByName('taleDetailPage', taleItem, false);
    }
  }

  /**
   * 构建收藏项UI组件
   * @param item 收藏项数据
   */
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
            .fontSize(FontSizeManager.getScaledFontSize(24))
        }
        .width(60)
        .height(60)
        .backgroundColor($r('app.color.border_secondary'))
        .borderRadius(8)
        .justifyContent(FlexAlign.Center)
      }

      // 内容信息
      Column({ space: 5 }) {
        // 标题
        Text(item.title)
          .fontSize(FontSizeManager.getScaledFontSize(16))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)

        // 类型和等级
        Row({ space: 10 }) {
          Text(item.type === 'SCP' ? 'SCP项目' : '故事文档')
            .fontSize(FontSizeManager.getScaledFontSize(12))
            .fontColor($r('app.color.tag_orange_text'))
            .backgroundColor($r('app.color.tag_orange_bg'))
            .padding({
              left: 8,
              right: 8,
              top: 2,
              bottom: 2
            })
            .borderRadius(4)

          Blank()
            .layoutWeight(1)

          if (item.objectClass) {
            Text(item.objectClass)
              .border({ radius: 5, width: 0.8, color: getColorsByClass(item.objectClass).borderColor })
              .fontWeight(FontWeight.Bold)
              .fontColor(getColorsByClass(item.objectClass).textColor)
              .backgroundColor(getColorsByClass(item.objectClass).backgroundColor)
              .fontSize(FontSizeManager.getScaledFontSize(12))
              .padding({
                top: 3,
                bottom: 3,
                left: 6,
                right: 6
              })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .backgroundColor($r('app.color.border_secondary'))
              .padding({
                left: 8,
                right: 8,
                top: 2,
                bottom: 2
              })
              .borderRadius(4)
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)

        // 描述
        if (item.description) {
          Text(item.description)
            .fontSize(FontSizeManager.getScaledFontSize(14))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
        }

        // 收藏时间
        Text(`收藏于 ${new Date(item.dateAdded).toLocaleDateString()}`)
          .fontSize(FontSizeManager.getScaledFontSize(12))
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 操作按钮
      Column({ space: 10 }) {
        Button() {
          Image($r('app.media.heart_fill'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.tag_orange_text'))
        }
        .width(40)
        .height(40)
        .backgroundColor($r('app.color.border_secondary'))
        .borderRadius(20)
        .onClick(() => {
          // 添加轻触振动反馈
          VibrationUtils.lightTap()
          this.removeFavorite(item);
        })
      }
    }
    .width('100%')
    .padding(15)
    .backgroundColor($r('app.color.background_secondary'))
    .borderRadius(10)
    .border({ width: 0.5, color: $r('app.color.border_primary') })
    .onClick(() => {
      VibrationUtils.lightTap()
      this.navigateToDetail(item);
    })
  }
}