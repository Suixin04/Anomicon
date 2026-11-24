import { HdsNavigationMenuContentOptions } from '@kit.UIDesignKit';

/** Stable identifiers and static presentation metadata for the phone tabs. */
export enum HomeTabId {
  EXPLORE = 0,
  CATALOG = 1,
  FOUNDATION = 2,
  STORY = 3,
  TERMINAL = 4
}

export class TabItem {
  readonly id: HomeTabId;
  readonly title: string;
  readonly menu: HdsNavigationMenuContentOptions | undefined;
  readonly iconNormal: Resource;
  readonly iconSelected: Resource;

  constructor(
    id: HomeTabId,
    title: string,
    menu: HdsNavigationMenuContentOptions | undefined,
    iconNormal: Resource,
    iconSelected: Resource
  ) {
    this.id = id;
    this.title = title;
    this.menu = menu;
    this.iconNormal = iconNormal;
    this.iconSelected = iconSelected;
  }
}
