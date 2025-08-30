import { CollapsibleCard, ImageWithLoadingView } from "uicomponents"
import { CollapsibleCardData, FavoriteService, FontSizeManager, getColorsByClass, SCP, scpApi,
  ShareService,
  VibrationUtils } from "utils"
import { PromptAction, promptAction } from "@kit.ArkUI"
import { common } from "@kit.AbilityKit"

/**
 * 自定义标题构建器 - 根据SCP数据动态生成页面标题
 * @param scp SCP项目数据，可能为null（加载中状态）
 */
@Builder
function cusTitle(scp: SCP | null) {
  if (!scp) {
    Column() {
      Text('加载中...')
        .fontColor($r('app.color.text_primary'))
        .fontSize(FontSizeManager.getScaledFontSize(16))
    }
    .margin({ left: 10 })
    .alignItems(HorizontalAlign.Start)
    .height('100%')
  } else {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(scp.number)
          .fontColor($r('app.color.text_accent'))
          .fontSize(14)
          .fontWeight(FontWeight.Normal)
        Text(scp.objectClass)
          .border({ radius: 5, width: 0.8, color: getColorsByClass(scp.objectClass).borderColor })
          .fontWeight(FontWeight.Bold)
          .fontColor(getColorsByClass(scp.objectClass).textColor)
          .backgroundColor(getColorsByClass(scp.objectClass).backgroundColor)
          .fontSize(12)
          .padding({
            top: 3,
            bottom: 3,
            left: 6,
            right: 6
          })
      }
      .width('100%')

      Text(scp.title)
        .fontColor($r('app.color.text_primary'))
        // .fontSize(FontSizeManager.getScaledFontSize(18))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
    }
    .margin({ left: 10 })
    .alignItems(HorizontalAlign.Start)
    .height('100%')
  }
}

/**
 * SCP对象详情页面组件 - 显示SCP项目详细信息
 * 包含项目描述、收容措施、特殊性质等详细内容
 * 支持收藏、分享等功能
 */
@ComponentV2
@Preview
export struct ObjDetailPage {
  /** 导航路径栈，用于页面导航管理 */
  @Consumer('objStack') objPathStack?: NavPathStack
  /** 当前显示的SCP项目，初始为null，待API加载 */
  @Local scpItem: SCP | null = null;
  /** 页面数据加载状态 */
  @Local isLoading: boolean = true;
  /** 当前SCP项目的收藏状态 */
  @Local isFavorited: boolean = false;
  /** 收藏操作的加载状态，防止重复操作 */
  @Local favoriteLoading: boolean = false;
  /** 动态卡片数据，用于渲染折叠卡片组件 */
  @Local cardDataList: CollapsibleCardData[] = [];

  private promptAction: PromptAction | undefined;

  aboutToAppear() {
    // 获取当前 UI 上下文的 PromptAction 实例
    this.promptAction = this.getUIContext().getPromptAction();
  }


  build() {
    NavDestination() {
      if (this.isLoading || !this.scpItem) {
        Column() {
          Text('正在加载详情...')
            .fontColor($r('app.color.text_primary'))
            .fontSize(FontSizeManager.getScaledFontSize(16))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.background_primary'))
      } else {
        Scroll() {
          Column({ space: 20 }) {
            if (this.scpItem.image) {
              Column({ space: 15 }) {
                ImageWithLoadingView({
                  src: this.scpItem.image,
                  imgWidth: '100%',
                  imgHeight: '100%',
                  objectFit: ImageFit.Contain
                })
              }
              .height(200)
              .border({ width: 0.5, color: $r('app.color.border_primary'), radius: 10 })
            }
            GridRow({ columns: 2 }) {
              GridCol() {
                Column() {
                  Row() {
                    Text('项目等级:')
                      .fontSize(FontSizeManager.getScaledFontSize(14))
                      .fontColor($r('app.color.text_secondary'))
                  }.width('100%')

                  Row() {
                    Text(this.scpItem.objectClass)
                      .margin({ top: 5 })
                      .border({ radius: 5, width: 0.8, color: $r('app.color.border_primary') })
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.text_primary'))
                      .fontSize(FontSizeManager.getScaledFontSize(12))
                      .padding({
                        top: 3,
                        bottom: 3,
                        left: 6,
                        right: 6
                      })
                  }
                  .width('100%')
                }
                .width('100%')
              }

              // 系列信息列
              GridCol({ span: 1 }) {
                Column() {
                  Row() {
                    Text('系列:')
                      .fontSize(FontSizeManager.getScaledFontSize(14))
                      .fontColor($r('app.color.text_secondary'))
                  }.width('100%')

                  Row() {
                    Text(`Series ${this.scpItem.series.toString()}`)
                      .margin({ top: 5 })
                      .fontColor($r('app.color.text_primary'))
                  }
                  .width('100%')
                }
                .width('100%')
              }

              // 添加日期信息列
              GridCol({ span: 1 }) {
                Column() {
                  Row() {
                    Text('添加日期:')
                      .margin({ top: 15 })
                      .fontSize(FontSizeManager.getScaledFontSize(14))
                      .fontColor($r('app.color.text_secondary'))
                  }.width('100%')

                  Row() {
                    Text(this.scpItem.dateAdded)
                      .fontSize(FontSizeManager.getScaledFontSize(14))
                      .margin({ top: 5 })
                      .fontColor($r('app.color.text_primary'))
                  }
                  .width('100%')
                }
                .width('100%')
              }

              // 标签信息列
              GridCol({ span: 1 }) {
                Column() {
                  Row() {
                    Text('标签:')
                      .margin({ top: 15 })
                      .fontSize(FontSizeManager.getScaledFontSize(14))
                      .fontColor($r('app.color.text_secondary'))
                  }.width('100%')

                  // 标签列表，支持自动换行显示
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.scpItem.tags, (tag: string, index: number) => {
                      Text(tag)
                        .backgroundColor($r('app.color.background_tag'))
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
                }
                .width('100%')
              }
            }
            .border({ width: 0.5, color: $r('app.color.border_primary'), radius: 10 })
            .width('100%')
            .backgroundColor($r('app.color.background_secondary'))
            .padding(25)

            ForEach(this.cardDataList, (cardData: CollapsibleCardData, index: number) => {
              CollapsibleCard({
                title: cardData.title,
                content: cardData.content,
                defaultExpanded: cardData.title == '项目描述' ? true : false
              })
            }, (cardData: CollapsibleCardData, index: number) => `${cardData.title}-${index}`)
          }
          .padding({ left: 25, right: 25, top: 25 })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
          .width('100%')
        }
        .border({ width: { top: 0.5 }, color: $r('app.color.border_primary') })
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
    }
    .title(cusTitle(this.scpItem))
    .backgroundColor($r('app.color.background_primary'))
    .menus([
      {
        value: '分享',
        icon: ($r("app.media.share")),
        action: () => {
          this.shareSCP();
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
    .onReady((context: NavDestinationContext) => {
      this.objPathStack = context.pathStack;

      FavoriteService.getInstance().initialize(getContext(this));

      const param = context.pathInfo.param as SCP;
      if (param) {
        this.loadFullDetail(param);
      } else {
        console.error('未收到SCP参数');
        this.isLoading = false;
      }
    })
  }

  /**
   * 生成动态卡片数据
   * 将SCP项目的各种属性整理成卡片格式，按优先级排序
   * @param scp SCP项目数据
   * @returns 排序后的卡片数据数组
   */
  private generateCardData(scp: SCP): CollapsibleCardData[] {
    const cards: CollapsibleCardData[] = [];

    // 1. 项目描述 - 优先级最高
    if (scp.description && scp.description.trim() !== '') {
      cards.push({
        title: '项目描述',
        content: scp.description,
        priority: 1
      });
    }

    // 2. 特殊收容措施 - 优先级第二
    if (scp.containmentProcedures && scp.containmentProcedures.trim() !== '') {
      cards.push({
        title: '特殊收容措施',
        content: scp.containmentProcedures,
        priority: 2
      });
    }

    // 3. 附录 - 优先级第三
    if (scp.addendum && scp.addendum.trim() !== '') {
      cards.push({
        title: '附录',
        content: scp.addendum,
        priority: 3
      });
    }

    // 4. 访谈记录 - 优先级第四
    if (scp.interviews && scp.interviews.trim() !== '') {
      cards.push({
        title: '访谈记录',
        content: scp.interviews,
        priority: 4
      });
    }

    // 5. 动态字段 - 根据字段名称确定优先级和标题
    if (scp.dynamicFields) {
      let dynamicPriority = 10; // 动态字段从优先级10开始
      const entries = Object.entries(scp.dynamicFields);
      for (let i = 0; i < entries.length; i++) {
        const key = entries[i][0];
        const value = entries[i][1];
        if (value && value.trim() !== '') {
          // 将字段名转换为更友好的标题
          const title = this.formatFieldTitle(key);
          cards.push({
            title: title,
            content: value,
            priority: dynamicPriority++
          });
        }
      }
    }

    // 按优先级排序
    return cards.sort((a, b) => a.priority - b.priority);
  }

  /**
   * 格式化字段标题，将API字段名转换为用户友好的标题
   * @param fieldName 字段的英文键名
   * @returns 对应的中文显示名称
   */
  private formatFieldTitle(fieldName: string): string {
    // 处理常见的字段名模式
    const titleMappings: Record<string, string> = {
      'addendum_a': '附录A',
      'addendum_b': '附录B',
      'addendum_c': '附录C',
      'interview_log': '访谈记录',
      'experiment_log': '实验记录',
      'incident_report': '事故报告',
      'recovery_log': '回收记录',
      'exploration_log': '探索记录'
    };

    // 检查是否有直接映射
    const lowerFieldName = fieldName.toLowerCase();
    if (titleMappings[lowerFieldName]) {
      return titleMappings[lowerFieldName];
    }

    // 处理包含中文的字段名（直接使用）
    if (/[\u4e00-\u9fa5]/.test(fieldName)) {
      return fieldName;
    }

    // 处理英文字段名：转换下划线为空格，首字母大写
    return fieldName
      .replace(/_/g, ' ')
      .replace(/\b\w/g, l => l.toUpperCase());
  }

  /**
   * 根据完整编号提取数字部分用于API调用
   * @param fullNumber 完整的SCP编号（如"SCP-049"）
   * @returns 提取的数字部分（如"49"）
   */
  private extractScpNumber(fullNumber: string): string {
    // 从 "SCP-049" 中提取 "49"（去掉前缀与前导零）
    const raw = fullNumber.replace(/^SCP-/i, '');
    return raw.replace(/^0+/, '') || '0';
  }

  /**
   * 加载完整的SCP详情数据
   * @param scpParam 初始的SCP参数数据
   */
  private async loadFullDetail(scpParam: SCP): Promise<void> {
    this.isLoading = true;
    try {
      const numberOnly = this.extractScpNumber(scpParam.number);
      const fullDetail = await scpApi.getScpDetail(numberOnly);

      if (fullDetail) {
        this.scpItem = fullDetail;
      } else {
        console.error('未能获取到SCP详情，使用传入的参数');
        // 如果API获取失败，使用传入的参数作为降级处理
        this.scpItem = scpParam;
      }

      // 生成动态卡片数据
      if (this.scpItem) {
        this.cardDataList = this.generateCardData(this.scpItem);
      }

      // 检查收藏状态
      await this.checkFavoriteStatus();
    } catch (error) {
      console.error('加载SCP详情失败:', error);
      // 发生错误时使用传入的参数
      this.scpItem = scpParam;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 检查当前SCP项目的收藏状态
   */
  private async checkFavoriteStatus(): Promise<void> {
    if (this.scpItem) {
      try {
        this.isFavorited = await FavoriteService.getInstance().isFavorited(this.scpItem.id);
      } catch (error) {
        console.error('检查收藏状态失败:', error);
      }
    }
  }

  /**
   * 切换当前SCP项目的收藏状态
   */
  private async toggleFavorite(): Promise<void> {
    if (!this.scpItem || this.favoriteLoading) {
      return;
    }

    this.favoriteLoading = true;
    try {
      const success = await FavoriteService.getInstance().toggleSCPFavorite(this.scpItem);
      if (success) {
        this.isFavorited = !this.isFavorited;
        const message = this.isFavorited ? '已添加到收藏' : '已取消收藏';
        // 添加振动反馈
        if (this.isFavorited) {
          VibrationUtils.successFeedback(); // 收藏成功
        } else {
          VibrationUtils.lightTap(); // 取消收藏
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
   * 分享当前SCP项目
   */
  private async shareSCP(): Promise<void> {
    if (!this.scpItem) {
      this.promptAction?.showToast({
        message: '暂无可分享的内容'
      });
      return;
    }

    try {
      const context = getContext(this) as common.UIAbilityContext;
      await ShareService.getInstance().shareSCP(context, this.scpItem);
    } catch (error) {
      console.error('分享失败:', error);
      this.promptAction?.showToast({
        message: '分享失败，请重试'
      });
    }
  }
}