import { AppTypography } from 'anomiconbasic';

const PROFILE_CARD_MAX_WIDTH: number = 680;
const STATISTICS_WIDE_BREAKPOINT: string = '520vp';

/** 动态统计格必须是组件；多参数 @Builder 会把 value 固定为首次构建值。 */
@ComponentV2
struct ResearchStatisticItem {
  @Require @Param symbol: Resource;
  @Require @Param value: string;
  @Require @Param label: string;

  build() {
    Column({ space: 8 }) {
      SymbolGlyph(this.symbol)
        .fontSize(21)
        .fontColor([$r('sys.color.icon_secondary')])
      Text(this.value)
        .fontSize(AppTypography.SUBTITLE_M)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.label)
        .fontSize(AppTypography.CAPTION_M)
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
    }
    .width('100%')
    .height(94)
    .padding({ left: 10, right: 10, top: 12, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(16)
  }
}

/**
 * 终端档案阅历摘要。
 *
 * 组件只消费可展示的原始值，不持有阅历计算、持久化或共享状态，方便终端首页
 * 在数据模型演进时保持稳定。统计栅格以组件宽度而非窗口宽度为断点，因此既可
 * 用于窄屏，也可放入最大 680vp 的页面内容区。
 */
@ComponentV2
export struct ResearchProfileCard {
  @Require @Param level: number;
  @Require @Param title: string;
  @Require @Param experience: number;
  @Require @Param currentLevelXp: number;
  @Require @Param nextLevelXp: number;
  @Require @Param progressPercent: number;
  @Require @Param effectiveActiveMs: number;
  @Require @Param studiedCount: number;
  @Require @Param favoriteCount: number;
  @Require @Param historyCount: number;
  @Require @Param favoriteReady: boolean;
  @Require @Param historyReady: boolean;
  @Require @Param loading: boolean;
  @Require @Param error: string;
  @Require @Param notice: string;
  @Require @Param materialEnabled: boolean;
  @Event onRetry: () => void;

  private normalizedInteger(value: number, minimum: number = 0): number {
    if (!Number.isFinite(value)) {
      return minimum;
    }
    return Math.max(minimum, Math.floor(value));
  }

  private normalizedLevel(): number {
    return this.normalizedInteger(this.level, 1);
  }

  private normalizedProgress(): number {
    if (!Number.isFinite(this.progressPercent)) {
      return 0;
    }
    return Math.max(0, Math.min(100, this.progressPercent));
  }

  private displayTitle(): string {
    const value = this.title.trim();
    return value.length > 0 ? value : '初访者';
  }

  private experienceInLevel(): number {
    const experience = this.normalizedInteger(this.experience);
    const currentLevelXp = this.normalizedInteger(this.currentLevelXp);
    return Math.max(0, experience - currentLevelXp);
  }

  private experienceForLevel(): number {
    const currentLevelXp = this.normalizedInteger(this.currentLevelXp);
    const nextLevelXp = this.normalizedInteger(this.nextLevelXp);
    return Math.max(0, nextLevelXp - currentLevelXp);
  }

  private progressDescription(): string {
    const required = this.experienceForLevel();
    if (required <= 0) {
      return '等级上限';
    }
    return `${Math.min(this.experienceInLevel(), required)} / ${required} XP`;
  }

  private effectiveTime(): string {
    const seconds = Math.floor(this.normalizedInteger(this.effectiveActiveMs) / 1000);
    if (seconds < 60) {
      return seconds > 0 ? `${seconds} 秒` : '0 分钟';
    }
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) {
      return `${minutes} 分钟`;
    }
    const hours = Math.floor(minutes / 60);
    const remainder = minutes % 60;
    if (remainder === 0) {
      return `${hours} 小时`;
    }
    return `${hours}时 ${remainder}分`;
  }

  @Builder
  private cardHeader() {
    Row({ space: 14 }) {
      Column({ space: 1 }) {
        Text('LV')
          .fontSize(AppTypography.CAPTION_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_emphasize'))
        Text(`${this.normalizedLevel()}`)
          .fontSize(AppTypography.TITLE_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width(58)
      .height(58)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(18)

      Column({ space: 3 }) {
        Text('档案阅历')
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
        Text(this.displayTitle())
          .fontSize(AppTypography.TITLE_S)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`累计 ${this.normalizedInteger(this.experience)} XP`)
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private progressSection() {
    Column({ space: 8 }) {
      Row() {
        Text(this.experienceForLevel() <= 0 ? '已达最高等级' : `距 Lv.${this.normalizedLevel() + 1}`)
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
        Blank()
        Text(this.progressDescription())
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
      }
      .width('100%')

      Progress({
        value: this.normalizedProgress(),
        total: 100,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(8)
        .color($r('sys.color.icon_emphasize'))
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .style({
          strokeWidth: 8,
          enableSmoothEffect: true
        })
        .borderRadius(4)
    }
    .width('100%')
  }

  @Builder
  private statistics() {
    GridRow({
      columns: { xs: 2, sm: 4 },
      gutter: { x: 12, y: 12 },
      breakpoints: {
        value: [STATISTICS_WIDE_BREAKPOINT],
        reference: BreakpointsReference.ComponentSize
      }
    }) {
      GridCol({ span: 1 }) {
        ResearchStatisticItem({
          symbol: $r('sys.symbol.clock_fill'),
          value: this.effectiveTime(),
          label: '有效阅读'
        })
      }
      GridCol({ span: 1 }) {
        ResearchStatisticItem({
          symbol: $r('sys.symbol.list_book_fill'),
          value: `${this.normalizedInteger(this.studiedCount)}`,
          label: '已研读'
        })
      }
      GridCol({ span: 1 }) {
        ResearchStatisticItem({
          symbol: $r('sys.symbol.star_fill'),
          value: this.favoriteReady ? `${this.normalizedInteger(this.favoriteCount)}` : '—',
          label: '收藏'
        })
      }
      GridCol({ span: 1 }) {
        ResearchStatisticItem({
          symbol: $r('sys.symbol.archivebox_fill'),
          value: this.historyReady ? `${this.normalizedInteger(this.historyCount)}` : '—',
          label: '记录'
        })
      }
    }
    .width('100%')
  }

  @Builder
  private loadingContent() {
    Row({ space: 12 }) {
      LoadingProgress()
        .width(22)
        .height(22)
        .color($r('sys.color.icon_secondary'))
      Text('正在同步本地阅历记录…')
        .fontSize(AppTypography.BODY_M)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height(112)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private errorContent() {
    Column({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(28)
        .fontColor([$r('sys.color.icon_secondary')])
      Text(this.error.trim().length > 0 ? this.error : '暂时无法读取档案阅历')
        .fontSize(AppTypography.BODY_M)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Button('重试', { type: ButtonType.Capsule, stateEffect: false })
        .height(48)
        .fontSize(AppTypography.BODY_M)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_on_primary'))
        .backgroundColor($r('sys.color.comp_background_emphasize'))
        .onClick(() => this.onRetry())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 4 })
  }

  @Builder
  private profileContent() {
    Column({ space: 18 }) {
      this.cardHeader()
      this.progressSection()
      this.statistics()
    }
    .width('100%')
  }

  @Builder
  private noticeContent() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(16)
        .fontColor([$r('sys.color.icon_secondary')])
      Text(this.notice)
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text('重试')
        .fontSize(AppTypography.CAPTION_L)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_emphasize'))
        .onClick(() => this.onRetry())
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private disclaimer() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.clock_fill'))
          .fontSize(15)
          .fontColor([$r('sys.color.icon_tertiary')])
        Text('有效阅读每分钟 +1 XP，单篇满 1 分钟额外 +8 XP，每日计分上限 180 分钟')
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
          .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.lock_fill'))
          .fontSize(15)
          .fontColor([$r('sys.color.icon_tertiary')])
        Text('仅记录本地阅读阅历，并非基金会世界观内的安保许可')
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
          .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 18 }) {
      if (this.loading) {
        this.loadingContent()
      } else if (this.error.trim().length > 0) {
        this.errorContent()
      } else {
        this.profileContent()
        if (this.notice.trim().length > 0) {
          this.noticeContent()
        }
      }

      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))

      this.disclaimer()
    }
    .width('100%')
    .constraintSize({ maxWidth: PROFILE_CARD_MAX_WIDTH })
    .padding(20)
    .backgroundColor(this.materialEnabled ?
      Color.Transparent : $r('sys.color.comp_background_primary'))
    .borderRadius(24)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
  }
}
