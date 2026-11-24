import {
  HideMode,
  HdsNavDestination,
  HdsNavDestinationTitleMode
} from '@kit.UIDesignKit';
import {
  SettingsMagneticSlider,
  SettingsMaterialToggle,
  SettingsSegmentSelector,
  SettingsThemeSelector
} from './SettingsControls';
import {
  adaptiveListLanesForWidth,
  adaptivePageMarginForWidth,
  AppTypography,
  createAppBackIcon,
  createAppTitleBarStyle,
  DestinationMotionState,
  isDarkModeActive,
  NavigationTransitionRegistry,
  pageContentTop,
  PHONE_PAGE_MARGIN,
  popNavigationDestination,
  pressAnimation,
  READING_CONTENT_MAX_WIDTH,
  ROW_PRESS_MODIFIER,
  WIDE_CONTENT_MAX_WIDTH,
  windowWidthVp
} from 'anomiconbasic';
import {
  ComplexPageMode,
  ReadingSettingsRange,
  ReadingTextAlign,
  ThemeMode,
  formatFontSizeLabel,
  formatLineHeightLabel,
  formatStorageBytes
} from '../../domain/SettingsModels';
import { SettingsViewModel } from '../viewmodel/SettingsViewModel';
import {
  SettingsBranding,
  SettingsNavigationTarget,
  SettingsStorageActions,
  SettingsStorageUsage,
  SettingsViewContract
} from './SettingsViewContracts';

const DUO_COLUMN_MIN_WIDTH: number = 680;
const TYPOGRAPHY_FONT_EPSILON: number = 0.005;
const TYPOGRAPHY_LINE_EPSILON: number = 0.0005;

@Builder
export function SettingsPageBuilder(contract: SettingsViewContract) {
  SettingsPage({
    viewModel: contract.viewModel,
    branding: contract.branding,
    storageActions: contract.storageActions,
    onHaptic: contract.onHaptic,
    onNavigate: contract.onNavigate
  })
}

@ComponentV2
struct SettingsIconBox {
  @Require @Param icon: Resource;

  build() {
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
  }
}

@ComponentV2
struct SettingsSliderValueRow {
  @Require @Param title: string;
  @Require @Param valueText: string;

  build() {
    Row() {
      Text(this.title)
        .fontSize(AppTypography.BODY_L)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
      Text(this.valueText)
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
struct SettingsToggleRow {
  @Require @Param icon: Resource;
  @Require @Param title: string;
  @Require @Param subtitle: string;
  @Require @Param isOn: boolean;
  @Require @Param materialEnabled: boolean;
  @Event onChange: (value: boolean) => void;

  build() {
    Row({ space: 12 }) {
      SettingsIconBox({ icon: this.icon })
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(AppTypography.BODY_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(this.subtitle)
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_secondary'))
          .lineHeightMultiple(1.25)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SettingsMaterialToggle({
        isOn: this.isOn,
        materialEnabled: this.materialEnabled,
        onChange: (value: boolean) => this.onChange(value)
      })
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
  }
}

@ComponentV2
struct SettingsActionRow {
  @Require @Param icon: Resource;
  @Require @Param title: string;
  @Require @Param subtitle: string;
  @Param trailingBadge: string = '';
  @Param showChevron: boolean = false;
  @Param rowEnabled: boolean = true;
  @Param componentId: string = '';
  @Event onAction: () => void;

  build() {
    Row({ space: 12 }) {
      SettingsIconBox({ icon: this.icon })
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(AppTypography.BODY_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(this.subtitle)
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.trailingBadge.length > 0) {
        Text(this.trailingBadge)
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.rowEnabled ? $r('sys.color.font_secondary') : $r('sys.color.font_tertiary'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(8)
      }
      if (this.showChevron) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .fontColor([$r('sys.color.icon_secondary')])
      }
    }
    .attributeModifier(ROW_PRESS_MODIFIER)
    .animation(pressAnimation())
    .opacity(this.rowEnabled ? 1 : 0.65)
    .width('100%')
    .constraintSize({ minHeight: 68 })
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .id(this.componentId)
    .onClick(() => {
      if (this.rowEnabled) {
        this.onAction();
      }
    })
  }
}

@ComponentV2
export struct SettingsPage {
  @Require @Param viewModel: SettingsViewModel;
  @Require @Param branding: SettingsBranding;
  @Param storageActions: SettingsStorageActions | undefined = undefined;
  @Event onHaptic: (enabled: boolean) => void;
  @Event onNavigate: (
    pageStack: NavPathStack | undefined,
    target: SettingsNavigationTarget
  ) => void;

  private pageStack: NavPathStack | undefined = undefined;
  private navDestinationId: string = '';
  @Local private readonly navMotion: DestinationMotionState = new DestinationMotionState();
  private scroller: Scroller = new Scroller();
  private readonly alignLabels: string[] = ['两端对齐', '左对齐'];
  private readonly complexModeLabels: string[] = ['智能识别', '仅提示', '始终原生'];
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

  // Defaults are only an initial render value. The injected shared VM is
  // copied in aboutToAppear, so constructing the page never reaches a second
  // global state accessor or races AppContainer initialization.
  @Local private fontSizeDraft: number = ReadingSettingsRange.FONT_SIZE_DEFAULT;
  @Local private lineHeightDraft: number = ReadingSettingsRange.LINE_HEIGHT_DEFAULT;
  @Local private immersiveMaterialDraft: boolean = false;
  @Local private paneWidth: number = 0;
  @Local private storageUsage: SettingsStorageUsage | undefined = undefined;
  @Local private storageBusy: boolean = false;
  private fontSizeDraftDirty: boolean = false;
  private lineHeightDraftDirty: boolean = false;

  private measuredWidthVp(): number {
    const width = this.paneWidth > 0 ? this.paneWidth : windowWidthVp();
    return width > 0 ? width : 390;
  }

  private horizontalMargin(): number {
    const width = this.paneWidth > 0 ? this.paneWidth : windowWidthVp();
    return width > 0 ? adaptivePageMarginForWidth(width) : PHONE_PAGE_MARGIN;
  }

  private usesTwoColumnLayout(): boolean {
    return adaptiveListLanesForWidth(this.measuredWidthVp(), DUO_COLUMN_MIN_WIDTH) === 2;
  }

  aboutToAppear(): void {
    this.fontSizeDraft = this.viewModel.fontSize;
    this.lineHeightDraft = this.viewModel.lineHeightMultiple;
    this.immersiveMaterialDraft = this.viewModel.immersiveMaterialEnabled;
    this.fontSizeDraftDirty = false;
    this.lineHeightDraftDirty = false;
    this.refreshStorageUsage();
  }

  aboutToDisappear(): void {
    NavigationTransitionRegistry.unregister(this.navDestinationId);
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

  private refreshStorageUsage(): void {
    const actions = this.storageActions;
    if (actions === undefined) {
      return;
    }
    actions.inspect().then((usage: SettingsStorageUsage): void => {
      this.storageUsage = usage;
    }).catch((): void => {
      // 存储统计失败不阻断设置页交互。
    });
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

  private setDefaultRevealHidden(value: boolean): void {
    if (this.viewModel.defaultRevealHiddenText === value) {
      return;
    }
    this.onHaptic(this.viewModel.hapticEnabled);
    this.viewModel.setDefaultRevealHiddenText(value);
  }

  private setKeepScreenOnReading(value: boolean): void {
    if (this.viewModel.keepScreenOnReading === value) {
      return;
    }
    this.onHaptic(this.viewModel.hapticEnabled);
    this.viewModel.setKeepScreenOnReading(value);
  }

  private alignSelectedIndex(): number {
    return this.viewModel.readingTextAlign === ReadingTextAlign.START ? 1 : 0;
  }

  private selectAlignByIndex(index: number): void {
    const next = index === 1 ? ReadingTextAlign.START : ReadingTextAlign.JUSTIFY;
    this.viewModel.setReadingTextAlign(next);
  }

  private complexModeSelectedIndex(): number {
    switch (this.viewModel.complexPageMode) {
      case ComplexPageMode.PROMPT_ONLY:
        return 1;
      case ComplexPageMode.ALWAYS_NATIVE:
        return 2;
      default:
        return 0;
    }
  }

  private selectComplexModeByIndex(index: number): void {
    let next = ComplexPageMode.SMART;
    if (index === 1) {
      next = ComplexPageMode.PROMPT_ONLY;
    } else if (index === 2) {
      next = ComplexPageMode.ALWAYS_NATIVE;
    }
    this.viewModel.setComplexPageMode(next);
  }

  private complexModeSubtitle(): string {
    switch (this.viewModel.complexPageMode) {
      case ComplexPageMode.PROMPT_ONLY:
        return '先用原生阅读呈现，遇到复杂排版或交互页仅在顶部提示';
      case ComplexPageMode.ALWAYS_NATIVE:
        return '关闭顶部原版网页推荐横幅，需要时仍可从菜单手动切换';
      default:
        return '纯交互部件自动进入原版网页，特效/多迭代页在顶部提示切换';
    }
  }

  private isTypographyModified(): boolean {
    return Math.abs(this.fontSizeDraft - ReadingSettingsRange.FONT_SIZE_DEFAULT) > TYPOGRAPHY_FONT_EPSILON ||
      Math.abs(this.lineHeightDraft - ReadingSettingsRange.LINE_HEIGHT_DEFAULT) > TYPOGRAPHY_LINE_EPSILON ||
      this.viewModel.readingTextAlign !== ReadingTextAlign.JUSTIFY;
  }

  private resetTypographyToDefaults(): void {
    this.onHaptic(this.viewModel.hapticEnabled);
    this.fontSizeDraft = ReadingSettingsRange.FONT_SIZE_DEFAULT;
    this.lineHeightDraft = ReadingSettingsRange.LINE_HEIGHT_DEFAULT;
    this.fontSizeDraftDirty = false;
    this.lineHeightDraftDirty = false;
    this.viewModel.resetReadingTypography();
  }

  private onFontSliderChange(value: number, mode: SliderChangeMode): void {
    const next = Math.round(value / ReadingSettingsRange.FONT_SIZE_STEP) *
      ReadingSettingsRange.FONT_SIZE_STEP;
    if (mode === SliderChangeMode.End) {
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

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().openToast({ message: message })
        .catch((): void => {
        });
    } catch (_error) {
    }
  }

  private confirmClearTempCaches(): void {
    if (this.storageActions === undefined || this.storageBusy) {
      return;
    }
    this.onHaptic(this.viewModel.hapticEnabled);
    const sizeText = this.storageUsage !== undefined ?
      formatStorageBytes(this.storageUsage.tempCacheBytes) : '临时';
    this.getUIContext().showAlertDialog({
      title: '清理临时缓存',
      message: `将清理已缓存的文章解析、原始网页快照与配图（约 ${sizeText}），收藏、阅读进度、研究员档案及已下载三维模型均会完整保留。`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: (): void => {}
      },
      secondaryButton: {
        value: '确认清理',
        fontColor: $r('sys.color.warning'),
        action: (): void => {
          this.performClearTempCaches();
        }
      }
    });
  }

  private performClearTempCaches(): void {
    const actions = this.storageActions;
    if (actions === undefined || this.storageBusy) {
      return;
    }
    this.storageBusy = true;
    actions.clearTempCaches().then((usage: SettingsStorageUsage): void => {
      this.storageUsage = usage;
      this.showToast('临时缓存已清理');
    }).catch((): void => {
      this.showToast('缓存清理失败，请稍后重试');
    }).finally((): void => {
      this.storageBusy = false;
    });
  }

  private confirmClearSearchHistory(): void {
    if (this.storageActions === undefined || this.storageBusy ||
      (this.storageUsage?.searchHistoryCount ?? 0) <= 0) {
      return;
    }
    this.onHaptic(this.viewModel.hapticEnabled);
    this.getUIContext().showAlertDialog({
      title: '清空搜索历史',
      message: '确认移除全部本地图鉴搜索记录吗？',
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: (): void => {}
      },
      secondaryButton: {
        value: '清空',
        fontColor: $r('sys.color.warning'),
        action: (): void => {
          this.performClearSearchHistory();
        }
      }
    });
  }

  private performClearSearchHistory(): void {
    const actions = this.storageActions;
    if (actions === undefined || this.storageBusy) {
      return;
    }
    this.storageBusy = true;
    actions.clearSearchHistory().then((usage: SettingsStorageUsage): void => {
      this.storageUsage = usage;
      this.showToast('搜索历史已清空');
    }).catch((): void => {
      this.showToast('清空搜索历史失败');
    }).finally((): void => {
      this.storageBusy = false;
    });
  }

  private tempCacheBadgeText(): string {
    if (this.storageBusy) {
      return '清理中…';
    }
    if (this.storageUsage === undefined) {
      return '计算中…';
    }
    return formatStorageBytes(this.storageUsage.tempCacheBytes);
  }

  private searchHistorySubtitle(): string {
    if (this.storageUsage === undefined) {
      return '正在读取本地搜索记录…';
    }
    if (this.storageUsage.searchHistoryCount <= 0) {
      return '暂无本地搜索记录';
    }
    return `当前保留 ${this.storageUsage.searchHistoryCount} 条本地搜索记录`;
  }

  private archive3DSubtitle(): string {
    if (this.storageUsage === undefined) {
      return '查看并管理已下载三维模型';
    }
    if (this.storageUsage.archive3DBytes <= 0) {
      return '尚未下载三维模型包，前往查看';
    }
    return `已下载模型占用 ${formatStorageBytes(this.storageUsage.archive3DBytes)}，前往管理`;
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
  private cardDivider(insetLeft: number = 52) {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.comp_divider'))
      .margin({ left: insetLeft })
  }

  @Builder
  private appearanceCard() {
    Column({ space: 14 }) {
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
      .padding({ bottom: 4 })

      this.cardDivider(0)
      SettingsToggleRow({
        icon: $r('sys.symbol.hand_tap_wave_2'),
        title: '触感反馈',
        subtitle: '切换按钮、滑块磁吸与折叠展开时提供轻触反馈',
        isOn: this.viewModel.hapticEnabled,
        materialEnabled: this.immersiveMaterialDraft,
        onChange: (value: boolean) => this.setHapticEnabled(value)
      })

      this.cardDivider(52)
      SettingsToggleRow({
        icon: $r('sys.symbol.square_stack_3d'),
        title: '沉浸光感',
        subtitle: '顶栏、底栏与悬浮胶囊启用鸿蒙自适应光感材质',
        isOn: this.immersiveMaterialDraft,
        materialEnabled: this.immersiveMaterialDraft,
        onChange: (value: boolean) => this.setImmersiveMaterialDraft(value)
      })
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
  private typographyPreviewBox() {
    Column({ space: 6 }) {
      Text('SCP-173 · 特殊收容措施')
        .fontSize(AppTypography.CAPTION_L)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
      Text() {
        Span('项目须始终收容于上锁的标准收容室内。进入人员不得少于三人，且须在离开前始终保持直接视线接触。')
        if (this.viewModel.defaultRevealHiddenText) {
          Span('【彩蛋已透视】切勿眨眼，它正在注视你。')
            .fontColor(isDarkModeActive() ? '#FCD34D' : '#92400E')
            .textBackgroundStyle({
              color: isDarkModeActive() ? '#2AF59E0B' : '#22F59E0B',
              radius: 4
            })
        } else {
          Span('【隐藏彩蛋 · 开启透视后直接显现】')
            .fontColor($r('sys.color.font_tertiary'))
            .textBackgroundStyle({
              color: isDarkModeActive() ? '#16FFFFFF' : '#0C000000',
              radius: 4
            })
        }
      }
      .fontSize(this.fontSizeDraft)
      .lineHeightMultiple(this.lineHeightDraft)
      .fontColor($r('sys.color.font_primary'))
      .textAlign(this.viewModel.readingTextAlign === ReadingTextAlign.START ?
        TextAlign.Start : TextAlign.JUSTIFY)
      .wordBreak(WordBreak.NORMAL)
      .enableAutoSpacing(true)
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(12)
  }

  @Builder
  private readingTypographyCard() {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        SettingsIconBox({ icon: $r('sys.symbol.textformat_size_square') })
        Column({ space: 2 }) {
          Text('阅读排版')
            .fontSize(AppTypography.BODY_L)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('字号、行距、对齐与彩蛋实时预览')
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.isTypographyModified()) {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.arrow_counterclockwise'))
              .fontSize(13)
              .fontColor([$r('sys.color.font_emphasize')])
            Text('恢复默认')
              .fontSize(AppTypography.CAPTION_L)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_emphasize'))
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(14)
          .id('resetTypographyButton')
          .onClick(() => this.resetTypographyToDefaults())
        }
      }
      .alignItems(VerticalAlign.Center)
      .width('100%')

      this.typographyPreviewBox()

      Column({ space: 8 }) {
        SettingsSliderValueRow({
          title: '正文字号',
          valueText: formatFontSizeLabel(this.fontSizeDraft)
        })
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
      .width('100%')

      this.cardDivider(0)

      Column({ space: 8 }) {
        SettingsSliderValueRow({
          title: '阅读行距',
          valueText: formatLineHeightLabel(this.lineHeightDraft)
        })
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
      .width('100%')

      this.cardDivider(0)

      Column({ space: 10 }) {
        Row({ space: 12 }) {
          SettingsIconBox({ icon: $r('sys.symbol.textformat') })
          Column({ space: 2 }) {
            Text('正文对齐')
              .fontSize(AppTypography.BODY_L)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Text('居中警告与引用等特殊排版仍保留原样式')
              .fontSize(AppTypography.CAPTION_L)
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Center)
        .width('100%')

        SettingsSegmentSelector({
          labels: this.alignLabels,
          selectedIndex: this.alignSelectedIndex(),
          hapticEnabled: this.viewModel.hapticEnabled,
          onHaptic: (enabled: boolean) => this.onHaptic(enabled),
          onSelectIndex: (index: number) => this.selectAlignByIndex(index)
        })
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
  }

  @Builder
  private readingBehaviorCard() {
    Column({ space: 14 }) {
      Column({ space: 10 }) {
        Row({ space: 12 }) {
          SettingsIconBox({ icon: $r('sys.symbol.website') })
          Column({ space: 2 }) {
            Text('复杂页面浏览')
              .fontSize(AppTypography.BODY_L)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Text(this.complexModeSubtitle())
              .fontSize(AppTypography.CAPTION_L)
              .fontColor($r('sys.color.font_secondary'))
              .lineHeightMultiple(1.25)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Center)
        .width('100%')

        SettingsSegmentSelector({
          labels: this.complexModeLabels,
          selectedIndex: this.complexModeSelectedIndex(),
          hapticEnabled: this.viewModel.hapticEnabled,
          onHaptic: (enabled: boolean) => this.onHaptic(enabled),
          onSelectIndex: (index: number) => this.selectComplexModeByIndex(index)
        })
      }
      .width('100%')

      this.cardDivider(52)
      SettingsToggleRow({
        icon: $r('sys.symbol.eye'),
        title: '默认反白透视',
        subtitle: '自动显现白字与零字号彩蛋，可在单篇阅读栏临时关闭',
        isOn: this.viewModel.defaultRevealHiddenText,
        materialEnabled: this.immersiveMaterialDraft,
        onChange: (value: boolean) => this.setDefaultRevealHidden(value)
      })

      this.cardDivider(52)
      SettingsToggleRow({
        icon: $r('sys.symbol.lightbulb'),
        title: '阅读时屏幕常亮',
        subtitle: '仅在条目正文页保持常亮，退出正文后自动恢复系统休眠',
        isOn: this.viewModel.keepScreenOnReading,
        materialEnabled: this.immersiveMaterialDraft,
        onChange: (value: boolean) => this.setKeepScreenOnReading(value)
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
  }

  @Builder
  private storageCard() {
    Column() {
      SettingsActionRow({
        icon: $r('sys.symbol.clean'),
        title: '清理临时缓存',
        subtitle: '文章解析、网页快照与配图缓存（保留收藏与进度）',
        trailingBadge: this.tempCacheBadgeText(),
        showChevron: false,
        rowEnabled: !this.storageBusy,
        componentId: 'clearTempCacheSettingsRow',
        onAction: (): void => this.confirmClearTempCaches()
      })
      this.cardDivider(56)
      SettingsActionRow({
        icon: $r('sys.symbol.magnifyingglass'),
        title: '清空搜索历史',
        subtitle: this.searchHistorySubtitle(),
        trailingBadge: '',
        showChevron: false,
        rowEnabled: !this.storageBusy && (this.storageUsage?.searchHistoryCount ?? 0) > 0,
        componentId: 'clearSearchHistorySettingsRow',
        onAction: (): void => this.confirmClearSearchHistory()
      })
      this.cardDivider(56)
      SettingsActionRow({
        icon: $r('sys.symbol.viewfinder_3D'),
        title: '三维档案模型包',
        subtitle: this.archive3DSubtitle(),
        trailingBadge: '',
        showChevron: true,
        rowEnabled: true,
        componentId: 'archive3DStorageSettingsRow',
        onAction: (): void => this.openPage(SettingsNavigationTarget.ARCHIVE_3D_GALLERY)
      })
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
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
      .animation(pressAnimation())
      .width('100%')
      .constraintSize({ minHeight: 68 })
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .onClick(() => this.openPage(SettingsNavigationTarget.ABOUT))

      this.cardDivider(56)
      SettingsActionRow({
        icon: $r('sys.symbol.doc_text_badge_checkmark'),
        title: '内容来源与许可',
        subtitle: 'CC BY-SA 3.0 授权使用',
        trailingBadge: '',
        showChevron: true,
        rowEnabled: true,
        componentId: 'contentLicenseSettingsRow',
        onAction: (): void => this.openPage(SettingsNavigationTarget.CONTENT_LICENSE)
      })
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

  @Builder
  private appearanceSection() {
    Column({ space: 12 }) {
      this.sectionTitle('外观与交互')
      this.appearanceCard()
    }
    .width('100%')
  }

  @Builder
  private readingSection() {
    Column({ space: 12 }) {
      this.sectionTitle('阅读体验')
      this.readingTypographyCard()
      this.readingBehaviorCard()
    }
    .width('100%')
  }

  @Builder
  private storageSection() {
    if (this.storageActions !== undefined) {
      Column({ space: 12 }) {
        this.sectionTitle('存储与缓存')
        this.storageCard()
      }
      .width('100%')
    }
  }

  @Builder
  private aboutSection() {
    Column({ space: 12 }) {
      this.sectionTitle('关于')
      this.informationCard()
      this.ccLicenseBadge()
    }
    .width('100%')
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 24 }) {
          this.persistenceError()
          if (this.usesTwoColumnLayout()) {
            Row({ space: 20 }) {
              Column({ space: 24 }) {
                this.appearanceSection()
                this.storageSection()
                this.aboutSection()
              }
              .layoutWeight(1)

              Column({ space: 24 }) {
                this.readingSection()
              }
              .layoutWeight(1)
            }
            .alignItems(VerticalAlign.Top)
            .width('100%')
          } else {
            this.appearanceSection()
            this.readingSection()
            this.storageSection()
            this.aboutSection()
          }
        }
        .width('100%')
        .constraintSize({
          maxWidth: this.usesTwoColumnLayout() ? WIDE_CONTENT_MAX_WIDTH : READING_CONTENT_MAX_WIDTH
        })
        .padding({
          left: this.horizontalMargin(),
          right: this.horizontalMargin(),
          top: pageContentTop(),
          bottom: 36
        })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .backgroundColor($r('sys.color.background_secondary'))
      .clip(false)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        const width = Number(newArea.width);
        if (Number.isFinite(width) && width > 0) {
          this.paneWidth = width;
        }
      })
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false,
      content: {
        title: { mainTitle: '设置' },
        backIcon: createAppBackIcon('settingsBackButton', (): void => {
          popNavigationDestination(this.pageStack);
        })
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
      this.navDestinationId = context.navDestinationId ?? '';
      NavigationTransitionRegistry.register(this.navDestinationId, this.navMotion);
    })
    .opacity(this.navMotion.opacity)
    .translate({ x: this.navMotion.translateX })
    .onWillShow(() => {
      this.refreshStorageUsage();
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
