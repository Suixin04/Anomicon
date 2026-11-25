import {
  accentPillBackgroundColor,
  accentPillForegroundColor,
  adaptivePageMarginForWidth,
  AppMotion,
  AppTypography,
  badgeInfoBackgroundColor,
  badgeInfoForegroundColor,
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
  RAISA_CONTACT_MAX_LENGTH,
  RAISA_DETAILS_MAX_LENGTH,
  RAISA_FEEDBACK_CATEGORIES,
  RAISA_GITHUB_ISSUES_URL,
  RAISA_MAX_ATTACHMENTS,
  RAISA_SUMMARY_MAX_LENGTH,
  RaisaDiagnosticSnapshot,
  RaisaFeedbackAttachment,
  RaisaFeedbackCategory,
  RaisaFeedbackCategoryDescriptor,
  RaisaFeedbackContext,
  RaisaFeedbackTicket,
  RaisaFeedbackViewModel,
  findRaisaFeedbackCategoryDescriptor,
  formatRaisaAttachmentBytes,
  formatRaisaDiagnosticLines,
  formatRaisaTicketPlainReport,
  formatRaisaTicketTimestamp,
  validateRaisaFeedbackAttachments
} from 'library';

function resolveCategorySymbol(category: RaisaFeedbackCategory): Resource {
  switch (category) {
    case RaisaFeedbackCategory.ARCHIVE_RENDER:
      return $r('sys.symbol.doc_text_fill');
    case RaisaFeedbackCategory.ARCHIVE_3D:
      return $r('sys.symbol.viewfinder_3D');
    case RaisaFeedbackCategory.SYSTEM_PROPOSAL:
      return $r('sys.symbol.lightbulb_fill');
    default:
      return $r('sys.symbol.exclamationmark_triangle_fill');
  }
}

function renderModeBadgeText(renderMode: string): string {
  if (renderMode === 'web') {
    return '原版网页';
  }
  if (renderMode === 'offline') {
    return '离线副本';
  }
  if (renderMode === 'native') {
    return '原生阅读';
  }
  return '';
}

@ComponentV2
struct RaisaCategoryTile {
  @Require @Param descriptor: RaisaFeedbackCategoryDescriptor;
  @Require @Param selected: boolean;
  @Param materialEnabled: boolean = true;
  @Event onSelect: () => void = () => {};

  private tileSurfaceColor(): ResourceColor {
    if (this.selected) {
      return isDarkModeActive() ? '#281F6FEB' : '#160A59F7';
    }
    return materialCardSurfaceColor(this.materialEnabled);
  }

  private tileBorderColor(): ResourceColor {
    if (this.selected) {
      return $r('sys.color.comp_background_emphasize');
    }
    return this.materialEnabled ? materialCardBorderColor(true) : Color.Transparent;
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Column() {
          SymbolGlyph(resolveCategorySymbol(this.descriptor.category))
            .fontSize(15)
            .fontColor([this.selected ?
              $r('sys.color.icon_emphasize') : $r('sys.color.icon_secondary')])
        }
        .width(28)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(9)

        Text(this.descriptor.title)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.descriptor.subtitle)
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .attributeModifier(CARD_PRESS_MODIFIER)
    .animation(pressAnimation())
    .width('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.tileSurfaceColor())
    .border({ width: this.selected ? 1.5 : (this.materialEnabled ? 0.5 : 0), color: this.tileBorderColor() })
    .borderRadius(14)
    .onClick(() => this.onSelect())
    .accessibilityText(`选择工单分类 ${this.descriptor.title}`)
  }
}

@ComponentV2
struct RaisaTicketHistoryRow {
  @Require @Param ticket: RaisaFeedbackTicket;
  @Param materialEnabled: boolean = true;
  @Event onCopyCode: () => void = () => {};
  @Event onOpenIssue: () => void = () => {};

  private categoryTag(): string {
    return findRaisaFeedbackCategoryDescriptor(this.ticket.category).shortTag;
  }

  private metadataLine(): string {
    const versionPart = this.ticket.submittedAppVersion.length > 0 ?
      `版本 ${this.ticket.submittedAppVersion}` : '版本未知';
    const timePart = formatRaisaTicketTimestamp(this.ticket.submittedAt);
    const articlePart = this.ticket.articleId.length > 0 ?
      ` · ${this.ticket.articleId.toUpperCase()}` : '';
    return `${versionPart} · ${timePart}${articlePart}`;
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(this.ticket.ticketCode)
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Bold)
          .fontColor(badgeInfoForegroundColor())
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(badgeInfoBackgroundColor())
          .borderRadius(8)

        Text(this.categoryTag())
          .fontSize(AppTypography.CAPTION_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(8)

        Blank()

        Row({ space: 8 }) {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.rectangle_on_rectangle'))
              .fontSize(12)
              .fontColor([$r('sys.color.icon_secondary')])
            Text('复制')
              .fontSize(AppTypography.CAPTION_L)
              .fontColor($r('sys.color.font_secondary'))
          }
          .attributeModifier(ROW_PRESS_MODIFIER)
          .animation(pressAnimation())
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(10)
          .onClick(() => this.onCopyCode())

          Row({ space: 4 }) {
            Text('查看进展')
              .fontSize(AppTypography.CAPTION_L)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_emphasize'))
            SymbolGlyph($r('sys.symbol.arrow_up_right'))
              .fontSize(12)
              .fontColor([$r('sys.color.icon_emphasize')])
          }
          .attributeModifier(ROW_PRESS_MODIFIER)
          .animation(pressAnimation())
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(10)
          .onClick(() => this.onOpenIssue())
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.ticket.summary)
        .fontSize(AppTypography.BODY_L)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(this.metadataLine())
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .padding(14)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
    .border(this.materialEnabled ?
      { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
    .borderRadius(16)
    .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
  }
}

@ComponentV2
struct RaisaAttachmentItemRow {
  @Require @Param attachment: RaisaFeedbackAttachment;
  @Event onRemove: () => void = () => {};

  build() {
    Row({ space: 10 }) {
      if (this.attachment.isImage && this.attachment.previewUri.length > 0) {
        Image(this.attachment.previewUri)
          .width(52)
          .height(52)
          .objectFit(ImageFit.Cover)
          .borderRadius(10)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
      } else {
        Column() {
          SymbolGlyph($r('sys.symbol.doc_text'))
            .fontSize(22)
            .fontColor([$r('sys.color.icon_emphasize')])
        }
        .width(52)
        .height(52)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(10)
      }

      Column({ space: 3 }) {
        Text(this.attachment.fileName)
          .fontSize(AppTypography.BODY_S)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.attachment.isImage ? '图片' : '文件'} · ${formatRaisaAttachmentBytes(this.attachment.byteLength)}`)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
          .fontSize(18)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .onClick(() => this.onRemove())
      .accessibilityText(`移除附件 ${this.attachment.fileName}`)
    }
    .width('100%')
    .padding(8)
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(12)
  }
}

/**
 * 沉浸式 RAISA 档案系统维护工单视图：
 * 分类报文、脱敏终端快照、签发回执与记录提交版本的本地历史档案。
 */
@ComponentV2
export struct RaisaFeedbackView {
  @Require @Param viewModel: RaisaFeedbackViewModel;
  @Require @Param scroller: Scroller;
  @Require @Param initialContext: RaisaFeedbackContext;
  @Require @Param diagnosticSnapshot: RaisaDiagnosticSnapshot;
  @Param materialEnabled: boolean = true;
  @Event onHaptic: () => void = () => {};
  @Event onCopyText: (text: string, notice: string) => void = (_text: string, _notice: string): void => {};
  @Event onOpenExternalUrl: (url: string) => void = (_url: string): void => {};
  @Param onPickImages: ((remainingSlots: number) => Promise<RaisaFeedbackAttachment[]>) | undefined = undefined;
  @Param onPickDocuments: ((remainingSlots: number) => Promise<RaisaFeedbackAttachment[]>) | undefined = undefined;

  @Local private horizontalMargin: number = PHONE_PAGE_MARGIN;
  @Local private selectedCategory: RaisaFeedbackCategory = RaisaFeedbackCategory.TERMINAL_BUG;
  @Local private summary: string = '';
  @Local private details: string = '';
  @Local private contact: string = '';
  @Local private includeDiagnostics: boolean = true;
  @Local private diagnosticsExpanded: boolean = false;
  @Local private contextAttached: boolean = false;
  @Local private composerVisible: boolean = true;
  @Local private attachments: RaisaFeedbackAttachment[] = [];
  @Local private pickingAttachments: boolean = false;
  @Local private attachmentNotice: string = '';
  @Local private draftSeed: number = Date.now();
  @Local private draftSequence: number = 1;

  aboutToAppear(): void {
    this.viewModel.clearLastResult();
    this.viewModel.clearSubmitError();
    this.syncInitialContext();
  }

  @Monitor('initialContext')
  private onInitialContextChange(): void {
    this.syncInitialContext();
  }

  private syncInitialContext(): void {
    this.selectedCategory = this.initialContext.initialCategory;
    this.contextAttached = this.initialContext.hasArticleContext();
  }

  private greenAccent(): string {
    return isDarkModeActive() ? '#4ADE80' : '#16A34A';
  }

  private greenSoftBg(): string {
    return isDarkModeActive() ? '#2816A34A' : '#1816A34A';
  }

  private amberAccent(): string {
    return isDarkModeActive() ? '#FBBF24' : '#B45309';
  }

  private amberSoftBg(): string {
    return isDarkModeActive() ? '#28D97706' : '#18D97706';
  }

  private dangerAccent(): string {
    return isDarkModeActive() ? '#FCA5A5' : '#B91C1C';
  }

  private dangerSoftBg(): string {
    return isDarkModeActive() ? '#26DC2626' : '#14DC2626';
  }

  private currentCategoryDescriptor(): RaisaFeedbackCategoryDescriptor {
    return findRaisaFeedbackCategoryDescriptor(this.selectedCategory);
  }

  private effectiveDiagnosticSnapshot(): RaisaDiagnosticSnapshot {
    if (this.contextAttached) {
      return this.diagnosticSnapshot;
    }
    return new RaisaDiagnosticSnapshot(
      this.diagnosticSnapshot.appVersion,
      this.diagnosticSnapshot.appVersionCode,
      this.diagnosticSnapshot.appVersionLabel,
      this.diagnosticSnapshot.deviceType,
      this.diagnosticSnapshot.osLabel,
      this.diagnosticSnapshot.windowWidthVp,
      this.diagnosticSnapshot.themeMode,
      this.diagnosticSnapshot.immersiveMaterial,
      this.diagnosticSnapshot.entrySource
    );
  }

  private draftIdempotencyKey(): string {
    return `harmony-${this.draftSeed}-${this.draftSequence}`;
  }

  private resetDraftComposer(): void {
    this.onHaptic();
    this.viewModel.clearLastResult();
    this.viewModel.clearSubmitError();
    this.summary = '';
    this.details = '';
    this.attachments = [];
    this.attachmentNotice = '';
    this.draftSequence++;
    this.composerVisible = true;
  }

  private remainingAttachmentSlots(): number {
    return Math.max(0, RAISA_MAX_ATTACHMENTS - this.attachments.length);
  }

  private removeAttachment(id: string): void {
    this.onHaptic();
    this.attachments = this.attachments.filter((item: RaisaFeedbackAttachment): boolean => item.id !== id);
    this.attachmentNotice = '';
    if (this.viewModel.submitError.length > 0) {
      this.viewModel.clearSubmitError();
    }
  }

  private async pickAttachments(asImages: boolean): Promise<void> {
    if (this.pickingAttachments || this.viewModel.submitting) {
      return;
    }
    const remaining = this.remainingAttachmentSlots();
    if (remaining <= 0) {
      this.attachmentNotice = `最多可附带 ${RAISA_MAX_ATTACHMENTS} 个附件`;
      return;
    }
    const handler = asImages ? this.onPickImages : this.onPickDocuments;
    if (handler === undefined) {
      return;
    }
    this.onHaptic();
    this.pickingAttachments = true;
    this.attachmentNotice = '';
    try {
      const picked = await handler(remaining);
      if (picked.length === 0) {
        return;
      }
      const next: RaisaFeedbackAttachment[] = this.attachments.slice();
      for (let index: number = 0; index < picked.length && next.length < RAISA_MAX_ATTACHMENTS; index++) {
        next.push(picked[index]);
      }
      const validationError = validateRaisaFeedbackAttachments(next);
      if (validationError.length > 0) {
        this.attachmentNotice = validationError;
        return;
      }
      this.attachments = next;
      if (this.viewModel.submitError.length > 0) {
        this.viewModel.clearSubmitError();
      }
    } catch (error) {
      this.attachmentNotice = error instanceof Error ? error.message : '选择附件失败';
    } finally {
      this.pickingAttachments = false;
    }
  }

  private copyPlainReport(notice: string): void {
    this.onHaptic();
    const report = formatRaisaTicketPlainReport(
      this.selectedCategory,
      this.summary,
      this.details,
      this.contact,
      this.includeDiagnostics,
      this.effectiveDiagnosticSnapshot()
    );
    this.onCopyText(report, notice);
  }

  private async handleSubmit(): Promise<void> {
    if (this.viewModel.submitting) {
      return;
    }
    this.onHaptic();
    try {
      await this.viewModel.submit(
        this.selectedCategory,
        this.summary,
        this.details,
        this.contact,
        this.includeDiagnostics,
        this.effectiveDiagnosticSnapshot(),
        this.draftIdempotencyKey(),
        this.attachments
      );
      this.composerVisible = false;
      this.summary = '';
      this.details = '';
      this.attachments = [];
      this.attachmentNotice = '';
      this.draftSequence++;
    } catch (_error) {
      // 错误提示已经由 viewModel.submitError 呈现在页面内。
    }
  }

  @Builder
  private dispatchHeaderBanner() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Column() {
          SymbolGlyph($r('sys.symbol.wrench_and_screwdriver_fill'))
            .fontSize(22)
            .fontColor([$r('sys.color.icon_emphasize')])
        }
        .width(46)
        .height(46)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(14)

        Column({ space: 3 }) {
          Text('RAISA-OPS // 终端运维通道')
            .fontSize(AppTypography.CAPTION_M)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_emphasize'))
          Text('档案系统故障与演进工单')
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

      Row({ space: 8 }) {
        Text(this.viewModel.isRelayConfigured() ? '直连通道在线' : '等待配置中转域名')
          .fontSize(AppTypography.CAPTION_M)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.viewModel.isRelayConfigured() ? this.greenAccent() : this.amberAccent())
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(this.viewModel.isRelayConfigured() ? this.greenSoftBg() : this.amberSoftBg())
          .borderRadius(10)

        Text(`当前终端 ${this.diagnosticSnapshot.appVersionLabel}`)
          .fontSize(AppTypography.CAPTION_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(10)

        Text(`已归档 ${this.viewModel.tickets.length} 单`)
          .fontSize(AppTypography.CAPTION_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(10)
      }
      .width('100%')

      Text('工单将经由专用 GitHub App 中转通道写入公开仓库 Issue，无需登录 GitHub 账号。')
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
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
  private acceptanceReceiptCard() {
    if (this.viewModel.lastResult !== undefined) {
      Column({ space: 14 }) {
        Row({ space: 12 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.checkmark_shield_fill'))
              .fontSize(24)
              .fontColor([this.greenAccent()])
          }
          .width(48)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.greenSoftBg())
          .borderRadius(14)

          Column({ space: 3 }) {
            Text(`RAISA 受理回执 // ${this.viewModel.lastResult!.ticket.ticketCode}`)
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.greenAccent())
            Text(this.viewModel.lastResult!.ticket.summary)
              .fontSize(AppTypography.SUBTITLE_M)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          Text(findRaisaFeedbackCategoryDescriptor(this.viewModel.lastResult!.ticket.category).title)
            .fontSize(AppTypography.CAPTION_L)
            .fontWeight(FontWeight.Medium)
            .fontColor(badgeInfoForegroundColor())
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(badgeInfoBackgroundColor())
            .borderRadius(8)

          Text(`提交版本 ${this.viewModel.lastResult!.ticket.submittedAppVersion}`)
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_secondary'))
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(8)
        }
        .width('100%')

        if (this.viewModel.lastResult!.deduplicated) {
          Text('检测到同份工单重复提交，已为你关联原有工单回执，未重复建单。')
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
        }

        if (this.viewModel.lastResult!.localSaveWarning.length > 0) {
          Text(this.viewModel.lastResult!.localSaveWarning)
            .fontSize(AppTypography.CAPTION_L)
            .fontColor(this.amberAccent())
            .padding(10)
            .backgroundColor(this.amberSoftBg())
            .borderRadius(10)
            .width('100%')
        }

        Row({ space: 10 }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.rectangle_on_rectangle'))
              .fontSize(14)
              .fontColor([$r('sys.color.font')])
            Text('复制编号')
              .fontSize(AppTypography.BODY_M)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font'))
          }
          .attributeModifier(ROW_PRESS_MODIFIER)
          .animation(pressAnimation())
          .height(40)
          .padding({ left: 14, right: 14 })
          .justifyContent(FlexAlign.Center)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(12)
          .onClick(() => {
            this.onHaptic();
            this.onCopyText(
              this.viewModel.lastResult!.ticket.ticketCode,
              `已复制工单编号 ${this.viewModel.lastResult!.ticket.ticketCode}`
            );
          })

          Row({ space: 6 }) {
            Text('查看公开进展')
              .fontSize(AppTypography.BODY_M)
              .fontWeight(FontWeight.Medium)
              .fontColor(accentPillForegroundColor())
            SymbolGlyph($r('sys.symbol.arrow_up_right'))
              .fontSize(14)
              .fontColor([accentPillForegroundColor()])
          }
          .attributeModifier(ROW_PRESS_MODIFIER)
          .animation(pressAnimation())
          .layoutWeight(1)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(accentPillBackgroundColor())
          .borderRadius(12)
          .onClick(() => {
            this.onHaptic();
            this.onOpenExternalUrl(this.viewModel.lastResult!.ticket.issueUrl);
          })
        }
        .width('100%')

        Row() {
          Text('继续签发新工单')
            .fontSize(AppTypography.BODY_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_emphasize'))
        }
        .attributeModifier(ROW_PRESS_MODIFIER)
        .animation(pressAnimation())
        .width('100%')
        .height(38)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(12)
        .onClick(() => this.resetDraftComposer())
      }
      .id('raisaAcceptanceReceiptCard')
      .width('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
      .border(this.materialEnabled ?
        { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
      .borderRadius(18)
      .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_REGULAR : undefined)
    }
  }

  @Builder
  private articleContextChipBanner() {
    if (this.contextAttached && this.initialContext.hasArticleContext()) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.info_circle_fill'))
          .fontSize(16)
          .fontColor([$r('sys.color.icon_emphasize')])

        Column({ space: 4 }) {
          Text(`关联档案：${this.initialContext.articleTitle.length > 0 ?
            this.initialContext.articleTitle : this.initialContext.articleId}`)
            .fontSize(AppTypography.BODY_S)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row({ space: 6 }) {
            if (this.initialContext.articleId.length > 0) {
              Text(this.initialContext.articleId.toUpperCase())
                .fontSize(AppTypography.CAPTION_M)
                .fontColor($r('sys.color.font_secondary'))
            }
            if (renderModeBadgeText(this.initialContext.renderMode).length > 0) {
              Text(`· ${renderModeBadgeText(this.initialContext.renderMode)}`)
                .fontSize(AppTypography.CAPTION_M)
                .fontColor($r('sys.color.font_secondary'))
            }
            if (this.initialContext.revealHiddenText) {
              Text('· 反白透视开启')
                .fontSize(AppTypography.CAPTION_M)
                .fontColor($r('sys.color.font_emphasize'))
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('移除')
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(10)
          .onClick(() => {
            this.onHaptic();
            this.contextAttached = false;
          })
      }
      .width('100%')
      .padding(12)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(badgeInfoBackgroundColor())
      .borderRadius(12)
    }
  }

  @Builder
  private attachmentsSection() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 2 }) {
          Text('现场截图与附件（选填）')
            .fontSize(AppTypography.BODY_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font'))
          Text(`最多 ${RAISA_MAX_ATTACHMENTS} 个，单文件 ≤ 2 MB（大图自动压缩）`)
            .fontSize(AppTypography.CAPTION_M)
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(`${this.attachments.length}/${RAISA_MAX_ATTACHMENTS}`)
          .fontSize(AppTypography.CAPTION_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(10)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 10 }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.picture_fill'))
            .fontSize(14)
            .fontColor([this.remainingAttachmentSlots() > 0 && !this.pickingAttachments ?
              $r('sys.color.icon_emphasize') : $r('sys.color.font_tertiary')])
          Text('选择图片')
            .fontSize(AppTypography.BODY_S)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.remainingAttachmentSlots() > 0 && !this.pickingAttachments ?
              $r('sys.color.font') : $r('sys.color.font_tertiary'))
        }
        .id('raisaPickImagesButton')
        .attributeModifier(ROW_PRESS_MODIFIER)
        .animation(pressAnimation())
        .layoutWeight(1)
        .height(38)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(10)
        .enabled(this.remainingAttachmentSlots() > 0 && !this.pickingAttachments && this.onPickImages !== undefined)
        .onClick(() => {
          this.pickAttachments(true);
        })

        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.paperclip'))
            .fontSize(14)
            .fontColor([this.remainingAttachmentSlots() > 0 && !this.pickingAttachments ?
              $r('sys.color.icon_emphasize') : $r('sys.color.font_tertiary')])
          Text('选择文件')
            .fontSize(AppTypography.BODY_S)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.remainingAttachmentSlots() > 0 && !this.pickingAttachments ?
              $r('sys.color.font') : $r('sys.color.font_tertiary'))
        }
        .id('raisaPickDocumentsButton')
        .attributeModifier(ROW_PRESS_MODIFIER)
        .animation(pressAnimation())
        .layoutWeight(1)
        .height(38)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(10)
        .enabled(this.remainingAttachmentSlots() > 0 && !this.pickingAttachments && this.onPickDocuments !== undefined)
        .onClick(() => {
          this.pickAttachments(false);
        })
      }
      .width('100%')

      if (this.attachmentNotice.length > 0) {
        Text(this.attachmentNotice)
          .fontSize(AppTypography.CAPTION_L)
          .fontColor(this.amberAccent())
          .width('100%')
      }

      if (this.attachments.length > 0) {
        Column({ space: 8 }) {
          ForEach(this.attachments, (item: RaisaFeedbackAttachment) => {
            RaisaAttachmentItemRow({
              attachment: item,
              onRemove: () => this.removeAttachment(item.id)
            })
          }, (item: RaisaFeedbackAttachment) => item.id)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .borderRadius(12)
  }

  @Builder
  private diagnosticsSection() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text('附带脱敏终端诊断快照')
            .fontSize(AppTypography.BODY_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font'))
          Text('含版本号、视口宽度、系统与关联条目，不含任何个人身份信息')
            .fontSize(AppTypography.CAPTION_M)
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.includeDiagnostics })
          .onChange((isOn: boolean) => {
            this.onHaptic();
            this.includeDiagnostics = isOn;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 6 }) {
        Text(this.diagnosticsExpanded ? '收起诊断字段预览' : '预览将发送的诊断字段')
          .fontSize(AppTypography.CAPTION_L)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_emphasize'))
        SymbolGlyph(this.diagnosticsExpanded ?
          $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
          .fontSize(12)
          .fontColor([$r('sys.color.icon_emphasize')])
      }
      .onClick(() => {
        this.getUIContext().animateTo(AppMotion.microAnimateParam(), (): void => {
          this.diagnosticsExpanded = !this.diagnosticsExpanded;
        });
      })

      if (this.diagnosticsExpanded) {
        Column({ space: 4 }) {
          ForEach(formatRaisaDiagnosticLines(this.effectiveDiagnosticSnapshot()), (line: string) => {
            Text(line)
              .fontSize(AppTypography.CAPTION_L)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
          }, (line: string, index: number) => `${index}:${line}`)
        }
        .width('100%')
        .padding(10)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(10)
      }
    }
    .width('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .borderRadius(12)
  }

  @Builder
  private composerCard() {
    Column({ space: 14 }) {
      this.articleContextChipBanner()

      Column({ space: 8 }) {
        Text('工单分类')
          .fontSize(AppTypography.SUBTITLE_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))

        GridRow({ columns: 2, gutter: { x: 10, y: 10 } }) {
          ForEach(RAISA_FEEDBACK_CATEGORIES, (item: RaisaFeedbackCategoryDescriptor) => {
            GridCol({ span: 1 }) {
              RaisaCategoryTile({
                descriptor: item,
                selected: this.selectedCategory === item.category,
                materialEnabled: this.materialEnabled,
                onSelect: () => {
                  this.onHaptic();
                  this.selectedCategory = item.category;
                }
              })
            }
          }, (item: RaisaFeedbackCategoryDescriptor) => item.category)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Row() {
          Text('工单简述')
            .fontSize(AppTypography.BODY_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font'))
          Blank()
          Text(`${this.summary.trim().length}/${RAISA_SUMMARY_MAX_LENGTH}`)
            .fontSize(AppTypography.CAPTION_M)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')

        TextInput({
          text: this.summary,
          placeholder: this.currentCategoryDescriptor().summaryPlaceholder
        })
          .id('raisaSummaryInput')
          .maxLength(RAISA_SUMMARY_MAX_LENGTH)
          .fontSize(AppTypography.BODY_M)
          .fontColor($r('sys.color.font'))
          .placeholderColor($r('sys.color.font_tertiary'))
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .height(44)
          .width('100%')
          .onChange((value: string) => {
            this.summary = value;
            if (this.viewModel.submitError.length > 0) {
              this.viewModel.clearSubmitError();
            }
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Row() {
          Text('详细说明与复现路径')
            .fontSize(AppTypography.BODY_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font'))
          Blank()
          Text(`${this.details.trim().length}/${RAISA_DETAILS_MAX_LENGTH}`)
            .fontSize(AppTypography.CAPTION_M)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')

        TextArea({
          text: this.details,
          placeholder: '请描述具体现象、涉及条目（如有）以及触发步骤，便于尽快定位修复…'
        })
          .id('raisaDetailsInput')
          .maxLength(RAISA_DETAILS_MAX_LENGTH)
          .fontSize(AppTypography.BODY_M)
          .fontColor($r('sys.color.font'))
          .placeholderColor($r('sys.color.font_tertiary'))
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(12)
          .padding(12)
          .height(128)
          .width('100%')
          .onChange((value: string) => {
            this.details = value;
            if (this.viewModel.submitError.length > 0) {
              this.viewModel.clearSubmitError();
            }
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text('联络代号（选填，不收集隐私标识）')
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font'))
        TextInput({
          text: this.contact,
          placeholder: 'GitHub @用户名或常用昵称，方便后续定位回复'
        })
          .id('raisaContactInput')
          .maxLength(RAISA_CONTACT_MAX_LENGTH)
          .fontSize(AppTypography.BODY_M)
          .fontColor($r('sys.color.font'))
          .placeholderColor($r('sys.color.font_tertiary'))
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .height(42)
          .width('100%')
          .onChange((value: string) => {
            this.contact = value;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      this.attachmentsSection()

      this.diagnosticsSection()

      if (!this.viewModel.isRelayConfigured()) {
        Column({ space: 8 }) {
          Text('中转服务端域名尚未绑定到客户端')
            .fontSize(AppTypography.BODY_S)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.amberAccent())
          Text('按仓库 tools/raisa-relay/README.md 部署海外中转服务并填入域名后即可一键直发；在此期间你可以一键复制标准工单报文前往 GitHub Issues 提交。')
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_secondary'))

          Row({ space: 8 }) {
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.rectangle_on_rectangle'))
                .fontSize(13)
                .fontColor([$r('sys.color.font')])
              Text('复制工单报文')
                .fontSize(AppTypography.CAPTION_L)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font'))
            }
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(10)
            .onClick(() => this.copyPlainReport('已复制完整 RAISA 工单报文'))

            Row({ space: 4 }) {
              Text('前往 GitHub Issues')
                .fontSize(AppTypography.CAPTION_L)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_emphasize'))
              SymbolGlyph($r('sys.symbol.arrow_up_right'))
                .fontSize(13)
                .fontColor([$r('sys.color.icon_emphasize')])
            }
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(10)
            .onClick(() => {
              this.onHaptic();
              this.onOpenExternalUrl(RAISA_GITHUB_ISSUES_URL);
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding(12)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(this.amberSoftBg())
        .borderRadius(12)
      }

      if (this.viewModel.submitError.length > 0) {
        Column({ space: 8 }) {
          Text(this.viewModel.submitError)
            .fontSize(AppTypography.CAPTION_L)
            .fontColor(this.dangerAccent())
            .width('100%')

          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.rectangle_on_rectangle'))
              .fontSize(12)
              .fontColor([$r('sys.color.font')])
            Text('复制当前报文兜底')
              .fontSize(AppTypography.CAPTION_L)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font'))
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(10)
          .onClick(() => this.copyPlainReport('已复制工单报文到剪贴板'))
        }
        .width('100%')
        .padding(12)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(this.dangerSoftBg())
        .borderRadius(12)
      }

      Row({ space: 8 }) {
        if (this.viewModel.submitting) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(accentPillForegroundColor())
        } else {
          SymbolGlyph($r('sys.symbol.paperplane_fill'))
            .fontSize(15)
            .fontColor([this.viewModel.isRelayConfigured() ?
              accentPillForegroundColor() : $r('sys.color.font_tertiary')])
        }
        Text(this.viewModel.submitting ? '正在签发工单…' : '签发 RAISA 工单')
          .fontSize(AppTypography.BODY_L)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.viewModel.isRelayConfigured() ?
            accentPillForegroundColor() : $r('sys.color.font_tertiary'))
      }
      .id('raisaSubmitButton')
      .attributeModifier(ROW_PRESS_MODIFIER)
      .animation(pressAnimation())
      .width('100%')
      .height(46)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.viewModel.isRelayConfigured() ?
        accentPillBackgroundColor() : $r('sys.color.comp_background_tertiary'))
      .borderRadius(14)
      .enabled(!this.viewModel.submitting && this.viewModel.isRelayConfigured())
      .onClick(() => {
        this.handleSubmit();
      })
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
  private ticketHistorySection() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.clock'))
          .fontSize(16)
          .fontColor([$r('sys.color.icon_secondary')])
        Text('近期已提交工单')
          .fontSize(AppTypography.TITLE_S)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
        Text(`${this.viewModel.tickets.length}`)
          .fontSize(AppTypography.CAPTION_M)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(10)
        Blank()
        if (this.viewModel.loadError.length > 0) {
          Text('重试加载')
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_emphasize'))
            .onClick(() => {
              this.viewModel.reload().catch((): void => {});
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.viewModel.loadError.length > 0 && this.viewModel.tickets.length === 0) {
        Text(this.viewModel.loadError)
          .fontSize(AppTypography.CAPTION_L)
          .fontColor(this.dangerAccent())
          .padding(12)
          .backgroundColor(this.dangerSoftBg())
          .borderRadius(12)
          .width('100%')
      } else if (this.viewModel.tickets.length === 0) {
        Column({ space: 6 }) {
          Text('本地尚无已签发的工单回执')
            .fontSize(AppTypography.BODY_M)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font'))
          Text('提交后的工单编号、提交时应用版本及 Issue 追踪链接会持久保存于此。')
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .padding(14)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(materialCardSurfaceColor(this.materialEnabled))
        .border(this.materialEnabled ?
          { width: 0.5, color: materialCardBorderColor(true) } : { width: 0 })
        .borderRadius(16)
      } else {
        Column({ space: 10 }) {
          ForEach(this.viewModel.tickets, (ticket: RaisaFeedbackTicket) => {
            RaisaTicketHistoryRow({
              ticket: ticket,
              materialEnabled: this.materialEnabled,
              onCopyCode: () => {
                this.onHaptic();
                this.onCopyText(ticket.ticketCode, `已复制工单编号 ${ticket.ticketCode}`);
              },
              onOpenIssue: () => {
                this.onHaptic();
                this.onOpenExternalUrl(ticket.issueUrl);
              }
            })
          }, (ticket: RaisaFeedbackTicket) => `${ticket.ticketId}:${ticket.submittedAt}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 18 }) {
        this.dispatchHeaderBanner()

        if (this.viewModel.lastResult !== undefined && !this.composerVisible) {
          this.acceptanceReceiptCard()
        } else {
          this.composerCard()
        }

        this.ticketHistorySection()

        Blank()
          .width('100%')
          .height(64)
      }
      .width('100%')
      .constraintSize({ maxWidth: READING_CONTENT_MAX_WIDTH })
      .padding({
        left: this.horizontalMargin,
        right: this.horizontalMargin,
        top: pageContentTop() + 10,
        bottom: 24
      })
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width = Number(newArea.width);
      if (Number.isFinite(width) && width > 0) {
        this.horizontalMargin = adaptivePageMarginForWidth(width);
      }
    })
  }
}
