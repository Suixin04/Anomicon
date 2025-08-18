import { mockSCPs, mockTales } from "../data/Data";
import { Tale } from "../utils/types";
import { CollapsibleCard } from "../utils/CollapsibleCard";
import { FavoriteService } from '../common/service/FavoriteService';
import { promptAction } from '@kit.ArkUI';

// SCP文档详情页面构建器
@Builder
export function DocBuilder() {
  scpDocDetail()
}

// 自定义标题构建器
@Builder
function cusTitle(tale: Tale) {
  Column({space: 10}){
    // 文档标题
    Text(tale.title)
      .fontColor('#fff')
      .fontSize(18)
      .width('100%')
      .fontWeight(FontWeight.Bold)
    // 作者和发布日期信息
    Text('作者: ' + tale.author + ' • ' + tale.datePublished)
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
  // 导航路径栈，用于页面导航
  pathStack: NavPathStack = new NavPathStack();
  // 当前显示的故事对象，默认为第一个故事
  @Local tale: Tale = mockTales[0];
  // 收藏状态
  @Local isFavorited: boolean = false;
  // 收藏操作加载状态
  @Local favoriteLoading: boolean = false;

  // 构建标签和相关信息的内容
  private buildTagsAndRelatedContent(): string[] {
    const content: string[] = [];
    
    // 添加标签信息
    if (this.tale.tags && this.tale.tags.length > 0) {
      content.push('标签: ' + this.tale.tags.join(', '));
    }
    
    // 添加相关SCP信息
    if (this.tale.relatedSCPs && this.tale.relatedSCPs.length > 0) {
      content.push('相关SCP: ' + this.tale.relatedSCPs.join(', '));
    }
    
    return content;
  }

  // 检查收藏状态
  private async checkFavoriteStatus(): Promise<void> {
    if (this.tale) {
      try {
        this.isFavorited = await FavoriteService.getInstance().isFavorited(this.tale.id);
      } catch (error) {
        console.error('检查收藏状态失败:', error);
      }
    }
  }

  // 切换收藏状态
  private async toggleFavorite(): Promise<void> {
    if (!this.tale || this.favoriteLoading) {
      return;
    }

    this.favoriteLoading = true;
    try {
      const success = await FavoriteService.getInstance().toggleTaleFavorite(this.tale);
      if (success) {
        this.isFavorited = !this.isFavorited;
        const message = this.isFavorited ? '已添加到收藏' : '已取消收藏';
        promptAction.showToast({
           message: message
         });
      } else {
        promptAction.showToast({
           message: '操作失败，请重试'
         });
      }
    } catch (error) {
      console.error('切换收藏状态失败:', error);
      promptAction.showToast({
         message: '操作失败，请重试'
       });
    } finally {
      this.favoriteLoading = false;
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({space: 20}) {
          // 使用CollapsibleCard显示文档内容
          CollapsibleCard({title: '文档内容', content: this.tale.content})
          // 使用CollapsibleCard显示标签和相关信息
          CollapsibleCard({
            title: '标签与相关信息',
            content: this.buildTagsAndRelatedContent()
          })
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
    .title(cusTitle(this.tale))
    .backgroundColor('#121212')
    .backButtonIcon($r("app.media.arrow_left"))
    // 页面菜单
    .menus([
      {
        value: '分享',
        icon: ($r("app.media.share")),
        action: () => {
          console.info('分享按钮点击');
        }
      },
      {
        value: this.isFavorited ? '取消收藏' : '收藏',
        icon: this.isFavorited ? $r('app.media.heart_em') : $r('app.media.heart'),
        action: () => {
          this.toggleFavorite();
        }
      }
    ])
    // 页面准备就绪时的回调处理
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      
      // 初始化收藏服务
      FavoriteService.initialize(getContext(this));
      
      // 获取传递的参数
      const param = context.pathInfo.param as Tale
      if (param) {
        this.tale = param;
        // 检查收藏状态
        this.checkFavoriteStatus();
      }
    })
  }
}