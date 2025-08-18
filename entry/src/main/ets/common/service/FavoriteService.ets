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

import { hilog } from '@kit.PerformanceAnalysisKit';
import RDBStoreUtil from '../database/RDBStoreUtil';
import PreferencesUtil from '../database/PreferencesUtil';
import { FavoriteItem } from '../../viewmodel/FavoriteItem';
import CommonConstants from '../constants/CommonConstants';
import { SCP, Tale } from '../../utils/types';

/**
 * Interface for favorite statistics.
 */
interface FavoriteStats {
  count: number;
  lastFavoriteDate: string;
}

const TAG = 'FavoriteService';

/**
 * Service class for managing SCP and Tale favorites.
 */
export class FavoriteService {
  private static isInitialized: boolean = false;
  private static instance: FavoriteService | null = null;

  /**
   * Get singleton instance of FavoriteService.
   */
  static getInstance(): FavoriteService {
    if (!FavoriteService.instance) {
      FavoriteService.instance = new FavoriteService();
    }
    return FavoriteService.instance;
  }

  /**
   * Initialize the favorite service.
   */
  static async initialize(context: Context): Promise<void> {
    if (FavoriteService.isInitialized) {
      return;
    }

    try {
      hilog.info(0x0000, TAG, 'Initializing FavoriteService...');
      
      // Initialize database and preferences
      RDBStoreUtil.createFavoriteRDB(context);
      PreferencesUtil.getFavoritePreferences(context);
      
      FavoriteService.isInitialized = true;
      hilog.info(0x0000, TAG, 'FavoriteService initialized successfully');
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to initialize FavoriteService: ' + error);
      throw new Error('Failed to initialize FavoriteService: ' + error);
    }
  }

  /**
   * Instance wrapper for initialize to support usage on default-exported instance.
   */
  async initialize(context: Context): Promise<void> {
    return FavoriteService.initialize(context);
  }

  /**
   * Add an SCP item to favorites.
   */
  async addSCPToFavorites(scp: SCP): Promise<boolean> {
    try {
      const favoriteItem = FavoriteItem.fromSCP(scp);
      const success = await RDBStoreUtil.insertFavorite(favoriteItem);
      
      if (success) {
        // Update preferences
        const currentCount = PreferencesUtil.getFavoriteCount();
        PreferencesUtil.saveFavoriteCount(currentCount + 1);
        PreferencesUtil.saveLastFavoriteDate(new Date().toISOString());
        
        hilog.info(0x0000, TAG, `Added SCP ${scp.number} to favorites`);
      }
      
      return success;
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to add SCP to favorites: ' + error);
      return false;
    }
  }

  /**
   * Add a Tale to favorites.
   */
  async addTaleToFavorites(tale: Tale): Promise<boolean> {
    try {
      const favoriteItem = FavoriteItem.fromTale(tale);
      const success = await RDBStoreUtil.insertFavorite(favoriteItem);
      
      if (success) {
        // Update preferences
        const currentCount = PreferencesUtil.getFavoriteCount();
        PreferencesUtil.saveFavoriteCount(currentCount + 1);
        PreferencesUtil.saveLastFavoriteDate(new Date().toISOString());
        
        hilog.info(0x0000, TAG, `Added Tale ${tale.title} to favorites`);
      }
      
      return success;
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to add Tale to favorites: ' + error);
      return false;
    }
  }

  /**
   * Remove an item from favorites.
   */
  async removeFromFavorites(itemId: string): Promise<boolean> {
    try {
      const success = await RDBStoreUtil.deleteFavorite(itemId);
      
      if (success) {
        // Update preferences
        const currentCount = PreferencesUtil.getFavoriteCount();
        PreferencesUtil.saveFavoriteCount(Math.max(0, currentCount - 1));
        
        hilog.info(0x0000, TAG, `Removed item ${itemId} from favorites`);
      }
      
      return success;
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to remove from favorites: ' + error);
      return false;
    }
  }

  /**
   * Check if an item is favorited.
   */
  async isFavorited(itemId: string): Promise<boolean> {
    try {
      return await RDBStoreUtil.isFavorited(itemId);
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to check if favorited: ' + error);
      return false;
    }
  }

  /**
   * Get all favorite items.
   */
  async getAllFavorites(): Promise<FavoriteItem[]> {
    try {
      return await RDBStoreUtil.queryAllFavorites();
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to get all favorites: ' + error);
      return [];
    }
  }

  /**
   * Get favorite items by type.
   */
  async getFavoritesByType(type: string): Promise<FavoriteItem[]> {
    try {
      return await RDBStoreUtil.queryFavoritesByType(type);
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to get favorites by type: ' + error);
      return [];
    }
  }

  /**
   * Get SCP favorites.
   */
  async getSCPFavorites(): Promise<FavoriteItem[]> {
    return await this.getFavoritesByType(CommonConstants.FAVORITE_TYPE_SCP);
  }

  /**
   * Get Tale favorites.
   */
  async getTaleFavorites(): Promise<FavoriteItem[]> {
    return await this.getFavoritesByType(CommonConstants.FAVORITE_TYPE_TALE);
  }

  /**
   * Get favorite count.
   */
  async getFavoriteCount(): Promise<number> {
    try {
      return await RDBStoreUtil.getFavoriteCount();
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to get favorite count: ' + error);
      return 0;
    }
  }

  /**
   * Get favorite statistics.
   */
  getFavoriteStats(): FavoriteStats {
    return {
      count: PreferencesUtil.getFavoriteCount(),
      lastFavoriteDate: PreferencesUtil.getLastFavoriteDate()
    };
  }

  /**
   * Toggle favorite status for an SCP item.
   */
  async toggleSCPFavorite(scp: SCP): Promise<boolean> {
    const isFav = await this.isFavorited(scp.id);
    if (isFav) {
      return await this.removeFromFavorites(scp.id);
    } else {
      return await this.addSCPToFavorites(scp);
    }
  }

  /**
   * Toggle favorite status for a Tale.
   */
  async toggleTaleFavorite(tale: Tale): Promise<boolean> {
    const isFav = await this.isFavorited(tale.id);
    if (isFav) {
      return await this.removeFromFavorites(tale.id);
    } else {
      return await this.addTaleToFavorites(tale);
    }
  }
}

export default new FavoriteService();