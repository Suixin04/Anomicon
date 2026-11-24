import { AppSettings, ComplexPageMode, ReadingTextAlign, ThemeMode } from './SettingsModels';

/** 设置数据端口。领域与展示层不感知 Preferences。 */
export interface SettingsRepository {
  /** Optional diagnostic from the platform-backed store. */
  readonly lastError?: string;
  load(): AppSettings;
  /** Returns false when the value could not be accepted by the persistence port. */
  saveThemeMode(value: ThemeMode): boolean;
  saveHapticEnabled(value: boolean): boolean;
  saveImmersiveMaterialEnabled(value: boolean): boolean;
  saveFontSize(value: number): boolean;
  saveLineHeightMultiple(value: number): boolean;
  saveComplexPageMode(value: ComplexPageMode): boolean;
  saveDefaultRevealHiddenText(value: boolean): boolean;
  saveReadingTextAlign(value: ReadingTextAlign): boolean;
  saveKeepScreenOnReading(value: boolean): boolean;
  flush(): Promise<void>;
}

/** 系统主题能力端口。ViewModel 不直接依赖 AbilityKit。 */
export interface ThemeModeApplier {
  apply(value: ThemeMode): void;
}
