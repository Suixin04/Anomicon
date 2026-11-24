import { LibraryContentRef } from 'library';
import { ExploreCollectionMode } from '../../domain/ExploreContracts';
import { ExploreHomeViewModel } from '../viewmodel/ExploreHomeViewModel';
import { ExploreCollectionVM } from '../viewmodel/ExploreCollectionVM';

/**
 * Window-space landing rectangle for the startup hand-off.
 *
 * The contract deliberately carries only vp numbers.  The explore feature
 * never sees the product startup coordinator or a Window/UIContext object.
 */
export interface ExploreHeroAnchor {
  readonly windowX: number;
  readonly windowY: number;
  readonly width: number;
  readonly height: number;
}

/** Explore 首页 View 的窄化输入；View 不需要知道 repository/service。 */
export interface ExploreHomeViewContract {
  viewModel: ExploreHomeViewModel;
  onOpenContent: (content: LibraryContentRef) => void;
  onOpenCollection: (mode: ExploreCollectionMode) => void;
}

/** Explore 全量页 View 的窄化输入；路由参数由产品层先转换为 mode。 */
export interface ExploreCollectionViewContract {
  readonly viewModel: ExploreCollectionVM;
  readonly scroller: Scroller;
  readonly onOpenContent: (content: LibraryContentRef) => void;
}

/** View 发出的导航事件，统一交回 products/phone。 */
export interface ExploreNavigationEvent {
  content?: LibraryContentRef;
  collectionMode?: ExploreCollectionMode;
}
