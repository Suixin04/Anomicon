import {
  LibraryContentKind,
  LibraryContentRef,
  LibraryFavorite,
  ReadingHistoryEntry
} from 'library';
import {
  TerminalEnrolledSeriesCard,
  TerminalOfflineArticleSummary
} from '../viewmodel/TerminalViewModel';
import { formatStorageBytes } from 'settings';
import {
  AppTypography,
  badgeInfoBackgroundColor,
  CARD_PRESS_MODIFIER,
  materialCardBorderColor,
  materialCardSurfaceColor,
  PHONE_PAGE_MARGIN,
  pressAnimation,
  ROW_PRESS_MODIFIER
} from 'anomiconbasic';

const FAVORITE_CARD_WIDTH: number = 212;
const FAVORITE_CARD_HEIGHT: number = 122;

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

/** 终端资料区轻量单行空态提示，避免抢占首屏空间。 */
@ComponentV2
export struct TerminalCompactEmptyBanner {
  @Require @Param symbol: Resource;
  @Require @Param title: string;
  @Require @Param description: string;
  @Param materialEnabled: boolean = false;

  build() {
    Row({ space: 12 }) {
      Column() {
        SymbolGlyph(this.symbol)
          .fontSize(17)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(10)

      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
        Text(this.description)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 11, bottom: 11 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .border(this.materialEnabled ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(16)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
  }
}

/** 终端常用入口工作条：三维档案馆 / 全部收藏 / 阅读设置。 */
@ComponentV2
export struct TerminalQuickWorkbenchBar {
  @Require @Param favoriteCount: number;
  @Require @Param materialEnabled: boolean;
  @Event onOpenArchive3DGallery: () => void = () => {};
  @Event onOpenFavorites: () => void = () => {};
  @Event onOpenSettings: () => void = () => {};

  @Builder
  private actionTile(
    symbol: Resource,
    title: string,
    trailingBadge: string,
    accessibilityLabel: string,
    onTap: () => void
  ) {
    Column({ space: 8 }) {
      Row() {
        Column() {
          SymbolGlyph(symbol)
            .fontSize(15)
            .fontColor([$r('sys.color.icon_emphasize')])
        }
        .width(28)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(9)

        Blank()

        if (trailingBadge.length > 0) {
          Text(trailingBadge)
            .fontSize(AppTypography.CAPTION_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
            .height(20)
            .padding({ left: 7, right: 7 })
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(10)
        } else {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(11)
            .fontColor([$r('sys.color.icon_tertiary')])
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(title)
        .fontSize(AppTypography.BODY_S)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .attributeModifier(CARD_PRESS_MODIFIER)
    .animation(pressAnimation())
    .layoutWeight(1)
    .height(68)
    .padding({ left: 11, right: 11, top: 10, bottom: 9 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .border(this.materialEnabled ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(16)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
    .onClick(() => onTap())
    .accessibilityText(accessibilityLabel)
  }

  build() {
    Row({ space: 10 }) {
      this.actionTile(
        $r('sys.symbol.viewfinder_3D'),
        '三维档案',
        '',
        '打开三维档案馆',
        (): void => this.onOpenArchive3DGallery()
      )
      this.actionTile(
        $r('sys.symbol.star_fill'),
        '全部收藏',
        `${this.favoriteCount}`,
        '打开全部收藏',
        (): void => this.onOpenFavorites()
      )
      this.actionTile(
        $r('sys.symbol.gearshape'),
        '阅读设置',
        '',
        '打开阅读设置',
        (): void => this.onOpenSettings()
      )
    }
    .width('100%')
  }
}

/** 收藏卡片使用稳定内容身份复用节点，并由 Repeat 更新最新快照。 */
@ComponentV2
export struct TerminalFavoriteCards {
  @Require @Param entries: LibraryFavorite[];
  @Require @Param materialEnabled: boolean;
  @Param horizontalPadding: number = PHONE_PAGE_MARGIN;
  @Event onOpenContent: (content: LibraryContentRef) => void;

  private displayId(content: LibraryContentRef): string {
    return content.kind === LibraryContentKind.SCP ? content.id.toUpperCase() : '已加入收藏';
  }

  @Builder
  private favoriteCard(row: RepeatItem<LibraryFavorite>) {
    Stack({ alignContent: Alignment.TopEnd }) {
      SymbolGlyph(contentIconFor(row.item.content.kind))
        .fontSize(86)
        .fontColor([$r('sys.color.icon_emphasize')])
        .opacity(0.07)
        .translate({ x: 20, y: -18 })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        Row() {
          Row({ space: 6 }) {
            SymbolGlyph(contentIconFor(row.item.content.kind))
              .fontSize(13)
              .fontColor([$r('sys.color.icon_emphasize')])
            Text(kindLabelFor(row.item.content.kind))
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_emphasize'))
              .maxLines(1)
          }
          .height(26)
          .padding({ left: 9, right: 9 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(13)
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
          .margin({ top: 3 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(14)
    }
    .attributeModifier(CARD_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width(FAVORITE_CARD_WIDTH)
    .height(FAVORITE_CARD_HEIGHT)
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .border(this.materialEnabled ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(18)
    .clip(true)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
    .onClick(() => this.onOpenContent(row.item.content))
    .accessibilityText(`打开收藏，${row.item.content.title}`)
  }

  build() {
    Row({ space: 10 }) {
      Repeat<LibraryFavorite>(this.entries)
        .each((row: RepeatItem<LibraryFavorite>) => {
          this.favoriteCard(row)
        })
        .key((favorite: LibraryFavorite) => favorite.content.key)
    }
    .constraintSize({ minWidth: '100%' })
    .justifyContent(FlexAlign.Start)
    .alignSelf(ItemAlign.Start)
    .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
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
      .width(28)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(9)

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
        .height(30)
        .padding({ left: 10, right: 8 })
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(15)
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
    .padding({ left: 24, right: 24, top: 20, bottom: 20 })
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
    Row({ space: 14 }) {
      Column({ space: 6 }) {
        Row({ space: 6 }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.doc_text_badge_clock_fill'))
              .fontSize(13)
              .fontColor([$r('sys.color.icon_emphasize')])
            Text('继续阅读')
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_emphasize'))
          }
          .height(22)
          .padding({ left: 8, right: 8 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(11)

          if (this.entry.completed) {
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                .fontSize(12)
                .fontColor(['#16A34A'])
              Text('已读')
                .fontSize(AppTypography.CAPTION_M)
                .fontWeight(FontWeight.Medium)
                .fontColor('#16A34A')
            }
            .height(22)
            .padding({ left: 7, right: 7 })
            .backgroundColor('#1A16A34A')
            .borderRadius(11)
          }
        }

        Text(this.entry.content.title)
          .fontSize(AppTypography.SUBTITLE_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
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
      .width(34)
      .height(34)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(17)
    }
    .attributeModifier(ROW_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .height(106)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 14, top: 14, bottom: 14 })
    .onClick(() => this.onOpenContent(this.entry.content))
    .accessibilityText(`继续阅读，${this.entry.content.title}`)
  }

  @Builder
  private recentRow() {
    Row({ space: 12 }) {
      Column() {
        SymbolGlyph(contentIconFor(this.entry.content.kind))
          .fontSize(18)
          .fontColor([$r('sys.color.icon_emphasize')])
      }
      .width(38)
      .height(38)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(12)

      Column({ space: 3 }) {
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

      Row({ space: 6 }) {
        if (this.entry.completed) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(14)
            .fontColor(['#16A34A'])
        }
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(13)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .alignItems(VerticalAlign.Center)
    }
    .attributeModifier(ROW_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .constraintSize({ minHeight: 62 })
    .alignItems(VerticalAlign.Center)
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
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
                .margin({ left: 64, right: 14 })
            }
          }
          .width('100%')
        })
        .key((entry: ReadingHistoryEntry) => entry.content.key)
    }
    .width('100%')
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .border(this.materialEnabled ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(this.continueReading ? 20 : 18)
    .clip(true)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
  }
}

/** 离线保存文章列表：突出离线就绪状态，断网冷启动可一键直达正文。 */
@ComponentV2
export struct TerminalOfflineArticleList {
  @Require @Param entries: TerminalOfflineArticleSummary[];
  @Require @Param materialEnabled: boolean;
  @Event onOpenContent: (content: LibraryContentRef) => void;

  @Builder
  private itemRow(item: TerminalOfflineArticleSummary) {
    Row({ space: 12 }) {
      Column() {
        SymbolGlyph($r('sys.symbol.archivebox_fill'))
          .fontSize(18)
          .fontColor([$r('sys.color.icon_emphasize')])
      }
      .width(38)
      .height(38)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(12)

      Column({ space: 3 }) {
        Text(item.content.title)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${item.detailText} · ${formatStorageBytes(item.totalBytes)}`)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 6 }) {
        Text(item.badgeText)
          .fontSize(AppTypography.CAPTION_M)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.ready ? '#16A34A' : $r('sys.color.warning'))
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(8)
          .maxLines(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(13)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .alignItems(VerticalAlign.Center)
    }
    .attributeModifier(ROW_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .constraintSize({ minHeight: 64 })
    .alignItems(VerticalAlign.Center)
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .onClick(() => this.onOpenContent(item.content))
    .accessibilityText(`打开离线文章，${item.content.title}，${item.badgeText}`)
  }

  build() {
    Column() {
      Repeat<TerminalOfflineArticleSummary>(this.entries)
        .each((row: RepeatItem<TerminalOfflineArticleSummary>) => {
          Column() {
            this.itemRow(row.item)
            if (row.index < this.entries.length - 1) {
              Divider()
                .strokeWidth(0.5)
                .color($r('sys.color.comp_divider'))
                .margin({ left: 64, right: 14 })
            }
          }
          .width('100%')
        })
        .key((item: TerminalOfflineArticleSummary) => `${item.content.key}:${item.badgeText}:${item.totalBytes}`)
    }
    .width('100%')
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .border(this.materialEnabled ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(18)
    .clip(true)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
  }
}

/** 终端“正在跟读”故事系列卡片：一眼续读下一篇或直达中心页顺序清单。 */
@ComponentV2
export struct TerminalEnrolledSeriesList {
  @Require @Param entries: TerminalEnrolledSeriesCard[];
  @Require @Param materialEnabled: boolean;
  @Event onResumeSeries: (seriesId: string, content: LibraryContentRef) => void;
  @Event onOpenSeriesHub: (hubId: string, title: string) => void;

  @Builder
  private seriesRow(item: TerminalEnrolledSeriesCard) {
    Row({ space: 12 }) {
      Column() {
        SymbolGlyph($r('sys.symbol.list_book_fill'))
          .fontSize(18)
          .fontColor([$r('sys.color.icon_emphasize')])
      }
      .width(38)
      .height(38)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(badgeInfoBackgroundColor())
      .borderRadius(12)

      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(item.nextEntry !== undefined ? `继续${item.title}` : item.title)
            .fontSize(AppTypography.BODY_M)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(item.progressText)
            .fontSize(AppTypography.CAPTION_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_emphasize'))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(badgeInfoBackgroundColor())
            .borderRadius(8)
            .maxLines(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(item.nextEntryLabel)
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('目录')
        .fontSize(AppTypography.CAPTION_M)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font'))
        .padding({ left: 9, right: 9, top: 5, bottom: 5 })
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(12)
        .onClick(() => this.onOpenSeriesHub(item.hubId, item.title))

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(13)
        .fontColor([$r('sys.color.icon_secondary')])
    }
    .id(`terminalSeriesCard:${item.seriesId}`)
    .attributeModifier(ROW_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .constraintSize({ minHeight: 68 })
    .alignItems(VerticalAlign.Center)
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .onClick(() => {
      if (item.nextEntry !== undefined) {
        this.onResumeSeries(item.seriesId, item.nextEntry);
      } else {
        this.onOpenSeriesHub(item.hubId, item.title);
      }
    })
    .accessibilityText(`${item.title}，${item.progressText}，${item.nextEntryLabel}`)
  }

  build() {
    Column() {
      Repeat<TerminalEnrolledSeriesCard>(this.entries)
        .each((row: RepeatItem<TerminalEnrolledSeriesCard>) => {
          Column() {
            this.seriesRow(row.item)
            if (row.index < this.entries.length - 1) {
              Divider()
                .strokeWidth(0.5)
                .color($r('sys.color.comp_divider'))
                .margin({ left: 64, right: 14 })
            }
          }
          .width('100%')
        })
        .key((item: TerminalEnrolledSeriesCard) =>
          `${item.seriesId}:${item.mainlineCompleted}:${item.nextEntryLabel}:${item.updatedAt}`)
    }
    .width('100%')
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .border(this.materialEnabled ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(18)
    .clip(true)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
  }
}
