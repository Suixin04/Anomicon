import { common } from '@kit.AbilityKit';
import { ThemeMode } from 'settings';
import { AppContainer } from './AppContainer';

/** Phone-product lifecycle composition root. */
export class AppLifecycleCoordinator {
  initialize(context: common.UIAbilityContext): void {
    AppContainer.getInstance().initialize(context);
  }

  /** Resume non-critical stores only after the first-page transition is visible. */
  warmUp(context: common.UIAbilityContext): void {
    const appContainer = AppContainer.getInstance();
    if (!appContainer.ownsAbility(context)) {
      return;
    }
    this.initializeAsync('application warm-up', appContainer.warmUp(context));
  }

  isCurrentAbility(context: common.UIAbilityContext): boolean {
    return AppContainer.getInstance().ownsAbility(context);
  }

  applyInitialTheme(context: common.UIAbilityContext): void {
    AppContainer.getInstance().applyInitialTheme(context);
  }

  initialThemeMode(context: common.UIAbilityContext): ThemeMode {
    return AppContainer.getInstance().initialThemeMode(context);
  }

  setForeground(context: common.UIAbilityContext, foreground: boolean): void {
    AppContainer.getInstance().setReadingActivityForeground(context, foreground);
  }

  /**
   * Wait for all application persistence queues (settings and reading
   * activity) before the Ability teardown callback returns.
   */
  flush(context: common.UIAbilityContext): Promise<void> {
    return AppContainer.getInstance().flushAbility(context);
  }

  /** Release only the graph owned by this exact Ability instance. */
  async releaseAbility(context: common.UIAbilityContext): Promise<void> {
    await AppContainer.getInstance().releaseAbility(context);
  }

  resetAbility(context: common.UIAbilityContext): void {
    AppContainer.getInstance().resetAbility(context);
  }

  private initializeAsync(name: string, task: Promise<void>): void {
    task.catch((error: Object): void => {
      const message = error instanceof Error ? error.message : 'unknown error';
      console.error(`${name} failed: ${message}`);
    });
  }
}
