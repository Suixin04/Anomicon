import { mockSCPs, mockTales } from "../data/Data";
import { Tale, SCP } from "../utils/types";
import { CollapsibleCard } from "../utils/CollapsibleCard";
import { FavoriteService } from '../common/service/FavoriteService';
import { ShareService } from '../common/service/ShareService';
import { scpApi } from "../utils/ScpApi";
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

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

  // 分享Tale故事
  private async shareTale(): Promise<void> {
    if (!this.tale) {
      promptAction.showToast({
        message: '暂无可分享的内容'
      });
      return;
    }

    try {
      const context = getContext(this) as common.UIAbilityContext;
      await ShareService.getInstance().shareTale(context, this.tale);
    } catch (error) {
      console.error('分享失败:', error);
      promptAction.showToast({
        message: '分享失败，请重试'
      });
    }
  }

  // 根据SCP编号获取SCP数据并跳转
  private async navigateToSCP(scpNumber: string): Promise<void> {
    try {
      // 从SCP编号中提取数字部分（例如：从"SCP-173"提取"173"）
      const numberOnly = scpNumber.replace(/^SCP-/i, '').replace(/^0+/, '') || '0';
      
      // 通过API获取SCP详情
      const scpData = await scpApi.getScpDetail(numberOnly);
      
      if (scpData) {
        // 跳转到SCP详情页
        this.pathStack.pushPathByName('scpObjDetail', scpData, false);
      } else {
        // 如果API获取失败，尝试从本地数据中查找
        const localScp = mockSCPs.find(item => item.number === scpNumber);
        if (localScp) {
          this.pathStack.pushPathByName('scpObjDetail', localScp, false);
        } else {
          promptAction.showToast({
            message: `未找到 ${scpNumber} 的详细信息`
          });
        }
      }
    } catch (error) {
      console.error('获取SCP数据失败:', error);
      // 降级处理：尝试使用本地数据
      const localScp = mockSCPs.find(item => item.number === scpNumber);
      if (localScp) {
        this.pathStack.pushPathByName('scpObjDetail', localScp, false);
      } else {
        promptAction.showToast({
          message: `获取 ${scpNumber} 信息失败，请重试`
        });
      }
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({space: 20}) {
          // 文档内容卡片
          Column({ space: 15 }) {
            // 文档内容
            Text(this.tale.content)
              .fontSize(14)
              .fontColor('#fff')
              .lineHeight(24)
          }
          .border({width: 0.5, color: '#ee717182', radius: 10})
          .width('100%')
          .backgroundColor('#1e1e1e')
          .justifyContent(FlexAlign.Start)
          .padding({left: 20, right: 20, top: 30, bottom: 30})

          // 标签和相关信息卡片
          Column({ space: 15 }) {
            // 标签部分
            if (this.tale.tags && this.tale.tags.length > 0) {
              Column({ space: 5 }) {
                Row() {
                  Text('标签:')
                    .fontSize(14)
                    .fontColor('#a0a0a0')
                }
                .width('100%')
                // 标签列表
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.tale.tags, (tag: string, index: number) => {
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
                .margin({bottom: 10})
              }
            }

            // 相关SCP部分
            if (this.tale.relatedSCPs && this.tale.relatedSCPs.length > 0) {
              Column({ space: 5 }) {
                Row() {
                  Text('相关SCP:')
                    .fontSize(14)
                    .fontColor('#a0a0a0')
                }
                .width('100%')
                // 相关SCP项目列表
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.tale.relatedSCPs, (scp: string, index: number) => {
                    Row({space: 5}) {
                      Text(scp)
                        .fontColor('#fff')
                        .fontSize(10)
                        .fontWeight(FontWeight.Bold)
                      Image($r('app.media.outer_link'))
                        .width(12)
                    }
                    .backgroundColor('#ff282525')
                    .borderRadius(6)
                    .padding({left: 6, right: 6, top: 5, bottom: 5})
                    .margin({right: 3, bottom: 3})
                    // 点击相关SCP项目可跳转到对应的SCP详情页
                    .onClick(() => {
                      this.navigateToSCP(scp);
                    })
                  })
                }
                .width('100%')
              }
            }
          }
          .border({width: 0.5, color: '#ee717182', radius: 10})
          .width('100%')
          .backgroundColor('#1e1e1e')
          .justifyContent(FlexAlign.Start)
          .padding({left: 20, right: 20, top: 30, bottom: 30})
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
          this.shareTale();
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
      FavoriteService.getInstance().initialize(getContext(this));
      
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