import { ExploreContentItem, ExploreEntry } from '../../domain/ExploreContracts';
import {
  LibraryContentKind,
  LibraryContentRef,
  createLibraryContentRef,
  isLibraryScpId
} from 'library';
import { ExploreCollectionMode } from '../../domain/ExploreContracts';
import { AppTypography, SkeletonBlock } from 'anomiconbasic';

const PREVIEW_LIMIT: number = 6;

/** 动态加载状态必须拥有 V2 组件边界，不能通过多参数 @Builder 传递。 */
@ComponentV2
struct ExploreSectionLoadState {
  @Require @Param itemCount: number;
  @Require @Param loading: boolean;
  @Require @Param error: string;
  @Event onRetry: () => void;

  @Builder
  private skeletonRows() {
    Column() {
      ForEach([0, 1, 2], (index: number) => {
        Row({ space: 12 }) {
          if (index === 0) {
            SkeletonBlock({ animated: true, radius: 8 })
              .width(28)
              .height(16)
          }
          Column({ space: 7 }) {
            SkeletonBlock({ animated: true, radius: 7 })
              .width(index === 1 ? '72%' : '84%')
              .height(14)
            SkeletonBlock({ animated: true, radius: 5 })
              .width('42%')
              .height(10)
          }
          .layoutWeight(1)
        }
        .width('100%')
        .height(60)
        .padding({ left: 16, right: 16 })
      }, (index: number) => `${index}`)
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
  }

  @Builder
  private emptyRows() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.doc_text'))
        .fontSize(18)
        .fontColor([$r('sys.color.icon_tertiary')])
      Text('暂时没有可显示的内容')
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height(72)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
  }

  build() {
    if (this.itemCount === 0 && this.loading) {
      this.skeletonRows()
    } else if (this.itemCount === 0 && this.error.length > 0) {
      Column({ space: 10 }) {
        Text('暂时无法加载')
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
        Text(this.error)
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .maxLines(2)
        Button('重试', { stateEffect: false })
          .height(40)
          .onClick(() => this.onRetry())
      }
      .width('100%')
      .padding({ top: 24, bottom: 24 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
    } else if (this.itemCount === 0) {
      // Empty READY is distinct from LOADING; rendering skeleton rows here
      // made a legitimate empty response look like an endless request.
      this.emptyRows()
    } else if (this.loading || this.error.length > 0) {
      Row({ space: 6 }) {
        if (this.loading) {
          LoadingProgress()
            .width(14)
            .height(14)
            .color($r('sys.color.icon_secondary'))
        }
        Text(this.loading ? '正在更新' : this.error)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
          .layoutWeight(1)
          .maxLines(2)
        if (!this.loading && this.error.length > 0) {
          Text('重试')
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_emphasize'))
            .padding({ left: 8, right: 8, top: 6, bottom: 6 })
            .onClick(() => this.onRetry())
        }
      }
      .width('100%')
      .padding({ left: 4, right: 4 })
    }
  }
}

/** 热门原创区块：entries/loading/error 均由 @Param 单向同步。 */
@ComponentV2
export struct ExploreTopRatedSection {
  @Require @Param entries: ExploreEntry[];
  @Require @Param loading: boolean;
  @Require @Param error: string;
  @Event onOpenContent: (content: LibraryContentRef) => void;
  @Event onRetry: () => void;

  private openEntry(entry: ExploreEntry): void {
    this.onOpenContent(createLibraryContentRef(
      isLibraryScpId(entry.id) ? LibraryContentKind.SCP : LibraryContentKind.WIKI,
      entry.id,
      entry.title
    ));
  }

  @Builder
  private entryRow(row: RepeatItem<ExploreEntry>) {
    Row({ space: 12 }) {
      Text(`${row.index + 1}`)
        .fontSize(AppTypography.BODY_M)
        .fontWeight(row.index < 3 ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(row.index < 3 ? $r('sys.color.font_emphasize') : $r('sys.color.font_secondary'))
        .width(24)
        .textAlign(TextAlign.Center)
      Column({ space: 3 }) {
        Text(row.item.title)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(row.item.id)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (row.item.score >= 0) {
        Text(`+${row.item.score.toLocaleString()}`)
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
      }
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([$r('sys.color.icon_secondary')])
    }
    .width('100%')
    .constraintSize({ minHeight: 60 })
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => this.openEntry(row.item))
  }

  build() {
    Column({ space: 12 }) {
      Column({ space: 2 }) {
        Text('热门原创')
          .fontSize(AppTypography.TITLE_S)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
        Text('SCP 中文主站高分内容')
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)

      if (this.entries.length > 0) {
        Column() {
          Repeat<ExploreEntry>(this.entries.slice(0, PREVIEW_LIMIT))
            .each((row: RepeatItem<ExploreEntry>) => {
              Column() {
                this.entryRow(row)
                if (row.index < Math.min(this.entries.length, PREVIEW_LIMIT) - 1) {
                  Divider()
                    .strokeWidth(0.5)
                    .color($r('sys.color.comp_divider'))
                    .margin({ left: 52, right: 16 })
                }
              }
              .width('100%')
            })
            .key((entry: ExploreEntry) =>
              `${entry.id.length}:${entry.id}${entry.title.length}:${entry.title}:${entry.score}`)
        }
        .width('100%')
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(16)
        .clip(true)
      }

      ExploreSectionLoadState({
        itemCount: this.entries.length,
        loading: this.loading,
        error: this.error,
        onRetry: () => this.onRetry()
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** 最近更新/轻松一下共用的混合来源区块。 */
@ComponentV2
export struct ExploreMixedSection {
  @Require @Param title: string;
  @Require @Param description: string;
  @Require @Param items: ExploreContentItem[];
  @Require @Param loading: boolean;
  @Require @Param error: string;
  @Require @Param showDate: boolean;
  @Require @Param mode: ExploreCollectionMode;
  @Event onOpenContent: (content: LibraryContentRef) => void;
  @Event onOpenCollection: (mode: ExploreCollectionMode) => void;
  @Event onRetry: () => void;

  private formatDate(value: string): string {
    if (/^\d{4}-\d{2}-\d{2}/.test(value) && value.length >= 16) {
      return `${value.substring(5, 10)} ${value.substring(11, 16)}`;
    }
    const parts = value.split(' ');
    if (parts.length < 4) {
      return value;
    }
    const months: string[] = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const month = months.indexOf(parts[1]);
    if (month < 0) {
      return value;
    }
    const day = parts[0].length === 1 ? `0${parts[0]}` : parts[0];
    const monthText = month + 1 < 10 ? `0${month + 1}` : `${month + 1}`;
    return `${monthText}-${day} ${parts[3]}`;
  }

  private openItem(item: ExploreContentItem): void {
    this.onOpenContent(createLibraryContentRef(item.kind, item.entry.id, item.entry.title));
  }

  private itemMeta(item: ExploreContentItem): string {
    return this.showDate && item.entry.date.length > 0 ?
      `${item.sourceLabel} · ${this.formatDate(item.entry.date)}` :
      `${item.sourceLabel} · ${item.entry.id}`;
  }

  @Builder
  private itemRow(row: RepeatItem<ExploreContentItem>) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(row.item.entry.title)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.itemMeta(row.item))
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([$r('sys.color.icon_secondary')])
    }
    .width('100%')
    .constraintSize({ minHeight: 60 })
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => this.openItem(row.item))
  }

  build() {
    Column({ space: 12 }) {
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(AppTypography.TITLE_S)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
        Text(this.description)
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)

      if (this.items.length > 0) {
        Column() {
          Repeat<ExploreContentItem>(this.items.slice(0, PREVIEW_LIMIT))
            .each((row: RepeatItem<ExploreContentItem>) => {
              Column() {
                this.itemRow(row)
                Divider()
                  .strokeWidth(0.5)
                  .color($r('sys.color.comp_divider'))
                  .margin({ left: 16, right: 16 })
              }
              .width('100%')
            })
            .key((item: ExploreContentItem) =>
              `${item.key.length}:${item.key}` +
              `${item.entry.title.length}:${item.entry.title}` +
              `${item.entry.date.length}:${item.entry.date}` +
              `${item.sourceLabel.length}:${item.sourceLabel}:${item.timestamp}`)
          Row({ space: 6 }) {
            Text('查看更多')
              .fontSize(AppTypography.BODY_S)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_emphasize'))
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(13)
              .fontColor([$r('sys.color.icon_emphasize')])
          }
          .width('100%')
          .height(48)
          .justifyContent(FlexAlign.Center)
          .onClick(() => this.onOpenCollection(this.mode))
          .accessibilityText(this.mode === ExploreCollectionMode.RECENT ?
            '查看全部最近更新' : '查看全部轻松内容')
        }
        .width('100%')
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(16)
        .clip(true)
      }

      ExploreSectionLoadState({
        itemCount: this.items.length,
        loading: this.loading,
        error: this.error,
        onRetry: () => this.onRetry()
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
