import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  AppSettings,
  ComplexPageMode,
  ReadingSettingsRange,
  ReadingTextAlign,
  ThemeMode,
  parseComplexPageMode,
  parseReadingTextAlign
} from '../domain/SettingsModels';
import { SettingsRepository } from '../domain/SettingsRepository';

class SettingsPreferenceKeys {
  static readonly THEME_MODE: string = 'theme_mode';
  static readonly HAPTIC_ENABLED: string = 'haptic_enabled';
  static readonly IMMERSIVE_MATERIAL_ENABLED: string = 'immersive_material_enabled';
  static readonly FONT_SIZE: string = 'reading_font_size_v2';
  static readonly LINE_HEIGHT_MULTIPLE: string = 'reading_line_height_multiple_v2';
  static readonly COMPLEX_PAGE_MODE: string = 'complex_page_mode';
  static readonly DEFAULT_REVEAL_HIDDEN_TEXT: string = 'default_reveal_hidden_text';
  static readonly READING_TEXT_ALIGN: string = 'reading_text_align';
  static readonly KEEP_SCREEN_ON_READING: string = 'keep_screen_on_reading';
}

const PREFERENCES_NAME: string = 'anomicon_settings_v3';

interface SettingsPreferenceValues {
  theme_mode?: preferences.ValueType;
  haptic_enabled?: preferences.ValueType;
  immersive_material_enabled?: preferences.ValueType;
  reading_font_size_v2?: preferences.ValueType;
  reading_line_height_multiple_v2?: preferences.ValueType;
  complex_page_mode?: preferences.ValueType;
  default_reveal_hidden_text?: preferences.ValueType;
  reading_text_align?: preferences.ValueType;
  keep_screen_on_reading?: preferences.ValueType;
}

/** Harmony Preferences 对设置仓库端口的实现。 */
export class SettingsPreferencesRepo implements SettingsRepository {
  private readonly context: common.UIAbilityContext;
  private dataPreferences: preferences.Preferences | undefined = undefined;
  private flushTask: Promise<void> | undefined = undefined;
  private dirty: boolean = false;
  lastError: string = '';

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.ensurePreferences();
  }

  load(): AppSettings {
    this.lastError = '';
    const store = this.ensurePreferences();
    if (store === undefined) {
      this.lastError = '设置存储暂不可用';
      return new AppSettings();
    }
    try {
      const values = store.getAllSync() as SettingsPreferenceValues;
      const haptic = this.readBoolean(values.haptic_enabled, true, '触感反馈');
      const immersiveMaterial = this.readBoolean(
        values.immersive_material_enabled,
        true,
        '沉浸光感'
      );
      const fontSize = this.readNumber(
        values.reading_font_size_v2,
        ReadingSettingsRange.FONT_SIZE_DEFAULT,
        '正文字号'
      );
      const lineHeight = this.readNumber(
        values.reading_line_height_multiple_v2,
        ReadingSettingsRange.LINE_HEIGHT_DEFAULT,
        '阅读行距'
      );
      const complexPageMode = parseComplexPageMode(
        typeof values.complex_page_mode === 'string' ? values.complex_page_mode : undefined
      );
      const defaultRevealHiddenText = this.readBoolean(
        values.default_reveal_hidden_text,
        false,
        '默认反白透视'
      );
      const readingTextAlign = parseReadingTextAlign(
        typeof values.reading_text_align === 'string' ? values.reading_text_align : undefined
      );
      const keepScreenOnReading = this.readBoolean(
        values.keep_screen_on_reading,
        false,
        '阅读时屏幕常亮'
      );
      return new AppSettings(
        this.parseThemeMode(values.theme_mode),
        haptic,
        immersiveMaterial,
        fontSize,
        lineHeight,
        complexPageMode,
        defaultRevealHiddenText,
        readingTextAlign,
        keepScreenOnReading
      );
    } catch (error) {
      this.logError('Load settings', error);
      this.lastError = '设置读取失败，已保留当前设置';
      return new AppSettings();
    }
  }

  saveThemeMode(value: ThemeMode): boolean {
    return this.persist(SettingsPreferenceKeys.THEME_MODE, value);
  }

  saveHapticEnabled(value: boolean): boolean {
    return this.persist(SettingsPreferenceKeys.HAPTIC_ENABLED, value);
  }

  saveImmersiveMaterialEnabled(value: boolean): boolean {
    return this.persist(SettingsPreferenceKeys.IMMERSIVE_MATERIAL_ENABLED, value);
  }

  saveFontSize(value: number): boolean {
    return this.persist(SettingsPreferenceKeys.FONT_SIZE, value);
  }

  saveLineHeightMultiple(value: number): boolean {
    return this.persist(SettingsPreferenceKeys.LINE_HEIGHT_MULTIPLE, value);
  }

  saveComplexPageMode(value: ComplexPageMode): boolean {
    return this.persist(SettingsPreferenceKeys.COMPLEX_PAGE_MODE, value);
  }

  saveDefaultRevealHiddenText(value: boolean): boolean {
    return this.persist(SettingsPreferenceKeys.DEFAULT_REVEAL_HIDDEN_TEXT, value);
  }

  saveReadingTextAlign(value: ReadingTextAlign): boolean {
    return this.persist(SettingsPreferenceKeys.READING_TEXT_ALIGN, value);
  }

  saveKeepScreenOnReading(value: boolean): boolean {
    return this.persist(SettingsPreferenceKeys.KEEP_SCREEN_ON_READING, value);
  }

  flush(): Promise<void> {
    if (!this.dirty) {
      return this.flushTask ?? Promise.resolve();
    }
    if (this.flushTask !== undefined) {
      return this.flushTask;
    }
    this.flushTask = this.flushPendingWrites();
    return this.flushTask;
  }

  private persist(key: string, value: preferences.ValueType): boolean {
    this.lastError = '';
    const store = this.ensurePreferences();
    if (store === undefined) {
      this.lastError = '设置存储暂不可用';
      return false;
    }
    try {
      store.putSync(key, value);
      this.dirty = true;
      // Keep the UI event synchronous while scheduling a durable write. The
      // lifecycle flush still observes the same promise and can retry failures.
      this.flush().catch((error: Object): void => {
        this.logError('Background flush settings', error);
      });
      return true;
    } catch (error) {
      this.logError(`Persist setting '${key}'`, error);
      this.lastError = '设置保存失败';
      return false;
    }
  }

  /** 合并连续设置写入；写入发生在 flush 期间时，再补一次落盘。 */
  private async flushPendingWrites(): Promise<void> {
    const store = this.dataPreferences;
    if (store === undefined) {
      this.dirty = false;
      this.flushTask = undefined;
      return;
    }
    try {
      while (this.dirty) {
        this.dirty = false;
        await store.flush();
      }
    } catch (error) {
      // 保留 dirty，后台/退出阶段可以再次尝试；调用方必须知道本次落盘失败。
      this.dirty = true;
      this.logError('Flush settings', error as Object);
      this.lastError = '设置落盘失败';
      throw error instanceof Error ? error : new Error('设置落盘失败');
    } finally {
      this.flushTask = undefined;
    }
  }

  /** Preferences may fail while the Ability/storage service is starting; retry on use. */
  private ensurePreferences(): preferences.Preferences | undefined {
    if (this.dataPreferences !== undefined) {
      return this.dataPreferences;
    }
    try {
      this.dataPreferences = preferences.getPreferencesSync(
        this.context,
        { name: PREFERENCES_NAME }
      );
    } catch (error) {
      this.logError('Initialize settings repository', error);
    }
    return this.dataPreferences;
  }

  private parseThemeMode(value: preferences.ValueType | undefined): ThemeMode {
    if (value === ThemeMode.LIGHT) {
      return ThemeMode.LIGHT;
    }
    if (value === ThemeMode.DARK) {
      return ThemeMode.DARK;
    }
    return ThemeMode.SYSTEM;
  }

  private readBoolean(
    value: preferences.ValueType | undefined,
    fallback: boolean,
    label: string
  ): boolean {
    if (value === undefined) {
      return fallback;
    }
    if (typeof value !== 'boolean') {
      throw new Error(`${label}设置类型无效`);
    }
    return value;
  }

  private readNumber(
    value: preferences.ValueType | undefined,
    fallback: number,
    label: string
  ): number {
    if (value === undefined) {
      return fallback;
    }
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      throw new Error(`${label}设置类型无效`);
    }
    return value;
  }

  private logError(operation: string, error: Object): void {
    const businessError: BusinessError = error as BusinessError;
    console.error(`${operation} failed. Code: ${businessError.code}, message: ${businessError.message}`);
  }
}
