import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

// 应用程序主入口能力类
export default class EntryAbility extends UIAbility {
  // Ability创建时的回调函数
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 设置应用颜色模式
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  // Ability销毁时的回调函数
  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  // 窗口阶段创建时的回调函数
  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 主窗口已创建，为此Ability设置主页面
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  // 窗口阶段销毁时的回调函数
  onWindowStageDestroy(): void {
    // 主窗口已销毁，释放UI相关资源
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  // Ability进入前台时的回调函数
  onForeground(): void {
    // Ability已切换到前台
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  // Ability进入后台时的回调函数
  onBackground(): void {
    // Ability已切换到后台
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}