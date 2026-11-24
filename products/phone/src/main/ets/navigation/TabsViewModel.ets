import { HdsNavigationMenuContentOptions } from '@kit.UIDesignKit';
import { HomeTabId, TabItem } from './TabItem';

/** Actions exposed by the title-bar menus.  The gallery callback is optional
 * so older composition roots can keep constructing the view model unchanged. */
export interface TabMenuActions {
  onCatalogSearch: () => void;
  onOpenSettings: () => void;
  onOpenArchive3DGallery?: () => void;
}

/** Phone-product tab state; menu actions are injected by the composition root. */
@ObservedV2
export class TabsViewModel {
  @Trace currentIndex: number = HomeTabId.EXPLORE;
  readonly items: TabItem[];

  constructor(actions: TabMenuActions) {
    this.items = [
      new TabItem(
        HomeTabId.EXPLORE,
        '探索',
        this.createSearchMenu(actions.onCatalogSearch),
        $r('sys.symbol.discover'),
        $r('sys.symbol.discover_fill')
      ),
      new TabItem(
        HomeTabId.CATALOG,
        '图鉴',
        this.createCatalogMenu(
          actions.onCatalogSearch,
          actions.onOpenArchive3DGallery ?? ((): void => {})
        ),
        $r('sys.symbol.list_book'),
        $r('sys.symbol.list_book_fill')
      ),
      new TabItem(
        HomeTabId.STORY,
        '故事',
        undefined,
        $r('sys.symbol.doc_text'),
        $r('sys.symbol.doc_text_fill')
      ),
      new TabItem(
        HomeTabId.TERMINAL,
        '终端',
        this.createSettingsMenu(actions.onOpenSettings),
        $r('sys.symbol.computer'),
        $r('sys.symbol.computer_fill')
      )
    ];
  }

  @Computed
  get currentTab(): TabItem {
    const index = this.currentIndex >= 0 && this.currentIndex < this.items.length ?
      this.currentIndex : 0;
    return this.items[index];
  }

  select(index: number): boolean {
    if (index < 0 || index >= this.items.length || index === this.currentIndex) {
      return false;
    }
    this.currentIndex = index;
    return true;
  }

  private createSearchMenu(action: () => void): HdsNavigationMenuContentOptions {
    return {
      value: [{
        content: {
          icon: $r('sys.symbol.magnifyingglass'),
          label: '搜索',
          action: action
        }
      }]
    };
  }

  /**
   * Keep both catalog actions in the same title-bar menu.  HDS can expose the
   * entries directly while retaining its normal overflow behaviour on narrow
   * windows; the composition root owns the actual navigation callbacks.
   */
  private createCatalogMenu(
    searchAction: () => void,
    archive3DAction: () => void
  ): HdsNavigationMenuContentOptions {
    return {
      // There are exactly two catalog actions; keep both as first-class menu
      // icons when the title bar has room instead of relying on the default
      // three-item budget (which may reserve a slot for overflow).
      maxCount: 2,
      value: [
        {
          content: {
            icon: $r('sys.symbol.magnifyingglass'),
            label: '搜索',
            action: searchAction
          }
        },
        {
          content: {
            icon: $r('sys.symbol.viewfinder_3D'),
            label: '三维档案馆',
            action: archive3DAction
          }
        }
      ]
    };
  }

  private createSettingsMenu(action: () => void): HdsNavigationMenuContentOptions {
    return {
      value: [{
        content: {
          icon: $r('sys.symbol.gearshape'),
          label: '设置',
          action: action
        }
      }]
    };
  }
}
