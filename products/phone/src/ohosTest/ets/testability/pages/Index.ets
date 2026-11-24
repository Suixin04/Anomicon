import { ArchiveStageControls } from '../../../../main/ets/pages/ArchiveStageControls';

/** Test-only host for exercising the viewer's controls without loading a native scene. */
@Entry
@ComponentV2
struct Index {
  @Local private autoRotate: boolean = false;
  @Local private materialEnabled: boolean = true;
  @Local private resets: number = 0;

  build() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        Text('沉浸光感').fontColor($r('sys.color.font'));
        Toggle({ type: ToggleType.Switch, isOn: this.materialEnabled })
          .id('archiveControlsMaterial')
          .onChange((enabled: boolean) => this.materialEnabled = enabled);
      }
      ArchiveStageControls({
        autoRotate: this.autoRotate,
        materialEnabled: this.materialEnabled,
        onToggleRotation: () => { this.autoRotate = !this.autoRotate; },
        onReset: () => { this.resets++; }
      });
      Text(`复位次数 ${this.resets}`).fontColor($r('sys.color.font_secondary'));
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.background_secondary'));
  }
}
