import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { setDarkModeActive } from 'anomiconbasic';
import { ThemeMode } from '../domain/SettingsModels';
import { ThemeModeApplier } from '../domain/SettingsRepository';

/** 把领域主题值翻译为 HarmonyOS 系统颜色模式。 */
export class HarmonyThemeModeApplier implements ThemeModeApplier {
  private readonly applicationContext: common.ApplicationContext;

  constructor(applicationContext: common.ApplicationContext) {
    this.applicationContext = applicationContext;
  }

  apply(value: ThemeMode): void {
    try {
      this.applicationContext.setColorMode(this.toSystemColorMode(value));
      if (value === ThemeMode.DARK) {
        setDarkModeActive(true);
      } else if (value === ThemeMode.LIGHT) {
        setDarkModeActive(false);
      }
    } catch (error) {
      const businessError = error as BusinessError;
      console.error(
        `Apply theme mode failed. Code: ${businessError.code}, message: ${businessError.message}`
      );
    }
  }

  private toSystemColorMode(value: ThemeMode): ConfigurationConstant.ColorMode {
    if (value === ThemeMode.LIGHT) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
    if (value === ThemeMode.DARK) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  }
}
