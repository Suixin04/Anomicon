import {
  accentPillBackgroundColor,
  accentPillForegroundColor,
  adaptivePageMarginForWidth,
  AppTypography,
  badgeInfoBackgroundColor,
  CARD_PRESS_MODIFIER,
  isDarkModeActive,
  materialCardBorderColor,
  materialCardSurfaceColor,
  pageContentTop,
  PHONE_PAGE_MARGIN,
  pressAnimation,
  READING_CONTENT_MAX_WIDTH,
  WIDE_CONTENT_MAX_WIDTH
} from 'anomiconbasic';
import {
  FoundationAssessmentExam,
  FoundationAssessmentIcon,
  FoundationAssessmentRecord,
  FoundationAssessmentViewModel,
  LibraryContentRef
} from 'library';
import { SettingsViewModel } from 'settings';
import {
  FOUNDATION_FEATURED_KNOWLEDGE,
  FOUNDATION_MANUAL_GRID_ITEMS,
  FoundationKnowledgeIcon,
  FoundationKnowledgeItem
} from '../model/FoundationKnowledge';

const SECTION_SPACE: number = 22;
const TWO_COLUMN_MIN_WIDTH: number = 680;
const WIDE_TWO_COLUMN_MIN_WIDTH: number = 840;

function resolveKnowledgeSymbol(icon: FoundationKnowledgeIcon): Resource {
  switch (icon) {
    case FoundationKnowledgeIcon.CLASSIFICATION:
      return $r('sys.symbol.square_fill_grid_2x2');
    case FoundationKnowledgeIcon.ESOTERIC_CLASSIFICATION:
      return $r('sys.symbol.exclamationmark_shield_fill');
    case FoundationKnowledgeIcon.CLEARANCE:
      return $r('sys.symbol.person_text_rectangle_fill');
    case FoundationKnowledgeIcon.TASK_FORCE:
      return $r('sys.symbol.bolt_shield_fill');
    case FoundationKnowledgeIcon.DEPARTMENT:
      return $r('sys.symbol.rectangle_4_group_fill');
    case FoundationKnowledgeIcon.FACILITY:
      return $r('sys.symbol.local_and_rectangle_fill');
    case FoundationKnowledgeIcon.GROUP:
      return $r('sys.symbol.person_3_fill');
    case FoundationKnowledgeIcon.HISTORY:
      return $r('sys.symbol.clock_arrow_2_circlepath_fill');
    default:
      return $r('sys.symbol.lock_shield_fill');
  }
}

function resolveAssessmentSymbol(icon: FoundationAssessmentIcon): Resource {
  switch (icon) {
    case FoundationAssessmentIcon.TASK_FORCE:
      return $r('sys.symbol.bolt_shield_fill');
    case FoundationAssessmentIcon.CRV:
      return $r('sys.symbol.eye');
    default:
      return $r('sys.symbol.lock_shield_fill');
  }
}

@ComponentV2
struct FoundationAssessmentExamCard {
  @Require @Param exam: FoundationAssessmentExam;
  @Param passed: boolean = false;
  @Param bestScore: number = 0;
  @Param attempts: number = 0;
  @Param materialEnabled: boolean = true;
  @Event onStart: () => void = () => {};

  private statusPillText(): string {
    if (this.passed) {
      return `已签章 · ${this.bestScore}/${this.exam.questions.length}`;
    }
    if (this.attempts > 0) {
      return `最高 ${this.bestScore}/${this.exam.questions.length} · +${this.exam.xpReward} XP`;
    }
    return `首次通过 +${this.exam.xpReward} XP`;
  }

  private actionText(): string {
    return this.passed ? '再次演练' : '开始核验';
  }

  private isCrvSubject(): boolean {
    return this.exam.icon === FoundationAssessmentIcon.CRV;
  }

  private passedPillBackground(): string {
    return isDarkModeActive() ? '#2916A34A' : '#1816A34A';
  }

  private passedPillTextColor(): string {
    return isDarkModeActive() ? '#4ADE80' : '#15803D';
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Column() {
          SymbolGlyph(resolveAssessmentSymbol(this.exam.icon))
            .fontSize(20)
            .fontColor([this.passed ? '#16A34A' : $r('sys.color.icon_emphasize')])
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.passed ?
          this.passedPillBackground() : $r('sys.color.comp_background_tertiary'))
        .borderRadius(14)

        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text(this.exam.code)
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_emphasize'))
              .padding({ left: 7, right: 7, top: 2, bottom: 2 })
              .backgroundColor(badgeInfoBackgroundColor())
              .borderRadius(7)

            Text(`建议 · ${this.exam.recommendedRank}`)
              .fontSize(AppTypography.CAPTION_M)
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)

            if (this.isCrvSubject()) {
              Text('含透视勘验')
                .fontSize(AppTypography.CAPTION_M)
                .fontWeight(FontWeight.Medium)
                .fontColor(isDarkModeActive() ? '#FBBF24' : '#B45309')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor('#22F59E0B')
                .borderRadius(7)
            }
          }
          .alignItems(VerticalAlign.Center)

          Text(this.exam.title)
            .fontSize(AppTypography.SUBTITLE_M)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.exam.subtitle)
        .fontSize(AppTypography.BODY_S)
        .fontColor($r('sys.color.font_secondary'))
        .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: 8 }) {
        Row({ space: 5 }) {
          if (this.passed) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(13)
              .fontColor(['#16A34A'])
          }
          Text(this.statusPillText())
            .fontSize(AppTypography.CAPTION_M)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.passed ? this.passedPillTextColor() : $r('sys.color.font_emphasize'))
            .maxLines(1)
        }
        .padding({ left: 9, right: 9, top: 5, bottom: 5 })
        .backgroundColor(this.passed ?
          this.passedPillBackground() : $r('sys.color.comp_background_tertiary'))
        .borderRadius(10)

        Text(`印章：${this.exam.sealTitle}`)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .layoutWeight(1)

        Row({ space: 4 }) {
          Text(this.actionText())
            .fontSize(AppTypography.CAPTION_L)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.passed ? $r('sys.color.font') : accentPillForegroundColor())
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(12)
            .fontColor([this.passed ? $r('sys.color.icon_secondary') : accentPillForegroundColor()])
        }
        .height(30)
        .padding({ left: 11, right: 10 })
        .backgroundColor(this.passed ?
          $r('sys.color.comp_background_tertiary') : accentPillBackgroundColor())
        .borderRadius(15)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .id(`assessmentCard_${this.exam.id}`)
    .attributeModifier(CARD_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .padding(15)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .border(this.materialEnabled ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(18)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
    .onClick(() => this.onStart())
    .accessibilityText(`${this.exam.code} ${this.exam.title}，${this.statusPillText()}，${this.actionText()}`)
  }
}

@ComponentV2
struct FoundationManualGridTile {
  @Require @Param item: FoundationKnowledgeItem;
  @Require @Param materialEnabled: boolean;
  @Event onOpenContent: (content: LibraryContentRef) => void;

  build() {
    Column({ space: 10 }) {
      Row({ space: 6 }) {
        Column() {
          SymbolGlyph(resolveKnowledgeSymbol(this.item.icon))
            .fontSize(17)
            .fontColor([$r('sys.color.icon_emphasize')])
        }
        .width(34)
        .height(34)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(10)

        Blank()

        if (this.item.categoryLabel.length > 0) {
          Text(this.item.categoryLabel)
            .fontSize(AppTypography.CAPTION_M)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 3 }) {
        Text(this.item.title)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.item.subtitle)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .attributeModifier(CARD_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .constraintSize({ minHeight: 112 })
    .padding(13)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .border(this.materialEnabled ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(16)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
    .onClick(() => this.onOpenContent(this.item.content))
    .accessibilityText(`打开基金会手册，${this.item.title}`)
  }
}

/**
 * 「基金会」中心 Tab：上方为 RAISA 档案员资质考核（3 科），下方为完整基金会手册目录。
 */
@ComponentV2
export struct FoundationHome {
  @Require @Param scroller: Scroller;
  @Require @Param assessments: FoundationAssessmentViewModel;
  @Require @Param settings: SettingsViewModel;
  @Param active: boolean = true;
  @Event onOpenContent: (content: LibraryContentRef) => void = (_content: LibraryContentRef): void => {};
  @Event onStartAssessment: (examId: string) => void = (_examId: string): void => {};

  @Local private horizontalMargin: number = PHONE_PAGE_MARGIN;
  @Local private sideBySide: boolean = false;
  @Local private wideTwoColumn: boolean = false;
  @Local private assessmentRevision: number = 0;
  private assessmentsUnsubscribe: (() => void) | undefined = undefined;

  private isImmersiveMaterialEnabled(): boolean {
    return this.settings.immersiveMaterialEnabled;
  }

  aboutToAppear(): void {
    this.assessmentsUnsubscribe = this.assessments.subscribe((): void => {
      this.assessmentRevision++;
    });
    if (this.active) {
      this.assessments.initialize().catch((): void => {});
    }
  }

  aboutToDisappear(): void {
    this.assessmentsUnsubscribe?.();
    this.assessmentsUnsubscribe = undefined;
  }

  @Monitor('active')
  onActiveChange(): void {
    if (this.active) {
      this.assessments.initialize().catch((): void => {});
      this.assessmentRevision++;
    }
  }

  private exams(): FoundationAssessmentExam[] {
    return this.assessments.listExams();
  }

  private recordForExam(examId: string): FoundationAssessmentRecord | undefined {
    if (this.assessmentRevision < 0) {
      return undefined;
    }
    return this.assessments.recordFor(examId);
  }

  private passedExamCount(): number {
    if (this.assessmentRevision < 0) {
      return 0;
    }
    return this.assessments.passedCount();
  }

  private totalExamCount(): number {
    return this.assessments.totalCount();
  }

  private earnedAssessmentXp(): number {
    if (this.assessmentRevision < 0) {
      return 0;
    }
    return this.assessments.earnedXp();
  }

  private maxAssessmentXp(): number {
    return this.assessments.maxXp();
  }

  private columnHalfGutter(): number {
    return this.wideTwoColumn ? 14 : 10;
  }

  private leftPaneRightMargin(): number {
    return this.sideBySide ? this.columnHalfGutter() : this.horizontalMargin;
  }

  @Builder
  private sectionHeader(title: string, subtitle: string) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(AppTypography.TITLE_S)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font'))
      Text(subtitle)
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private assessmentSummaryBanner() {
    Row({ space: 12 }) {
      Column() {
        SymbolGlyph(this.passedExamCount() >= this.totalExamCount() ?
          $r('sys.symbol.checkmark_shield_fill') : $r('sys.symbol.seal_shield_fill'))
          .fontSize(20)
          .fontColor([this.passedExamCount() >= this.totalExamCount() ?
            '#16A34A' : $r('sys.color.icon_emphasize')])
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(12)

      Column({ space: 2 }) {
        Text(`RAISA 终端核验 · 已签发 ${this.passedExamCount()}/${this.totalExamCount()} 枚印章`)
          .fontSize(AppTypography.BODY_S)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`每科首次通过可获一次性阅历奖励 · 已累计 ${this.earnedAssessmentXp()} / ${this.maxAssessmentXp()} XP`)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .id('foundationAssessmentSummary')
    .width('100%')
    .padding(14)
    .backgroundColor(materialCardSurfaceColor(this.isImmersiveMaterialEnabled()))
    .border(this.isImmersiveMaterialEnabled() ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(16)
    .backgroundBlurStyle(this.isImmersiveMaterialEnabled() ? BlurStyle.COMPONENT_REGULAR : undefined)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private assessmentsSection() {
    Column({ space: 12 }) {
      this.sectionHeader(
        '档案资质考核',
        '模拟 RAISA 编目工单与认知勘验，不阻断日常阅读，通过后签发工牌印章'
      )

      this.assessmentSummaryBanner()

      Column({ space: 10 }) {
        ForEach(this.exams(), (exam: FoundationAssessmentExam) => {
          FoundationAssessmentExamCard({
            exam: exam,
            passed: this.recordForExam(exam.id)?.passed ?? false,
            bestScore: this.recordForExam(exam.id)?.bestScore ?? 0,
            attempts: this.recordForExam(exam.id)?.attempts ?? 0,
            materialEnabled: this.isImmersiveMaterialEnabled(),
            onStart: () => this.onStartAssessment(exam.id)
          })
        }, (exam: FoundationAssessmentExam) => `${exam.id}:${this.assessmentRevision}`)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: this.horizontalMargin, right: this.leftPaneRightMargin() })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private featuredKnowledgeCard(item: FoundationKnowledgeItem) {
    Row({ space: 14 }) {
      Column() {
        SymbolGlyph(resolveKnowledgeSymbol(item.icon))
          .fontSize(22)
          .fontColor([$r('sys.color.icon_emphasize')])
      }
      .width(46)
      .height(46)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(14)

      Column({ space: 4 }) {
        if (item.categoryLabel.length > 0) {
          Text(item.categoryLabel)
            .fontSize(AppTypography.CAPTION_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_emphasize'))
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(9)
        }
        Text(item.title)
          .fontSize(AppTypography.SUBTITLE_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.subtitle)
          .fontSize(AppTypography.CAPTION_L)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(13)
          .fontColor([$r('sys.color.icon_emphasize')])
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(16)
    }
    .attributeModifier(CARD_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .padding(15)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(materialCardSurfaceColor(this.isImmersiveMaterialEnabled()))
    .border(this.isImmersiveMaterialEnabled() ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(18)
    .backgroundBlurStyle(this.isImmersiveMaterialEnabled() ? BlurStyle.COMPONENT_REGULAR : undefined)
    .onClick(() => this.onOpenContent(item.content))
    .accessibilityText(`打开基金会手册导读，${item.title}`)
  }

  @Builder
  private manualSection() {
    Column({ space: 14 }) {
      this.sectionHeader('基金会手册', '核心设定、分级制度与组织档案（离线答卷前可随时查阅）')

      this.featuredKnowledgeCard(FOUNDATION_FEATURED_KNOWLEDGE)

      GridRow({ columns: 2, gutter: { x: 10, y: 10 } }) {
        ForEach(FOUNDATION_MANUAL_GRID_ITEMS, (item: FoundationKnowledgeItem) => {
          GridCol({ span: 1 }) {
            FoundationManualGridTile({
              item: item,
              materialEnabled: this.isImmersiveMaterialEnabled(),
              onOpenContent: (content: LibraryContentRef) => this.onOpenContent(content)
            })
          }
        }, (item: FoundationKnowledgeItem) => item.key)
      }
      .width('100%')
    }
    .width('100%')
    .padding({
      left: this.sideBySide ? this.columnHalfGutter() : this.horizontalMargin,
      right: this.horizontalMargin
    })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: SECTION_SPACE }) {
        Flex({
          direction: this.sideBySide ? FlexDirection.Row : FlexDirection.Column,
          alignItems: ItemAlign.Start
        }) {
          Column() {
            this.assessmentsSection()
          }
          .width(this.sideBySide ? (this.wideTwoColumn ? '48%' : '50%') : '100%')
          .margin({ bottom: this.sideBySide ? 0 : SECTION_SPACE })

          Column() {
            this.manualSection()
          }
          .width(this.sideBySide ? (this.wideTwoColumn ? '52%' : '50%') : '100%')
        }
        .width('100%')

        Blank()
          .width('100%')
          .height(120)
      }
      .width('100%')
      .constraintSize({ maxWidth: this.sideBySide ? WIDE_CONTENT_MAX_WIDTH : READING_CONTENT_MAX_WIDTH })
      .padding({
        top: pageContentTop() + 12,
        bottom: 24
      })
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(this.sideBySide ? BarState.Auto : BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .width('100%')
    .height('100%')
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const viewportWidth = Number(newArea.width);
      if (Number.isFinite(viewportWidth) && viewportWidth > 0) {
        this.horizontalMargin = adaptivePageMarginForWidth(viewportWidth);
        this.sideBySide = viewportWidth >= TWO_COLUMN_MIN_WIDTH;
        this.wideTwoColumn = viewportWidth >= WIDE_TWO_COLUMN_MIN_WIDTH;
      }
    })
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
