import { AppStorageV2 } from '@kit.ArkUI';
import CommonConstants from '../constants/CommonConstants';
import PreferencesUtil from '../database/PreferencesUtil';

/**
 * 系列状态管理类 - 用于跟踪当前选中的SCP系列
 * 使用@ObservedV2和@Trace确保状态变化能触发UI更新
 */
@ObservedV2
export class SeriesState {
  @Trace value: number = 0
}

/**
 * Observable font size data class for real-time UI updates.
 */
@ObservedV2
export class FontSizeData {
  @Trace fontSize: number = CommonConstants.SET_SIZE_NORMAL;

  constructor(fontSize: number = CommonConstants.SET_SIZE_NORMAL) {
    this.fontSize = fontSize;
  }
}

/**
 * Global font size manager for the application.
 */
export class FontSizeManager {
  private static instance: FontSizeManager | null = null;
  private static isInitialized: boolean = false;
  private static readonly FONT_SIZE_KEY = 'globalFontSize';

  /**
   * Get singleton instance.
   */
  static getInstance(): FontSizeManager {
    if (!FontSizeManager.instance) {
      FontSizeManager.instance = new FontSizeManager();
    }
    return FontSizeManager.instance;
  }

  /**
   * Initialize font size manager.
   */
  static async initialize(context: Context): Promise<void> {
    if (FontSizeManager.isInitialized) {
      return;
    }

    // 初始化偏好设置
    PreferencesUtil.getFavoritePreferences(context);

    // 获取保存的字体大小
    const savedFontSize = await PreferencesUtil.getFontSize() || CommonConstants.SET_SIZE_NORMAL;

    // 设置到全局存储，使用可观察的数据类
    AppStorageV2.connect(FontSizeData, FontSizeManager.FONT_SIZE_KEY, () => new FontSizeData(savedFontSize));

    FontSizeManager.isInitialized = true;
  }

  /**
   * Update global font size.
   */
  static updateFontSize(fontSize: number): void {
    // 保存到偏好设置
    PreferencesUtil.saveFontSize(fontSize);

    // 获取并更新全局存储中的值
    const fontSizeData = AppStorageV2.connect(FontSizeData, FontSizeManager.FONT_SIZE_KEY,
      () => new FontSizeData(CommonConstants.SET_SIZE_NORMAL));
    if (fontSizeData) {
      // 直接修改@Trace装饰的属性，会自动触发UI更新
      fontSizeData.fontSize = fontSize;
    }
  }

  /**
   * Get current font size.
   */
  static getCurrentFontSize(): number {
    const fontSizeData = AppStorageV2.connect(FontSizeData, FontSizeManager.FONT_SIZE_KEY,
      () => new FontSizeData(CommonConstants.SET_SIZE_NORMAL));
    return fontSizeData?.fontSize || CommonConstants.SET_SIZE_NORMAL;
  }

  /**
   * Get scaled font size based on base size.
   */
  static getScaledFontSize(baseSize: number): number {
    const currentSize = FontSizeManager.getCurrentFontSize();
    const scale = currentSize / CommonConstants.SET_SIZE_NORMAL;
    return Math.round(baseSize * scale);
  }

  /**
   * Get font size data object for UI binding.
   */
  static getFontSizeData(): FontSizeData | undefined {
    return AppStorageV2.connect(FontSizeData, FontSizeManager.FONT_SIZE_KEY,
      () => new FontSizeData(CommonConstants.SET_SIZE_NORMAL));
  }
}

export default FontSizeManager;