import { ImageWithLoadingView } from './ImageWithLoading'
import { curves } from '@kit.ArkUI'
import { RecommendationSkeleton } from './SkeletonScreen'
import { FontSizeManager, getColorsByClass, SCP } from 'utils'

/**
 * 今日推荐组件 - 展示每日推荐的SCP项目
 * @param recommendedScp 推荐的SCP项目数据
 * @param isLoading 是否正在加载状态
 * @param onRecommendationClick 点击推荐项的回调函数
 */
@ComponentV2
export struct RecommendationView {
  @Param recommendedScp: SCP | null = null
  @Param isLoading: boolean = false
  @Local private scaleValue: number = 1.0

  @Param onRecommendationClick: (scp: SCP) => void = () => {
  }

  build() {
    if (this.isLoading && !this.recommendedScp) {
      RecommendationSkeleton({ visible: true })
    } else {
      Column({ space: 15 }) {
        Row({ space: 10 }) {
          Image($r('app.media.star'))
            .fillColor($r('app.color.icon_warning'))
            .width(20)
          Text('今日推荐 SCP')
            .fontSize(FontSizeManager.getScaledFontSize(18))
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ bottom: 15, top: 10 })

        Row({ space: 15 }) {
          ImageWithLoadingView({
            src: this.recommendedScp?.image,
            imgWidth: 80,
            imgHeight: 80,
            imgRadius: {
              topLeft: 8,
              topRight: 8,
              bottomLeft: 8,
              bottomRight: 8
            }
          })
          Column({ space: 10 }) {
            Row({ space: 8 }) {
              Text(this.recommendedScp?.number ?? '')
                .fontColor($r('app.color.primary_color'))
                .fontSize(FontSizeManager.getScaledFontSize(14))
                .fontWeight(FontWeight.Bold)

              Blank()
                .layoutWeight(1)

              Text(this.recommendedScp?.objectClass ?? '')
                .border({
                  radius: 5,
                  width: 0.8,
                  color: getColorsByClass(this.recommendedScp?.objectClass ?? '').borderColor
                })
                .fontWeight(FontWeight.Bold)
                .fontColor(getColorsByClass(this.recommendedScp?.objectClass ?? '').textColor)
                .backgroundColor(getColorsByClass(this.recommendedScp?.objectClass ?? '').backgroundColor)
                .fontSize(FontSizeManager.getScaledFontSize(12))
                .padding({
                  top: 3,
                  bottom: 3,
                  left: 6,
                  right: 6
                })
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }

            Text(this.recommendedScp?.title ?? '')
              .fontColor($r('app.color.text_primary'))
              .fontSize(FontSizeManager.getScaledFontSize(18))
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.recommendedScp?.description ?? '')
              .fontColor($r('app.color.text_secondary'))
              .fontSize(FontSizeManager.getScaledFontSize(14))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.JUSTIFY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
        .padding({ bottom: 10, left: 10, right: 10 })
        .onClick(() => {
          if (this.recommendedScp) {
            this.onRecommendationClick(this.recommendedScp)
          }
        })
      }
      .margin({ top: 10 })
      .padding(15)
      .width('100%')
      .backgroundColor($r('app.color.overlay_medium'))
      .border({ radius: 10, width: 0.5, color: $r('app.color.border_primary') })
      .scale({ x: this.scaleValue, y: this.scaleValue })
      .animation({
        duration: 150,
        curve: Curve.EaseOut
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          animateTo({
            duration: 150,
            curve: Curve.EaseOut
          }, () => {
            this.scaleValue = 0.98
          })
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          animateTo({
            duration: 200,
            curve: curves.springMotion(0.6, 0.8)
          }, () => {
            this.scaleValue = 1.0
          })
        }
      })
    }
  }
}
