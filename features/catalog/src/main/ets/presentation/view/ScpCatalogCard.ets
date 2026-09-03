import { CatalogPreviewState, ScpCatalogEntry } from '../ScpCatalogItem';
import { CatalogPreview } from '../../domain/CatalogContracts';
import { AppTypography } from 'anomiconbasic';

/** Preview loading is supplied by the screen ViewModel; no service singleton crosses this View. */
export type CatalogPreviewLoader = (
  itemId: string,
  onRefreshed?: (preview: CatalogPreview) => void,
  forceRefresh?: boolean
) => Promise<CatalogPreview>;

interface CatalogPreviewImageParams {
  source: string;
  entry: ScpCatalogEntry;
  generation: number;
}

/** 纯净瀑布流卡片：卡片出现时按需读取预览。 */
@ComponentV2
export struct ScpCatalogCard {
  @Require @Param entry: ScpCatalogEntry;
  @Require @Param onOpen: (itemId: string, name: string) => void;
  @Require @Param loadPreview: CatalogPreviewLoader;
  @Require @Param onPreviewLoaded: (entry: ScpCatalogEntry, info: CatalogPreview) => boolean;
  /** Product composition owns platform-specific sandbox path conversion. */
  @Require @Param resolveLocalPreviewSource: (path: string) => string;
  @Require @Param show3DModel: boolean;
  @Param readCompleted: boolean = false;
  @Param refreshToken: number = 0;

  private mounted: boolean = false;

  @Monitor('entry')
  onEntryChange(): void {
    // A keyed Repeat normally remounts this component when the immutable
    // entry changes.  Keep a lifecycle-safe fallback for runtimes that reuse
    // the node despite the key update: a visible card must request its new
    // entry immediately instead of waiting for another onAppear.
    if (this.mounted) {
      this.startPreviewLoad();
    }
  }

  @Monitor('refreshToken')
  onRefreshTokenChange(): void {
    // Repeat may update a recycled, off-screen node when the parent token
    // changes.  Leave its pending flag untouched; onAppear will consume it
    // when the item actually enters the viewport.
    if (this.mounted && (this.entry.previewState === CatalogPreviewState.IDLE ||
      this.entry.previewRefreshPending)) {
      this.startPreviewLoad();
    }
  }

  private handleAppear(): void {
    this.mounted = true;
    this.startPreviewLoad();
  }

  private startPreviewLoad(): void {
    // `onDisAppear` is also emitted when WaterFlow reflows after an image
    // changes an item's height.  Keep a settled/in-flight attempt authoritative
    // across that transient lifecycle; only an explicit parent refresh may
    // start a new attempt for the same entry.
    const shouldForceRefresh = this.entry.previewRefreshPending;
    if (this.entry.previewState !== CatalogPreviewState.IDLE && !shouldForceRefresh) {
      return;
    }
    if (shouldForceRefresh) {
      this.entry.previewPath = '';
      this.entry.previewUrl = '';
      this.entry.previewState = CatalogPreviewState.IDLE;
      // Home increments the generation while invalidating a refresh.  The
      // first card only consumes the pending flag; it must not invalidate the
      // same refresh a second time.
      if (!this.entry.previewRefreshPending) {
        this.entry.previewGeneration++;
      }
      this.entry.previewRefreshPending = false;
    }
    const requestedEntry = this.entry;
    requestedEntry.previewState = CatalogPreviewState.LOADING;
    const generation = requestedEntry.previewGeneration;
    const isCurrent = (): boolean => generation === requestedEntry.previewGeneration;
    const apply = (info: CatalogPreview): void => {
      if (!isCurrent()) {
        return;
      }
      const accepted = this.onPreviewLoaded(requestedEntry, info);
      if (!accepted) {
        // A page transition or filter change can invalidate the owner between
        // the request and its result.  Leave this object retryable.
        requestedEntry.previewState = CatalogPreviewState.IDLE;
        requestedEntry.previewRefreshPending = shouldForceRefresh;
        return;
      }
    };
    const fail = (error: Object): void => {
      if (!isCurrent()) {
        return;
      }
      if (error instanceof Error && error.message === '目录页面已离开') {
        // A page transition invalidates the ViewModel owner.  Leave this
        // entry idle so the next appearance can own a fresh request.
        requestedEntry.previewState = CatalogPreviewState.IDLE;
        requestedEntry.previewRefreshPending = shouldForceRefresh;
        return;
      }
      requestedEntry.previewState = CatalogPreviewState.FAILED;
    };
    // Normalize synchronous adapter throws into the same retryable state.
    Promise.resolve()
      .then(() => this.loadPreview(
        requestedEntry.itemId,
        (refreshed: CatalogPreview) => apply(refreshed),
        shouldForceRefresh
      ))
      .then((info: CatalogPreview) => apply(info))
      .catch((error: Object) => fail(error));
  }

  private handleDisAppear(): void {
    this.mounted = false;
    // A WaterFlow item can disappear solely because a neighboring image
    // changed height.  Its request and resolved projection must survive that
    // transient virtualization event; Refresh owns explicit invalidation.
  }

  private previewSource(): string {
    if (this.entry.previewPath.length > 0) {
      return this.resolveLocalPreviewSource(this.entry.previewPath);
    }
    return this.entry.previewUrl;
  }

  private isCurrentImage(params: CatalogPreviewImageParams): boolean {
    return params.entry === this.entry &&
      params.generation === params.entry.previewGeneration &&
      params.source === this.previewSource() &&
      this.entry.previewState === CatalogPreviewState.READY;
  }

  private handleImageError(params: CatalogPreviewImageParams): void {
    if (this.isCurrentImage(params)) {
      // Invalidate any delayed refresh callback for the failed source.  The
      // list-level Refresh is the only path that may try this image again.
      this.entry.previewGeneration++;
      this.entry.previewPath = '';
      this.entry.previewUrl = '';
      this.entry.previewState = CatalogPreviewState.FAILED;
      // Do not retry on every WaterFlow reflow.  The parent Refresh clears the
      // failed projection and supplies the next forceRefresh attempt.
    }
  }

  private imageErrorHandler(
    params: CatalogPreviewImageParams
  ): (error: ImageError) => void {
    const captured: CatalogPreviewImageParams = {
      source: params.source,
      entry: params.entry,
      generation: params.generation
    };
    return (_error: ImageError): void => {
      this.handleImageError(captured);
    };
  }

  private shouldRenderImage(): boolean {
    const sourceLength = this.previewSource().length;
    return this.entry.previewState === CatalogPreviewState.READY && sourceLength > 0;
  }

  @Builder
  private previewImage($$: CatalogPreviewImageParams) {
    Image($$.source)
      .width('100%')
      // 只约束宽度，让 ArkUI 按原图比例计算高度；Contain 避免默认 Cover 裁剪内容。
      .objectFit(ImageFit.Contain)
      .autoResize(true)
      .onError(this.imageErrorHandler($$))
  }

  build() {
    Column() {
      if (this.shouldRenderImage()) {
        this.previewImage({
          source: this.previewSource(),
          entry: this.entry,
          generation: this.entry.previewGeneration
        })
      }

      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(this.entry.itemId)
            .fontSize(AppTypography.BODY_S)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.show3DModel) {
            Row({ space: 3 }) {
              SymbolGlyph($r('sys.symbol.puzzle'))
                .fontSize(12)
                .fontColor(['#FFFFFF']);
              Text('3D')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF');
            }
            .height(20)
            .padding({ left: 6, right: 6 })
            .backgroundColor('#315B9E')
            .borderRadius(6)
            .hitTestBehavior(HitTestMode.None)
            .accessibilityText('含三维档案');
          }
          if (this.readCompleted) {
            Row({ space: 3 }) {
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(11)
                .fontColor(['#FFFFFF']);
              Text('已读完')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF');
            }
            .height(20)
            .padding({ left: 6, right: 6 })
            .backgroundColor('#3C7A57')
            .borderRadius(6)
            .hitTestBehavior(HitTestMode.None)
            .accessibilityText('已读完');
          }
        }
        .width('100%')
        .height(22)

        if (this.entry.title.length > 0) {
          Text(this.entry.title)
            .fontSize(AppTypography.BODY_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        if (this.entry.description.length > 0) {
          Text(this.entry.description)
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(12)
    }
    .width('100%')
    .clip(true)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .onAppear(() => this.handleAppear())
    .onDisAppear(() => this.handleDisAppear())
    .onClick(() => this.onOpen(this.entry.itemId, this.entry.title))
  }
}
