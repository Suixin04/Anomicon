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

import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import CommonConstants from '../constants/CommonConstants';
import { FavoriteItem } from '../model/FavoriteItem';

const TAG: string = 'RDBStoreUtil';

/**
 * The RDBStoreUtil provides rdbStore of create, save and query for SCP favorites.
 */
export class RDBStoreUtil {
  favoriteRDB?: relationalStore.RdbStore;
  private isInitialized: boolean = false;

  /**
   * The method of creating an RDBStore Instance.
   */
  async createFavoriteRDB(context: Context): Promise<void> {
    if (this.isInitialized && this.favoriteRDB) {
      return;
    }

    const STORE_CONFIG: relationalStore.StoreConfig = {
      name: 'SCPFavorite.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };

    return new Promise<void>((resolve, reject) => {
      relationalStore.getRdbStore(context, STORE_CONFIG, (err: BusinessError, rdbStore: relationalStore.RdbStore) => {
        if (err) {
          hilog.error(0x0000, TAG, `Get RdbStore failed, code is ${err.code},message is ${err.message}`);
          reject(err);
          return;
        }

        this.favoriteRDB = rdbStore;
        hilog.info(0x0000, TAG, 'Get RdbStore successfully.');

        // 创建表
        this.createFavoriteTable().then(() => {
          this.isInitialized = true;
          resolve();
        }).catch((error: Error) => {
          reject(error);
        });
      });
    });
  }

  /**
   * The method of creating a favorite table.
   */
  async createFavoriteTable(): Promise<void> {
    if (!this.favoriteRDB) {
      throw new Error('RdbStore is not initialized');
    }

    try {
      await this.favoriteRDB.execute(CommonConstants.CREATE_FAVORITES_TABLE_SQL);
      hilog.info(0x0000, TAG, `execute create favorite table sql success`);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(0x0000, TAG, `execute sql failed, code is ${error.code},message is ${error.message}`);
      throw new Error(`execute sql failed, code is ${error.code},message is ${error.message}`);
    }
  }

  /**
   * The method of inserting a favorite item.
   */
  async insertFavorite(item: FavoriteItem): Promise<boolean> {
    const favoriteData: relationalStore.ValuesBucket = {
      'SCP_ID': item.scpId,
      'SCP_NUMBER': item.scpNumber,
      'TITLE': item.title,
      'OBJECT_CLASS': item.objectClass,
      'DESCRIPTION': item.description,
      'IMAGE_URL': item.imageUrl,
      'DATE_ADDED': item.dateAdded,
      'TYPE': item.type
    };

    try {
      const rowId = await this.favoriteRDB?.insert('FAVORITES', favoriteData,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
      hilog.info(0x0000, TAG, `Insert favorite successful, rowId = ${rowId}`);
      return true;
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(0x0000, TAG, `Insert favorite failed, code is ${error.code},message is ${error.message}`);
      return false;
    }
  }

  /**
   * The method of deleting a favorite item.
   */
  async deleteFavorite(scpId: string): Promise<boolean> {
    let predicates = new relationalStore.RdbPredicates('FAVORITES');
    predicates.equalTo('SCP_ID', scpId);

    try {
      const rows = await this.favoriteRDB?.delete(predicates);
      hilog.info(0x0000, TAG, `Delete favorite rows: ${rows}`);
      return (rows as number) > 0;
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(0x0000, TAG, `Delete favorite failed, code is ${error.code},message is ${error.message}`);
      return false;
    }
  }

  /**
   * The method of checking if an item is favorited.
   */
  async isFavorited(scpId: string): Promise<boolean> {
    try {
      const resultSet = await this.favoriteRDB?.querySql(CommonConstants.CHECK_FAVORITE_SQL, [scpId]);
      if (resultSet && resultSet.goToFirstRow()) {
        const count = resultSet.getValue(resultSet.getColumnIndex('count')) as number;
        resultSet.close();
        return count > 0;
      }
      return false;
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(0x0000, TAG, `Check favorite failed, code is ${error.code},message is ${error.message}`);
      return false;
    }
  }

  /**
   * The method of querying all favorites.
   */
  async queryAllFavorites(): Promise<FavoriteItem[]> {
    let favoritesSet: Array<FavoriteItem> = [];

    try {
      const resultSet = await this.favoriteRDB?.querySql(CommonConstants.QUERY_ALL_FAVORITES_SQL);
      if (resultSet) {
        while (resultSet.goToNextRow()) {
          const id = resultSet.getValue(resultSet.getColumnIndex('ID')) as number;
          const scpId = resultSet.getValue(resultSet.getColumnIndex('SCP_ID')) as string;
          const scpNumber = resultSet.getValue(resultSet.getColumnIndex('SCP_NUMBER')) as string;
          const title = resultSet.getValue(resultSet.getColumnIndex('TITLE')) as string;
          const objectClass = resultSet.getValue(resultSet.getColumnIndex('OBJECT_CLASS')) as string;
          const description = resultSet.getValue(resultSet.getColumnIndex('DESCRIPTION')) as string;
          const imageUrl = resultSet.getValue(resultSet.getColumnIndex('IMAGE_URL')) as string;
          const dateAdded = resultSet.getValue(resultSet.getColumnIndex('DATE_ADDED')) as string;
          const type = resultSet.getValue(resultSet.getColumnIndex('TYPE')) as string;

          favoritesSet.push(new FavoriteItem(id, scpId, scpNumber, title, objectClass, description, imageUrl, dateAdded,
            type));
        }
        resultSet.close();
      }
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(0x0000, TAG, `Query all favorites failed, code is ${error.code},message is ${error.message}`);
    }

    return favoritesSet;
  }

  /**
   * The method of querying favorites by type.
   */
  async queryFavoritesByType(type: string): Promise<FavoriteItem[]> {
    let favoritesSet: Array<FavoriteItem> = [];

    try {
      const resultSet = await this.favoriteRDB?.querySql(CommonConstants.QUERY_FAVORITES_BY_TYPE_SQL, [type]);
      if (resultSet) {
        while (resultSet.goToNextRow()) {
          const id = resultSet.getValue(resultSet.getColumnIndex('ID')) as number;
          const scpId = resultSet.getValue(resultSet.getColumnIndex('SCP_ID')) as string;
          const scpNumber = resultSet.getValue(resultSet.getColumnIndex('SCP_NUMBER')) as string;
          const title = resultSet.getValue(resultSet.getColumnIndex('TITLE')) as string;
          const objectClass = resultSet.getValue(resultSet.getColumnIndex('OBJECT_CLASS')) as string;
          const description = resultSet.getValue(resultSet.getColumnIndex('DESCRIPTION')) as string;
          const imageUrl = resultSet.getValue(resultSet.getColumnIndex('IMAGE_URL')) as string;
          const dateAdded = resultSet.getValue(resultSet.getColumnIndex('DATE_ADDED')) as string;
          const itemType = resultSet.getValue(resultSet.getColumnIndex('TYPE')) as string;

          favoritesSet.push(new FavoriteItem(id, scpId, scpNumber, title, objectClass, description, imageUrl, dateAdded,
            itemType));
        }
        resultSet.close();
      }
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(0x0000, TAG, `Query favorites by type failed, code is ${error.code},message is ${error.message}`);
    }

    return favoritesSet;
  }

  /**
   * The method of getting favorite count.
   */
  async getFavoriteCount(): Promise<number> {
    try {
      const resultSet = await this.favoriteRDB?.querySql('SELECT COUNT(*) as count FROM FAVORITES');
      if (resultSet && resultSet.goToFirstRow()) {
        const count = resultSet.getValue(resultSet.getColumnIndex('count')) as number;
        resultSet.close();
        return count;
      }
      return 0;
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(0x0000, TAG, `Get favorite count failed, code is ${error.code},message is ${error.message}`);
      return 0;
    }
  }
}

export default new RDBStoreUtil();