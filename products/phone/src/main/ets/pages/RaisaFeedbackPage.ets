import { common } from '@kit.AbilityKit';
import {
  HideMode,
  HdsNavDestination,
  HdsNavDestinationTitleMode
} from '@kit.UIDesignKit';
import {
  AppInfoPort,
  ClipboardPort,
  DestinationMotionState,
  ExternalUrlPolicy,
  HapticFeedbackPort,
  NavigationTransitionRegistry,
  createAppBackIcon,
  createAppTitleBarStyle,
  popNavigationDestination,
  windowWidthVp
} from 'anomiconbasic';
import {
  RAISA_GITHUB_ISSUES_URL,
  RaisaAttachmentPickerPort,
  RaisaDiagnosticSnapshot,
  RaisaFeedbackAttachment,
  RaisaFeedbackContext,
  RaisaFeedbackViewModel,
  emptyRaisaFeedbackContext
} from 'library';
import { RaisaFeedbackView } from 'terminal';
import { SettingsViewModel, ThemeMode } from 'settings';
import { parseFeedbackRouteContext } from '../navigation/RouteParamAdapters';

function themeModeLabel(mode: ThemeMode): string {
  if (mode === ThemeMode.LIGHT) {
    return '浅色';
  }
  if (mode === ThemeMode.DARK) {
    return '深色';
  }
  return '跟随系统';
}

@Builder
export function RaisaFeedbackPageBuilder(
  feedback: RaisaFeedbackViewModel,
  settings: SettingsViewModel,
  appInfo: AppInfoPort,
  hapticService: HapticFeedbackPort,
  clipboard: ClipboardPort,
  attachmentPicker: RaisaAttachmentPickerPort
) {
  RaisaFeedbackPage({
    feedback: feedback,
    settings: settings,
    appInfo: appInfo,
    hapticService: hapticService,
    clipboard: clipboard,
    attachmentPicker: attachmentPicker
  });
}

/**
 * RAISA 档案系统维护工单页宿主：由手机产品层组装上下文参数、剪贴板、外链打开、附件选择与终端诊断快照。
 */
@ComponentV2
struct RaisaFeedbackPage {
  @Require @Param feedback: RaisaFeedbackViewModel;
  @Require @Param settings: SettingsViewModel;
  @Require @Param appInfo: AppInfoPort;
  @Require @Param hapticService: HapticFeedbackPort;
  @Require @Param clipboard: ClipboardPort;
  @Require @Param attachmentPicker: RaisaAttachmentPickerPort;

  private pageStack: NavPathStack | undefined = undefined;
  private navDestinationId: string = '';
  @Local private readonly navMotion: DestinationMotionState = new DestinationMotionState();
  @Local private routeReady: boolean = false;
  @Local private feedbackContext: RaisaFeedbackContext = emptyRaisaFeedbackContext('settings');
  private readonly scroller: Scroller = new Scroller();

  aboutToDisappear(): void {
    NavigationTransitionRegistry.unregister(this.navDestinationId);
  }

  private buildDiagnosticSnapshot(): RaisaDiagnosticSnapshot {
    return new RaisaDiagnosticSnapshot(
      this.appInfo.versionName(),
      this.appInfo.versionCode(),
      this.appInfo.versionLabel(),
      this.appInfo.deviceType(),
      this.appInfo.osLabel(),
      Math.round(windowWidthVp()),
      themeModeLabel(this.settings.themeMode),
      this.settings.immersiveMaterialEnabled,
      this.feedbackContext.entrySource,
      this.feedbackContext.articleId,
      this.feedbackContext.articleTitle,
      this.feedbackContext.articleUrl,
      this.feedbackContext.renderMode,
      this.feedbackContext.revealHiddenText
    );
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 2200
      });
    } catch (_error) {
    }
  }

  private async copyText(text: string, notice: string): Promise<void> {
    try {
      await this.clipboard.copyText(text);
      this.showToast(notice);
    } catch (error) {
      this.showToast(error instanceof Error ? error.message : '复制失败');
    }
  }

  private async openExternalUrl(rawUrl: string): Promise<void> {
    try {
      const safeUrl = ExternalUrlPolicy.resolveHttps(rawUrl, RAISA_GITHUB_ISSUES_URL);
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (context === undefined) {
        throw new Error('当前页面上下文不可用');
      }
      await context.openLink(safeUrl);
    } catch (_error) {
      this.showToast('无法打开浏览器');
    }
  }

  private async pickImages(remainingSlots: number): Promise<RaisaFeedbackAttachment[]> {
    try {
      return await this.attachmentPicker.pickImages(remainingSlots);
    } catch (error) {
      this.showToast(error instanceof Error ? error.message : '选择图片失败');
      return [];
    }
  }

  private async pickDocuments(remainingSlots: number): Promise<RaisaFeedbackAttachment[]> {
    try {
      return await this.attachmentPicker.pickDocuments(remainingSlots);
    } catch (error) {
      this.showToast(error instanceof Error ? error.message : '选择文件失败');
      return [];
    }
  }

  build() {
    HdsNavDestination() {
      if (this.routeReady) {
        RaisaFeedbackView({
          viewModel: this.feedback,
          scroller: this.scroller,
          initialContext: this.feedbackContext,
          diagnosticSnapshot: this.buildDiagnosticSnapshot(),
          materialEnabled: this.settings.immersiveMaterialEnabled,
          onHaptic: (): void => {
            this.hapticService.playSelection(this.settings.hapticEnabled);
          },
          onCopyText: (text: string, notice: string): void => {
            this.copyText(text, notice);
          },
          onOpenExternalUrl: (url: string): void => {
            this.openExternalUrl(url);
          },
          onPickImages: (remainingSlots: number): Promise<RaisaFeedbackAttachment[]> =>
            this.pickImages(remainingSlots),
          onPickDocuments: (remainingSlots: number): Promise<RaisaFeedbackAttachment[]> =>
            this.pickDocuments(remainingSlots)
        })
      }
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false,
      content: {
        title: { mainTitle: 'RAISA 终端运维工单' },
        backIcon: createAppBackIcon('feedbackBackButton', (): void => {
          popNavigationDestination(this.pageStack);
        })
      },
      style: createAppTitleBarStyle(this.settings.immersiveMaterialEnabled)
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
      this.feedbackContext = parseFeedbackRouteContext(context.pathInfo.param as Object | null | undefined);
      this.routeReady = true;
      if (!this.feedback.initialized) {
        this.feedback.initialize().catch((): void => {});
      }
    })
    .opacity(this.navMotion.opacity)
    .translate({ x: this.navMotion.translateX })
    .onBackPressed((): boolean => {
      popNavigationDestination(this.pageStack);
      return true;
    })
  }
}
