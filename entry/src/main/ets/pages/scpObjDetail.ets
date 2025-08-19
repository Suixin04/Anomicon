import { CollapsibleCard } from "../utils/CollapsibleCard";
import { ImageWithLoading, SCP, CollapsibleCardData } from "../utils/types";
import { scpApi } from "../utils/ScpApi";
import { FavoriteService } from "../common/service/FavoriteService";
import { ShareService } from "../common/service/ShareService";
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

// SCP对象详情页面构建器
@Builder
export function ObjBuilder() {
  scpObjDetail()
}

// 自定义标题构建器
@Builder
function cusTitle(scp: SCP | null) {
  if (!scp) {
    Column() {
      Text('加载中...')
        .fontColor('#fff')
        .fontSize(16)
    }
    .margin({ left: 10 })
    .alignItems(HorizontalAlign.Start)
    .height('100%')
  } else {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(scp.number)
          .fontColor('#ff4444')
          .fontSize(14)
          .fontWeight(FontWeight.Normal)
        Text(scp.objectClass)
          .border({ radius: 5, width: 0.8, color: '#ee717182' })
          .fontWeight(FontWeight.Bold)
          .fontColor('#fff')
          .fontSize(12)
          .padding({ top: 3, bottom: 3, left: 6, right: 6 })
      }
      .width('100%')
      Text(scp.title)
        .fontColor('#fff')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
    }
    .margin({ left: 10 })
    .alignItems(HorizontalAlign.Start)
    .height('100%')
  }
}

// SCP对象详情页面组件
@Entry
@ComponentV2
@Preview
struct scpObjDetail {
  // 导航路径栈，用于页面导航
  pathStack: NavPathStack = new NavPathStack();
  // 当前显示的SCP项目，初始为null，待API加载
  @Local scpItem: SCP | null = null;
  // 加载状态
  @Local isLoading: boolean = true;
  // 收藏状态
  @Local isFavorited: boolean = false;
  // 收藏操作加载状态
  @Local favoriteLoading: boolean = false;
  // 动态卡片数据
  @Local cardDataList: CollapsibleCardData[] = [];

  // 生成动态卡片数据
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

  // 格式化字段标题，将API字段名转换为用户友好的标题
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

  // 根据 number 提取数字部分用于API调用
  private extractScpNumber(fullNumber: string): string {
    // 从 "SCP-049" 中提取 "49"（去掉前缀与前导零）
    const raw = fullNumber.replace(/^SCP-/i, '');
    return raw.replace(/^0+/, '') || '0';
  }

  // 加载完整的SCP详情
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

  // 检查收藏状态
  private async checkFavoriteStatus(): Promise<void> {
    if (this.scpItem) {
      try {
        this.isFavorited = await FavoriteService.getInstance().isFavorited(this.scpItem.id);
      } catch (error) {
        console.error('检查收藏状态失败:', error);
      }
    }
  }

  // 切换收藏状态
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

  // 分享SCP项目
  private async shareSCP(): Promise<void> {
    if (!this.scpItem) {
      promptAction.showToast({
        message: '暂无可分享的内容'
      });
      return;
    }

    try {
      const context = getContext(this) as common.UIAbilityContext;
      await ShareService.getInstance().shareSCP(context, this.scpItem);
    } catch (error) {
      console.error('分享失败:', error);
      promptAction.showToast({
        message: '分享失败，请重试'
      });
    }
  }

  build() {
    NavDestination() {
      if (this.isLoading || !this.scpItem) {
        // 加载状态
        Column() {
          Text('正在加载详情...')
            .fontColor('#fff')
            .fontSize(16)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#121212')
      } else {
        Scroll() {
          Column({space: 20}) {
            Column({ space: 15 }) {
              // SCP项目图片，使用ImageWithLoading组件支持加载状态显示
              ImageWithLoading({src: this.scpItem.image, imgWidth: '100%', imgHeight: '100%', imgRadius: 0})
            }
            .height(200)
            .width('100%')
            .border({width: 0.5, color: '#ee717182', radius: 10})
            // 项目信息网格布局
            GridRow({columns: 2}) {
              GridCol() {
                Column() {
                  Row() {
                    Text('项目等级:')
                      .fontSize(14)
                      .fontColor('#a0a0a0')
                  }.width('100%')
                  Row() {
                    Text(this.scpItem.objectClass)
                      .margin({top: 5})
                      .border({radius: 5, width: 0.8, color: '#ee717182'})
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#fff')
                      .fontSize(12)
                      .padding({top: 3, bottom: 3, left: 6, right: 6})
                  }
                  .width('100%')
                }
                .width('100%')
              }
              GridCol({ span: 1 }) {
                Column() {
                  Row() {
                    Text('系列:')
                      .fontSize(14)
                      .fontColor('#a0a0a0')
                  }.width('100%')
                  Row() {
                    Text(`Series ${this.scpItem.series.toString()}`)
                      .margin({top: 5})
                      .fontColor('#fff')
                  }
                  .width('100%')
                }
                .width('100%')
              }
              GridCol({ span: 1 }) {
                Column() {
                  Row() {
                    Text('添加日期:')
                      .margin({top: 15})
                      .fontSize(14)
                      .fontColor('#a0a0a0')
                  }.width('100%')
                  Row() {
                    Text(this.scpItem.dateAdded)
                      .fontSize(14)
                      .margin({top: 5})
                      .fontColor('#fff')
                  }
                  .width('100%')
                }
                .width('100%')
              }
              GridCol({ span: 1 }) {
                Column() {
                  Row() {
                    Text('标签:')
                      .margin({top: 15})
                      .fontSize(14)
                      .fontColor('#a0a0a0')
                  }.width('100%')
                  // 标签列表
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.scpItem.tags, (tag: string, index: number) => {
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
                }
                .width('100%')
              }
            }
            .border({width: 0.5, color: '#ee717182', radius: 10})
            .width('100%')
            .backgroundColor('#1e1e1e')
            .padding(25)

            // 动态渲染折叠卡片
            ForEach(this.cardDataList, (cardData: CollapsibleCardData, index: number) => {
              CollapsibleCard({
                title: cardData.title,
                content: cardData.content,
                defaultExpanded: cardData.title == '项目描述' ? true : false
              })
            }, (cardData: CollapsibleCardData, index: number) => `${cardData.title}-${index}`)
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
    }
    .title(cusTitle(this.scpItem))
    .backgroundColor('#121212')
    .backButtonIcon($r("app.media.arrow_left"))
    // 页面菜单
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
        icon: this.isFavorited ? $r('app.media.heart') : $r('app.media.heart_em'),
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
      const param = context.pathInfo.param as SCP;
      if (param) {
        // 立即加载完整详情
        this.loadFullDetail(param);
      } else {
        console.error('未收到SCP参数');
        this.isLoading = false;
      }
    })
  }
}