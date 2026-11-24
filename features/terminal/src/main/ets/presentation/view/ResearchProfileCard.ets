import {
  accentPillBackgroundColor,
  accentPillForegroundColor,
  AppMotion,
  AppTypography,
  materialCardBorderColor,
  materialCardSurfaceColor,
  pressAnimation,
  ROW_PRESS_MODIFIER,
  WIDE_CONTENT_MAX_WIDTH
} from 'anomiconbasic';
import { ResearchDailyProgress } from 'library';
import {
  DailyActivityBar,
  buildRecentSevenDayActivity,
  formatTodayQuotaLabel
} from '../model/TerminalProfileHelpers';

const PROFILE_WIDE_BANNER_MIN_WIDTH: number = 620;
const STATISTICS_WIDE_BREAKPOINT: string = '520vp';
const ACTIVITY_BAR_MAX_HEIGHT: number = 22;

/** 动态统计格必须是组件；多参数 @Builder 会把 value 固定为首次构建值。 */
@ComponentV2
struct ResearchStatisticItem {
  @Require @Param symbol: Resource;
  @Require @Param value: string;
  @Require @Param label: string;
  @Param clickable: boolean = false;
  @Event onTap: () => void = () => {};

  @Builder
  private tileContent() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        SymbolGlyph(this.symbol)
          .fontSize(16)
          .fontColor([this.clickable ? $r('sys.color.icon_emphasize') : $r('sys.color.icon_secondary')])
        Text(this.label)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .layoutWeight(1)
        if (this.clickable) {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(11)
            .fontColor([$r('sys.color.icon_tertiary')])
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.value)
        .fontSize(AppTypography.SUBTITLE_M)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(72)
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(15)
  }

  build() {
    if (this.clickable) {
      Column() {
        this.tileContent()
      }
      .attributeModifier(ROW_PRESS_MODIFIER)
      .animation(pressAnimation())
      .width('100%')
      .onClick(() => this.onTap())
      .accessibilityText(`查看全部${this.label}，当前 ${this.value}`)
    } else {
      this.tileContent()
    }
  }
}

/**
 * 终端档案阅历摘要（研究员档案工牌）。
 *
 * 组件只消费可展示的原始值，不持有阅历计算、持久化或共享状态。
 * 规则说明折叠收入右上角信息按钮以释放首屏空间，同时展示今日计分进度与近 7 日活跃条。
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
  @Param todayActiveMs: number = 0;
  @Param dailyProgress: ResearchDailyProgress[] = [];
  @Param maxWidth: number = WIDE_CONTENT_MAX_WIDTH;
  @Event onRetry: () => void;
  @Event onOpenFavorites: () => void = () => {};
  @Event onOpenHistory: () => void = () => {};
  @Local private wideBanner: boolean = false;
  @Local private rulesExpanded: boolean = false;

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

  @Computed
  get recentActivityBars(): DailyActivityBar[] {
    return buildRecentSevenDayActivity(this.dailyProgress, this.todayActiveMs);
  }

  @Builder
  private cardHeader() {
    Row({ space: 12 }) {
      Column({ space: 0 }) {
        Text('LV')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_emphasize'))
        Text(`${this.normalizedLevel()}`)
          .fontSize(AppTypography.TITLE_S)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width(52)
      .height(52)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(16)

      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text('档案阅历')
            .fontSize(AppTypography.CAPTION_L)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
          Text(`累计 ${this.normalizedInteger(this.experience)} XP`)
            .fontSize(AppTypography.CAPTION_M)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
        }
        Text(this.displayTitle())
          .fontSize(AppTypography.TITLE_S)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize(15)
          .fontColor([this.rulesExpanded ? accentPillForegroundColor() : $r('sys.color.icon_secondary')])
      }
      .width(30)
      .height(30)
      .backgroundColor(this.rulesExpanded ?
        accentPillBackgroundColor() : $r('sys.color.comp_background_tertiary'))
      .animation(pressAnimation())
      .accessibilityText(this.rulesExpanded ? '收起阅历规则说明' : '查看阅历规则说明')
      .onClick(() => {
        this.getUIContext().animateTo(AppMotion.springAnimateParam(true), (): void => {
          this.rulesExpanded = !this.rulesExpanded;
        });
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private progressSection() {
    Column({ space: 6 }) {
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
        .height(7)
        .color($r('sys.color.icon_emphasize'))
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .style({
          strokeWidth: 7,
          enableSmoothEffect: true
        })
        .borderRadius(3.5)
    }
    .width('100%')
  }

  @Builder
  private activityStrip() {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text('今日研读')
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_secondary'))
        Text(formatTodayQuotaLabel(this.todayActiveMs))
          .fontSize(AppTypography.BODY_S)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Row({ space: 6 }) {
        ForEach(this.recentActivityBars, (bar: DailyActivityBar) => {
          Column({ space: 3 }) {
            Stack({ alignContent: Alignment.Bottom }) {
              Column()
                .width(7)
                .height(ACTIVITY_BAR_MAX_HEIGHT)
                .borderRadius(3.5)
                .backgroundColor($r('sys.color.comp_background_secondary'))
              if (bar.ratio > 0) {
                Column()
                  .width(7)
                  .height(Math.max(4, Math.round(ACTIVITY_BAR_MAX_HEIGHT * bar.ratio)))
                  .borderRadius(3.5)
                  .backgroundColor(bar.isToday ?
                    $r('sys.color.icon_emphasize') : $r('sys.color.comp_background_emphasize'))
                  .opacity(bar.isToday ? 1 : 0.45)
              }
            }
            .width(7)
            .height(ACTIVITY_BAR_MAX_HEIGHT)

            Text(bar.label)
              .fontSize(9)
              .fontWeight(bar.isToday ? FontWeight.Bold : FontWeight.Regular)
              .fontColor(bar.isToday ? $r('sys.color.font_emphasize') : $r('sys.color.font_tertiary'))
          }
          .alignItems(HorizontalAlign.Center)
        }, (bar: DailyActivityBar) => bar.key)
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(14)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private statistics() {
    GridRow({
      columns: { xs: 2, sm: 4 },
      gutter: { x: 10, y: 10 },
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
          symbol: $r('sys.symbol.book_open_fill'),
          value: `${this.normalizedInteger(this.studiedCount)} 篇`,
          label: '已研读'
        })
      }
      GridCol({ span: 1 }) {
        ResearchStatisticItem({
          symbol: $r('sys.symbol.star_fill'),
          value: this.favoriteReady ? `${this.normalizedInteger(this.favoriteCount)}` : '—',
          label: '收藏',
          clickable: true,
          onTap: () => this.onOpenFavorites()
        })
      }
      GridCol({ span: 1 }) {
        ResearchStatisticItem({
          symbol: $r('sys.symbol.doc_text_badge_clock_fill'),
          value: this.historyReady ? `${this.normalizedInteger(this.historyCount)}` : '—',
          label: '记录',
          clickable: true,
          onTap: () => this.onOpenHistory()
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
    .height(96)
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
        .height(44)
        .fontSize(AppTypography.BODY_M)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_on_primary'))
        .backgroundColor($r('sys.color.comp_background_emphasize'))
        .onClick(() => this.onRetry())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 4 })
  }

  @Builder
  private profileContent() {
    if (this.wideBanner) {
      Row({ space: 18 }) {
        Column({ space: 12 }) {
          this.cardHeader()
          this.progressSection()
          this.activityStrip()
        }
        .width('48%')
        .alignItems(HorizontalAlign.Start)

        Column() {
          this.statistics()
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    } else {
      Column({ space: 12 }) {
        this.cardHeader()
        this.progressSection()
        this.activityStrip()
        this.statistics()
      }
      .width('100%')
    }
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
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private rulesDrawer() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.clock_fill'))
          .fontSize(14)
          .fontColor([$r('sys.color.icon_secondary')])
        Text('有效阅读每分钟 +1 XP，单篇满 1 分钟额外 +8 XP，每日计分上限 180 分钟')
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_secondary'))
          .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.lock_fill'))
          .fontSize(14)
          .fontColor([$r('sys.color.icon_secondary')])
        Text('仅记录本地阅读阅历，并非基金会世界观内的安保许可')
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_secondary'))
          .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(14)
    .transition(AppMotion.slideUpFadeTransition(-6))
  }

  build() {
    Column({ space: 12 }) {
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

      if (this.rulesExpanded) {
        this.rulesDrawer()
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: this.maxWidth })
    .padding(18)
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .border(this.materialEnabled ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(22)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width = Number(newArea.width);
      if (Number.isFinite(width) && width > 0) {
        this.wideBanner = width >= PROFILE_WIDE_BANNER_MIN_WIDTH;
      }
    })
  }
}
