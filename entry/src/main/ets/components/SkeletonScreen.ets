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
  
  // 今日推荐骨架屏
  @Builder
  private recommendationSkeleton() {
    Column({ space: 15 }) {
      // 标题区域骨架
      Row({ space: 10 }) {
        Stack() {
          Text()
            .width(20)
            .height(20)
            .backgroundColor('rgba(255, 255, 255, 0.1)')
            .borderRadius(4)
          
          Text()
            .width(20)
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
        .clip(true)
        
        Stack() {
          Text()
            .width(120)
            .height(18)
            .backgroundColor('rgba(255, 255, 255, 0.12)')
            .borderRadius(4)
          
          Text()
            .width(120)
            .height(18)
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
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ bottom: 15, top: 10 })

      // 内容区域骨架
      Row({ space: 15 }) {
        // 图片骨架
        Stack() {
          Text()
            .width(80)
            .height(80)
            .backgroundColor('rgba(255, 255, 255, 0.1)')
            .borderRadius(8)
          
          Text()
            .width(80)
            .height(80)
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
        .clip(true)
        
        // 文本内容骨架
        Column({ space: 10 }) {
          // SCP编号和等级骨架
          Row({ space: 8 }) {
            Stack() {
              Text()
                .width(70)
                .height(14)
                .backgroundColor('rgba(255, 255, 255, 0.1)')
                .borderRadius(4)
              
              Text()
                .width(70)
                .height(14)
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
                .width(50)
                .height(12)
                .backgroundColor('rgba(255, 255, 255, 0.08)')
                .borderRadius(5)
                .border({ radius: 5, width: 0.8, color: '#ee717182' })
                .padding({ top: 3, bottom: 3, left: 6, right: 6 })
              
              Text()
                .width(50)
                .height(12)
                .borderRadius(5)
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
          
          // 标题骨架
          Stack() {
            Text()
              .width('80%')
              .height(18)
              .backgroundColor('rgba(255, 255, 255, 0.12)')
              .borderRadius(4)
            
            Text()
              .width('80%')
              .height(18)
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
          
          // 描述骨架（2行）
          Column({ space: 6 }) {
            ForEach([0, 1], (index: number) => {
              Stack() {
                Text()
                  .width(index === 1 ? '70%' : '100%')
                  .height(14)
                  .backgroundColor('rgba(255, 255, 255, 0.08)')
                  .borderRadius(4)
                
                Text()
                  .width(index === 1 ? '70%' : '100%')
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
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Top)
      .width('100%')
      .padding({ bottom: 10, left: 10, right: 10 })
    }
    .margin({ top: 10 })
    .padding(15)
    .width('100%')
    .backgroundColor('#22ff4444')
    .border({ radius: 10, width: 0.5, color: '#ee717182' })
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
      .padding({ left: 15, right: 15, top: 15, bottom: 15 })
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
      // .padding({ left: 15, right: 15 })
    }
  }
}

// 今日推荐骨架屏组件
@ComponentV2
export struct RecommendationSkeleton {
  // 动画状态：流光位置
  @Local private translateX: string = '-100%'
  // 是否显示骨架屏
  @Param visible: boolean = true
  
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
      Column({ space: 15 }) {
        // 标题区域骨架
        Row({ space: 10 }) {
          Stack() {
            Text()
              .width(20)
              .height(20)
              .backgroundColor('rgba(255, 255, 255, 0.1)')
              .borderRadius(4)
            
            Text()
              .width(20)
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
          .clip(true)
          
          Stack() {
            Text()
              .width(120)
              .height(18)
              .backgroundColor('rgba(255, 255, 255, 0.12)')
              .borderRadius(4)
            
            Text()
              .width(120)
              .height(18)
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
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ bottom: 15, top: 10 })

        // 内容区域骨架
        Row({ space: 15 }) {
          // 图片骨架
          Stack() {
            Text()
              .width(80)
              .height(80)
              .backgroundColor('rgba(255, 255, 255, 0.1)')
              .borderRadius(8)
            
            Text()
              .width(80)
              .height(80)
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
          .clip(true)
          
          // 文本内容骨架
          Column({ space: 10 }) {
            // SCP编号和等级骨架
            Row({ space: 8 }) {
              Stack() {
                Text()
                  .width(70)
                  .height(14)
                  .backgroundColor('rgba(255, 255, 255, 0.1)')
                  .borderRadius(4)
                
                Text()
                  .width(70)
                  .height(14)
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
                  .width(50)
                  .height(12)
                  .backgroundColor('rgba(255, 255, 255, 0.08)')
                  .borderRadius(5)
                  .border({ radius: 5, width: 0.8, color: '#ee717182' })
                  .padding({ top: 3, bottom: 3, left: 6, right: 6 })
                
                Text()
                  .width(50)
                  .height(12)
                  .borderRadius(5)
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
            
            // 标题骨架
            Stack() {
              Text()
                .width('80%')
                .height(18)
                .backgroundColor('rgba(255, 255, 255, 0.12)')
                .borderRadius(4)
              
              Text()
                .width('80%')
                .height(18)
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
            
            // 描述骨架（2行）
            Column({ space: 6 }) {
              ForEach([0, 1], (index: number) => {
                Stack() {
                  Text()
                    .width(index === 1 ? '70%' : '100%')
                    .height(14)
                    .backgroundColor('rgba(255, 255, 255, 0.08)')
                    .borderRadius(4)
                  
                  Text()
                    .width(index === 1 ? '70%' : '100%')
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
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
        .padding({ bottom: 10, left: 10, right: 10 })
      }
      .margin({ top: 10 })
      .padding(15)
      .width('100%')
      .backgroundColor('#22ff4444')
      .border({ radius: 10, width: 0.5, color: '#ee717182' })
    }
  }
}