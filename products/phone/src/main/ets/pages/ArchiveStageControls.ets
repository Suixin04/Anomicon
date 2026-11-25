@Extend(Button)
function stageButton(fill: ResourceColor) {
  .width(44)
  .height(44)
  .padding(0)
  .backgroundColor(fill)
  .border({ width: 1, color: $r('app.color.archive_button_outline') })
  .hitTestBehavior(HitTestMode.Block)
}

/** The stage stays dark in both themes. Only the circular button fills are translucent. */
@ComponentV2
export struct ArchiveStageControls {
  @Require @Param autoRotate: boolean;
  @Require @Param materialEnabled: boolean;
  @Event onToggleRotation: () => void;
  @Event onReset: () => void;

  private buttonFill(active: boolean): ResourceColor {
    if (active) {
      return this.materialEnabled ? $r('app.color.archive_button_active_glass') : $r('app.color.archive_button_active');
    }
    return this.materialEnabled ? $r('app.color.archive_button_glass') : $r('app.color.archive_button_fill');
  }

  build() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph(this.autoRotate ? $r('sys.symbol.pause_fill') : $r('sys.symbol.a_360_rotation'))
          .fontSize(22)
          .fontColor([Color.White]);
      }
      .id('archiveToggleRotation')
      .stageButton(this.buttonFill(this.autoRotate))
      .accessibilityText(this.autoRotate ? '暂停自动旋转' : '开启自动旋转')
      .accessibilitySelected(this.autoRotate)
      .onClick(() => this.onToggleRotation());

      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.arrow_counterclockwise'))
          .fontSize(20)
          .fontColor([Color.White]);
      }
      .id('archiveResetView')
      .stageButton(this.buttonFill(false))
      .accessibilityText('复位模型视角')
      .onClick(() => this.onReset());
    }
    .id('archiveStageControls')
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: 12, right: 12 })
    .position({ left: 0, bottom: 12 })
    // Let fingers between the buttons reach the stage's pan and pinch recognizers.
    .hitTestBehavior(HitTestMode.None);
  }
}
