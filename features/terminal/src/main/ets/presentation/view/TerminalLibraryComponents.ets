import {
  LibraryContentKind,
  LibraryContentRef,
  LibraryFavorite
} from 'library';
import { ReadingHistoryEntry } from 'library';
import { AppTypography } from 'anomiconbasic';

const FAVORITE_CARD_WIDTH: number = 220;
const FAVORITE_CARD_HEIGHT: number = 132;

function contentIconFor(kind: LibraryContentKind): Resource {
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

function kindLabelFor(kind: LibraryContentKind): string {
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

/** 收藏卡片使用稳定内容身份复用节点，并由 Repeat 更新最新快照。 */
@ComponentV2
export struct TerminalFavoriteCards {
  @Require @Param entries: LibraryFavorite[];
  @Require @Param materialEnabled: boolean;
  @Event onOpenContent: (content: LibraryContentRef) => void;

  private displayId(content: LibraryContentRef): string {
    return content.kind === LibraryContentKind.SCP ? content.id.toUpperCase() : '已加入收藏';
  }

  @Builder
  private favoriteCard(row: RepeatItem<LibraryFavorite>) {
    Stack({ alignContent: Alignment.TopEnd }) {
      SymbolGlyph(contentIconFor(row.item.content.kind))
        .fontSize(92)
        .fontColor([$r('sys.color.icon_emphasize')])
        .opacity(0.08)
        .translate({ x: 22, y: -20 })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        Row() {
          Row({ space: 6 }) {
            SymbolGlyph(contentIconFor(row.item.content.kind))
              .fontSize(14)
              .fontColor([$r('sys.color.icon_emphasize')])
            Text(kindLabelFor(row.item.content.kind))
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_emphasize'))
              .maxLines(1)
          }
          .height(28)
          .padding({ left: 9, right: 9 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(14)
        }
        .width('100%')

        Blank()

        Text(row.item.content.title)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.displayId(row.item.content))
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 4 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
    }
    .width(FAVORITE_CARD_WIDTH)
    .height(FAVORITE_CARD_HEIGHT)
    .backgroundColor(this.materialEnabled ?
      Color.Transparent : $r('sys.color.comp_background_primary'))
    .borderRadius(20)
    .clip(true)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
    .onClick(() => this.onOpenContent(row.item.content))
    .accessibilityText(`打开收藏，${row.item.content.title}`)
  }

  build() {
    Row({ space: 12 }) {
      Repeat<LibraryFavorite>(this.entries)
        .each((row: RepeatItem<LibraryFavorite>) => {
          this.favoriteCard(row)
        })
        .key((favorite: LibraryFavorite) => favorite.content.key)
    }
    .constraintSize({ minWidth: '100%' })
    .justifyContent(FlexAlign.Start)
    .alignSelf(ItemAlign.Start)
    .padding({ left: 16, right: 16 })
  }
}

/** 动态资料区标题。普通 @Builder 多参数按值传递不会跟随状态刷新。 */
@ComponentV2
export struct TerminalLibrarySectionTitle {
  @Require @Param symbol: Resource;
  @Require @Param title: string;
  @Require @Param count: number;
  @Require @Param showMore: boolean;
  @Event onOpen: () => void;

  build() {
    Row({ space: 9 }) {
      Column() {
        SymbolGlyph(this.symbol)
          .fontSize(15)
          .fontColor([$r('sys.color.icon_emphasize')])
      }
      .width(30)
      .height(30)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(10)

      Text(this.title)
        .fontSize(AppTypography.SUBTITLE_M)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font'))

      Text(`${this.count}`)
        .fontSize(AppTypography.CAPTION_M)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_tertiary'))
        .height(22)
        .padding({ left: 8, right: 8 })
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(11)

      Blank()

      if (this.showMore) {
        Row({ space: 3 }) {
          Text('全部')
            .fontSize(AppTypography.CAPTION_L)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_emphasize'))
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(11)
            .fontColor([$r('sys.color.icon_emphasize')])
        }
        .height(32)
        .padding({ left: 10, right: 8 })
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(16)
        .onClick(() => this.onOpen())
        .accessibilityText(`查看全部${this.title}`)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

@ComponentV2
export struct TerminalErrorState {
  @Require @Param message: string;
  @Event onRetry: () => void;

  build() {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(24)
        .fontColor([$r('sys.color.icon_secondary')])
      Text(this.message)
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .maxLines(2)
      Text('重试')
        .fontSize(AppTypography.BODY_M)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_emphasize'))
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .onClick(() => this.onRetry())
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 22, bottom: 22 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
  }
}

/** 阅读记录卡通过 @Param 接收 Repeat 发布的最新不可变快照。 */
@ComponentV2
struct TerminalReadingHistoryRow {
  @Require @Param entry: ReadingHistoryEntry;
  @Require @Param continueReading: boolean;
  @Event onOpenContent: (content: LibraryContentRef) => void;

  private displayId(content: LibraryContentRef): string {
    return content.kind === LibraryContentKind.SCP ? content.id.toUpperCase() : content.id;
  }

  private historyMetadata(): string {
    const content = this.entry.content;
    const identifier = content.kind === LibraryContentKind.SCP ?
      ` · ${this.displayId(content)}` : '';
    return `${kindLabelFor(content.kind)}${identifier} · ` +
      this.relativeReadTime(this.entry.lastReadAt);
  }

  private relativeReadTime(timestamp: number): string {
    const elapsed = Math.max(0, Date.now() - timestamp);
    const minutes = Math.floor(elapsed / 60000);
    if (minutes < 1) {
      return '刚刚';
    }
    if (minutes < 60) {
      return `${minutes} 分钟前`;
    }
    const hours = Math.floor(minutes / 60);
    if (hours < 24) {
      return `${hours} 小时前`;
    }
    const days = Math.floor(hours / 24);
    return days < 30 ? `${days} 天前` : '较早';
  }

  @Builder
  private resumeCard() {
    Stack({ alignContent: Alignment.TopEnd }) {
      SymbolGlyph(contentIconFor(this.entry.content.kind))
        .fontSize(104)
        .fontColor([$r('sys.color.icon_emphasize')])
        .opacity(0.07)
        .translate({ x: 26, y: -24 })
        .hitTestBehavior(HitTestMode.None)

      Row({ space: 16 }) {
        Column({ space: 7 }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.doc_text_badge_clock_fill'))
              .fontSize(14)
              .fontColor([$r('sys.color.icon_emphasize')])
            Text('继续阅读')
              .fontSize(AppTypography.CAPTION_L)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_emphasize'))
          }
          .height(24)

          Text(this.entry.content.title)
            .fontSize(AppTypography.SUBTITLE_M)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(this.historyMetadata())
            .fontSize(AppTypography.CAPTION_M)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column() {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(14)
            .fontColor([$r('sys.color.icon_emphasize')])
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(18)
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 18, right: 16, top: 16, bottom: 16 })
    }
    .width('100%')
    .height(128)
    .onClick(() => this.onOpenContent(this.entry.content))
    .accessibilityText(`继续阅读，${this.entry.content.title}`)
  }

  @Builder
  private recentRow() {
    Row({ space: 12 }) {
      Column() {
        SymbolGlyph(contentIconFor(this.entry.content.kind))
          .fontSize(20)
          .fontColor([$r('sys.color.icon_emphasize')])
      }
      .width(42)
      .height(42)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(14)

      Column({ space: 4 }) {
        Text(this.entry.content.title)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.historyMetadata())
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(13)
        .fontColor([$r('sys.color.icon_secondary')])
    }
    .width('100%')
    .constraintSize({ minHeight: 72 })
    .alignItems(VerticalAlign.Center)
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .onClick(() => this.onOpenContent(this.entry.content))
    .accessibilityText(`打开最近浏览，${this.entry.content.title}`)
  }

  build() {
    if (this.continueReading) {
      this.resumeCard()
    } else {
      this.recentRow()
    }
  }
}

/** 动态阅读记录列表由 Repeat 复用稳定内容节点并刷新最新快照。 */
@ComponentV2
export struct TerminalReadingHistoryList {
  @Require @Param entries: ReadingHistoryEntry[];
  @Require @Param continueReading: boolean;
  @Require @Param materialEnabled: boolean;
  @Event onOpenContent: (content: LibraryContentRef) => void;

  build() {
    Column() {
      Repeat<ReadingHistoryEntry>(this.entries)
        .each((row: RepeatItem<ReadingHistoryEntry>) => {
          Column() {
            TerminalReadingHistoryRow({
              entry: row.item,
              continueReading: this.continueReading,
              onOpenContent: (content: LibraryContentRef) => this.onOpenContent(content)
            })
            if (row.index < this.entries.length - 1) {
              Divider()
                .strokeWidth(0.5)
                .color($r('sys.color.comp_divider'))
                .margin({ left: 68, right: 14 })
            }
          }
          .width('100%')
        })
        .key((entry: ReadingHistoryEntry) => entry.content.key)
    }
    .width('100%')
    .backgroundColor(this.materialEnabled ?
      Color.Transparent : $r('sys.color.comp_background_primary'))
    .borderRadius(this.continueReading ? 22 : 18)
    .clip(true)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
  }
}
