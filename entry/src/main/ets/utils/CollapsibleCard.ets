// 可折叠卡片组件，用于显示可展开/折叠的内容
@ComponentV2
@Preview
export struct CollapsibleCard {
  // 卡片标题（必需参数）
  @Param @Require title: string = '';
  // 卡片内容（必需参数，支持字符串或字符串数组）
  @Param @Require content: string | Array<string>; 
  // 卡片展开状态，默认只有"项目描述"是展开的
  @Local private isExpanded: boolean = this.title == '项目描述' ? true : false;

  // 展开/折叠按钮图标
  private expandedIcon: Resource = $r('app.media.ic_arrow_up');
  private collapsedIcon: Resource = $r('app.media.ic_arrow_down');

  build() {
    Column() {
      // 标题行，点击可切换展开/折叠状态
      Row({space: 10}) {
        Image($r('app.media.file_text'))
          .width(20)

        Text(this.title)
          .fontColor('#fff')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)

        // 根据展开状态显示不同图标
        Image(this.isExpanded ? this.expandedIcon : this.collapsedIcon)
          .width(24)
          .height(24)
      }
      .width('100%')
      .padding({ top: 10, bottom: 10, left: 15, right: 15 })
      .backgroundColor('#1e1e1e')
      // 根据展开状态动态设置圆角
      .border({ radius: this.isExpanded ? { topLeft: 10, topRight: 10, bottomLeft: 0, bottomRight: 0 } : 10 })
      .onClick(() => {
        // 添加动画效果
        animateTo({ duration: 300 }, () => {
          this.isExpanded = !this.isExpanded;
        });
      })

      // 内容区域，根据 isExpanded 状态显示或隐藏
      if (this.isExpanded) {
        Column() {
          // 如果内容是数组，则循环渲染
          if (this.content instanceof Array) {
            ForEach(this.content, (item: string) => {
              Text(item)
                .fontSize(16)
                .fontColor('#fff')
                .lineHeight(24)
                .margin({ bottom: 10 })
            })
          } else {
            // 如果内容是单个字符串
            Text(this.content)
              .fontSize(16)
              .fontColor('#fff')
              .lineHeight(24)
              .margin({ bottom: 10 })
          }
        }
        .width('100%')
        .padding(15)
        .backgroundColor('#1e1e1e')
        // 为内容区域设置底部圆角
        .border({ radius: { topLeft: 0, topRight: 0, bottomLeft: 10, bottomRight: 10 } })
        .transition({
          type: TransitionType.All,
          scale: { x: 1, y: 1 },
          opacity: 1
        })
      }
    }
    .width('100%')
    .border({ width: 0.5, color: '#ee717182', radius: 10})
    .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 4 })
  }
}