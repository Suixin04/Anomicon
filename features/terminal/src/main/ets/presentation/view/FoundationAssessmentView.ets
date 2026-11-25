import {
  accentPillBackgroundColor,
  accentPillForegroundColor,
  adaptivePageMarginForWidth,
  AppMotion,
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
  ROW_PRESS_MODIFIER
} from 'anomiconbasic';
import {
  FoundationAssessmentExam,
  FoundationAssessmentQuestion,
  FoundationAssessmentRecord,
  FoundationAssessmentSubmissionResult,
  LibraryContentRef
} from 'library';

const OPTION_LETTERS: string[] = ['A', 'B', 'C', 'D'];

class AssessmentReviewReference {
  readonly ref: LibraryContentRef;
  readonly label: string;
  readonly fromMistake: boolean;

  constructor(ref: LibraryContentRef, label: string, fromMistake: boolean) {
    this.ref = ref;
    this.label = label;
    this.fromMistake = fromMistake;
  }
}

@ComponentV2
struct AssessmentOptionRow {
  @Require @Param optionText: string;
  @Require @Param optionIndex: number;
  @Require @Param correctIndex: number;
  @Require @Param selectedOptionIndex: number;
  @Param materialEnabled: boolean = true;
  @Event onSelect: () => void = () => {};

  private answered(): boolean {
    return this.selectedOptionIndex >= 0;
  }

  private letter(): string {
    return this.optionIndex >= 0 && this.optionIndex < OPTION_LETTERS.length ?
      OPTION_LETTERS[this.optionIndex] : '?';
  }

  private rowBackgroundColor(): ResourceColor {
    if (!this.answered()) {
      return materialCardSurfaceColor(this.materialEnabled);
    }
    if (this.optionIndex === this.correctIndex) {
      return isDarkModeActive() ? '#2816A34A' : '#1816A34A';
    }
    if (this.optionIndex === this.selectedOptionIndex) {
      return isDarkModeActive() ? '#28DC2626' : '#16DC2626';
    }
    return materialCardSurfaceColor(this.materialEnabled);
  }

  private rowBorderColor(): ResourceColor {
    if (!this.answered()) {
      return this.materialEnabled ? materialCardBorderColor(true) : Color.Transparent;
    }
    if (this.optionIndex === this.correctIndex) {
      return '#16A34A';
    }
    if (this.optionIndex === this.selectedOptionIndex) {
      return '#DC2626';
    }
    return this.materialEnabled ? materialCardBorderColor(true) : Color.Transparent;
  }

  private badgeBgColor(): ResourceColor {
    if (!this.answered()) {
      return $r('sys.color.comp_background_tertiary');
    }
    if (this.optionIndex === this.correctIndex) {
      return '#16A34A';
    }
    if (this.optionIndex === this.selectedOptionIndex) {
      return '#DC2626';
    }
    return $r('sys.color.comp_background_tertiary');
  }

  private badgeTextColor(): ResourceColor {
    if (!this.answered()) {
      return $r('sys.color.font_secondary');
    }
    if (this.optionIndex === this.correctIndex || this.optionIndex === this.selectedOptionIndex) {
      return '#FFFFFF';
    }
    return $r('sys.color.font_secondary');
  }

  build() {
    Row({ space: 12 }) {
      Column() {
        Text(this.letter())
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.badgeTextColor())
      }
      .width(26)
      .height(26)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.badgeBgColor())
      .borderRadius(13)

      Text(this.optionText)
        .fontSize(AppTypography.BODY_S)
        .fontWeight(this.answered() && this.optionIndex === this.correctIndex ?
          FontWeight.Medium : FontWeight.Regular)
        .fontColor($r('sys.color.font'))
        .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
        .layoutWeight(1)

      if (this.answered() && this.optionIndex === this.correctIndex) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(17)
          .fontColor(['#16A34A'])
      } else if (this.answered() && this.optionIndex === this.selectedOptionIndex) {
        SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
          .fontSize(17)
          .fontColor(['#DC2626'])
      }
    }
    .id(`assessmentOption_${this.optionIndex}`)
    .attributeModifier(ROW_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .padding({ left: 14, right: 14, top: 13, bottom: 13 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.rowBackgroundColor())
    .border({
      width: this.answered() &&
        (this.optionIndex === this.correctIndex || this.optionIndex === this.selectedOptionIndex) ?
        1 : 0.5,
      color: this.rowBorderColor()
    })
    .borderRadius(14)
    .onClick(() => this.onSelect())
    .accessibilityText(`选项 ${this.letter()}，${this.optionText}`)
  }
}

/**
 * 沉浸式 RAISA 资质考核视图：工单报文 + 互动「反白透视」勘验 + 即时批注与核验回执单。
 */
@ComponentV2
export struct FoundationAssessmentView {
  @Require @Param exam: FoundationAssessmentExam;
  @Require @Param scroller: Scroller;
  @Param initialRecord: FoundationAssessmentRecord | undefined = undefined;
  @Require @Param profileRefreshError: string;
  @Event onRetryProfileRefresh: () => void;
  @Param materialEnabled: boolean = true;
  @Param hapticEnabled: boolean = true;
  @Event onHaptic: () => void = () => {};
  @Event onSubmitAttempt: (
    examId: string,
    score: number
  ) => Promise<FoundationAssessmentSubmissionResult> =
    (_examId: string, _score: number): Promise<FoundationAssessmentSubmissionResult> =>
      Promise.reject(new Error('未装配考核提交通道'));
  @Event onOpenReference: (content: LibraryContentRef) => void =
    (_content: LibraryContentRef): void => {};
  @Event onFinishClose: () => void = () => {};

  @Local private currentIndex: number = 0;
  @Local private selectedOptionIndex: number = -1;
  @Local private chosenIndices: number[] = [];
  @Local private clueRevealed: boolean = false;
  @Local private submitting: boolean = false;
  @Local private submitError: string = '';
  @Local private submissionResult: FoundationAssessmentSubmissionResult | undefined = undefined;
  @Local private horizontalMargin: number = PHONE_PAGE_MARGIN;

  private totalQuestions(): number {
    return this.exam.questions.length;
  }

  private currentQuestion(): FoundationAssessmentQuestion {
    const safeIndex = Math.max(0, Math.min(this.currentIndex, this.exam.questions.length - 1));
    return this.exam.questions[safeIndex];
  }

  private hasAnsweredCurrent(): boolean {
    return this.selectedOptionIndex >= 0;
  }

  private isCurrentCorrect(): boolean {
    return this.selectedOptionIndex === this.currentQuestion().correctIndex;
  }

  private isLastQuestion(): boolean {
    return this.currentIndex >= this.totalQuestions() - 1;
  }

  private progressRatio(): number {
    const answeredCount = this.currentIndex + (this.hasAnsweredCurrent() ? 1 : 0);
    return Math.round(answeredCount / Math.max(1, this.totalQuestions()) * 100);
  }

  private toggleRevealClue(): void {
    this.onHaptic();
    this.getUIContext().animateTo(AppMotion.microAnimateParam(), (): void => {
      this.clueRevealed = !this.clueRevealed;
    });
  }

  private selectOption(optionIndex: number): void {
    if (this.hasAnsweredCurrent() || this.submitting) {
      return;
    }
    this.onHaptic();
    this.selectedOptionIndex = optionIndex;
    const nextChosen = this.chosenIndices.slice();
    nextChosen[this.currentIndex] = optionIndex;
    this.chosenIndices = nextChosen;
  }

  private computeScore(): number {
    let score = 0;
    for (let index = 0; index < this.exam.questions.length; index++) {
      if (index < this.chosenIndices.length &&
        this.chosenIndices[index] === this.exam.questions[index].correctIndex) {
        score++;
      }
    }
    return score;
  }

  private async advanceOrSubmit(): Promise<void> {
    if (!this.hasAnsweredCurrent() || this.submitting) {
      return;
    }
    this.onHaptic();
    if (!this.isLastQuestion()) {
      this.currentIndex += 1;
      this.selectedOptionIndex = -1;
      this.clueRevealed = false;
      this.submitError = '';
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
      return;
    }
    await this.submitFinalAttempt();
  }

  private async submitFinalAttempt(): Promise<void> {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    this.submitError = '';
    try {
      const score = this.computeScore();
      const result = await this.onSubmitAttempt(this.exam.id, score);
      this.submissionResult = result;
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
    } catch (error) {
      this.submitError = error instanceof Error ? error.message : '提交核验结果失败';
    } finally {
      this.submitting = false;
    }
  }

  private replayExam(): void {
    this.onHaptic();
    this.currentIndex = 0;
    this.selectedOptionIndex = -1;
    this.chosenIndices = [];
    this.clueRevealed = false;
    this.submitError = '';
    this.submissionResult = undefined;
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
  }

  private buildReviewReferences(): AssessmentReviewReference[] {
    const items: AssessmentReviewReference[] = [];
    const seenKeys: Set<string> = new Set();
    for (let index = 0; index < this.exam.questions.length; index++) {
      const q = this.exam.questions[index];
      const missed = index >= this.chosenIndices.length ||
        this.chosenIndices[index] !== q.correctIndex;
      if (missed && !seenKeys.has(q.reference.key)) {
        seenKeys.add(q.reference.key);
        items.push(new AssessmentReviewReference(q.reference, q.referenceLabel, true));
      }
    }
    if (items.length === 0) {
      for (let index = 0; index < this.exam.questions.length; index++) {
        const q = this.exam.questions[index];
        if (!seenKeys.has(q.reference.key)) {
          seenKeys.add(q.reference.key);
          items.push(new AssessmentReviewReference(q.reference, q.referenceLabel, false));
        }
      }
    }
    return items;
  }

  private greenAccent(): string {
    return isDarkModeActive() ? '#4ADE80' : '#15803D';
  }

  private greenSoftBg(): string {
    return isDarkModeActive() ? '#2816A34A' : '#1816A34A';
  }

  private errorAccent(): string {
    return isDarkModeActive() ? '#F87171' : '#DC2626';
  }

  private amberTextColor(): string {
    return isDarkModeActive() ? '#FBBF24' : '#B45309';
  }

  private amberSoftBg(): string {
    return isDarkModeActive() ? '#29F59E0B' : '#1AF59E0B';
  }

  private receiptStatusHeadline(result: FoundationAssessmentSubmissionResult): string {
    if (result.passed) {
      return `核验通过 · 已签发「${result.exam.sealTitle}」印章`;
    }
    return `未达合格线（需答对 ${result.exam.passScore}/${result.totalQuestions} 题）`;
  }

  private receiptXpNotice(result: FoundationAssessmentSubmissionResult): string {
    if (result.awardedXpNow > 0) {
      return `首次通过奖励 +${result.awardedXpNow} XP · 已记入档案阅历`;
    }
    if (result.record.passed) {
      return `已持有「${result.exam.sealTitle}」印章 · 本次为复核演练（${result.record.bestScore}/${result.totalQuestions}）`;
    }
    return `首次通过可获 +${result.exam.xpReward} XP，建议参阅下方资料后重测`;
  }

  @Builder
  private dispatchProgressHeader() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(`RAISA-EVAL // ${this.exam.code}`)
          .fontSize(AppTypography.CAPTION_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_emphasize'))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(badgeInfoBackgroundColor())
          .borderRadius(8)

        if (this.initialRecord !== undefined && this.initialRecord.passed) {
          Text('已持章复核')
            .fontSize(AppTypography.CAPTION_M)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.greenAccent())
            .padding({ left: 7, right: 7, top: 3, bottom: 3 })
            .backgroundColor(this.greenSoftBg())
            .borderRadius(8)
        }

        Blank()

        Text(`工单 ${this.currentIndex + 1} / ${this.totalQuestions()}`)
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Progress({
        value: this.progressRatio(),
        total: 100,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(5)
        .color($r('sys.color.icon_emphasize'))
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .style({ strokeWidth: 5, enableSmoothEffect: true })
        .borderRadius(2.5)
    }
    .width('100%')
  }

  @Builder
  private questionBriefingCard() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text(this.currentQuestion().dispatchCode)
          .fontSize(AppTypography.CAPTION_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_secondary'))
        Text(this.currentQuestion().dispatchTag)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(7)

        Blank()

        if (this.currentQuestion().hasHiddenClue()) {
          Row({ space: 4 }) {
            SymbolGlyph(this.clueRevealed ? $r('sys.symbol.eye_slash') : $r('sys.symbol.eye'))
              .fontSize(13)
              .fontColor([this.clueRevealed ? this.amberTextColor() : $r('sys.color.icon_emphasize')])
            Text(this.clueRevealed ? '透视中' : '反白透视')
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.clueRevealed ? this.amberTextColor() : $r('sys.color.font_emphasize'))
          }
          .id('assessmentRevealButton')
          .height(26)
          .padding({ left: 9, right: 9 })
          .backgroundColor(this.clueRevealed ?
            this.amberSoftBg() : $r('sys.color.comp_background_tertiary'))
          .borderRadius(13)
          .alignItems(VerticalAlign.Center)
          .onClick(() => this.toggleRevealClue())
          .accessibilityText(this.clueRevealed ? '关闭隐藏线索透视' : '开启反白透视查验隐藏线索')
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.currentQuestion().briefing)
        .fontSize(AppTypography.BODY_M)
        .fontColor($r('sys.color.font'))
        .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
        .width('100%')

      if (this.currentQuestion().hasHiddenClue()) {
        if (this.clueRevealed) {
          Column({ space: 4 }) {
            Text('[反白透视显影]')
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.amberTextColor())
            Text(this.currentQuestion().hiddenClue)
              .fontSize(AppTypography.BODY_S)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.amberTextColor())
              .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
              .width('100%')
          }
          .id('assessmentRevealedClue')
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .backgroundColor(this.amberSoftBg())
          .border({ width: 0.8, color: '#66F59E0B' })
          .borderRadius(12)
          .transition(AppMotion.fadeTransition(AppMotion.MICRO_DURATION))
        } else {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.eye'))
              .fontSize(13)
              .fontColor([$r('sys.color.icon_secondary')])
            Text(this.currentQuestion().hiddenClueMaskHint)
              .fontSize(AppTypography.CAPTION_L)
              .fontColor($r('sys.color.font_secondary'))
              .layoutWeight(1)
          }
          .id('assessmentMaskedClueHint')
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(12)
          .alignItems(VerticalAlign.Center)
          .onClick(() => this.toggleRevealClue())
        }
      }
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .border(this.materialEnabled ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(18)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
  }

  @Builder
  private feedbackPanel() {
    Column({ space: 10 }) {
      Row({ space: 6 }) {
        SymbolGlyph(this.isCurrentCorrect() ?
          $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.exclamationmark_circle'))
          .fontSize(16)
          .fontColor([this.isCurrentCorrect() ? '#16A34A' : this.amberTextColor()])

        Text(this.isCurrentCorrect() ? '[核验通过]' : '[规程偏差]')
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isCurrentCorrect() ? this.greenAccent() : this.amberTextColor())

        Blank()

        Text(this.currentQuestion().dispatchCode)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.currentQuestion().explanation)
        .fontSize(AppTypography.BODY_S)
        .fontColor($r('sys.color.font_secondary'))
        .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
        .width('100%')

      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.doc_text'))
          .fontSize(14)
          .fontColor([$r('sys.color.icon_emphasize')])
        Text(this.currentQuestion().referenceLabel)
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_emphasize'))
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(12)
          .fontColor([$r('sys.color.icon_emphasize')])
      }
      .attributeModifier(ROW_PRESS_MODIFIER)
      .animation(pressAnimation())
      .width('100%')
      .padding({ left: 11, right: 11, top: 9, bottom: 9 })
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(12)
      .alignItems(VerticalAlign.Center)
      .onClick(() => this.onOpenReference(this.currentQuestion().reference))
    }
    .id('assessmentFeedbackPanel')
    .width('100%')
    .padding(14)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .border(this.materialEnabled ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(16)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
    .transition(AppMotion.fadeTransition(AppMotion.MICRO_DURATION))
  }

  @Builder
  private activeQuestionBody() {
    Column({ space: 16 }) {
      this.dispatchProgressHeader()

      this.questionBriefingCard()

      Text(this.currentQuestion().prompt)
        .fontSize(AppTypography.SUBTITLE_S)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font'))
        .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
        .width('100%')

      Column({ space: 10 }) {
        ForEach(this.currentQuestion().options, (option: string, optionIndex: number) => {
          AssessmentOptionRow({
            optionText: option,
            optionIndex: optionIndex,
            correctIndex: this.currentQuestion().correctIndex,
            selectedOptionIndex: this.selectedOptionIndex,
            materialEnabled: this.materialEnabled,
            onSelect: () => this.selectOption(optionIndex)
          })
        }, (option: string, optionIndex: number) => `${this.currentIndex}:${optionIndex}:${option}`)
      }
      .width('100%')

      if (this.hasAnsweredCurrent()) {
        this.feedbackPanel()

        if (this.submitError.length > 0) {
          Text(this.submitError)
            .fontSize(AppTypography.CAPTION_L)
            .fontColor(this.errorAccent())
            .width('100%')
        }

        Button(
          this.submitting ?
            '正在签发回执…' :
            (this.isLastQuestion() ? '生成核验回执' : '下一道工单'),
          { type: ButtonType.Capsule, stateEffect: false }
        )
          .id('assessmentNextButton')
          .width('100%')
          .height(46)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
          .fontColor(accentPillForegroundColor())
          .backgroundColor(accentPillBackgroundColor())
          .enabled(!this.submitting)
          .onClick(() => {
            this.advanceOrSubmit();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private receiptView() {
    Column({ space: 18 }) {
      Column({ space: 14 }) {
        Row({ space: 12 }) {
          Column() {
            SymbolGlyph(this.submissionResult!.passed ?
              $r('sys.symbol.seal_shield_fill') : $r('sys.symbol.exclamationmark_circle'))
              .fontSize(26)
              .fontColor([this.submissionResult!.passed ? '#16A34A' : this.amberTextColor()])
          }
          .width(52)
          .height(52)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.submissionResult!.passed ?
            this.greenSoftBg() : this.amberSoftBg())
          .borderRadius(16)

          Column({ space: 3 }) {
            Text(`RAISA 核验回执 // ${this.submissionResult!.exam.code}`)
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_secondary'))
            Text(this.submissionResult!.exam.title)
              .fontSize(AppTypography.TITLE_S)
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

        Row({ space: 12 }) {
          Text(`${this.submissionResult!.score} / ${this.submissionResult!.totalQuestions}`)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.submissionResult!.passed ? this.greenAccent() : $r('sys.color.font'))

          Column({ space: 4 }) {
            Text(this.receiptStatusHeadline(this.submissionResult!))
              .fontSize(AppTypography.BODY_S)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.submissionResult!.passed ? this.greenAccent() : this.amberTextColor())
            Text(this.receiptXpNotice(this.submissionResult!))
              .fontSize(AppTypography.CAPTION_M)
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(14)
        .alignItems(VerticalAlign.Center)

        if (this.profileRefreshError.length > 0) {
          Row({ space: 10 }) {
            Text(`成绩已保存，档案阅历刷新失败。${this.profileRefreshError}`)
              .fontSize(AppTypography.CAPTION_L)
              .fontColor($r('sys.color.font_secondary'))
              .layoutWeight(1)
            Button('刷新阅历', { type: ButtonType.Capsule, stateEffect: false })
              .id('assessmentRetryProfile')
              .onClick(() => this.onRetryProfileRefresh())
          }
          .width('100%')
        }

        Text(this.submissionResult!.passed ?
          this.submissionResult!.exam.passRemark : this.submissionResult!.exam.failRemark)
          .fontSize(AppTypography.BODY_S)
          .fontColor($r('sys.color.font_secondary'))
          .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
          .width('100%')
      }
      .id('assessmentReceiptCard')
      .width('100%')
      .padding(18)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
      .border(this.materialEnabled ?
        { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
      .borderRadius(20)
      .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)

      Column({ space: 10 }) {
        Text(this.submissionResult!.score < this.submissionResult!.totalQuestions ?
          '错题关联资料复盘' : '相关设定延伸阅读')
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .width('100%')

        ForEach(this.buildReviewReferences(), (item: AssessmentReviewReference) => {
          Row({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.doc_text'))
              .fontSize(16)
              .fontColor([$r('sys.color.icon_emphasize')])
            Column({ space: 2 }) {
              Text(item.label)
                .fontSize(AppTypography.BODY_S)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font'))
              Text(item.fromMistake ? '来自刚才有偏差的工单，推荐立即查阅' : '已掌握对应考点，可重温原档案设定')
                .fontSize(AppTypography.CAPTION_M)
                .fontColor($r('sys.color.font_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(13)
              .fontColor([$r('sys.color.icon_tertiary')])
          }
          .attributeModifier(ROW_PRESS_MODIFIER)
          .animation(pressAnimation())
          .width('100%')
          .padding(14)
          .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
          .border(this.materialEnabled ?
            { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
          .borderRadius(14)
          .alignItems(VerticalAlign.Center)
          .onClick(() => this.onOpenReference(item.ref))
        }, (item: AssessmentReviewReference) => item.ref.key)
      }
      .width('100%')

      Row({ space: 12 }) {
        Button('再次演练', { type: ButtonType.Capsule, stateEffect: false })
          .layoutWeight(1)
          .height(44)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .onClick(() => this.replayExam())

        Button('返回基金会', { type: ButtonType.Capsule, stateEffect: false })
          .id('assessmentDoneButton')
          .layoutWeight(1)
          .height(44)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
          .fontColor(accentPillForegroundColor())
          .backgroundColor(accentPillBackgroundColor())
          .onClick(() => this.onFinishClose())
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        if (this.submissionResult !== undefined) {
          this.receiptView()
        } else {
          this.activeQuestionBody()
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: READING_CONTENT_MAX_WIDTH })
      .padding({
        left: this.horizontalMargin,
        right: this.horizontalMargin,
        top: pageContentTop() + 12,
        bottom: 44
      })
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .clip(false)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .width('100%')
    .height('100%')
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const viewportWidth = Number(newArea.width);
      if (Number.isFinite(viewportWidth) && viewportWidth > 0) {
        this.horizontalMargin = adaptivePageMarginForWidth(viewportWidth);
      }
    })
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
