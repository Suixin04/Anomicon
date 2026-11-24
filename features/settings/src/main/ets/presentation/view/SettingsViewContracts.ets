import { SettingsViewModel } from '../viewmodel/SettingsViewModel';

/** Device-independent app identity rendered by the Settings information pages. */
export class AboutPageContent {
  readonly displayName: string;
  readonly englishName: string;
  readonly versionName: string;
  readonly appIcon: Resource;

  constructor(
    displayName: string,
    englishName: string,
    versionName: string,
    appIcon: Resource
  ) {
    this.displayName = displayName;
    this.englishName = englishName;
    this.versionName = versionName;
    this.appIcon = appIcon;
  }
}

/** A single attribution or licence destination rendered as a platform hyperlink. */
export class ContentLicenseLink {
  readonly title: string;
  readonly address: string;

  constructor(title: string, address: string) {
    this.title = title;
    this.address = address;
  }
}

/** Product-provided copy for the otherwise device-independent content licence page. */
export class ContentLicenseContent {
  readonly pageTitle: string;
  readonly licenseName: string;
  readonly usageNotice: string;
  readonly links: ContentLicenseLink[];
  readonly disclaimer: string;

  constructor(
    pageTitle: string,
    licenseName: string,
    usageNotice: string,
    links: ContentLicenseLink[],
    disclaimer: string
  ) {
    this.pageTitle = pageTitle;
    this.licenseName = licenseName;
    this.usageNotice = usageNotice;
    this.links = links;
    this.disclaimer = disclaimer;
  }
}

/** Product-owned destinations emitted by the device-independent Settings View. */
export enum SettingsNavigationTarget {
  ABOUT = 'about',
  CONTENT_LICENSE = 'content_license',
  ARCHIVE_3D_GALLERY = 'archive_3d_gallery',
  RAISA_FEEDBACK = 'raisa_feedback'
}

/** Snapshot of disposable local caches and managed offline assets shown on Settings. */
export interface SettingsStorageUsage {
  readonly tempCacheBytes: number;
  readonly archive3DBytes: number;
  readonly offlineArticlesBytes: number;
  readonly offlineArticlesCount: number;
}

/** Narrow storage maintenance port supplied by the product composition layer. */
export interface SettingsStorageActions {
  inspect(): Promise<SettingsStorageUsage>;
  clearTempCaches(): Promise<SettingsStorageUsage>;
  searchHistoryCount(): number;
  /** Returns after durable deletion, or throws so the caller can offer a retry. */
  clearSearchHistory(): void;
}

/** Branding resources remain product-customizable and are injected into the Settings HAR. */
export class SettingsBranding {
  readonly displayName: string;
  readonly englishName: string;
  readonly versionName: string;
  readonly appIcon: Resource;
  readonly ccLogo: Resource;
  readonly ccBy: Resource;
  readonly ccSa: Resource;

  constructor(
    displayName: string,
    englishName: string,
    versionName: string,
    appIcon: Resource,
    ccLogo: Resource,
    ccBy: Resource,
    ccSa: Resource
  ) {
    this.displayName = displayName;
    this.englishName = englishName;
    this.versionName = versionName;
    this.appIcon = appIcon;
    this.ccLogo = ccLogo;
    this.ccBy = ccBy;
    this.ccSa = ccSa;
  }
}

/**
 * Settings View 的窄化输入。
 *
 * 产品层负责品牌资源、触感实现和路由映射；Settings View 只发送事件，
 * 不依赖 product 导航类、AppContainer 或任何 data adapter。
 */
export interface SettingsViewContract {
  readonly viewModel: SettingsViewModel;
  readonly branding: SettingsBranding;
  readonly storageActions?: SettingsStorageActions;
  readonly onHaptic: (enabled: boolean) => void;
  readonly onNavigate: (
    pageStack: NavPathStack | undefined,
    target: SettingsNavigationTarget
  ) => void;
}
