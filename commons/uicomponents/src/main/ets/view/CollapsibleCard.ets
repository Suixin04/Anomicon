import { curves } from '@kit.ArkUI';
import { FontSizeManager } from 'utils';

// 可折叠卡片组件，用于显示可展开/折叠的内容
@ComponentV2
@Preview
export struct CollapsibleCard {
  // 卡片标题（必需参数）
  @Param @Require title: string = '';
  // 卡片内容（必需参数，支持字符串或字符串数组）
  @Param @Require content: string | Array<string>;
  // 默认展开状态（可选参数）
  @Param defaultExpanded: boolean = false;
  // 卡片展开状态，优先使用defaultExpanded参数，否则默认只有"项目描述"是展开的
  @Local private isExpanded: boolean =
    this.defaultExpanded !== undefined ? this.defaultExpanded : (this.title == '项目描述' ? true : false);
  // 展开/折叠按钮图标
  private arrowIcon: Resource = $r('app.media.ic_arrow_down');

  build() {
    // 主容器
    Column() {
      // 标题栏，包含标题和展开/折叠图标
      Row({ space: 10 }) {
        // 标题图标
        Image($r('app.media.file_text'))
          .width(20)

        // 标题文本
        Text(this.title)
          .fontColor($r('app.color.text_primary'))
          .fontSize(FontSizeManager.getScaledFontSize(20))
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)

        // 展开/折叠箭头图标，带旋转动画
        Image(this.arrowIcon)
          .width(24)
          .height(24)
          .rotate({ angle: this.isExpanded ? 180 : 0 })
          .animation({ curve: curves.interpolatingSpring(0, 1, 228, 22) })
      }
      .width('100%')
      .padding({
        top: 10,
        bottom: 10,
        left: 15,
        right: 15
      })
      .backgroundColor($r('app.color.background_secondary'))
      // 动态设置边框圆角，当展开时顶部有圆角，底部无圆角
      .border({
        radius: this.isExpanded ? {
          topLeft: 10,
          topRight: 10,
          bottomLeft: 0,
          bottomRight: 0
        } : 10
      })
      .animation({ curve: curves.interpolatingSpring(0, 1, 528, 39) })
      // 点击事件处理，添加动画效果
      .onClick(() => {
        this.getUIContext()?.animateTo({ curve: curves.interpolatingSpring(0, 1, 528, 39) }, () => {
          this.isExpanded = !this.isExpanded;
        });
      })

      // 内容区域，仅在展开时显示
      if (this.isExpanded) {
        Column() {
          // 内容部分，根据内容类型（字符串或数组）进行渲染
          if (this.content instanceof Array) {
            // 如果是字符串数组，使用ForEach循环渲染
            ForEach(this.content, (item: string) => {
              Text(item)
                .fontSize(FontSizeManager.getScaledFontSize(16))
                .fontColor($r('app.color.text_primary'))
                .lineHeight(24)
                .textAlign(TextAlign.JUSTIFY)
                .margin({ bottom: 10 })
            })
          } else {
            // 如果是单个字符串，直接渲染
            Text(this.content)
              .fontSize(FontSizeManager.getScaledFontSize(16))
              .fontColor($r('app.color.text_primary'))
              .lineHeight(24)
              .textAlign(TextAlign.JUSTIFY)
              .margin({ bottom: 10 })
          }
        }
        .width('100%')
        .padding(15)
        .backgroundColor($r('app.color.background_secondary'))
        // 设置内容区域的底部圆角
        .border({
          radius: {
            topLeft: 0,
            topRight: 0,
            bottomLeft: 10,
            bottomRight: 10
          }
        })
        // 添加展开动画效果
        .animation({ curve: curves.interpolatingSpring(0, 1, 528, 39) })
        // 添加过渡动画效果
        .transition({
          type: TransitionType.All,
          scale: { x: 1, y: 0 },
          opacity: 0
        })
      }
    }
    .width('100%')
    // 设置整体边框和阴影效果
    .border({ width: 0.5, color: $r('app.color.border_primary'), radius: 10 })
    .shadow({
      radius: 8,
      color: $r('app.color.shadow_light'),
      offsetX: 0,
      offsetY: 4
    })
  }
}