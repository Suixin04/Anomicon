import {
  accentPillBackgroundColor,
  accentPillForegroundColor,
  badgeInfoBackgroundColor,
  badgeInfoForegroundColor
} from 'anomiconbasic';

/** Used below the scene in both layouts and runnable independently of ArkGraphics3D. */
@ComponentV2
export struct ArchiveStageControls {
  @Require @Param autoRotate: boolean;
  @Require @Param materialEnabled: boolean;
  @Event onToggleRotation: () => void;
  @Event onReset: () => void;

  build() {
    Row({ space: 8 }) {
      Button(this.autoRotate ? '停止自动旋转' : '自动旋转', { stateEffect: false })
        .id('archiveToggleRotation')
        .height(36)
        .fontSize(12)
        .fontColor(this.autoRotate ? accentPillForegroundColor() : badgeInfoForegroundColor())
        .backgroundColor(this.autoRotate ? accentPillBackgroundColor() : badgeInfoBackgroundColor())
        .border({ width: 1, color: $r('app.color.archive_button_outline') })
        .onClick(() => this.onToggleRotation());
      Blank().layoutWeight(1);
      Button('复位', { stateEffect: false })
        .id('archiveResetView')
        .height(36)
        .fontSize(12)
        .fontColor($r('app.color.archive_reset_text'))
        .backgroundColor($r('app.color.archive_reset_fill'))
        .border({ width: 1, color: $r('app.color.archive_button_outline') })
        .onClick(() => this.onReset());
    }
    .id('archiveStageControls')
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 12 })
    .borderRadius(18)
    .backgroundColor(this.materialEnabled ? $r('app.color.archive_controls_glass') : $r('app.color.archive_controls_surface'))
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_THIN : undefined)
    .border({ width: 1, color: $r('app.color.archive_controls_outline') })
    .accessibilityText('三维模型控制：自动旋转与复位');
  }
}
