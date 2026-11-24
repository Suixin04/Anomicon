import {
  adaptiveListLanesForWidth,
  adaptivePageMarginForWidth,
  AppTypography,
  CARD_PRESS_MODIFIER,
  PHONE_PAGE_MARGIN,
  pageContentTop,
  pressAnimation,
  SkeletonBlock,
  ViewModelLoadState,
  WIDE_CONTENT_MAX_WIDTH,
  windowWidthVp
} from 'anomiconbasic';
import {
  LibraryCollectionItem,
  LibraryCollectionMode
} from '../../domain/LibraryContracts';
import {
  LibraryContentKind,
  LibraryContentRef
} from '../../domain/LibraryContentRef';
import { LibraryCollectionVM } from '../viewmodel/LibraryCollectionVM';
import { LibraryCollectionViewContract } from './LibraryViewContracts';

const ROW_SPACE: number = 10;

/** Feature export: product passes a narrow contract, not services. */
@Builder
export function LibraryCollectionView(contract: LibraryCollectionViewContract) {
  LibraryCollectionContent({
    viewModel: contract.viewModel,
    scroller: contract.scroller,
    onOpenContent: contract.onOpenContent
  });
}

/**
 * 收藏、继续阅读与最近浏览的设备无关内容 View。
 *
 * HdsNavDestination、路由参数和 NavPathStack 均由 product host 管理；
 * 本 View 只渲染 ViewModel 状态并发出打开内容事件。
 */
@ComponentV2
struct LibraryCollectionContent {
  @Require @Param viewModel: LibraryCollectionVM;
  @Require @Param scroller: Scroller;
  @Require @Param onOpenContent: (content: LibraryContentRef) => void;
  @Local private paneWidth: number = 0;

  private horizontalMargin(): number {
    const width = this.paneWidth > 0 ? this.paneWidth : windowWidthVp();
    return width > 0 ? adaptivePageMarginForWidth(width) : PHONE_PAGE_MARGIN;
  }

  private hasItems(): boolean {
    const loadingEmpty = this.isLoading() && this.currentItems().length === 0 && this.currentError().length === 0;
    return !loadingEmpty && this.currentItems().length > 0;
  }

  private listLanes(): number {
    if (!this.hasItems()) {
      return 1;
    }
    const width = this.paneWidth > 0 ? this.paneWidth : windowWidthVp();
    return adaptiveListLanesForWidth(width, 680);
  }

  private currentMode(): LibraryCollectionMode {
    return this.viewModel.snapshot.data?.mode ?? LibraryCollectionMode.RECENT;
  }

  private currentItems(): LibraryCollectionItem[] {
    return this.viewModel.snapshot.data?.items ?? [];
  }

  private isLoading(): boolean {
    return this.viewModel.snapshot.state === ViewModelLoadState.LOADING ||
      this.viewModel.snapshot.state === ViewModelLoadState.REFRESHING;
  }

  private pageTitle(): string {
    switch (this.currentMode()) {
      case LibraryCollectionMode.FAVORITES:
        return '全部收藏';
      case LibraryCollectionMode.CONTINUE_READING:
        return '继续阅读';
      default:
        return '最近浏览';
    }
  }

  private kindLabel(kind: LibraryContentKind): string {
    switch (kind) {
      case LibraryContentKind.SCP:
        return 'SCP 档案';
      case LibraryContentKind.TALE:
        return '故事';
      case LibraryContentKind.KNOWLEDGE:
        return '基金会手册';
      default:
        return '维基页面';
    }
  }

  private contentIcon(kind: LibraryContentKind): Resource {
    switch (kind) {
      case LibraryContentKind.SCP:
        return $r('sys.symbol.archivebox_fill');
      case LibraryContentKind.TALE:
        return $r('sys.symbol.doc_text_fill');
      case LibraryContentKind.KNOWLEDGE:
        return $r('sys.symbol.list_book_fill');
      default:
        return $r('sys.symbol.doc_text_fill');
    }
  }

  private displayId(content: LibraryContentRef): string {
    return content.kind === LibraryContentKind.SCP ? content.id.toUpperCase() : content.id;
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const hours = date.getHours();
    const minutes = date.getMinutes();
    const monthText = month < 10 ? `0${month}` : `${month}`;
    const dayText = day < 10 ? `0${day}` : `${day}`;
    const hourText = hours < 10 ? `0${hours}` : `${hours}`;
    const minuteText = minutes < 10 ? `0${minutes}` : `${minutes}`;
    return `${date.getFullYear()}-${monthText}-${dayText} ${hourText}:${minuteText}`;
  }

  private timeLabel(item: LibraryCollectionItem): string {
    switch (this.currentMode()) {
      case LibraryCollectionMode.FAVORITES:
        return `收藏于 ${this.formatDate(item.timestamp)}`;
      case LibraryCollectionMode.CONTINUE_READING:
        return `上次阅读于 ${this.formatDate(item.timestamp)}`;
      default:
        return `浏览于 ${this.formatDate(item.timestamp)}`;
    }
  }

  private currentError(): string {
    return this.viewModel.snapshot.error?.message ?? '';
  }

  private emptyDescription(): string {
    switch (this.currentMode()) {
      case LibraryCollectionMode.FAVORITES:
        return '阅读档案或故事时，可在右上角菜单加入收藏。';
      case LibraryCollectionMode.CONTINUE_READING:
        return '未读完的档案与故事会自动保留进度，方便随时续读。';
      default:
        return '调阅任意档案、故事或手册后，记录将留存于此。';
    }
  }

  private stateIcon(): Resource {
    switch (this.currentMode()) {
      case LibraryCollectionMode.FAVORITES:
        return $r('sys.symbol.star');
      case LibraryCollectionMode.CONTINUE_READING:
        return $r('sys.symbol.doc_text_badge_clock');
      default:
        return $r('sys.symbol.clock');
    }
  }

  @Builder
  private stateView(symbol: Resource, title: string, description: string, retry: boolean) {
    Column({ space: 10 }) {
      SymbolGlyph(symbol)
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
        .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
        .maxLines(3)
      if (retry) {
        Text('重试')
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_emphasize'))
          .padding({ left: 16, right: 16, top: 9, bottom: 9 })
          .onClick(() => this.viewModel.retry())
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 260 })
    .justifyContent(FlexAlign.Center)
    .padding({ left: 28, right: 28 })
  }

  @Builder
  private skeletonRow(index: number) {
    Row({ space: 12 }) {
      SkeletonBlock({ animated: true, radius: 13 })
        .width(42)
        .height(42)
      Column({ space: 6 }) {
        SkeletonBlock({ animated: true, radius: 7 })
          .width(index % 2 === 0 ? '76%' : '88%')
          .height(14)
        SkeletonBlock({ animated: true, radius: 5 })
          .width('52%')
          .height(10)
        SkeletonBlock({ animated: true, radius: 5 })
          .width(index % 3 === 0 ? '64%' : '46%')
          .height(10)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SkeletonBlock({ animated: true, radius: 7 })
        .width(14)
        .height(14)
    }
    .width('100%')
    .height(82)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
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
    .padding({ top: 8, bottom: 24 })
  }

  @Builder
  private partialErrorView() {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(18)
        .fontColor([$r('sys.color.icon_secondary')])
      Text(this.currentError())
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Button('重试', { stateEffect: false })
        .fontSize(AppTypography.CAPTION_L)
        .onClick(() => this.viewModel.retry())
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(8)
  }

  @Builder
  private collectionRow(row: RepeatItem<LibraryCollectionItem>) {
    Row({ space: 12 }) {
      Column() {
        SymbolGlyph(this.contentIcon(row.item.content.kind))
          .fontSize(22)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .width(42)
      .height(42)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(13)

      Column({ space: 3 }) {
        Text(row.item.content.title)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.kindLabel(row.item.content.kind)} · ${this.displayId(row.item.content)}`)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.timeLabel(row.item))
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([$r('sys.color.icon_secondary')])
    }
    .attributeModifier(CARD_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .constraintSize({ minHeight: 82 })
    .alignItems(VerticalAlign.Center)
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .onClick(() => this.onOpenContent(row.item.content))
    .accessibilityText(`打开${this.kindLabel(row.item.content.kind)}，${row.item.content.title}`)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      List({ scroller: this.scroller, space: ROW_SPACE }) {
        if (this.isLoading() && this.currentItems().length === 0 && this.currentError().length === 0) {
          ListItem() {
            this.loadingView()
          }
        } else if (this.currentError().length > 0 && this.currentItems().length === 0) {
          ListItem() {
            this.stateView(
              $r('sys.symbol.exclamationmark_circle'),
              '读取失败',
              this.currentError(),
              this.viewModel.snapshot.data?.routeError === undefined
            )
          }
        } else if (this.currentItems().length === 0) {
          ListItem() {
            this.stateView(this.stateIcon(), this.pageTitle(), this.emptyDescription(), false)
          }
        } else {
          Repeat<LibraryCollectionItem>(this.currentItems())
            .each((row: RepeatItem<LibraryCollectionItem>) => {
              ListItem() {
                this.collectionRow(row)
              }
            })
            .key((item: LibraryCollectionItem) => item.content.key)
            .virtualScroll()
        }
      }
      .lanes(this.listLanes(), 12)
      .contentStartOffset(pageContentTop() + 8 + (this.hasItems() && this.currentError().length > 0 ? 52 : 0))
      .contentEndOffset(48)
      .width('100%')
      .constraintSize({ maxWidth: WIDE_CONTENT_MAX_WIDTH })
      .height('100%')
      .padding({ left: this.horizontalMargin(), right: this.horizontalMargin() })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })

      if (this.hasItems() && this.currentError().length > 0) {
        Column() {
          this.partialErrorView()
        }
        .width('100%')
        .constraintSize({ maxWidth: WIDE_CONTENT_MAX_WIDTH })
        .padding({
          left: this.horizontalMargin(),
          right: this.horizontalMargin(),
          top: pageContentTop() + 8
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width = Number(newArea.width);
      if (Number.isFinite(width) && width > 0) {
        this.paneWidth = width;
      }
    })
  }
}
