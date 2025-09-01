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

import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import CommonConstants from '../constants/CommonConstants';

const TAG = 'PreferencesUtil';

/**
 * The PreferencesUtil provides preferences of create, save and query for SCP favorites.
 */
export class PreferencesUtil {
  preference?: preferences.Preferences;

  /**
   * The method of creating a preferences Instance.
   */
  getFavoritePreferences(context: Context) {
    this.preference = preferences.getPreferencesSync(context, { name: 'SCPFavoritePreferences' });
    hilog.info(0x0000, TAG, 'create favorite preferences success');
  }

  /**
   * The method of saving favorite count.
   */
  saveFavoriteCount(count: number) {
    this.preference?.putSync(CommonConstants.KEY_FAVORITE_COUNT, count);
    this.preference?.flush(
      (err: BusinessError) => {
        if (err) {
          hilog.error(0x0000, TAG, 'Failed to flush favorite count. code =' + err.code + ', message =' + err.message);
          return;
        }
        hilog.info(0x0000, TAG, 'Succeeded in flushing favorite count.');
      });
  }

  /**
   * The method of getting favorite count.
   */
  getFavoriteCount(): number {
    let count: number = 0;
    count = this.preference?.getSync(CommonConstants.KEY_FAVORITE_COUNT, 0) as number;
    return count;
  }

  /**
   * The method of saving last favorite date.
   */
  saveLastFavoriteDate(date: string) {
    this.preference?.putSync(CommonConstants.KEY_LAST_FAVORITE_DATE, date);
    this.preference?.flush(
      (err: BusinessError) => {
        if (err) {
          hilog.error(0x0000, TAG,
            'Failed to flush last favorite date. code =' + err.code + ', message =' + err.message);
          return;
        }
        hilog.info(0x0000, TAG, 'Succeeded in flushing last favorite date.');
      });
  }

  /**
   * The method of getting last favorite date.
   */
  getLastFavoriteDate(): string {
    let date: string = '';
    date = this.preference?.getSync(CommonConstants.KEY_LAST_FAVORITE_DATE, '') as string;
    return date;
  }

  /**
   * The method of checking if a key exists.
   */
  async isKeyExist(key: string): Promise<boolean> {
    let isKeyExist: boolean = false;
    try {
      isKeyExist = await this.preference?.has(key) || false;
    } catch (err) {
      hilog.error(0x0000, TAG, 'Has the value failed with err: ' + err);
    }
    return isKeyExist;
  }

  /**
   * The method of saving font size.
   */
  saveFontSize(fontSize: number) {
    this.preference?.putSync(CommonConstants.KEY_APP_FONT_SIZE, fontSize);
    this.preference?.flush(
      (err: BusinessError) => {
        if (err) {
          hilog.error(0x0000, TAG, 'Failed to flush font size. code =' + err.code + ', message =' + err.message);
          return;
        }
        hilog.info(0x0000, TAG, 'Succeeded in flushing font size.');
      });
  }

  /**
   * The method of getting font size.
   */
  async getFontSize(): Promise<number> {
    let fontSize: number = CommonConstants.SET_SIZE_NORMAL;
    fontSize = this.preference?.getSync(CommonConstants.KEY_APP_FONT_SIZE, CommonConstants.SET_SIZE_NORMAL) as number;
    return fontSize;
  }

  saveApproveStatus(status: boolean) {
    this.preference?.putSync(CommonConstants.KEY_APPROVE_STATUS, status);
    this.preference?.flush(
      (err: BusinessError) => {
        if (err) {
          hilog.error(0x0000, TAG, 'Failed to flush approve status. code =' + err.code + ', message =' + err.message);
          return;
        }
        hilog.info(0x0000, TAG, 'Succeeded in flushing approve status.');
      });
  }

  getApproveStatus(): boolean {
    if (!this.preference) {
      hilog.warn(0x0000, TAG, 'PreferencesUtil not initialized, using default approve status');
      return CommonConstants.APPROVE_STATUS;
    }
    const status = this.preference.getSync(CommonConstants.KEY_APPROVE_STATUS, CommonConstants.APPROVE_STATUS);
    return status !== undefined ? Boolean(status) : CommonConstants.APPROVE_STATUS;
  }

  async getApproveStatusAsync(): Promise<boolean> {
    try {
      const status = await this.preference?.get(CommonConstants.KEY_APPROVE_STATUS, CommonConstants.APPROVE_STATUS);
      return status !== undefined ? Boolean(status) : CommonConstants.APPROVE_STATUS;
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to get approve status: ' + error);
      return CommonConstants.APPROVE_STATUS;
    }
  }
}

export default new PreferencesUtil();