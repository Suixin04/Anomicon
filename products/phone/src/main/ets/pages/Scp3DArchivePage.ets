import {
  Quaternion
} from '@kit.ArkGraphics3D';
import { schedulingOptimization } from '@kit.FASTKit';
import { FrameCallback } from '@kit.ArkUI';
import {
  HideMode,
  HdsNavDestination,
  HdsNavDestinationTitleMode
} from '@kit.UIDesignKit';
import {
  accentPillBackgroundColor,
  accentPillForegroundColor,
  AppTypography,
  badgeInfoBackgroundColor,
  badgeInfoForegroundColor,
  badgeWarningForegroundColor,
  PHONE_PAGE_MARGIN,
  createAppTitleBarStyle,
  pageContentTop
} from 'anomiconbasic';
import {
  ArchiveModelDescriptor,
  ArchiveSceneSource,
  Scp3DModelAsset,
  resolveScp3DModelAsset
} from 'archive3d';
import { LibraryContentKind } from 'library';
import { Scp3DArchiveRouteParams } from '../navigation/AppRoutes';
import { parseScp3DArchiveRoute } from '../navigation/RouteParamAdapters';
import {
  Archive3DSceneHandle,
  loadArchive3DScene
} from '../composition/Archive3DSceneLoader';
import { FastPerformanceHintScope } from '../composition/FastPerformanceHints';

const VIEWER_HEIGHT: number = 388;
const ROTATION_SENSITIVITY_X: number = 0.008;
const ROTATION_SENSITIVITY_Y: number = 0.006;
const MIN_PITCH: number = -1.05;
const MAX_PITCH: number = 1.05;
// Match the former 0.014 rad / 50 ms pace while advancing on VSync. The
// frame callback keeps the model responsive on 60/90 Hz screens without
// making the idle scene a continuous renderer.
const AUTO_ROTATE_SPEED_RAD_PER_SECOND: number = 0.28;

class ArchiveRenderFrameCallback extends FrameCallback {
  private readonly task: (frameTimeInNano: number) => void;

  constructor(task: (frameTimeInNano: number) => void) {
    super();
    this.task = task;
  }

  onFrame(frameTimeInNano: number): void {
    this.task(frameTimeInNano);
  }
}

/** Resolve a verified local source before ArkGraphics3D touches the file. */
export type Scp3DArchiveSceneSourceResolver =
  (asset: Scp3DModelAsset) => Promise<ArchiveSceneSource>;

/** Product route adapter; no native graphics object crosses the route seam. */
@Builder
export function Scp3DArchivePageBuilder(
  resolveSceneSource?: Scp3DArchiveSceneSourceResolver
) {
  Scp3DArchivePage({ resolveSceneSource: resolveSceneSource });
}

/**
 * Offline-first three-dimensional archive screen.
 *
 * The page owns the short-lived Scene/Node graph because Component3D is a
 * product/platform concern. The archive HAR contributes only an immutable
 * manifest row, which keeps route serialization, caching and licensing data
 * independent from native graphics lifetimes.
 */
@ComponentV2
struct Scp3DArchivePage {
  private readonly scroller: Scroller = new Scroller();
  /** GLB parsing and Scene construction are local-file processing work. */
  private readonly sceneLoadHint: FastPerformanceHintScope =
    new FastPerformanceHintScope(
      schedulingOptimization.SceneType.LOCAL_FILE_PROCESSING,
      schedulingOptimization.DurationType.MEDIUM
    );
  private sceneHandle: Archive3DSceneHandle | undefined = undefined;
  private loadGeneration: number = 0;
  private renderTimer: number = -1;
  /** A one-shot VSync callback is used instead of a wall-clock 16 ms timer. */
  private renderFramePending: boolean = false;
  private renderGeneration: number = 0;
  private continuousRender: boolean = false;
  private gestureDepth: number = 0;
  private lastRenderFrameTimeNano: number = 0;
  private pageActive: boolean = false;
  private pageShown: boolean = false;
  private panStartYaw: number = 0;
  private panStartPitch: number = 0;
  private pinchStartScale: number = 1;
  // These values are deliberately non-reactive. They are native scene
  // transforms, not UI state; keeping them out of @Local avoids rebuilding
  // the surrounding ArkUI tree for every touch sample.
  private interactionYaw: number = 0;
  private interactionPitch: number = 0;
  private interactionScale: number = 1;
  private transformDirty: boolean = false;

  @Local private routeResolved: boolean = false;
  @Local private contentId: string = '';
  @Local private title: string = '';
  @Local private asset: Scp3DModelAsset | undefined = undefined;
  @Local private loading: boolean = false;
  @Local private sceneReady: boolean = false;
  // Component3D reads SceneOptions only when the native control is created;
  // keep one stable object for the lifetime of each loaded Scene so gesture
  // state changes never look like a dynamic scene-option mutation.
  private sceneOptions: SceneOptions | undefined = undefined;
  @Local private errorMessage: string = '';
  @Local private autoRotate: boolean = false;
  @Local private creditsVisible: boolean = false;
  @Param resolveSceneSource: Scp3DArchiveSceneSourceResolver | undefined = undefined;

  aboutToAppear(): void {
    this.pageActive = false;
    this.pageShown = false;
    this.gestureDepth = 0;
    this.continuousRender = false;
    this.lastRenderFrameTimeNano = 0;
  }

  aboutToDisappear(): void {
    this.pageActive = false;
    this.pageShown = false;
    this.invalidateLoad();
    this.stopAutoRotate();
    this.cancelRender();
    this.releaseScene();
  }

  private isRenderable(): boolean {
    return this.pageActive && this.pageShown && this.sceneHandle !== undefined;
  }

  private applyRouteParam(param: Object | null | undefined): void {
    this.routeResolved = false;
    this.contentId = '';
    this.title = '';
    this.asset = undefined;
    this.errorMessage = '';
    this.creditsVisible = false;
    this.loading = false;
    this.invalidateLoad();
    this.stopAutoRotate();
    this.gestureDepth = 0;
    this.continuousRender = false;
    this.lastRenderFrameTimeNano = 0;
    this.releaseScene();

    const route: Scp3DArchiveRouteParams | undefined = parseScp3DArchiveRoute(param);
    if (route === undefined || route.content.kind !== LibraryContentKind.SCP) {
      this.errorMessage = '三维档案参数无效，请从 SCP 档案页重新进入。';
      return;
    }
    const content = route.content;
    const resolved = resolveScp3DModelAsset(content.id, content.title);
    if (resolved === undefined) {
      this.errorMessage = '该项目暂无三维档案。';
      return;
    }
    this.routeResolved = true;
    this.contentId = content.id.toUpperCase();
    this.title = content.title.trim().length > 0 ? content.title : this.contentId;
    this.asset = resolved;
    this.requestLoadIfNeeded();
  }

  private requestLoadIfNeeded(): void {
    if (!this.pageActive || !this.pageShown || !this.routeResolved ||
      this.asset === undefined || this.loading || this.sceneReady) {
      return;
    }
    this.beginLoad(this.asset);
  }

  private beginLoad(asset: Scp3DModelAsset): void {
    const generation: number = ++this.loadGeneration;
    this.releaseScene();
    this.loading = true;
    this.errorMessage = '';
    this.sceneLoadHint.begin();
    this.loadSceneAsync(asset, generation);
  }

  private async loadSceneAsync(asset: Scp3DModelAsset, generation: number): Promise<void> {
    try {
      // The application repository verifies size/hash and returns either the
      // reviewed rawfile or an app-private content-addressed cache path. The
      // viewer never passes a network URL directly to Scene.load.
      const source: ArchiveSceneSource = this.resolveSceneSource !== undefined ?
        await this.resolveSceneSource(asset) :
        ArchiveSceneSource.bundled(ArchiveModelDescriptor.fromAsset(asset));
      const handle: Archive3DSceneHandle = await loadArchive3DScene(asset, source);
      if (generation !== this.loadGeneration || !this.pageActive || !this.pageShown) {
        handle.dispose();
        return;
      }
      this.sceneHandle = handle;
      this.interactionYaw = 0;
      this.interactionPitch = 0;
      this.interactionScale = asset.initialScale;
      this.sceneOptions = {
        scene: handle.scene,
        modelType: ModelType.SURFACE
      } as SceneOptions;
      this.sceneReady = true;
      this.loading = false;
      this.errorMessage = '';
      this.transformDirty = true;
      this.requestRender();
    } catch (error) {
      if (generation !== this.loadGeneration || !this.pageActive || !this.pageShown) {
        return;
      }
      this.loading = false;
      this.sceneReady = false;
      const message = error instanceof Error ? error.message : '';
      this.errorMessage = message.indexOf('尚未下载') >= 0 ||
        message.indexOf('未安装') >= 0 ?
        '该模型尚未下载，请先前往三维档案馆获取。' :
        '三维模型暂时无法加载，请稍后重试。';
    } finally {
      this.sceneLoadHint.end();
    }
  }

  private retryLoad(): void {
    if (this.asset === undefined || !this.pageActive || !this.pageShown || this.loading) {
      return;
    }
    this.errorMessage = '';
    this.beginLoad(this.asset);
  }

  private invalidateLoad(): void {
    this.loadGeneration++;
  }

  private releaseScene(): void {
    this.cancelRender();
    this.sceneReady = false;
    this.transformDirty = false;
    // Remove the native control from the tree before releasing its Scene.
    this.sceneOptions = undefined;
    const handle: Archive3DSceneHandle | undefined = this.sceneHandle;
    this.sceneHandle = undefined;
    handle?.dispose();
  }

  private cancelRender(): void {
    // postFrameCallback has no cancellation API. Invalidate any callback that
    // is already queued; its token check will make it a no-op when it fires.
    this.renderGeneration++;
    this.renderFramePending = false;
    if (this.renderTimer >= 0) {
      clearTimeout(this.renderTimer);
      this.renderTimer = -1;
    }
  }

  /**
   * Coalesce touch samples to the next VSync. During a gesture or auto
   * rotation the callback re-arms itself, so the native scene can follow the
   * display cadence; once interaction ends, one final dirty frame is flushed
   * and the loop stops.
   */
  private requestRender(): void {
    if (!this.isRenderable() || this.renderFramePending) {
      return;
    }
    this.renderFramePending = true;
    const generation: number = this.renderGeneration;
    try {
      this.getUIContext().postFrameCallback(new ArchiveRenderFrameCallback(
        (frameTimeInNano: number): void => this.onRenderFrame(generation, frameTimeInNano)
      ));
    } catch (_error) {
      // The normal path is VSync aligned. A short-lived fallback keeps the
      // viewer usable if a callback is requested during an unusual UI
      // teardown/re-attach window.
      this.renderFramePending = false;
      if (this.renderTimer >= 0) {
        return;
      }
      this.renderTimer = setTimeout((): void => {
        this.renderTimer = -1;
        this.renderFramePending = false;
        this.onRenderFrame(generation, 0);
      }, 16);
    }
  }

  private onRenderFrame(generation: number, frameTimeInNano: number): void {
    this.renderFramePending = false;
    if (generation !== this.renderGeneration || !this.isRenderable()) {
      return;
    }

    if (this.autoRotate && this.sceneReady) {
      const deltaSeconds: number = this.frameDeltaSeconds(frameTimeInNano);
      this.interactionYaw += AUTO_ROTATE_SPEED_RAD_PER_SECOND * deltaSeconds;
      this.transformDirty = true;
    }

    // Touch events only update the cheap local numbers. Apply the native TRS
    // once here, immediately before the frame, instead of crossing the
    // ArkTS/native boundary for every touch sample.
    if (this.transformDirty) {
      this.applyModelTransform(false);
    }

    const scene = this.sceneHandle?.scene;
    if (scene !== undefined) {
      scene.renderFrame({ alwaysRender: this.continuousRender });
    }
    if (this.continuousRender && this.isRenderable()) {
      this.requestRender();
    }
  }

  private frameDeltaSeconds(frameTimeInNano: number): number {
    if (!Number.isFinite(frameTimeInNano) || frameTimeInNano <= 0) {
      this.lastRenderFrameTimeNano = 0;
      return 1 / 60;
    }
    if (this.lastRenderFrameTimeNano <= 0) {
      this.lastRenderFrameTimeNano = frameTimeInNano;
      return 1 / 60;
    }
    const elapsed: number = (frameTimeInNano - this.lastRenderFrameTimeNano) / 1000000000;
    this.lastRenderFrameTimeNano = frameTimeInNano;
    // Guard against a long suspend/resume gap changing the rotation speed.
    return this.clamp(elapsed, 1 / 120, 0.05);
  }

  private clamp(value: number, minimum: number, maximum: number): number {
    return Math.max(minimum, Math.min(maximum, value));
  }

  private multiplyQuaternion(a: Quaternion, b: Quaternion): Quaternion {
    return {
      x: a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
      y: a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
      z: a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
      w: a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z
    };
  }

  private rotationFor(yaw: number, pitch: number): Quaternion {
    const yawRotation: Quaternion = {
      x: 0,
      y: Math.sin(yaw * 0.5),
      z: 0,
      w: Math.cos(yaw * 0.5)
    };
    const pitchRotation: Quaternion = {
      x: Math.sin(pitch * 0.5),
      y: 0,
      z: 0,
      w: Math.cos(pitch * 0.5)
    };
    return this.multiplyQuaternion(yawRotation, pitchRotation);
  }

  private applyModelTransform(scheduleRender: boolean = true): void {
    const root = this.sceneHandle?.modelRoot;
    if (root === undefined) {
      return;
    }
    root.rotation = this.rotationFor(this.interactionYaw, this.interactionPitch);
    root.scale = {
      x: this.interactionScale,
      y: this.interactionScale,
      z: this.interactionScale
    };
    this.transformDirty = false;
    if (scheduleRender) {
      this.requestRender();
    }
  }

  private resetView(): void {
    this.interactionYaw = 0;
    this.interactionPitch = 0;
    this.interactionScale = this.asset?.initialScale ?? 1;
    this.transformDirty = true;
    this.requestRender();
  }

  private minimumModelScale(): number {
    return this.asset?.minimumScale ?? 0.72;
  }

  private maximumModelScale(): number {
    return this.asset?.maximumScale ?? 1.65;
  }

  private beginPan(): void {
    if (!this.sceneReady) {
      return;
    }
    this.stopAutoRotate();
    this.autoRotate = false;
    this.panStartYaw = this.interactionYaw;
    this.panStartPitch = this.interactionPitch;
    this.beginContinuousRender();
  }

  private updatePan(event: GestureEvent): void {
    if (!this.sceneReady) {
      return;
    }
    this.interactionYaw = this.panStartYaw + event.offsetX * ROTATION_SENSITIVITY_X;
    this.interactionPitch = this.clamp(
      this.panStartPitch - event.offsetY * ROTATION_SENSITIVITY_Y,
      MIN_PITCH,
      MAX_PITCH
    );
    this.transformDirty = true;
    this.requestRender();
  }

  private beginPinch(): void {
    if (!this.sceneReady) {
      return;
    }
    this.stopAutoRotate();
    this.autoRotate = false;
    this.pinchStartScale = this.interactionScale;
    this.beginContinuousRender();
  }

  private updatePinch(event: GestureEvent): void {
    if (!this.sceneReady || !Number.isFinite(event.scale) || event.scale <= 0) {
      return;
    }
    this.interactionScale = this.clamp(
      this.pinchStartScale * event.scale,
      this.minimumModelScale(),
      this.maximumModelScale()
    );
    this.transformDirty = true;
    this.requestRender();
  }

  private toggleAutoRotate(): void {
    if (!this.sceneReady) {
      return;
    }
    this.autoRotate = !this.autoRotate;
    if (this.autoRotate) {
      this.startAutoRotate();
    } else {
      this.stopAutoRotate();
      if (this.gestureDepth === 0) {
        this.requestRender();
      }
    }
  }

  private startAutoRotate(): void {
    this.continuousRender = true;
    this.lastRenderFrameTimeNano = 0;
    this.requestRender();
  }

  private stopAutoRotate(): void {
    this.lastRenderFrameTimeNano = 0;
    if (this.gestureDepth === 0) {
      this.continuousRender = false;
    }
  }

  private beginContinuousRender(): void {
    this.gestureDepth++;
    this.continuousRender = true;
    this.lastRenderFrameTimeNano = 0;
    this.requestRender();
  }

  private endContinuousRender(): void {
    if (this.gestureDepth > 0) {
      this.gestureDepth--;
    }
    if (this.gestureDepth === 0 && !this.autoRotate) {
      this.continuousRender = false;
      this.lastRenderFrameTimeNano = 0;
      this.requestRender();
    }
  }

  /**
   * Release native rendering while the destination is not operable, but keep
   * the visibility bit intact. HDS can call onInactive when another surface
   * temporarily covers this destination; onActive must still be able to
   * recreate the scene without waiting for a second onShown callback.
   */
  private pauseRenderer(): void {
    this.pageActive = false;
    this.invalidateLoad();
    this.stopAutoRotate();
    this.autoRotate = false;
    this.gestureDepth = 0;
    this.continuousRender = false;
    this.cancelRender();
    this.releaseScene();
    this.loading = false;
  }

  /** Mark the destination hidden and release its renderer. */
  private hidePage(): void {
    this.creditsVisible = false;
    this.pageShown = false;
    this.pauseRenderer();
  }

  private assetSizeLabel(): string {
    if (this.asset === undefined) {
      return '—';
    }
    const megabytes: number = this.asset.byteLength / (1024 * 1024);
    if (megabytes >= 1) {
      return `${megabytes.toFixed(1)} MB`;
    }
    return `${(this.asset.byteLength / 1024).toFixed(0)} KB`;
  }

  private stageObjectClassLabel(): string {
    return this.asset === undefined ? '' : this.asset.objectClass.trim().toUpperCase();
  }

  private stageBadgeTextColor(objectClass: string): string {
    if (objectClass === 'SAFE') {
      return '#D6F5E8';
    }
    if (objectClass === 'EUCLID') {
      return '#FBE7BE';
    }
    if (objectClass === 'KETER') {
      return '#FFDCE0';
    }
    return '#EAF2FF';
  }

  private stageBadgeBackgroundColor(objectClass: string): string {
    if (objectClass === 'SAFE') {
      return '#1E4D3B';
    }
    if (objectClass === 'EUCLID') {
      return '#5A441D';
    }
    if (objectClass === 'KETER') {
      return '#66262C';
    }
    return '#314F86';
  }

  @Builder
  private stageBadge() {
    if (this.stageObjectClassLabel().length > 0) {
      Row() {
        Text(this.stageObjectClassLabel())
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.stageBadgeTextColor(this.stageObjectClassLabel()))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.stageBadgeBackgroundColor(this.stageObjectClassLabel()))
          .borderRadius(8)
          .accessibilityText(`项目等级，${this.stageObjectClassLabel()}`);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14 });
    }
  }

  @Builder
  private stageControls() {
    Row({ space: 8 }) {
      Button(this.autoRotate ? '停止自动旋转' : '自动旋转', { stateEffect: false })
        .height(36)
        .fontSize(12)
        .fontColor(this.autoRotate ? accentPillForegroundColor() : badgeInfoForegroundColor())
        .backgroundColor(this.autoRotate ? accentPillBackgroundColor() : badgeInfoBackgroundColor())
        .onClick(() => this.toggleAutoRotate());
      Blank().layoutWeight(1);
      Button('复位', { stateEffect: false })
        .height(36)
        .fontSize(12)
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('sys.color.comp_background_primary'))
        .onClick(() => this.resetView());
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(18)
    .accessibilityText('三维模型控制：自动旋转与复位');
  }

  @Builder
  private loadingOverlay() {
    Column({ space: 10 }) {
      LoadingProgress()
        .width(34)
        .height(34)
        .color('#8FB4FF');
      Text('正在载入三维档案')
        .fontSize(AppTypography.SUBTITLE_S)
        .fontColor('#EAF0FF');
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#E60A1220')
    .hitTestBehavior(HitTestMode.None);
  }

  @Builder
  private errorOverlay() {
    Column({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(28)
        .fontColor(['#F0B66B']);
      Text(this.errorMessage)
        .fontSize(AppTypography.BODY_M)
        .fontColor('#EAF0FF')
        .textAlign(TextAlign.Center)
        .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      if (this.asset !== undefined) {
        Button('重新加载', { stateEffect: false })
          .height(38)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor('#3E65B2')
          .onClick(() => this.retryLoad());
      } else {
        Text('请返回档案页重新进入三维档案')
          .fontSize(AppTypography.BODY_S)
          .fontColor('#AAB9D3');
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 28, right: 28 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#E60A1220');
  }

  @Builder
  private viewerStage() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.sceneReady && this.sceneHandle !== undefined && this.sceneOptions !== undefined) {
        Component3D(this.sceneOptions)
          .width('100%')
          .height('100%')
          // Component3D accepts percentage render targets on API 26. A
          // slightly smaller GPU target preserves crisp upscaling while
          // keeping the mobile frame budget below the full surface size.
          .renderWidth('90%')
          .renderHeight('90%')
          .onAppear(() => this.requestRender());
      }

      // A dedicated gesture layer keeps the native Component3D surface as a
      // pure renderer child and takes priority over the surrounding Scroll;
      // users can scroll from the content outside the observation stage.
      Column()
        .width('100%')
        .height('100%')
        .gesture(
          PanGesture({ fingers: 1, direction: PanDirection.All, distance: 3 })
            .onActionStart(() => this.beginPan())
            .onActionUpdate((event: GestureEvent) => this.updatePan(event))
            .onActionEnd(() => this.endContinuousRender())
            .onActionCancel(() => this.endContinuousRender())
        )
        .gesture(
          // HarmonyOS uses 5vp as the default/minimum useful pinch threshold;
          // matching it avoids an ignored gesture on API 26 devices.
          PinchGesture({ fingers: 2, distance: 5 })
            .onActionStart(() => this.beginPinch())
            .onActionUpdate((event: GestureEvent) => this.updatePinch(event))
            .onActionEnd(() => this.endContinuousRender())
            .onActionCancel(() => this.endContinuousRender())
        )
        .hitTestBehavior(HitTestMode.Default);

      this.stageBadge();
      if (this.loading) {
        this.loadingOverlay();
      } else if (this.errorMessage.length > 0) {
        this.errorOverlay();
      }
    }
    .width('100%')
    .height(VIEWER_HEIGHT)
    .backgroundColor('#0A1221')
    .borderRadius(24)
    .clip(true)
    .accessibilityText('三维档案观察区');
  }

  @Builder
  private creditsSheet() {
    if (this.asset !== undefined) {
      Scroll() {
        Column({ space: 12 }) {
          Text(this.asset.attribution)
            .fontSize(AppTypography.BODY_S)
            .fontColor($r('sys.color.font'))
            .width('100%')
            .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT);
          Text(this.asset.contentAttribution)
            .fontSize(AppTypography.BODY_S)
            .fontColor($r('sys.color.font'))
            .width('100%')
            .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT);
          Text(`许可：${this.asset.license}`)
            .fontSize(AppTypography.BODY_S)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%');
          Hyperlink(this.asset.licenseUrl, '查看许可文本')
            .color($r('sys.color.font_emphasize'))
            .width('100%');
          Text(this.asset.sourceLabel)
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT);
          Hyperlink(this.asset.sourceUrl, '查看模型来源')
            .color($r('sys.color.font_emphasize'))
            .width('100%');
          Hyperlink(this.asset.contentSourceUrl, '查看条目来源')
            .color($r('sys.color.font_emphasize'))
            .width('100%');
          Text(this.asset.notice)
            .fontSize(AppTypography.CAPTION_L)
            .fontColor(badgeWarningForegroundColor())
            .width('100%')
            .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT);
          Text(this.asset.modificationNote)
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT);
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 4, bottom: 28 });
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off);
    }
  }

  @Builder
  private metadataRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(AppTypography.BODY_S)
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1);
      Text(value)
        .fontSize(AppTypography.BODY_S)
        .fontColor($r('sys.color.font'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 });
  }

  @Builder
  private metadataSectionLabel(label: string) {
    Text(label)
      .fontSize(AppTypography.CAPTION_L)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_tertiary'))
      .width('100%')
      .margin({ top: 2, bottom: 1 });
  }

  @Builder
  private archiveInfo() {
    if (this.asset !== undefined) {
      Column({ space: 12 }) {
        Row() {
          Column({ space: 3 }) {
            Text('档案说明')
              .fontSize(AppTypography.SUBTITLE_M)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font'));
            Text(`项目等级 · ${this.asset.objectClass}`)
              .fontSize(AppTypography.CAPTION_L)
              .fontColor($r('sys.color.font_tertiary'));
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1);
          Button('来源', { stateEffect: false })
            .height(34)
            .fontSize(12)
            .fontColor(badgeInfoForegroundColor())
            .backgroundColor(badgeInfoBackgroundColor())
            .onClick(() => this.creditsVisible = true);
        }
        .width('100%');
        Text(this.asset.description)
          .fontSize(AppTypography.BODY_M)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT);
        Divider()
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'));
        this.metadataSectionLabel('文件信息');
        this.metadataRow('格式', this.asset.format.toUpperCase());
        this.metadataRow('大小', this.assetSizeLabel());
        this.metadataRow('版本', this.asset.version);
        Divider()
          .strokeWidth(0.5)
          .color($r('sys.color.comp_divider'));
        this.metadataSectionLabel('模型规格');
        this.metadataRow('网格面数', `${this.asset.estimatedTriangleCount} 三角面`);
      }
      .width('100%')
      .padding(18)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(20);
    }
  }

  build() {
    HdsNavDestination() {
      // Keep a full-size layout root below HDS. Without it a destination with
      // a short/temporarily empty document can be measured at intrinsic height
      // and centered inside the available page surface.
      Stack({ alignContent: Alignment.Top }) {
        Scroll(this.scroller) {
          Column({ space: 16 }) {
            this.viewerStage();
            if (!this.loading && this.errorMessage.length === 0 && this.sceneReady) {
              // Keep controls in normal document flow below the observation
              // surface. This is more reliable than aligning a child inside a
              // Component3D Stack and leaves the gesture surface unobstructed.
              this.stageControls();
            }
            this.archiveInfo();
          }
          .width('100%')
          .constraintSize({ maxWidth: 640 })
          .padding({
            left: PHONE_PAGE_MARGIN,
            right: PHONE_PAGE_MARGIN,
            // HDS title/status bars are visual overlays here. Keep the model
            // and metadata below them while the page background reaches them.
            top: pageContentTop(),
            bottom: 34
          });
        }
        .width(LayoutPolicy.matchParent)
        .height(LayoutPolicy.matchParent)
        .align(Alignment.Top)
        .clip(false)
        .background($r('sys.color.background_secondary'), {
          ignoresLayoutSafeAreaEdges: [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
        })
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off);
      }
      .width(LayoutPolicy.matchParent)
      .height(LayoutPolicy.matchParent)
      .clip(false)
      .bindSheet(this.creditsVisible, this.creditsSheet(), {
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        preferType: SheetType.BOTTOM,
        dragBar: true,
        showClose: true,
        title: { title: '资源来源与许可', subtitle: this.contentId },
        backgroundColor: $r('sys.color.comp_background_primary'),
        onWillDismiss: (action: DismissSheetAction): void => {
          this.creditsVisible = false;
          action.dismiss();
        },
        onDisappear: (): void => {
          this.creditsVisible = false;
        }
      });
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      // Match the established secondary-page pattern. The destination
      // ignores the system safe area and the document applies its own inset.
      enableComponentSafeArea: false,
      content: {
        title: {
          mainTitle: '三维档案',
          subTitle: this.contentId
        },
        backIcon: { label: '返回', componentId: 'scp3dArchiveBackButton' }
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
      this.applyRouteParam(context.pathInfo.param as Object | null | undefined);
    })
    .onShown(() => {
      this.pageShown = true;
      this.requestLoadIfNeeded();
    })
    .onHidden(() => this.hidePage())
    .onActive(() => {
      this.pageActive = true;
      this.requestLoadIfNeeded();
    })
    .onInactive(() => this.pauseRenderer())
    .onWillDisappear(() => this.hidePage())
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    );
  }
}
