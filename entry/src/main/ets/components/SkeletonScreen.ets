/**
 * 骨架屏组件
 * 提供带有流光动画效果的加载占位符
 */

@ComponentV2
export struct SkeletonScreen {
  // 动画状态：流光位置
  @Local private translateX: string = '-100%'
  // 是否显示骨架屏
  @Param visible: boolean = true
  // 骨架屏项目数量
  @Param itemCount: number = 5
  
  // 流光动画
  private startShimmerAnimation(): void {
    animateTo({
      duration: 1500,
      curve: Curve.Linear,
      iterations: -1, // 无限循环
      playMode: PlayMode.Normal
    }, () => {
      this.translateX = '100%'
    })
  }
  
  // 停止动画
  private stopShimmerAnimation(): void {
    this.translateX = '-100%'
  }
  
  // 单个骨架屏项目
  @Builder
  private skeletonItem() {
    Column({ space: 10 }) {
      // 图片骨架
      Stack() {
        // 背景层
        Text()
          .width('100%')
          .height(128)
          .backgroundColor('rgba(255, 255, 255, 0.1)')
          .borderRadius(8)
        
        // 流光层
        Text()
          .width('100%')
          .height(128)
          .borderRadius(8)
          .translate({ x: this.translateX })
          .linearGradient({
            direction: GradientDirection.Right,
            colors: [
              ['rgba(255, 255, 255, 0)', 0],
              ['rgba(255, 255, 255, 0.3)', 0.5],
              ['rgba(255, 255, 255, 0)', 1]
            ]
          })
      }
      .width('100%')
      .height(128)
      .clip(true)
      
      // 内容骨架
      Column({ space: 15 }) {
        // SCP编号和系列骨架
        Row({ space: 10 }) {
          Stack() {
            Text()
              .width(80)
              .height(16)
              .backgroundColor('rgba(255, 255, 255, 0.1)')
              .borderRadius(4)
            
            Text()
              .width(80)
              .height(16)
              .borderRadius(4)
              .translate({ x: this.translateX })
              .linearGradient({
                direction: GradientDirection.Right,
                colors: [
                  ['rgba(255, 255, 255, 0)', 0],
                  ['rgba(255, 255, 255, 0.3)', 0.5],
                  ['rgba(255, 255, 255, 0)', 1]
                ]
              })
          }
          .clip(true)
          
          Stack() {
            Text()
              .width(60)
              .height(14)
              .backgroundColor('rgba(255, 255, 255, 0.08)')
              .borderRadius(4)
            
            Text()
              .width(60)
              .height(14)
              .borderRadius(4)
              .translate({ x: this.translateX })
              .linearGradient({
                direction: GradientDirection.Right,
                colors: [
                  ['rgba(255, 255, 255, 0)', 0],
                  ['rgba(255, 255, 255, 0.2)', 0.5],
                  ['rgba(255, 255, 255, 0)', 1]
                ]
              })
          }
          .clip(true)
        }
        .width('100%')
        
        // 标题骨架
        Stack() {
          Text()
            .width('70%')
            .height(20)
            .backgroundColor('rgba(255, 255, 255, 0.12)')
            .borderRadius(4)
          
          Text()
            .width('70%')
            .height(20)
            .borderRadius(4)
            .translate({ x: this.translateX })
            .linearGradient({
              direction: GradientDirection.Right,
              colors: [
                ['rgba(255, 255, 255, 0)', 0],
                ['rgba(255, 255, 255, 0.3)', 0.5],
                ['rgba(255, 255, 255, 0)', 1]
              ]
            })
        }
        .width('100%')
        .alignContent(Alignment.Start)
        .clip(true)
        
        // 描述骨架（3行）
        Column({ space: 8 }) {
          ForEach([0, 1, 2], (index: number) => {
            Stack() {
              Text()
                .width(index === 2 ? '60%' : '100%')
                .height(14)
                .backgroundColor('rgba(255, 255, 255, 0.08)')
                .borderRadius(4)
              
              Text()
                .width(index === 2 ? '60%' : '100%')
                .height(14)
                .borderRadius(4)
                .translate({ x: this.translateX })
                .linearGradient({
                  direction: GradientDirection.Right,
                  colors: [
                    ['rgba(255, 255, 255, 0)', 0],
                    ['rgba(255, 255, 255, 0.2)', 0.5],
                    ['rgba(255, 255, 255, 0)', 1]
                  ]
                })
            }
            .width('100%')
            .alignContent(Alignment.Start)
            .clip(true)
          })
        }
        .width('100%')
        
        // 标签骨架
        Row({ space: 8 }) {
          ForEach([0, 1, 2], () => {
            Stack() {
              Text()
                .width(50)
                .height(24)
                .backgroundColor('rgba(255, 255, 255, 0.06)')
                .borderRadius(6)
              
              Text()
                .width(50)
                .height(24)
                .borderRadius(6)
                .translate({ x: this.translateX })
                .linearGradient({
                  direction: GradientDirection.Right,
                  colors: [
                    ['rgba(255, 255, 255, 0)', 0],
                    ['rgba(255, 255, 255, 0.2)', 0.5],
                    ['rgba(255, 255, 255, 0)', 1]
                  ]
                })
            }
            .clip(true)
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 30, bottom: 30 })
    }
    .width('100%')
    .backgroundColor('#1e1e1e')
    .borderRadius(10)
    .border({ width: 0.5, color: '#ee717182' })
  }
  
  aboutToAppear(): void {
    if (this.visible) {
      this.startShimmerAnimation()
    }
  }
  
  aboutToDisappear(): void {
    this.stopShimmerAnimation()
  }
  
  build() {
    if (this.visible) {
      Column({ space: 20 }) {
        ForEach(Array.from<number, number>({ length: this.itemCount }, (_, index: number) => index), (item: number) => {
          this.skeletonItem()
        }, (item: number) => item.toString())
      }
      .width('100%')
      .padding({ left: 25, right: 25 })
    }
  }
}