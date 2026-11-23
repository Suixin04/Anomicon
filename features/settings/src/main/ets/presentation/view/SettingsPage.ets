import {
  HideMode,
  HdsNavDestination,
  HdsNavDestinationTitleMode
} from '@kit.UIDesignKit';
import {
  SettingsMagneticSlider,
  SettingsMaterialToggle,
  SettingsThemeSelector
} from './SettingsControls';
import {
  pageContentTop,
  PHONE_PAGE_MARGIN,
  createAppTitleBarStyle,
  ROW_PRESS_MODIFIER
} from 'anomiconbasic';
import { AppTypography, ReadingBodyText } from 'anomiconbasic';
import {
  ReadingSettingsRange,
  ThemeMode,
} from '../../domain/SettingsModels';
import { SettingsViewModel } from '../viewmodel/SettingsViewModel';
import {
  SettingsBranding,
  SettingsNavigationTarget,
  SettingsViewContract
} from './SettingsViewContracts';

@Builder
export function SettingsPageBuilder(contract: SettingsViewContract) {
  SettingsPage({
    viewModel: contract.viewModel,
    branding: contract.branding,
    onHaptic: contract.onHaptic,
    onNavigate: contract.onNavigate
  })
}

@ComponentV2
struct SettingsSliderHeader {
  @Require @Param icon: Resource;
  @Require @Param title: string;
  @Require @Param value: number;
  @Require @Param fractionDigits: number;
  @Require @Param unit: string;

  build() {
    Row({ space: 12 }) {
      Column() {
        SymbolGlyph(this.icon)
          .fontSize(22)
          .fontColor([$r('sys.color.icon_primary')])
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(8)

      Text(this.title)
        .fontSize(AppTypography.BODY_L)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      .layoutWeight(1)

      Text(`${this.value.toFixed(this.fractionDigits)}${this.unit}`)
        .fontSize(AppTypography.SUBTITLE_S)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_emphasize'))
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(8)
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
  }
}

@ComponentV2
export struct SettingsPage {
  @Require @Param viewModel: SettingsViewModel;
  @Require @Param branding: SettingsBranding;
  @Event onHaptic: (enabled: boolean) => void;
  @Event onNavigate: (
    pageStack: NavPathStack | undefined,
    target: SettingsNavigationTarget
  ) => void;
  private pageStack: NavPathStack | undefined = undefined;
  private scroller: Scroller = new Scroller();
  private readonly fontDetents: number[] = [
    ReadingSettingsRange.FONT_SIZE_MIN,
    ReadingSettingsRange.FONT_SIZE_DEFAULT,
    ReadingSettingsRange.FONT_SIZE_MAX
  ];
  private readonly lineHeightDetents: number[] = [
    ReadingSettingsRange.LINE_HEIGHT_MIN,
    ReadingSettingsRange.LINE_HEIGHT_DEFAULT,
    ReadingSettingsRange.LINE_HEIGHT_MAX
  ];

  // Defaults are only an initial render value.  The injected shared VM is
  // copied in aboutToAppear, so constructing the page never reaches a second
  // global state accessor or races AppContainer initialization.
  @Local private fontSizeDraft: number = ReadingSettingsRange.FONT_SIZE_DEFAULT;
  @Local private lineHeightDraft: number = ReadingSettingsRange.LINE_HEIGHT_DEFAULT;
  @Local private immersiveMaterialDraft: boolean = false;
  private fontSizeDraftDirty: boolean = false;
  private lineHeightDraftDirty: boolean = false;

  aboutToAppear(): void {
    this.fontSizeDraft = this.viewModel.fontSize;
    this.lineHeightDraft = this.viewModel.lineHeightMultiple;
    this.immersiveMaterialDraft = this.viewModel.immersiveMaterialEnabled;
    this.fontSizeDraftDirty = false;
    this.lineHeightDraftDirty = false;
  }

  @Monitor('viewModel.fontSize')
  private syncFontSizeDraft(): void {
    if (!this.fontSizeDraftDirty) {
      this.fontSizeDraft = this.viewModel.fontSize;
    }
  }

  @Monitor('viewModel.lineHeightMultiple')
  private syncLineHeightDraft(): void {
    if (!this.lineHeightDraftDirty) {
      this.lineHeightDraft = this.viewModel.lineHeightMultiple;
    }
  }

  @Monitor('viewModel.immersiveMaterialEnabled')
  private syncImmersiveMaterialDraft(): void {
    this.immersiveMaterialDraft = this.viewModel.immersiveMaterialEnabled;
  }

  private openPage(target: SettingsNavigationTarget): void {
    this.commitAppearanceDraft();
    this.commitTypographyDrafts();
    this.onHaptic(this.viewModel.hapticEnabled);
    this.onNavigate(this.pageStack, target);
  }

  private commitAppearanceDraft(): void {
    if (this.viewModel.immersiveMaterialEnabled !== this.immersiveMaterialDraft) {
      this.viewModel.setImmersiveMaterialEnabled(this.immersiveMaterialDraft);
    }
  }

  private commitTypographyDrafts(): void {
    if (this.fontSizeDraftDirty || this.viewModel.fontSize !== this.fontSizeDraft) {
      if (this.viewModel.setFontSize(this.fontSizeDraft)) {
        this.fontSizeDraftDirty = false;
      }
    }
    if (this.lineHeightDraftDirty || this.viewModel.lineHeightMultiple !== this.lineHeightDraft) {
      if (this.viewModel.setLineHeightMultiple(this.lineHeightDraft)) {
        this.lineHeightDraftDirty = false;
      }
    }
  }

  private selectTheme(value: ThemeMode, playFeedback: boolean = true): void {
    if (this.viewModel.themeMode === value) {
      return;
    }
    this.commitTypographyDrafts();
    if (playFeedback) {
      this.onHaptic(this.viewModel.hapticEnabled);
    }
    this.viewModel.setThemeMode(value);
  }

  private setHapticEnabled(value: boolean): void {
    if (this.viewModel.hapticEnabled === value) {
      return;
    }
    if (!value) {
      this.onHaptic(true);
    }
    this.viewModel.setHapticEnabled(value);
    if (value) {
      this.onHaptic(true);
    }
  }

  private setImmersiveMaterialDraft(value: boolean): void {
    if (this.immersiveMaterialDraft === value) {
      return;
    }
    this.onHaptic(this.viewModel.hapticEnabled);
    // Toggle 的 onChange 已是一次完整提交：立即发布并只落盘一次。
    if (this.viewModel.setImmersiveMaterialEnabled(value)) {
      this.immersiveMaterialDraft = value;
    }
  }

  private onFontSliderChange(value: number, mode: SliderChangeMode): void {
    // 量化值只在跨步时变化，比较值即事件级幂等过滤，无需时间节流。
    const next = Math.round(value / ReadingSettingsRange.FONT_SIZE_STEP) *
      ReadingSettingsRange.FONT_SIZE_STEP;
    if (mode === SliderChangeMode.End) {
      // 松手必须提交：即使值与草稿相同（拖动中已更新），
      // 早退会把本次设置变更吞掉，导致其它页面不刷新。
      this.fontSizeDraft = next;
      this.fontSizeDraftDirty = true;
      if (this.viewModel.setFontSize(next)) {
        this.fontSizeDraftDirty = false;
      }
      return;
    }
    if (next === this.fontSizeDraft) {
      return;
    }
    this.fontSizeDraft = next;
    this.fontSizeDraftDirty = true;
  }

  private onLineHeightSliderChange(value: number, mode: SliderChangeMode): void {
    const next = Math.round(value / ReadingSettingsRange.LINE_HEIGHT_STEP) *
      ReadingSettingsRange.LINE_HEIGHT_STEP;
    if (mode === SliderChangeMode.End) {
      this.lineHeightDraft = next;
      this.lineHeightDraftDirty = true;
      if (this.viewModel.setLineHeightMultiple(next)) {
        this.lineHeightDraftDirty = false;
      }
      return;
    }
    if (next === this.lineHeightDraft) {
      return;
    }
    this.lineHeightDraft = next;
    this.lineHeightDraftDirty = true;
  }

  @Builder
  private sectionTitle(title: string) {
    Text(title)
      .fontSize(AppTypography.SUBTITLE_M)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
      .width('100%')
  }

  @Builder
  private settingIcon(icon: Resource) {
    Column() {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([$r('sys.color.icon_primary')])
    }
    .width(40)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(8)
  }

  @Builder
  private appearanceCard() {
    Column({ space: 16 }) {
      Column({ space: 12 }) {
        Row() {
          Text('主题')
            .fontSize(AppTypography.BODY_L)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
        }
        .width('100%')
        SettingsThemeSelector({
          value: this.viewModel.themeMode,
          hapticEnabled: this.viewModel.hapticEnabled,
          onHaptic: (enabled: boolean) => this.onHaptic(enabled),
          onThemeChange: (value: ThemeMode) => this.selectTheme(value, false)
        })
      }
      .width('100%')
      .padding({ bottom: 8 })

      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))

      Row({ space: 12 }) {
        this.settingIcon($r('sys.symbol.hand_tap_wave_2'))
        Text('触感反馈')
          .fontSize(AppTypography.BODY_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
        SettingsMaterialToggle({
          isOn: this.viewModel.hapticEnabled,
          materialEnabled: this.immersiveMaterialDraft,
          onChange: (value: boolean) => this.setHapticEnabled(value)
        })
      }
      .alignItems(VerticalAlign.Center)
      .width('100%')

      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))

      Row({ space: 12 }) {
        this.settingIcon($r('sys.symbol.square_stack_3d'))
        Text('沉浸光感')
          .fontSize(AppTypography.BODY_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
        SettingsMaterialToggle({
          isOn: this.immersiveMaterialDraft,
          materialEnabled: this.immersiveMaterialDraft,
          onChange: (value: boolean) => this.setImmersiveMaterialDraft(value)
        })
      }
      .alignItems(VerticalAlign.Center)
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
  }

  @Builder
  private persistenceError() {
    if (this.viewModel.errorMessage.length > 0) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
          .fontSize(18)
          .fontColor([$r('sys.color.icon_emphasize')])
        Text(this.viewModel.errorMessage)
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
        Button('重试', { stateEffect: false })
          .fontSize(AppTypography.CAPTION_L)
          .onClick(() => this.viewModel.retryLoad())
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(8)
    }
  }

  @Builder
  private fontSizePreview() {
    Column({ space: 4 }) {
      Text('SCP-173 · 特殊收容措施')
        .fontSize(AppTypography.CAPTION_L)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
      ReadingBodyText({
        content: '项目须始终收容于上锁的标准收容室内。',
        fontSize: this.fontSizeDraft,
        lineHeightMultiple: this.lineHeightDraft,
        color: $r('sys.color.font_primary')
      })
    }
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .constraintSize({ minHeight: 88 })
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(12)
  }

  @Builder
  private lineHeightPreview() {
    Column({ space: 4 }) {
      Text('观测协议 · 节选')
        .fontSize(AppTypography.CAPTION_L)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
      ReadingBodyText({
        content: '进入收容室的人员不得少于三人，\n且须在离开前始终保持直接视线接触。',
        fontSize: this.fontSizeDraft,
        lineHeightMultiple: this.lineHeightDraft,
        color: $r('sys.color.font_primary')
      })
    }
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .constraintSize({ minHeight: 128 })
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(12)
  }

  @Builder
  private fontSizeCard() {
    Column({ space: 14 }) {
      SettingsSliderHeader({
        icon: $r('sys.symbol.textformat_size_square'),
        title: '正文字号',
        value: this.fontSizeDraft,
        fractionDigits: 2,
        unit: ' fp'
      })
      this.fontSizePreview()
      SettingsMagneticSlider({
        value: this.fontSizeDraft,
        min: ReadingSettingsRange.FONT_SIZE_MIN,
        max: ReadingSettingsRange.FONT_SIZE_MAX,
        step: ReadingSettingsRange.FONT_SIZE_STEP,
        detents: this.fontDetents,
        labels: ['较小', '标准', '较大'],
        materialEnabled: this.immersiveMaterialDraft,
        hapticEnabled: this.viewModel.hapticEnabled,
        onHaptic: (enabled: boolean) => this.onHaptic(enabled),
        onValueChange: (value: number, mode: SliderChangeMode) => this.onFontSliderChange(value, mode)
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
  }

  @Builder
  private lineHeightCard() {
    Column({ space: 14 }) {
      SettingsSliderHeader({
        icon: $r('sys.symbol.text_arrow_up_and_down'),
        title: '阅读行距',
        value: this.lineHeightDraft,
        fractionDigits: 3,
        unit: '×'
      })
      this.lineHeightPreview()
      SettingsMagneticSlider({
        value: this.lineHeightDraft,
        min: ReadingSettingsRange.LINE_HEIGHT_MIN,
        max: ReadingSettingsRange.LINE_HEIGHT_MAX,
        step: ReadingSettingsRange.LINE_HEIGHT_STEP,
        detents: this.lineHeightDetents,
        labels: ['紧凑', '舒适', '宽松'],
        materialEnabled: this.immersiveMaterialDraft,
        hapticEnabled: this.viewModel.hapticEnabled,
        onHaptic: (enabled: boolean) => this.onHaptic(enabled),
        onValueChange: (value: number, mode: SliderChangeMode) => this.onLineHeightSliderChange(value, mode)
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
  }

  @Builder
  private divider() {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.comp_divider'))
      .margin({ left: 56 })
  }

  @Builder
  private informationRow(
    icon: Resource,
    title: string,
    subtitle: string,
    action: () => void,
    componentId: string
  ) {
    Row({ space: 12 }) {
      this.settingIcon(icon)
      Column({ space: 2 }) {
        Text(title)
          .fontSize(AppTypography.BODY_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(subtitle)
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('sys.color.icon_secondary')])
    }
    .attributeModifier(ROW_PRESS_MODIFIER)
    .animation({ duration: 120, curve: Curve.FastOutSlowIn })
    .width('100%')
    .constraintSize({ minHeight: 68 })
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .id(componentId)
    .onClick(action)
  }

  @Builder
  private informationCard() {
    Column() {
      Row({ space: 12 }) {
        Image(this.branding.appIcon)
          .width(40)
          .height(40)
          .borderRadius(8)
        Column({ space: 2 }) {
          Text(this.branding.displayName)
            .fontSize(AppTypography.BODY_L)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(`${this.branding.englishName} · ${this.branding.versionName}`)
            .fontSize(AppTypography.CAPTION_L)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .attributeModifier(ROW_PRESS_MODIFIER)
      .animation({ duration: 120, curve: Curve.FastOutSlowIn })
      .width('100%')
      .constraintSize({ minHeight: 68 })
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .onClick(() => this.openPage(SettingsNavigationTarget.ABOUT))

      this.divider()
      this.informationRow(
        $r('sys.symbol.doc_text_badge_checkmark'),
        '内容来源与许可',
        'CC BY-SA 3.0 授权使用',
        () => this.openPage(SettingsNavigationTarget.CONTENT_LICENSE),
        'contentLicenseSettingsRow'
      )
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  private ccLicenseBadge() {
    Row({ space: 6 }) {
      Image(this.branding.ccLogo)
        .width(16)
        .height(16)
        .objectFit(ImageFit.Contain)
        .fillColor($r('sys.color.font_tertiary'))
      Image(this.branding.ccBy)
        .width(16)
        .height(16)
        .objectFit(ImageFit.Contain)
        .fillColor($r('sys.color.font_tertiary'))
      Image(this.branding.ccSa)
        .width(16)
        .height(16)
        .objectFit(ImageFit.Contain)
        .fillColor($r('sys.color.font_tertiary'))
      Text('CC BY-SA 3.0')
        .fontSize(AppTypography.CAPTION_L)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_tertiary'))
    }
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 24 }) {
          this.persistenceError()
          Column({ space: 12 }) {
            this.sectionTitle('外观与反馈')
            this.appearanceCard()
          }
          .width('100%')

          Column({ space: 12 }) {
            this.sectionTitle('阅读')
            this.fontSizeCard()
            this.lineHeightCard()
          }
          .width('100%')

          Column({ space: 12 }) {
            this.sectionTitle('关于')
            this.informationCard()
            this.ccLicenseBadge()
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ maxWidth: 680 })
        .padding({
          left: PHONE_PAGE_MARGIN,
          right: PHONE_PAGE_MARGIN,
          top: pageContentTop(),
          bottom: 36
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))
      .clip(false)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false,
      content: {
        title: { mainTitle: '设置' },
        backIcon: { label: '返回', componentId: 'settingsBackButton' }
      },
      style: createAppTitleBarStyle(this.viewModel.immersiveMaterialEnabled)
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .backgroundColor($r('sys.color.background_secondary'))
    .bindToScrollable([this.scroller])
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP,
      hideRatio: 1.5
    })
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
    })
    .onWillDisappear(() => {
      this.commitAppearanceDraft();
      this.commitTypographyDrafts();
    })
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    )
  }
}
