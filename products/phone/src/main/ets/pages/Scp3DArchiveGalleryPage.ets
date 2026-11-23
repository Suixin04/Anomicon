import {
  HideMode,
  HdsNavDestination,
  HdsNavDestinationTitleMode
} from '@kit.UIDesignKit';
import {
  accentPillBackgroundColor,
  accentPillForegroundColor,
  AppTypography,
  badgeDangerBackgroundColor,
  badgeDangerForegroundColor,
  badgeInfoBackgroundColor,
  badgeInfoForegroundColor,
  badgeWarningBackgroundColor,
  badgeWarningForegroundColor,
  PHONE_PAGE_MARGIN,
  createAppTitleBarStyle,
  pageContentTop
} from 'anomiconbasic';
import {
  Scp3DAssetDelivery,
  Scp3DAssetManifestEntry,
  SCP_3D_ASSET_MANIFEST
} from 'archive3d';
import {
  LibraryContentKind,
  createLibraryContentRef
} from 'library';
import {
  AppRoutes,
  Scp3DArchiveRouteParams
} from '../navigation/AppRoutes';
import { AppNavigationCoordinator } from '../navigation/AppNavigationCoordinator';

/** The gallery filter is deliberately independent from the downloader state machine. */
export enum Scp3DArchiveGalleryFilter {
  ALL = 'all',
  DOWNLOADED = 'downloaded',
  PENDING = 'pending'
}

/**
 * Installation states accepted by the gallery. The page stays independent
 * from request.agent while still rendering the live repository snapshot.
 */
export enum Scp3DArchiveInstallState {
  BUNDLED = 'bundled',
  READY = 'ready',
  NOT_INSTALLED = 'not_installed',
  QUEUED = 'queued',
  WAITING = 'waiting',
  DOWNLOADING = 'downloading',
  VERIFYING = 'verifying',
  FAILED = 'failed'
}

export type Scp3DArchiveInstallStatusResolver =
  (entry: Scp3DAssetManifestEntry) => Scp3DArchiveInstallState;

/** Optional product navigation seam; scene loading remains product-owned. */
export type Scp3DArchiveAssetOpenHandler =
  (entry: Scp3DAssetManifestEntry) => void;

/**
 * Product-facing install seam.  The gallery deliberately knows only about
 * manifest rows and immutable snapshots; request.agent/file paths stay in the
 * application composition root.
 */
export interface Scp3DArchiveInstallActions {
  status(entry: Scp3DAssetManifestEntry): Scp3DArchiveInstallState;
  subscribe(
    entry: Scp3DAssetManifestEntry,
    listener: (state: Scp3DArchiveInstallState) => void
  ): () => void;
  install(entry: Scp3DAssetManifestEntry): Promise<void>;
  remove(entry: Scp3DAssetManifestEntry): Promise<void>;
}

/** Safe fallback for previews that do not inject the application repository. */
export function defaultScp3DArchiveInstallStatus(
  entry: Scp3DAssetManifestEntry
): Scp3DArchiveInstallState {
  return entry.delivery === Scp3DAssetDelivery.BUNDLED ?
    Scp3DArchiveInstallState.BUNDLED : Scp3DArchiveInstallState.NOT_INSTALLED;
}

const FILTER_LABELS: string[] = ['全部', '已下载', '待下载'];
const FILTER_VALUES: Scp3DArchiveGalleryFilter[] = [
  Scp3DArchiveGalleryFilter.ALL,
  Scp3DArchiveGalleryFilter.DOWNLOADED,
  Scp3DArchiveGalleryFilter.PENDING
];

/**
 * Manifest-driven archive index. Scene/renderer objects never cross this
 * page; download and deletion are delegated through the narrow install seam.
 */
@ComponentV2
struct Scp3DArchiveGalleryPage {
  private readonly scroller: Scroller = new Scroller();
  private pageStack: NavPathStack | undefined = undefined;
  /** Snapshot the build-time list so a future repository cannot mutate it. */
  private readonly manifest: Scp3DAssetManifestEntry[] = SCP_3D_ASSET_MANIFEST.slice();

  @Param installStatus: Scp3DArchiveInstallStatusResolver =
    defaultScp3DArchiveInstallStatus;
  @Param onOpenAsset: Scp3DArchiveAssetOpenHandler | undefined = undefined;
  @Param installActions: Scp3DArchiveInstallActions | undefined = undefined;
  @Local private selectedFilter: Scp3DArchiveGalleryFilter =
    Scp3DArchiveGalleryFilter.ALL;
  @Local private stateVersion: number = 0;
  @Local private activeActionAssetId: string = '';
  private readonly liveStates: Map<string, Scp3DArchiveInstallState> = new Map();
  private readonly stateUnsubscribers: Array<() => void> = [];

  aboutToAppear(): void {
    const actions = this.installActions;
    if (actions === undefined) {
      return;
    }
    this.manifest.forEach((entry: Scp3DAssetManifestEntry): void => {
      this.liveStates.set(entry.assetId, actions.status(entry));
      this.stateUnsubscribers.push(actions.subscribe(entry, (state: Scp3DArchiveInstallState): void => {
        this.liveStates.set(entry.assetId, state);
        // The map is intentionally kept private; this scalar invalidates the
        // component without exposing mutable repository state to ArkUI.
        this.stateVersion++;
      }));
    });
  }

  aboutToDisappear(): void {
    const items = this.stateUnsubscribers.splice(0, this.stateUnsubscribers.length);
    items.forEach((unsubscribe: () => void): void => unsubscribe());
    this.liveStates.clear();
  }

  private currentState(entry: Scp3DAssetManifestEntry): Scp3DArchiveInstallState {
    // Reading stateVersion makes the reactive dependency explicit for ArkUI's
    // compiler even though the actual values live in a private Map.
    const version = this.stateVersion;
    const live = this.liveStates.get(entry.assetId);
    // `version` is read in the fallback branch to keep a tracked dependency;
    // it is monotonic and therefore does not alter the resolved state.
    return live ?? (version >= 0 ?
      (this.installActions?.status(entry) ?? this.installStatus(entry)) :
      this.installStatus(entry));
  }

  private visibleEntries(): Scp3DAssetManifestEntry[] {
    if (this.selectedFilter === Scp3DArchiveGalleryFilter.ALL) {
      return this.manifest;
    }
    return this.manifest.filter((entry: Scp3DAssetManifestEntry): boolean => {
      const state = this.currentState(entry);
      if (this.selectedFilter === Scp3DArchiveGalleryFilter.DOWNLOADED) {
        return state === Scp3DArchiveInstallState.BUNDLED ||
          state === Scp3DArchiveInstallState.READY;
      }
      return state !== Scp3DArchiveInstallState.BUNDLED &&
        state !== Scp3DArchiveInstallState.READY;
    });
  }

  private countFor(filter: Scp3DArchiveGalleryFilter): number {
    if (filter === Scp3DArchiveGalleryFilter.ALL) {
      return this.manifest.length;
    }
    let count: number = 0;
    this.manifest.forEach((entry: Scp3DAssetManifestEntry): void => {
      const state = this.currentState(entry);
      const downloaded = state === Scp3DArchiveInstallState.BUNDLED ||
        state === Scp3DArchiveInstallState.READY;
      if ((filter === Scp3DArchiveGalleryFilter.DOWNLOADED && downloaded) ||
        (filter === Scp3DArchiveGalleryFilter.PENDING && !downloaded)) {
        count++;
      }
    });
    return count;
  }

  private statusLabel(entry: Scp3DAssetManifestEntry): string {
    switch (this.currentState(entry)) {
      case Scp3DArchiveInstallState.BUNDLED:
        return '已内置';
      case Scp3DArchiveInstallState.READY:
        return '已下载';
      case Scp3DArchiveInstallState.QUEUED:
        return '等待下载';
      case Scp3DArchiveInstallState.WAITING:
        return '等待网络';
      case Scp3DArchiveInstallState.DOWNLOADING:
        return '下载中';
      case Scp3DArchiveInstallState.VERIFYING:
        return '校验中';
      case Scp3DArchiveInstallState.FAILED:
        return '下载失败';
      default:
        return '待下载';
    }
  }

  private isReady(entry: Scp3DAssetManifestEntry): boolean {
    const state = this.currentState(entry);
    return state === Scp3DArchiveInstallState.BUNDLED ||
      state === Scp3DArchiveInstallState.READY;
  }

  private formatSize(byteLength: number): string {
    if (byteLength < 1024 * 1024) {
      return `${(byteLength / 1024).toFixed(1)} KB`;
    }
    return `${(byteLength / (1024 * 1024)).toFixed(1)} MB`;
  }

  private selectFilter(filter: Scp3DArchiveGalleryFilter): void {
    if (this.selectedFilter !== filter) {
      this.selectedFilter = filter;
    }
  }

  private isFilterSelected(filter: Scp3DArchiveGalleryFilter): boolean {
    return this.selectedFilter === filter;
  }

  /** Open the existing viewer only after the gallery has resolved a local asset. */
  private openAsset(entry: Scp3DAssetManifestEntry): void {
    // Product navigation may intercept this seam (for example, to show a
    // download sheet); uninstalled remote rows never enter the viewer.
    const handler = this.onOpenAsset;
    if (handler !== undefined) {
      handler(entry);
      return;
    }
    if (!this.isReady(entry)) {
      return;
    }
    const content = createLibraryContentRef(
      LibraryContentKind.SCP,
      entry.contentId,
      entry.contentId.toUpperCase()
    );
    const params: Scp3DArchiveRouteParams = { content: content };
    AppNavigationCoordinator.push(this.pageStack, AppRoutes.ARCHIVE_3D, params);
  }

  private isActionInFlight(entry: Scp3DAssetManifestEntry): boolean {
    return this.activeActionAssetId === entry.assetId;
  }

  private async installAsset(entry: Scp3DAssetManifestEntry): Promise<void> {
    const actions = this.installActions;
    if (actions === undefined || this.isActionInFlight(entry)) {
      return;
    }
    this.activeActionAssetId = entry.assetId;
    try {
      await actions.install(entry);
    } catch (_error) {
      // Repository publishes FAILED with a user-facing reason.  Keep the
      // page alive here so a transient network error never breaks navigation.
    } finally {
      this.activeActionAssetId = '';
      this.stateVersion++;
    }
  }

  private async removeAsset(entry: Scp3DAssetManifestEntry): Promise<void> {
    const actions = this.installActions;
    if (actions === undefined || this.isActionInFlight(entry)) {
      return;
    }
    this.activeActionAssetId = entry.assetId;
    try {
      await actions.remove(entry);
    } catch (_error) {
      // Keep the READY state when deletion fails; the next render will still
      // offer the delete action rather than pretending the cache is gone.
    } finally {
      this.activeActionAssetId = '';
      this.stateVersion++;
    }
  }

  private badgeForegroundColor(entry: Scp3DAssetManifestEntry): ResourceColor {
    if (this.isReady(entry)) {
      return badgeInfoForegroundColor();
    }
    if (this.currentState(entry) === Scp3DArchiveInstallState.FAILED) {
      return badgeDangerForegroundColor();
    }
    return badgeWarningForegroundColor();
  }

  private badgeBackgroundColor(entry: Scp3DAssetManifestEntry): ResourceColor {
    if (this.isReady(entry)) {
      return badgeInfoBackgroundColor();
    }
    if (this.currentState(entry) === Scp3DArchiveInstallState.FAILED) {
      return badgeDangerBackgroundColor();
    }
    return badgeWarningBackgroundColor();
  }

  @Builder
  private filterBar() {
    Row({ space: 8 }) {
      ForEach(FILTER_VALUES, (filter: Scp3DArchiveGalleryFilter, index: number) => {
        Button(`${FILTER_LABELS[index]} ${this.countFor(filter)}`, {
          type: ButtonType.Capsule,
          stateEffect: false
        })
          .layoutWeight(1)
          .height(36)
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(this.isFilterSelected(filter) ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.isFilterSelected(filter) ?
            accentPillForegroundColor() : $r('sys.color.font_secondary'))
          .backgroundColor(this.isFilterSelected(filter) ?
            accentPillBackgroundColor() : $r('sys.color.comp_background_tertiary'))
          .onClick(() => this.selectFilter(filter))
          .accessibilityText(`${FILTER_LABELS[index]}，${this.countFor(filter)} 个`);
      }, (filter: Scp3DArchiveGalleryFilter) => filter);
    }
    .width('100%');
  }

  @Builder
  private statusBadge(entry: Scp3DAssetManifestEntry) {
    Text(this.statusLabel(entry))
      .fontSize(AppTypography.CAPTION_M)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.badgeForegroundColor(entry))
      .padding({ left: 9, right: 9, top: 5, bottom: 5 })
      .backgroundColor(this.badgeBackgroundColor(entry))
      .borderRadius(8);
  }

  @Builder
  private archiveCard(entry: Scp3DAssetManifestEntry) {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text(entry.contentId.toUpperCase())
            .fontSize(AppTypography.SUBTITLE_M)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(entry.description)
            .fontSize(AppTypography.BODY_S)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1);
        this.statusBadge(entry);
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.icon_secondary')])
          .hitTestBehavior(HitTestMode.None);
      }
      .width('100%')
      .alignItems(VerticalAlign.Top);

      Row({ space: 8 }) {
        Text(entry.objectClass)
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_tertiary'))
          .layoutWeight(1);
        Text(entry.format.toUpperCase())
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_tertiary'));
        Text(this.formatSize(entry.byteLength))
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_tertiary'));
      }
      .width('100%');

      if (this.installActions !== undefined && entry.delivery === Scp3DAssetDelivery.ON_DEMAND) {
        Row({ space: 8 }) {
          if (this.isActionInFlight(entry) ||
            this.currentState(entry) === Scp3DArchiveInstallState.DOWNLOADING ||
            this.currentState(entry) === Scp3DArchiveInstallState.VERIFYING ||
            this.currentState(entry) === Scp3DArchiveInstallState.QUEUED ||
            this.currentState(entry) === Scp3DArchiveInstallState.WAITING) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color(accentPillBackgroundColor());
            Text(this.statusLabel(entry))
              .fontSize(AppTypography.CAPTION_L)
              .fontColor($r('sys.color.font_secondary'));
          } else if (this.isReady(entry)) {
            Button('删除', { stateEffect: true })
              .height(32)
              .fontSize(AppTypography.CAPTION_L)
              .fontColor(badgeDangerForegroundColor())
              .backgroundColor(badgeDangerBackgroundColor())
              // The card opens the viewer on click; action buttons must stop
              // the hit test at this node so deleting never also navigates.
              .hitTestBehavior(HitTestMode.Block)
              .onClick(() => { this.removeAsset(entry); });
          } else {
            Button('下载', { stateEffect: true })
              .height(32)
              .fontSize(AppTypography.CAPTION_L)
              .fontColor(badgeInfoForegroundColor())
              .backgroundColor(badgeInfoBackgroundColor())
              .hitTestBehavior(HitTestMode.Block)
              .onClick(() => { this.installAsset(entry); });
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.End);
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
    .onClick(() => this.openAsset(entry))
    .accessibilityText(`${entry.contentId.toUpperCase()}，${this.statusLabel(entry)}`);
  }

  @Builder
  private emptyState() {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.viewfinder_3D'))
        .fontSize(28)
        .fontColor([$r('sys.color.icon_secondary')]);
      Text('暂无匹配档案')
        .fontSize(AppTypography.BODY_M)
        .fontColor($r('sys.color.font_secondary'));
    }
    .width('100%')
    .height(220)
    .justifyContent(FlexAlign.Center);
  }

  build() {
    HdsNavDestination() {
      // HdsNavDestination supplies the route surface; keep a full-size
      // layout root inside it so a short manifest is not measured as an
      // intrinsic-height child and vertically centered by HDS.
      Stack({ alignContent: Alignment.Top }) {
        Scroll(this.scroller) {
          Column({ space: 14 }) {
            this.filterBar();
            if (this.visibleEntries().length === 0) {
              this.emptyState();
            } else {
              ForEach(this.visibleEntries(), (entry: Scp3DAssetManifestEntry) => {
                this.archiveCard(entry);
              }, (entry: Scp3DAssetManifestEntry) => entry.assetId);
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: 640 })
          .padding({
            left: PHONE_PAGE_MARGIN,
            right: PHONE_PAGE_MARGIN,
            // The destination is laid out through the system bars. Keep
            // interactive content below the status bar and MINI title bar;
            // the surrounding background remains fully immersive.
            top: pageContentTop(),
            bottom: 34
          });
        }
        // matchParent is important when the destination ignores a system
        // safe area: percentage sizing can move a component without growing
        // it, leaving an uncovered strip at the bottom.
        .width(LayoutPolicy.matchParent)
        .height(LayoutPolicy.matchParent)
        // Scroll lays out a short child in the center by default when its
        // viewport has an explicit height. Force document-style top flow.
        .align(Alignment.Top)
        // Let the first content pixels participate in the HDS title-bar
        // backdrop/blur instead of clipping them at the Scroll boundary.
        .clip(false)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true });
      }
      .width(LayoutPolicy.matchParent)
      .height(LayoutPolicy.matchParent)
      .clip(false)
      .background($r('sys.color.background_secondary'), {
        ignoresLayoutSafeAreaEdges: [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
      });
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      // Keep the same title/content contract as the other secondary pages:
      // the title bar is an overlay and page content supplies its own inset.
      enableComponentSafeArea: false,
      content: {
        title: {
          mainTitle: '三维档案馆',
          subTitle: `${this.manifest.length} 个档案`
        },
        backIcon: { label: '返回', componentId: 'scp3dArchiveGalleryBackButton' }
      },
      style: createAppTitleBarStyle()
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .backgroundColor($r('sys.color.background_secondary'))
    .bindToScrollable([this.scroller])
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP,
      hideRatio: 1.5
    })
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
    })
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    );
  }
}

/** Route-map entry point. Install actions are injected by the product root. */
@Builder
export function Scp3DArchiveGalleryPageBuilder(
  installStatus?: Scp3DArchiveInstallStatusResolver,
  onOpenAsset?: Scp3DArchiveAssetOpenHandler,
  installActions?: Scp3DArchiveInstallActions
) {
  Scp3DArchiveGalleryPage({
    installStatus: installStatus ?? defaultScp3DArchiveInstallStatus,
    onOpenAsset: onOpenAsset,
    installActions: installActions
  });
}
