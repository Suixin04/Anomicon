import {
  uiMaterial,
  CapsuleSegmentButtonV2,
  SegmentButtonV2ItemOptions,
  SegmentButtonV2Items,
  ColorMetrics,
  LengthMetrics
} from '@kit.ArkUI';
import { AppTypography } from 'anomiconbasic';
import { ThemeMode } from '../../domain/SettingsModels';

/** Generic capsule segmented selector shared by theme, alignment and complex-page policy. */
@ComponentV2
export struct SettingsSegmentSelector {
  @Require @Param labels: string[];
  @Require @Param selectedIndex: number;
  @Require @Param hapticEnabled: boolean;
  /** Injected side effect; the control itself stays platform agnostic. */
  @Param onHaptic: ((enabled: boolean) => void) | undefined = undefined;
  @Event onSelectIndex: (index: number) => void;

  @Local private items: SegmentButtonV2Items = new SegmentButtonV2Items([]);

  aboutToAppear(): void {
    this.syncItems();
  }

  @Monitor('labels')
  private onLabelsChange(): void {
    this.syncItems();
  }

  private syncItems(): void {
    const options: SegmentButtonV2ItemOptions[] = [];
    for (let index = 0; index < this.labels.length; index++) {
      options.push({ text: this.labels[index] });
    }
    this.items = new SegmentButtonV2Items(options);
  }

  private normalizedIndex(): number {
    if (this.labels.length === 0) {
      return 0;
    }
    return Math.max(0, Math.min(this.labels.length - 1, this.selectedIndex));
  }

  private select(index: number): void {
    if (index === this.normalizedIndex()) {
      return;
    }
    this.onHaptic?.(this.hapticEnabled);
    this.onSelectIndex(index);
  }

  private resourceColor(value: ResourceColor, fallback: number): ColorMetrics {
    try {
      return ColorMetrics.resourceColor(value);
    } catch (_error) {
      // 系统颜色资源在定制设备上可能缺失，保留可读的数值颜色兜底。
      return ColorMetrics.numeric(fallback);
    }
  }

  build() {
    CapsuleSegmentButtonV2({
      items: this.items,
      selectedIndex: this.normalizedIndex(),
      $selectedIndex: (index: number) => this.select(index),
      itemFontColor: this.resourceColor($r('sys.color.font_primary'), 0xff182431),
      itemSelectedFontColor: this.resourceColor($r('sys.color.font_on_primary'), 0xffffffff),
      itemFontSize: LengthMetrics.fp(14),
      itemSelectedFontSize: LengthMetrics.fp(14),
      itemFontWeight: FontWeight.Medium,
      itemSelectedFontWeight: FontWeight.Medium,
      itemSelectedBackgroundColor: this.resourceColor($r('sys.color.comp_background_emphasize'), 0xff0a59f7),
      buttonBackgroundColor: this.resourceColor($r('sys.color.comp_background_tertiary'), 0xffe9eef5),
      itemBorderRadius: LengthMetrics.vp(20),
      buttonBorderRadius: LengthMetrics.vp(20),
      // 轨道高度贴合内容：buttonPadding(4) + itemMinHeight(40) + buttonPadding(4) = 48vp，
      // 与旧自绘控件（48 容器 / 40 指示器 / 4 内衬）一致。buttonMinHeight 会把轨道撑高
      // 而 item 顶部对齐、不拉伸，造成底部空档，故不用它。
      itemMinHeight: LengthMetrics.vp(40),
      buttonPadding: LengthMetrics.vp(4),
      itemPadding: {
        top: LengthMetrics.vp(4),
        end: LengthMetrics.vp(4),
        bottom: LengthMetrics.vp(4),
        start: LengthMetrics.vp(4)
      }
    })
      .width('100%')
  }
}

@ComponentV2
export struct SettingsThemeSelector {
  @Require @Param value: ThemeMode;
  @Require @Param hapticEnabled: boolean;
  /** Injected side effect; the control itself stays platform agnostic. */
  @Param onHaptic: ((enabled: boolean) => void) | undefined = undefined;
  @Event onThemeChange: (value: ThemeMode) => void;

  private readonly labels: string[] = ['跟随系统', '浅色', '深色'];

  private selectedIndex(): number {
    if (this.value === ThemeMode.LIGHT) {
      return 1;
    }
    if (this.value === ThemeMode.DARK) {
      return 2;
    }
    return 0;
  }

  private modeAt(index: number): ThemeMode {
    if (index === 1) {
      return ThemeMode.LIGHT;
    }
    if (index === 2) {
      return ThemeMode.DARK;
    }
    return ThemeMode.SYSTEM;
  }

  build() {
    SettingsSegmentSelector({
      labels: this.labels,
      selectedIndex: this.selectedIndex(),
      hapticEnabled: this.hapticEnabled,
      onHaptic: this.onHaptic,
      onSelectIndex: (index: number): void => this.onThemeChange(this.modeAt(index))
    })
  }
}

@ComponentV2
export struct SettingsMaterialToggle {
  @Require @Param isOn: boolean;
  @Require @Param materialEnabled: boolean;
  @Event onChange: (value: boolean) => void;

  // Keep one material instance for the lifetime of this wrapper. Recreating the
  // material object during unrelated state refreshes causes the native switch
  // to re-enter its material rendering path.
  private readonly material: uiMaterial.Material = new uiMaterial.Material();

  @Builder
  private toggle(material: uiMaterial.Material | undefined) {
    Toggle({ type: ToggleType.Switch, isOn: this.isOn })
      .systemMaterial(material)
      .switchPointColor($r('sys.color.ohos_id_color_foreground_contrary'))
      .onChange((value: boolean) => this.onChange(value))
  }

  build() {
    // systemMaterial(undefined) is the SDK-defined way to leave material mode.
    // Branch directly on the param: separate branches recreate only the native
    // Toggle when the mode changes, without rebuilding the surrounding settings
    // page. No deferred mirror state keeps a stale material style alive.
    if (this.materialEnabled) {
      this.toggle(this.material)
    } else {
      this.toggle(undefined)
    }
  }
}

@ComponentV2
export struct SettingsMagneticSlider {
  @Require @Param value: number;
  @Require @Param min: number;
  @Require @Param max: number;
  @Require @Param step: number;
  @Require @Param detents: number[];
  @Require @Param labels: string[];
  @Require @Param materialEnabled: boolean;
  @Require @Param hapticEnabled: boolean;
  @Param onHaptic: ((enabled: boolean) => void) | undefined = undefined;
  @Event onValueChange: (value: number, mode: SliderChangeMode) => void;

  @Local private sliderValue: number = 0;
  @Local private trackWidth: number = 0;

  private readonly sliderInset: number = 6;
  private readonly trackThickness: number = 20;
  private readonly labelWidth: number = 32;
  private readonly material: uiMaterial.Material = new uiMaterial.Material();
  private activeDetent: number = -1;
  private interacting: boolean = false;

  aboutToAppear(): void {
    this.syncFromValue();
  }

  /** Keep the native slider mirror aligned when another consumer changes the setting. */
  @Monitor('value')
  private onValueChanged(): void {
    if (!this.interacting) {
      this.syncFromValue();
    }
  }

  private syncFromValue(): void {
    this.sliderValue = this.normalize(this.value) / this.step;
  }

  private displayValue(): number {
    return this.normalize(this.sliderValue * this.step);
  }

  private setDisplayValue(value: number): void {
    this.sliderValue = this.normalize(value) / this.step;
  }

  private normalize(value: number): number {
    const stepped = Math.round(value / this.step) * this.step;
    return Math.max(this.min, Math.min(this.max, stepped));
  }

  private valueRatio(value: number): number {
    if (this.max <= this.min) {
      return 0;
    }
    return Math.max(0, Math.min(1, (value - this.min) / (this.max - this.min)));
  }

  private xForValue(value: number): number {
    const valueInset = this.sliderInset + this.trackThickness / 2;
    return valueInset + Math.max(0, this.trackWidth - valueInset * 2) * this.valueRatio(value);
  }

  private isThumbAt(detent: number): boolean {
    return Math.abs(detent - this.displayValue()) < this.step / 2;
  }

  private nearestDetent(value: number): number {
    let nearest = this.detents[0];
    let distance = Math.abs(value - nearest);
    for (let index: number = 1; index < this.detents.length; index++) {
      const nextDistance = Math.abs(value - this.detents[index]);
      if (nextDistance < distance) {
        nearest = this.detents[index];
        distance = nextDistance;
      }
    }
    return nearest;
  }

  private captureRange(): number {
    return Math.max(this.step * 2, (this.max - this.min) * 0.01);
  }

  private releaseRange(): number {
    return Math.max(this.step * 5, (this.max - this.min) * 0.0225);
  }

  private magneticValue(value: number): number {
    const normalized = this.normalize(value);
    if (this.activeDetent >= 0) {
      if (Math.abs(normalized - this.activeDetent) <= this.releaseRange()) {
        return this.activeDetent;
      }
      this.activeDetent = -1;
    }

    const nearest = this.nearestDetent(normalized);
    if (Math.abs(normalized - nearest) <= this.captureRange()) {
      this.activeDetent = nearest;
      this.onHaptic?.(this.hapticEnabled);
      return nearest;
    }
    return normalized;
  }

  private handleChange(value: number, mode: SliderChangeMode): void {
    const actualValue = value * this.step;
    if (mode === SliderChangeMode.Begin) {
      this.interacting = true;
      this.activeDetent = -1;
      this.setDisplayValue(actualValue);
      this.onValueChange(this.displayValue(), mode);
      return;
    }

    if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click) {
      this.setDisplayValue(this.magneticValue(actualValue));
      this.onValueChange(this.displayValue(), mode);
      return;
    }

    this.setDisplayValue(this.magneticValue(actualValue));
    this.onValueChange(this.displayValue(), SliderChangeMode.End);
    this.activeDetent = -1;
    this.interacting = false;
  }

  @Builder
  private slider(material: uiMaterial.Material | undefined) {
    Slider({
      value: this.sliderValue!!,
      min: this.min / this.step,
      max: this.max / this.step,
      step: 1,
      style: SliderStyle.InSet
    })
      .width('100%')
      .trackThickness(this.trackThickness)
      .selectedColor($r('sys.color.comp_background_emphasize'))
      .trackColor($r('sys.color.comp_background_tertiary'))
      .blockColor($r('sys.color.ohos_id_color_foreground_contrary'))
      .sliderInteractionMode(SliderInteraction.SLIDE_AND_CLICK)
      .enableHapticFeedback(false)
      .systemMaterial(material)
      .onChange((value: number, mode: SliderChangeMode) => this.handleChange(value, mode))
  }

  build() {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.Center }) {
        // Material is a creation-time rendering mode for the native Slider.
        // Recreate only this child when the preference changes so no stale
        // interaction/material state survives into the next drag. Branching
        // directly on the param makes the switch immediate: no timer or
        // interaction deferral can keep the old material style visible.
        if (this.materialEnabled) {
          this.slider(this.material)
        } else {
          this.slider(undefined)
        }

        ForEach(this.detents, (detent: number) => {
          Circle()
            .width(3)
            .height(3)
            .fill(detent < this.displayValue() ?
              $r('sys.color.icon_on_primary') : $r('sys.color.icon_tertiary'))
            .opacity(this.isThumbAt(detent) ? 0 : 0.72)
            .position({ x: this.xForValue(detent) - 1.5, y: 22.5 })
            .hitTestBehavior(HitTestMode.None)
        }, (detent: number) => detent.toString())
      }
      .width('100%')
      .height(48)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const width = Number(newArea.width);
        if (width > 0) {
          this.trackWidth = width;
        }
      })

      Stack({ alignContent: Alignment.Start }) {
        ForEach(this.labels, (label: string, index: number) => {
          Text(label)
            .width(this.labelWidth)
            .fontSize(AppTypography.CAPTION_L)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_tertiary'))
            .textAlign(TextAlign.Center)
            .position({
              x: this.xForValue(this.detents[index]) - this.labelWidth / 2,
              y: 0
            })
        }, (label: string) => label)
      }
      .width('100%')
      .height(20)
    }
    .width('100%')
  }
}
