import { FavoriteService, FontSizeManager, scpApi, ShareService, Tale, VibrationUtils } from "utils"
import { promptAction } from "@kit.ArkUI"
import { common } from "@kit.AbilityKit"
import { mockSCPs, mockTales } from "../data/Data"
import { PromptAction } from '@kit.ArkUI';

/**
 * 自定义标题栏构建器 - 显示故事标题和作者信息
 * @param tale 故事对象，包含标题、作者、发布日期等信息
 */
@Builder
function cusTitle(tale: Tale) {
  Column({ space: 10 }) {
    Text(tale.title)
      .fontColor($r('app.color.text_primary'))
      .fontSize(18)
      .width('100%')
      .fontWeight(FontWeight.Bold)
    Text('作者: ' + tale.author + ' • ' + tale.datePublished)
      .width('100%')
      .fontColor($r('app.color.text_secondary'))
      .fontSize(14)
      .margin({ bottom: 10 })
  }
  .width('100%')
  .margin({ left: 10 })
  .alignItems(HorizontalAlign.Start)
  .height('100%')
}

/**
 * SCP文档详情页面组件 - 显示故事详细内容
 * 包含故事内容、标签、相关SCP项目等信息
 * 支持收藏、分享等功能
 */
@ComponentV2
export struct TaleDetailPage {
  /** 导航路径栈，用于页面导航 */
  @Consumer('pageStack') pageStack?: NavPathStack
  /** 当前显示的故事对象，默认为第一个故事 */
  @Local tale: Tale = mockTales[0];
  /** 当前故事的收藏状态 */
  @Local isFavorited: boolean = false;
  /** 收藏操作加载状态 */
  @Local favoriteLoading: boolean = false;

  private promptAction: PromptAction | undefined;
  aboutToAppear() {
    // 获取当前 UI 上下文的 PromptAction 实例
    this.promptAction = this.getUIContext().getPromptAction();
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 20 }) {
          Column({ space: 15 }) {
            Text(this.tale.content)
              .fontSize(FontSizeManager.getScaledFontSize(14))
              .fontColor($r('app.color.text_primary'))
              .lineHeight(24)
              .textAlign(TextAlign.JUSTIFY)
          }
          .border({ width: 0.5, color: $r('app.color.border_primary'), radius: 10 })
          .width('100%')
          .backgroundColor($r('app.color.background_secondary'))
          .justifyContent(FlexAlign.Start)
          .padding({
            left: 20,
            right: 20,
            top: 30,
            bottom: 30
          })

          // 标签和相关信息展示卡片
          Column({ space: 15 }) {
            // 故事标签展示区域
            if (this.tale.tags && this.tale.tags.length > 0) {
              Column({ space: 5 }) {
                Row() {
                  Text('标签:')
                    .fontSize(FontSizeManager.getScaledFontSize(14))
                    .fontColor($r('app.color.text_secondary'))
                }
                .width('100%')

                // 标签列表 - 支持换行显示
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.tale.tags, (tag: string, index: number) => {
                    Text(tag)
                      .backgroundColor($r('app.color.tag_bg'))
                      .borderRadius(6)
                      .fontColor($r('app.color.text_primary'))
                      .fontSize(FontSizeManager.getScaledFontSize(10))
                      .fontWeight(FontWeight.Bold)
                      .padding({
                        left: 6,
                        right: 6,
                        top: 5,
                        bottom: 5
                      })
                      .margin({ right: 3, bottom: 3 })
                  })
                }
                .width('100%')
                .margin({ bottom: 10 })
              }
            }

            // 相关SCP项目展示区域
            if (this.tale.relatedSCPs && this.tale.relatedSCPs.length > 0) {
              Column({ space: 5 }) {
                Row() {
                  Text('相关SCP:')
                    .fontSize(FontSizeManager.getScaledFontSize(14))
                    .fontColor($r('app.color.text_secondary'))
                }
                .width('100%')

                // 相关SCP项目列表 - 可点击跳转
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.tale.relatedSCPs, (scp: string, index: number) => {
                    Row({ space: 5 }) {
                      Text(scp)
                        .fontColor($r('app.color.text_primary'))
                        .fontSize(FontSizeManager.getScaledFontSize(10))
                        .fontWeight(FontWeight.Bold)
                      Image($r('app.media.outer_link'))
                        .width(12)
                    }
                    .backgroundColor($r('app.color.tag_bg'))
                    .borderRadius(6)
                    .padding({
                      left: 6,
                      right: 6,
                      top: 5,
                      bottom: 5
                    })
                    .margin({ right: 3, bottom: 3 })
                    // 点击相关SCP项目跳转到对应的SCP详情页面
                    .onClick(() => {
                      this.navigateToSCP(scp);
                    })
                  })
                }
                .width('100%')
              }
            }
          }
          .border({ width: 0.5, color: $r('app.color.border_primary'), radius: 10 })
          .width('100%')
          .backgroundColor($r('app.color.background_secondary'))
          .justifyContent(FlexAlign.Start)
          .padding({
            left: 20,
            right: 20,
            top: 30,
            bottom: 30
          })
        }
        .padding({ left: 25, right: 25, top: 25 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
        .width('100%')
      }
      .backgroundColor($r('app.color.background_primary'))
      .border({ width: { top: 0.5 }, color: $r('app.color.border_primary') })
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
    }
    .title(cusTitle(this.tale))
    .backgroundColor($r('app.color.background_primary'))
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
        icon: this.isFavorited ? $r('app.media.heart_fill') : $r('app.media.heart'),
        action: () => {
          this.toggleFavorite();
        }
      }
    ])
    // 页面准备就绪时的生命周期回调处理
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;

      // 初始化收藏功能服务
      FavoriteService.getInstance().initialize(getContext(this));

      // 获取路由传递的故事参数
      const param = context.pathInfo.param as Tale
      if (param) {
        this.tale = param;
        // 异步检查当前故事的收藏状态
        this.checkFavoriteStatus();
      }
    })
  }

  /**
   * 检查当前故事的收藏状态
   * 从本地存储中查询是否已收藏
   */
  private async checkFavoriteStatus(): Promise<void> {
    if (this.tale) {
      try {
        this.isFavorited = await FavoriteService.getInstance().isFavorited(this.tale.id);
      } catch (error) {
        console.error('检查收藏状态失败:', error);
      }
    }
  }

  /**
   * 切换故事的收藏状态
   * 添加或移除收藏，并显示相应提示
   */
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

        // 添加振动反馈
        if (this.isFavorited) {
          VibrationUtils.successFeedback();
        } else {
          VibrationUtils.lightTap();
        }

        this.promptAction?.showToast({
          message: message
        });
      } else {
        this.promptAction?.showToast({
          message: '操作失败，请重试'
        });
      }
    } catch (error) {
      console.error('切换收藏状态失败:', error);
      this.promptAction?.showToast({
        message: '操作失败，请重试'
      });
    } finally {
      this.favoriteLoading = false;
    }
  }

  /**
   * 分享当前故事内容
   * 通过系统分享服务分享故事
   */
  private async shareTale(): Promise<void> {
    if (!this.tale) {
      this.promptAction?.showToast({
        message: '暂无可分享的内容'
      });
      return;
    }

    try {
      const context = getContext(this) as common.UIAbilityContext;
      await ShareService.getInstance().shareTale(context, this.tale);
    } catch (error) {
      console.error('分享失败:', error);
      this.promptAction?.showToast({
        message: '分享失败，请重试'
      });
    }
  }

  /**
   * 根据SCP编号获取SCP数据并跳转到详情页
   * 优先从API获取，失败时降级使用本地数据
   * @param scpNumber SCP编号，如"SCP-173"
   */
  private async navigateToSCP(scpNumber: string): Promise<void> {
    try {
      // 从SCP编号中提取数字部分（例如：从"SCP-173"提取"173"）
      const numberOnly = scpNumber.replace(/^SCP-/i, '').replace(/^0+/, '') || '0';

      // 通过API获取SCP详情
      const scpData = await scpApi.getScpDetail(numberOnly);

      if (scpData) {
        // 跳转到SCP详情页
        this.pageStack?.pushPathByName('objDetailPage', scpData, false);
      } else {
        // 如果API获取失败，尝试从本地数据中查找
        const localScp = mockSCPs.find(item => item.number === scpNumber);
        if (localScp) {
          this.pageStack?.pushPathByName('objDetailPage', localScp, false);
        } else {
          this.promptAction?.showToast({
            message: `暂未收录 ${scpNumber}`
          });
        }
      }
    } catch (error) {
      console.error('获取SCP数据失败:', error);
      // 降级处理：尝试使用本地数据
      const localScp = mockSCPs.find(item => item.number === scpNumber);
      if (localScp) {
        this.pageStack?.pushPathByName('scpObjDetail', localScp, false);
      } else {
        this.promptAction?.showToast({
          message: `获取 ${scpNumber} 信息失败，请重试`
        });
      }
    }
  }
}