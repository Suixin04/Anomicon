import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FrameCallback, window } from '@kit.ArkUI';
import { ThemeMode } from 'settings';
import { AppLifecycleCoordinator } from '../composition/AppLifecycleCoordinator';
import { notifyStartingWindowReleased } from '../startup/StartupCoordinator';
import { updateWindowAvoidArea } from 'anomiconbasic';

const DOMAIN: number = 0x0000;
const TAG: string = 'AnomiconAbility';
// Keep non-critical persistence away from the system-window settle period,
// stable-layout sampling and the roughly 660ms product hand-off.
const STARTUP_WARM_UP_DELAY_MS: number = 1650;

/** Starts non-critical persistence after the launch transition has cleared. */
class StartupWarmUpFrameCallback extends FrameCallback {
  private readonly task: () => void;

  constructor(task: () => void) {
    super();
    this.task = task;
  }

  onFrame(_frameTimeInNano: number): void {
    this.task();
  }
}

/** Phone product entry point.  The active path re-exports this class. */
export default class EntryAbility extends UIAbility {
  private readonly lifecycle: AppLifecycleCoordinator = new AppLifecycleCoordinator();
  private avoidAreaWindow: window.Window | undefined = undefined;
  private avoidAreaCallback: ((options: window.AvoidAreaOptions) => void) | undefined = undefined;

  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  async onDestroy(): Promise<void> {
    await this.lifecycle.releaseAbility(this.context);
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');
    const lifecycle = this.lifecycle;
    lifecycle.initialize(this.context);
    // Settings are read synchronously while assembling the minimal shared VM.
    // Apply them before the first ArkUI frame to prevent a light/dark flash.
    lifecycle.applyInitialTheme(this.context);
    const windowBackgroundColor = this.resolveWindowBackgroundColor(
      lifecycle.initialThemeMode(this.context),
      this.context.config.colorMode
    );
    try {
      this.applyWindowBackground(windowStage.getMainWindowSync(), windowBackgroundColor);
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Set initial window background failed: %{public}s', businessError.message);
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        this.releaseStartingWindow(windowStage);
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
      try {
        this.applyWindowBackground(windowStage.getMainWindowSync(), this.resolveWindowBackgroundColor(
          lifecycle.initialThemeMode(this.context),
          this.context.config.colorMode
        ));
      } catch (error) {
        const businessError = error as BusinessError;
        hilog.warn(DOMAIN, TAG, 'Sync window background failed: %{public}s', businessError.message);
      }
      this.releaseStartingWindow(windowStage);
      if (!lifecycle.isCurrentAbility(this.context)) {
        return;
      }
      this.trackWindowAvoidArea(windowStage);
      this.scheduleWarmUp(windowStage);
    });
  }

  /**
   * Keep the system Starting Window until the matching ArkUI content tree has
   * reached its next render callback.  That callback is not a compositor-finish
   * signal; the coordinator applies its own measured settle and layout gates
   * after the explicit removal operation completes.
   */
  private releaseStartingWindow(windowStage: window.WindowStage): void {
    try {
      const uiContext = windowStage.getMainWindowSync().getUIContext();
      uiContext.postFrameCallback(new StartupWarmUpFrameCallback((): void => {
        windowStage.removeStartingWindow().then((): void => {
          hilog.info(DOMAIN, TAG, '%{public}s', 'Starting window removed.');
          notifyStartingWindowReleased();
        }).catch((error: BusinessError): void => {
          hilog.warn(DOMAIN, TAG, 'Remove starting window failed: %{public}s', error.message);
          notifyStartingWindowReleased();
        });
      }));
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Schedule starting window removal failed: %{public}s', businessError.message);
      notifyStartingWindowReleased();
    }
  }

  private scheduleWarmUp(windowStage: window.WindowStage): void {
    try {
      const uiContext = windowStage.getMainWindowSync().getUIContext();
      const lifecycle = this.lifecycle;
      uiContext.postDelayedFrameCallback(new StartupWarmUpFrameCallback((): void => {
        if (lifecycle.isCurrentAbility(this.context)) {
          lifecycle.warmUp(this.context);
        }
      }), STARTUP_WARM_UP_DELAY_MS);
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Schedule application warm-up failed: %{public}s', businessError.message);
      if (this.lifecycle.isCurrentAbility(this.context)) {
        this.lifecycle.warmUp(this.context);
      }
    }
  }

  private trackWindowAvoidArea(windowStage: window.WindowStage): void {
    try {
      const mainWindow = windowStage.getMainWindowSync();
      const uiContext = mainWindow.getUIContext();
      const lifecycle = this.lifecycle;
      const apply = (): void => {
        if (!lifecycle.isCurrentAbility(this.context)) {
          return;
        }
        const avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        updateWindowAvoidArea(uiContext.px2vp(Number(avoidArea.topRect.height)));
      };
      apply();
      const callback = (options: window.AvoidAreaOptions): void => {
        if (options.type === window.AvoidAreaType.TYPE_SYSTEM &&
          lifecycle.isCurrentAbility(this.context)) {
          updateWindowAvoidArea(uiContext.px2vp(Number(options.area.topRect.height)));
        }
      };
      mainWindow.on('avoidAreaChange', callback);
      this.avoidAreaWindow = mainWindow;
      this.avoidAreaCallback = callback;
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Read window avoid area failed: %{public}s', businessError.message);
    }
  }

  onWindowStageWillDestroy(_windowStage: window.WindowStage): void {
    this.releaseWindowAvoidAreaListener();
  }

  onWindowStageDestroy(): void {
    this.lifecycle.resetAbility(this.context);
    this.releaseWindowAvoidAreaListener();
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    this.lifecycle.setForeground(this.context, true);
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onWillBackground(): void {
    this.lifecycle.setForeground(this.context, false);
  }

  onBackground(): void {
    const lifecycle = this.lifecycle;
    lifecycle.setForeground(this.context, false);
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
    lifecycle.flush(this.context).catch((error: Object): void => {
      const message = error instanceof Error ? error.message : 'unknown error';
      hilog.warn(DOMAIN, TAG, 'Flush persistence failed: %{public}s', message);
    });
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    if (this.avoidAreaWindow !== undefined) {
      this.applyWindowBackground(
        this.avoidAreaWindow,
        this.resolveWindowBackgroundColor(
          this.lifecycle.initialThemeMode(this.context),
          newConfig.colorMode
        )
      );
    }
  }

  private resolveWindowBackgroundColor(
    mode: ThemeMode,
    colorMode: ConfigurationConstant.ColorMode | undefined
  ): string {
    if (mode === ThemeMode.DARK) {
      return '#000000';
    }
    if (mode === ThemeMode.LIGHT) {
      return '#F1F3F5';
    }
    return colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#000000' : '#F1F3F5';
  }

  private applyWindowBackground(mainWindow: window.Window, color: string): void {
    try {
      mainWindow.setWindowBackgroundColor(color);
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Set window background color failed: %{public}s', businessError.message);
    }
  }

  private releaseWindowAvoidAreaListener(): void {
    if (this.avoidAreaWindow !== undefined && this.avoidAreaCallback !== undefined) {
      try {
        this.avoidAreaWindow.off('avoidAreaChange', this.avoidAreaCallback);
      } catch (error) {
        const businessError = error as BusinessError;
        hilog.warn(DOMAIN, TAG, 'Release window avoid area listener failed: %{public}s', businessError.message);
      }
    }
    this.avoidAreaWindow = undefined;
    this.avoidAreaCallback = undefined;
  }
}
