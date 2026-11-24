import { AppStorageV2 } from '@kit.ArkUI';
import {
  ALL_SERIES_ID,
  DEFAULT_CN_SERIES_ID,
  DEFAULT_SERIES_ID,
  findCatalogSeriesById,
  ScpCatalogBranch
} from '../domain/ScpSeriesItem';
import { CatalogSearchSharedState } from './view/SearchViewContracts';

/** 图鉴 Tab 标题栏底部工具栏高度（分支切换行 + 系列 chips 行，vp）。与 Index bottomBuilder 配置对齐。 */
export const CATALOG_TOOLBAR_HEIGHT: number = 86;

/**
 * 图鉴搜索共享状态：图鉴页与搜索页之间共享关键词、分支与当前系列，
 * 两个页面观察该状态即时联动。
 *
 * 注意：搜索页是 route_map 懒加载页面，其页面上下文里的模块图与
 * 主页面不共享，普通 static 单例会各自成双。必须用 AppStorageV2.connect
 * 建立应用级共享实例，两个页面才读写同一份状态。
 */
@ObservedV2
export class ScpCatalogSearchState implements CatalogSearchSharedState {
  @Trace query: string = '';
  /** 当前图鉴分支（主站译文 / 中文原创）。 */
  @Trace branch: ScpCatalogBranch = ScpCatalogBranch.MAIN;
  /** 当前图鉴系列（图鉴页 chips 与搜索页 chips 互通）。 */
  @Trace seriesId: string = DEFAULT_SERIES_ID;
  @Trace lastMainSeriesId: string = DEFAULT_SERIES_ID;
  @Trace lastCnSeriesId: string = DEFAULT_CN_SERIES_ID;

  setQuery(value: string): void {
    this.query = value;
  }

  clear(): void {
    this.query = '';
  }

  setSeriesId(id: string): void {
    if (this.seriesId !== id) {
      this.seriesId = id;
    }
    if (id === ALL_SERIES_ID) {
      return;
    }
    const descriptor = findCatalogSeriesById(id);
    if (descriptor === undefined) {
      return;
    }
    this.branch = descriptor.branch;
    if (descriptor.branch === ScpCatalogBranch.CN) {
      this.lastCnSeriesId = descriptor.id;
    } else {
      this.lastMainSeriesId = descriptor.id;
    }
  }

  selectBranch(branch: ScpCatalogBranch): void {
    if (this.branch === branch) {
      return;
    }
    this.branch = branch;
    this.seriesId = branch === ScpCatalogBranch.CN
      ? this.lastCnSeriesId
      : this.lastMainSeriesId;
  }

}

/** 获取/创建应用级共享的搜索状态实例（跨懒加载页面上下文唯一）。 */
export function sharedCatalogSearchState(): ScpCatalogSearchState {
  return AppStorageV2.connect(ScpCatalogSearchState, () => new ScpCatalogSearchState())!;
}
