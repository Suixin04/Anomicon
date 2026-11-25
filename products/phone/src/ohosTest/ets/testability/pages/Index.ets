import { ArchiveStageControls } from '../../../../main/ets/pages/ArchiveStageControls';

/** The test stage uses a still from the project's SCP-049 showcase to exercise the production overlay. */
@Entry
@ComponentV2
struct Index {
  @Local private autoRotate: boolean = false;
  @Local private materialEnabled: boolean = true;
  @Local private resets: number = 0;
  @Local private pans: number = 0;
  @Local private pinches: number = 0;

  build() {
    Column({ space: 12 }) {
      Text('SCP-049 · 静帧控件预览').fontColor($r('sys.color.font'));
      Stack({ alignContent: Alignment.Top }) {
        Image($r('app.media.archive_049_still'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .gesture(PanGesture({ fingers: 1, distance: 3 }).onActionStart(() => {
            this.pans++;
            this.autoRotate = false;
          }))
          .gesture(PinchGesture({ fingers: 2, distance: 5 }).onActionStart(() => {
            this.pinches++;
            this.autoRotate = false;
          }));
        ArchiveStageControls({
          autoRotate: this.autoRotate,
          materialEnabled: this.materialEnabled,
          onToggleRotation: () => { this.autoRotate = !this.autoRotate; },
          onReset: () => {
            this.resets++;
            this.autoRotate = false;
          }
        });
      }
      .id('archiveControlsTestStage')
      .width('100%')
      .height(388)
      .constraintSize({ maxHeight: '62%' })
      .backgroundColor('#272E41')
      .borderRadius(24)
      .clip(true);

      Row({ space: 12 }) {
        Text('沉浸光感').fontColor($r('sys.color.font'));
        Toggle({ type: ToggleType.Switch, isOn: this.materialEnabled })
          .id('archiveControlsMaterial')
          .onChange((enabled: boolean) => this.materialEnabled = enabled);
      }
      Text(`复位 ${this.resets} · 拖动 ${this.pans} · 捏合 ${this.pinches}`)
        .id('archiveControlsEvents')
        .fontColor($r('sys.color.font_secondary'));
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.background_secondary'));
  }
}
