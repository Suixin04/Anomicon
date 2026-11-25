import {
  HideMode,
  HdsNavDestination,
  HdsNavDestinationTitleMode
} from '@kit.UIDesignKit';
import {
  FoundationAssessmentExam,
  FoundationAssessmentSubmissionResult,
  FoundationAssessmentViewModel,
  LibraryContentRef,
  findFoundationAssessmentExam
} from 'library';
import { FoundationAssessmentView } from 'terminal';
import { SettingsViewModel } from 'settings';
import {
  createAppBackIcon,
  createAppTitleBarStyle,
  DestinationMotionState,
  HapticFeedbackPort,
  NavigationTransitionRegistry,
  popNavigationDestination
} from 'anomiconbasic';
import {
  AppRoutes,
  ScpArticleRouteParams
} from '../navigation/AppRoutes';
import { AppNavigationCoordinator } from '../navigation/AppNavigationCoordinator';
import { parseAssessmentRouteExamId } from '../navigation/RouteParamAdapters';

@Builder
export function FoundationAssessmentPageBuilder(
  assessments: FoundationAssessmentViewModel,
  settings: SettingsViewModel,
  hapticService: HapticFeedbackPort
) {
  FoundationAssessmentPage({
    assessments: assessments,
    settings: settings,
    hapticService: hapticService
  });
}

/**
 * 基金会资质考核详情页宿主：由手机产品层组装路由参数、触感反馈与回跳阅读。
 */
@ComponentV2
struct FoundationAssessmentPage {
  @Require @Param assessments: FoundationAssessmentViewModel;
  @Require @Param settings: SettingsViewModel;
  @Require @Param hapticService: HapticFeedbackPort;

  private pageStack: NavPathStack | undefined = undefined;
  private navDestinationId: string = '';
  @Local private readonly navMotion: DestinationMotionState = new DestinationMotionState();
  @Local private exam: FoundationAssessmentExam | undefined = undefined;
  private readonly scroller: Scroller = new Scroller();

  aboutToDisappear(): void {
    NavigationTransitionRegistry.unregister(this.navDestinationId);
  }

  private resolveExam(param: Object | null | undefined): void {
    const examId = parseAssessmentRouteExamId(param);
    this.exam = examId.length > 0 ? findFoundationAssessmentExam(examId) : undefined;
  }

  private pageTitle(): string {
    return this.exam !== undefined ? `${this.exam.code} · ${this.exam.title}` : '档案资质考核';
  }

  private openReference(content: LibraryContentRef): void {
    this.hapticService.playSelection(this.settings.hapticEnabled);
    const params: ScpArticleRouteParams = { content: content };
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.ARTICLE, params);
  }

  build() {
    HdsNavDestination() {
      if (this.exam !== undefined) {
        FoundationAssessmentView({
          exam: this.exam!,
          scroller: this.scroller,
          initialRecord: this.assessments.recordFor(this.exam!.id),
          profileRefreshError: this.assessments.profileRefreshError,
          onRetryProfileRefresh: (): void => { this.assessments.refreshResearchProfile(); },
          materialEnabled: this.settings.immersiveMaterialEnabled,
          hapticEnabled: this.settings.hapticEnabled,
          onHaptic: (): void => {
            this.hapticService.playSelection(this.settings.hapticEnabled);
          },
          onSubmitAttempt: (
            examId: string,
            score: number
          ): Promise<FoundationAssessmentSubmissionResult> =>
            this.assessments.submitAttempt(examId, score),
          onOpenReference: (content: LibraryContentRef): void => this.openReference(content),
          onFinishClose: (): void => {
            this.hapticService.playSelection(this.settings.hapticEnabled);
            popNavigationDestination(this.pageStack);
          }
        })
      } else {
        Column({ space: 12 }) {
          Text('未找到对应的资质考核科目')
            .fontSize(15)
            .fontColor($r('sys.color.font_secondary'))
          Button('返回基金会', { stateEffect: false })
            .onClick(() => popNavigationDestination(this.pageStack))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false,
      content: {
        title: { mainTitle: this.pageTitle() },
        backIcon: createAppBackIcon('assessmentBackButton', (): void => {
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
      this.resolveExam(context.pathInfo.param as Object | null | undefined);
      if (!this.assessments.initialized) {
        this.assessments.initialize().catch((): void => {});
      }
    })
    .opacity(this.navMotion.opacity)
    .translate({ x: this.navMotion.translateX })
    .onBackPressed((): boolean => {
      popNavigationDestination(this.pageStack);
      return true;
    })
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    )
  }
}
