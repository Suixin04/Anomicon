import { uiMaterial } from '@kit.ArkUI';
import { AppTypography } from 'anomiconbasic';

/** 文章标题栏下方阅读状态区高度；正文顶部留白必须同步计入。 */
export const ARTICLE_READING_STATUS_HEIGHT: number = 40;

/**
 * 阅读状态只消费已确认状态：圆环表示本文阅读进度，右侧显示账本派生的等级与总经验。
 * 组件本身使用沉浸系统材质；bottomBuilder 只负责把它接入 HDS 标题栏。
 */
@ComponentV2
export struct ArticleReadingStatusBar {
  @Require @Param progress: number;
  @Require @Param level: number;
  @Require @Param experience: number;
  @Require @Param contentReady: boolean;
  @Param compactProfile: boolean = false;
  @Param materialEnabled: boolean = true;

  private readonly material: uiMaterial.ImmersiveMaterial =
    new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      applyShadow: false
    });

  private normalizedProgress(): number {
    if (!Number.isFinite(this.progress)) {
      return 0;
    }
    return Math.max(0, Math.min(100, Math.round(this.progress)));
  }

  private normalizedInteger(value: number, minimum: number = 0): number {
    if (!Number.isFinite(value)) {
      return minimum;
    }
    return Math.max(minimum, Math.floor(value));
  }

  build() {
    Row() {
      Row({ space: 9 }) {
        Progress({
          value: this.contentReady ? this.normalizedProgress() : 0,
          total: 100,
          type: ProgressType.Ring
        })
          .width(24)
          .height(24)
          .color($r('sys.color.icon_emphasize'))
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .style({
            strokeWidth: 3,
            enableSmoothEffect: true,
            shadow: false
          })

        Text(this.contentReady ? `已读 ${this.normalizedProgress()}%` : '正在准备正文')
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
          .maxLines(1)

        Blank()

        if (this.compactProfile) {
          Text(`Lv.${this.normalizedInteger(this.level, 1)} · ${this.normalizedInteger(this.experience)} XP`)
            .fontSize(AppTypography.CAPTION_M)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
        } else {
          Text(`Lv.${this.normalizedInteger(this.level, 1)}`)
            .fontSize(AppTypography.CAPTION_L)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_emphasize'))
            .maxLines(1)

          Text(`${this.normalizedInteger(this.experience)} XP`)
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
        }
      }
      .width('100%')
      .height(32)
      .padding({ left: 12, right: 12 })
      .borderRadius(16)
      .backgroundColor(this.materialEnabled ?
        Color.Transparent : $r('sys.color.comp_background_primary'))
      .systemMaterial(this.materialEnabled ? this.material : undefined)
      .accessibilityText(
        this.contentReady ?
          `本文已读${this.normalizedProgress()}%，等级${this.normalizedInteger(this.level, 1)}，` +
            `总经验${this.normalizedInteger(this.experience)}` :
          '正在准备正文阅读状态'
      )
    }
    .width('100%')
    .height(ARTICLE_READING_STATUS_HEIGHT)
    .padding({ left: 16, right: 16, bottom: 8 })
  }
}
