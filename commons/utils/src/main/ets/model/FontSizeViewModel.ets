/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import CommonConstants from "../constants/CommonConstants";
import PreferencesUtil from "../database/PreferencesUtil";


/**
 * Font size view model for managing font size settings.
 */
export class FontSizeViewModel {
  /**
   * Initialize font size preferences.
   */
  async initializeFontPreferences(context: Context): Promise<void> {
    PreferencesUtil.getFavoritePreferences(context);
  }

  /**
   * Get current font size.
   */
  async getCurrentFontSize(): Promise<number> {
    return PreferencesUtil.getFontSize();
  }

  /**
   * Save font size.
   */
  saveFontSize(fontSize: number): void {
    PreferencesUtil.saveFontSize(fontSize);
  }

  /**
   * Get font size description based on value.
   */
  getFontSizeDescription(fontSize: number): string {
    if (fontSize === CommonConstants.SET_SIZE_SMALL) {
      return '小';
    } else if (fontSize === CommonConstants.SET_SIZE_NORMAL) {
      return '标准';
    } else if (fontSize === CommonConstants.SET_SIZE_LARGE) {
      return '大';
    } else if (fontSize === CommonConstants.SET_SIZE_EXTRA_LARGE) {
      return '特大';
    } else if (fontSize === CommonConstants.SET_SIZE_HUGE) {
      return '超大';
    } else {
      return '自定义';
    }
  }

  /**
   * Get all available font sizes.
   */
  getAvailableFontSizes(): number[] {
    return [
      CommonConstants.SET_SIZE_SMALL,
      CommonConstants.SET_SIZE_NORMAL,
      CommonConstants.SET_SIZE_LARGE,
      CommonConstants.SET_SIZE_EXTRA_LARGE,
      CommonConstants.SET_SIZE_HUGE
    ];
  }
}

export default new FontSizeViewModel();