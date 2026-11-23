import {
  AppTypography,
  CARD_PRESS_MODIFIER,
  PHONE_PAGE_MARGIN,
  pageContentTop,
  ViewModelLoadState,
  SkeletonBlock
} from 'anomiconbasic';
import {
  LibraryContentRef,
  createLibraryContentRef
} from 'library';
import {
  ExploreCollectionMode,
  ExploreContentItem
} from '../../domain/ExploreContracts';
import {
  ExploreCollectionVM
} from '../viewmodel/ExploreCollectionVM';
import { ExploreCollectionEventType } from '../viewmodel/ExploreViewModelContracts';
import { ExploreCollectionViewContract } from './ExploreViewContracts';

const CONTENT_MAX_WIDTH: number = 680;
const ROW_SPACE: number = 8;

/**
 * Recently updated / daily-joke collection content.
 *
 * HdsNavDestination, route parsing and navigation effects remain product-owned;
 * this View only projects its screen ViewModel into the existing lazy list.
 */
@Builder
export function ExploreCollectionView(contract: ExploreCollectionViewContract) {
  ExploreCollectionContent({
    viewModel: contract.viewModel,
    scroller: contract.scroller,
    onOpenContent: contract.onOpenContent
  });
}

@ComponentV2
struct ExploreCollectionContent {
  @Require @Param viewModel: ExploreCollectionVM;
  @Require @Param scroller: Scroller;
  @Require @Param onOpenContent: (content: LibraryContentRef) => void;

  aboutToDisappear(): void {
    this.viewModel.dispose();
  }

  private currentItems(): ExploreContentItem[] {
    return this.viewModel.snapshot.data?.items ?? [];
  }

  private pageTitle(): string {
    return (this.viewModel.snapshot.data?.mode ?? ExploreCollectionMode.RECENT) ===
      ExploreCollectionMode.RECENT ? '最近更新' : '轻松一下';
  }

  private isLoading(): boolean {
    const state = this.viewModel.snapshot.state;
    return this.currentItems().length === 0 &&
      (state === ViewModelLoadState.LOADING || state === ViewModelLoadState.REFRESHING);
  }

  private currentError(): string {
    // Partial snapshots intentionally keep their rows visible.  Hiding the
    // error whenever items existed made stale/failed updates indistinguishable
    // from a fresh READY state and removed the retry affordance.
    return this.viewModel.snapshot.error?.message ?? '';
  }

  private retry(): void {
    this.viewModel.dispatch({ type: ExploreCollectionEventType.RETRY });
  }

  private formatDate(value: string): string {
    if (/^\d{4}-\d{2}-\d{2}/.test(value) && value.length >= 16) {
      return `${value.substring(0, 10)} ${value.substring(11, 16)}`;
    }
    return value;
  }

  private itemMeta(item: ExploreContentItem): string {
    if ((this.viewModel.snapshot.data?.mode ?? ExploreCollectionMode.RECENT) ===
      ExploreCollectionMode.RECENT && item.entry.date.length > 0) {
      return `${item.sourceLabel} · ${this.formatDate(item.entry.date)}`;
    }
    return `${item.sourceLabel} · ${item.entry.id}`;
  }

  private openItem(item: ExploreContentItem): void {
    this.onOpenContent(createLibraryContentRef(
      item.kind,
      item.entry.id,
      item.entry.title
    ));
  }

  @Builder
  private skeletonRow(index: number) {
    Row({ space: 12 }) {
      Column({ space: 7 }) {
        SkeletonBlock({ animated: true, radius: 7 })
          .width(index % 2 === 0 ? '78%' : '90%')
          .height(14)
        SkeletonBlock({ animated: true, radius: 5 })
          .width(index % 3 === 0 ? '58%' : '44%')
          .height(10)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SkeletonBlock({ animated: true, radius: 7 })
        .width(14)
        .height(14)
    }
    .width('100%')
    .constraintSize({ minHeight: 68 })
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
  }

  @Builder
  private loadingView() {
    Column({ space: ROW_SPACE }) {
      ForEach([0, 1, 2, 3, 4, 5], (index: number) => {
        this.skeletonRow(index)
      }, (index: number) => `${index}`)
    }
    .width('100%')
    .constraintSize({ minHeight: 260 })
    .padding({ top: 8, bottom: 24 })
  }

  @Builder
  private itemRow(row: RepeatItem<ExploreContentItem>) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(row.item.entry.title)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.itemMeta(row.item))
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([$r('sys.color.icon_secondary')])
    }
    .attributeModifier(CARD_PRESS_MODIFIER)
    .animation({ duration: 120, curve: Curve.FastOutSlowIn })
    .width('100%')
    .constraintSize({ minHeight: 68 })
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .onClick(() => this.openItem(row.item))
    .accessibilityText(`打开${row.item.sourceLabel}，${row.item.entry.title}`)
  }

  @Builder
  private stateView(title: string, description: string, retry: boolean) {
    Column({ space: 10 }) {
      SymbolGlyph(retry ? $r('sys.symbol.exclamationmark_circle') : $r('sys.symbol.clock'))
        .fontSize(30)
        .fontColor([$r('sys.color.icon_tertiary')])
      Text(title)
        .fontSize(AppTypography.SUBTITLE_M)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font'))
      Text(description)
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      if (retry) {
        Button('重试', { stateEffect: false })
          .height(40)
          .onClick(() => this.retry())
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 260 })
    .justifyContent(FlexAlign.Center)
    .padding({ left: 28, right: 28 })
  }

  @Builder
  private partialNotice() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(17)
        .fontColor([$r('sys.color.icon_secondary')])
      Text(this.currentError())
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text('重试')
        .fontSize(AppTypography.CAPTION_L)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_emphasize'))
        .onClick(() => this.retry())
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(12)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      List({ scroller: this.scroller, space: ROW_SPACE }) {
        ListItem() {
          Column()
            .width('100%')
            .height(pageContentTop() + 8)
        }
        if (this.isLoading()) {
          ListItem() {
            this.loadingView()
          }
        } else if (this.currentItems().length === 0 && this.currentError().length > 0) {
          ListItem() {
            this.stateView(
              '加载失败',
              this.currentError(),
              this.viewModel.snapshot.data?.routeError === undefined
            )
          }
        } else if (this.currentItems().length === 0) {
          ListItem() {
            this.stateView(this.pageTitle(), '当前没有可显示的内容', false)
          }
        } else {
          if (this.currentError().length > 0) {
            ListItem() {
              this.partialNotice()
            }
          }
          Repeat<ExploreContentItem>(this.currentItems())
            .each((row: RepeatItem<ExploreContentItem>) => {
              ListItem() {
                this.itemRow(row)
              }
            })
            .key((item: ExploreContentItem) => item.key)
            .virtualScroll()
        }
        ListItem() {
          Column()
            .width('100%')
            .height(48)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
      .height('100%')
      .padding({ left: PHONE_PAGE_MARGIN, right: PHONE_PAGE_MARGIN })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
