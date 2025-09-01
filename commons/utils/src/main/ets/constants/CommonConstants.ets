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

/**
 * Common constants for SCP favorite features.
 */
export default class CommonConstants {
  /**
   * The sql of creating favorites table.
   */
  static readonly CREATE_FAVORITES_TABLE_SQL: string =
    'CREATE TABLE IF NOT EXISTS FAVORITES (ID INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'SCP_ID TEXT NOT NULL UNIQUE, SCP_NUMBER TEXT NOT NULL, TITLE TEXT NOT NULL, ' +
      'OBJECT_CLASS TEXT NOT NULL, DESCRIPTION TEXT, IMAGE_URL TEXT, ' +
      'DATE_ADDED TEXT NOT NULL, TYPE TEXT NOT NULL)';
  /**
   * The sql of querying all favorites.
   */
  static readonly QUERY_ALL_FAVORITES_SQL: string =
    'SELECT * FROM FAVORITES ORDER BY DATE_ADDED DESC';
  /**
   * The sql of querying favorites by type.
   */
  static readonly QUERY_FAVORITES_BY_TYPE_SQL: string =
    'SELECT * FROM FAVORITES WHERE TYPE = ? ORDER BY DATE_ADDED DESC';
  /**
   * The sql of checking if item is favorited.
   */
  static readonly CHECK_FAVORITE_SQL: string =
    'SELECT COUNT(*) as count FROM FAVORITES WHERE SCP_ID = ?';
  /**
   * Favorite item types.
   */
  static readonly FAVORITE_TYPE_SCP: string = 'SCP';
  static readonly FAVORITE_TYPE_TALE: string = 'TALE';
  /**
   * Preferences keys.
   */
  static readonly KEY_FAVORITE_COUNT: string = 'favoriteCount';
  static readonly KEY_LAST_FAVORITE_DATE: string = 'lastFavoriteDate';
  static readonly KEY_APP_FONT_SIZE: string = 'appFontSize';
  static readonly KEY_APPROVE_STATUS: string = 'isApproved';
  /**
   * Font size constants.
   */
  static readonly SET_SIZE_SMALL: number = 14;
  static readonly SET_SIZE_NORMAL: number = 16;
  static readonly SET_SIZE_LARGE: number = 18;
  static readonly SET_SIZE_EXTRA_LARGE: number = 20;
  static readonly SET_SIZE_HUGE: number = 24;
  /**
   * Slider constants for font size.
   */
  static readonly SET_SLIDER_MIN: number = 14;
  static readonly SET_SLIDER_MAX: number = 24;
  static readonly SET_SLIDER_STEP: number = 2;

  static readonly APPROVE_STATUS: boolean = false;
}