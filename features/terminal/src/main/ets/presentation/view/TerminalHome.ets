import { ResearchProfileCard } from './ResearchProfileCard';
import {
  TerminalErrorState,
  TerminalFavoriteCards,
  TerminalLibrarySectionTitle,
  TerminalReadingHistoryList
} from './TerminalLibraryComponents';
import {
  FOUNDATION_KNOWLEDGE_SECTIONS,
  FoundationKnowledgeIcon,
  FoundationKnowledgeItem,
  FoundationKnowledgeSection
} from '../model/FoundationKnowledge';
import { LibraryContentRef, LibraryFavorite } from 'library';
import { ReadingHistoryEntry } from 'library';
import { ResearchProgress } from 'library';
import { LibraryCollectionMode } from 'library';
import { pageContentTop, PHONE_PAGE_MARGIN, PHONE_TAB_CONTENT_MAX_WIDTH } from 'anomiconbasic';
import { AppTypography } from 'anomiconbasic';
import { TerminalViewModel } from '../viewmodel/TerminalViewModel';
import { SettingsViewModel } from 'settings';

const SECTION_SPACE: number = 28;
const TERMINAL_TWO_COLUMN_MIN_WIDTH: number = 840;
const TERMINAL_WIDE_CONTENT_MAX_WIDTH: number = 1120;

/**
 * 终端首页：档案阅历、个人资料库与基金会手册。
 *
 * 页面只消费应用级共享状态，不直接访问数据库；收藏与历史写入成功后，
 * ViewModel 会整体替换数组，此处以稳定的 content.key 更新有限预览。
 */
@ComponentV2
export struct TerminalHome {
  @Require @Param scroller: Scroller;
  @Require @Param active: boolean;
  @Require @Param onOpenContent: (content: LibraryContentRef) => void;
  @Require @Param onOpenCollection: (mode: LibraryCollectionMode) => void;
  @Require @Param viewModel: TerminalViewModel;
  @Require @Param settings: SettingsViewModel;
  @Local private sideBySide: boolean = false;

  private isImmersiveMaterialEnabled(): boolean {
    return this.settings.immersiveMaterialEnabled;
  }

  aboutToAppear(): void {
    // TabContent can be mounted before it becomes the selected tab.  Do not
    // start title enrichment or shared-state subscriptions for a hidden tab;
    // the active monitor will activate the VM when it is actually visible.
    if (this.active) {
      this.viewModel.activate();
    }
  }

  aboutToDisappear(): void {
    this.viewModel.deactivate();
  }

  @Monitor('active')
  onActiveChange(): void {
    if (this.active) {
      this.viewModel.activate();
    } else {
      this.viewModel.deactivate();
    }
  }

  @Computed
  get favoriteEntries(): LibraryFavorite[] {
    return this.viewModel.favoriteEntries;
  }

  /** 继续阅读是最近浏览的快捷入口，只提升最近一条，避免形成重复列表。 */
  @Computed
  get resumeEntries(): ReadingHistoryEntry[] {
    return this.viewModel.resumeEntries;
  }

  /** 最近预览排除已经提升到“继续上次阅读”的条目，同一内容不重复出现。 */
  @Computed
  get recentEntries(): ReadingHistoryEntry[] {
    return this.viewModel.recentEntries;
  }

  @Computed
  get recentCount(): number {
    return this.viewModel.recentCount;
  }

  @Computed
  get favoriteCount(): number {
    return this.viewModel.favoriteCount;
  }

  @Computed
  get favoriteLoading(): boolean {
    return this.viewModel.favoriteLoading;
  }

  @Computed
  get favoriteError(): string {
    return this.viewModel.favoriteError;
  }

  @Computed
  get favoriteReady(): boolean {
    return this.viewModel.favoriteInitialized;
  }

  @Computed
  get historyCount(): number {
    return this.viewModel.historyCount;
  }

  @Computed
  get historyLoading(): boolean {
    return this.viewModel.historyLoading;
  }

  @Computed
  get historyError(): string {
    return this.viewModel.historyError;
  }

  @Computed
  get historyReady(): boolean {
    return this.viewModel.historyInitialized;
  }

  @Computed
  get researchSnapshot(): ResearchProgress {
    return this.viewModel.profile;
  }

  @Computed
  get researchLoading(): boolean {
    return this.viewModel.researchLoading;
  }

  @Computed
  get researchError(): string {
    return this.viewModel.researchError;
  }

  @Computed
  get researchReady(): boolean {
    return this.viewModel.researchInitialized;
  }

  private knowledgeIcon(icon: FoundationKnowledgeIcon): Resource {
    switch (icon) {
      case FoundationKnowledgeIcon.CLASSIFICATION:
        return $r('sys.symbol.list_book_fill');
      case FoundationKnowledgeIcon.CLEARANCE:
        return $r('sys.symbol.lock_fill');
      case FoundationKnowledgeIcon.TASK_FORCE:
        return $r('sys.symbol.person_2_badge_flag_fill');
      case FoundationKnowledgeIcon.DEPARTMENT:
        return $r('sys.symbol.building_fill');
      case FoundationKnowledgeIcon.FACILITY:
        return $r('sys.symbol.building');
      case FoundationKnowledgeIcon.GROUP:
        return $r('sys.symbol.person_2');
      case FoundationKnowledgeIcon.HISTORY:
        return $r('sys.symbol.clock_fill');
      default:
        return $r('sys.symbol.company_fill');
    }
  }

  private retryFavorites(): void {
    this.viewModel.refreshFavorites();
  }

  private retryHistory(): void {
    this.viewModel.refreshHistory();
  }

  private retryResearch(): void {
    this.viewModel.refreshResearch();
  }

  private researchProgressPercent(): number {
    const target = this.researchSnapshot.levelExperienceTarget;
    if (target <= 0) {
      return 100;
    }
    return Math.max(0, Math.min(100,
      this.researchSnapshot.levelExperience / target * 100
    ));
  }

  @Builder
  private sectionHeader(title: string, subtitle: string) {
    Column({ space: 3 }) {
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
  private emptyState(symbol: Resource, title: string, description: string) {
    Column({ space: 8 }) {
      SymbolGlyph(symbol)
        .fontSize(28)
        .fontColor([$r('sys.color.icon_tertiary')])
      Text(title)
        .fontSize(AppTypography.BODY_M)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font'))
      Text(description)
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .lineHeightMultiple(AppTypography.UI_PARAGRAPH_LINE_HEIGHT)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 26, bottom: 26 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
  }

  @Builder
  private loadingState(label: string) {
    Row({ space: 10 }) {
      LoadingProgress()
        .width(20)
        .height(20)
        .color($r('sys.color.icon_secondary'))
      Text(label)
        .fontSize(AppTypography.BODY_M)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height(92)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
  }

  @Builder
  private partialError(message: string, onRetry: () => void) {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(16)
        .fontColor([$r('sys.color.icon_secondary')])
      Text(message)
        .fontSize(AppTypography.CAPTION_L)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text('重试')
        .fontSize(AppTypography.CAPTION_L)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_emphasize'))
        .onClick(() => onRetry())
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(12)
  }

  @Builder
  private favoritesPreview() {
    Column({ space: 12 }) {
      Column() {
        TerminalLibrarySectionTitle({
          symbol: $r('sys.symbol.star_fill'),
          title: '收藏',
          count: this.favoriteCount,
          showMore: this.favoriteCount > 5,
          onOpen: () => this.onOpenCollection(LibraryCollectionMode.FAVORITES)
        })
      }
      .width('100%')
      .padding({ left: PHONE_PAGE_MARGIN, right: PHONE_PAGE_MARGIN })

      if (this.favoriteLoading && this.favoriteCount === 0) {
        Column() {
          this.loadingState('正在读取收藏…')
        }
        .width('100%')
        .padding({ left: PHONE_PAGE_MARGIN, right: PHONE_PAGE_MARGIN })
      } else if (this.favoriteError.length > 0 && this.favoriteCount === 0) {
        Column() {
          TerminalErrorState({
            message: this.favoriteError,
            onRetry: () => this.retryFavorites()
          })
        }
        .width('100%')
        .padding({ left: PHONE_PAGE_MARGIN, right: PHONE_PAGE_MARGIN })
      } else if (this.favoriteCount === 0) {
        Column() {
          this.emptyState(
            $r('sys.symbol.star'),
            '还没有收藏',
            '阅读档案或故事时，可通过右上角菜单加入收藏。'
          )
        }
        .width('100%')
        .padding({ left: PHONE_PAGE_MARGIN, right: PHONE_PAGE_MARGIN })
      } else {
        Column({ space: 8 }) {
          Scroll() {
            TerminalFavoriteCards({
              entries: this.favoriteEntries,
              materialEnabled: this.isImmersiveMaterialEnabled(),
              onOpenContent: (content: LibraryContentRef) => this.onOpenContent(content)
            })
          }
          .width('100%')
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(this.sideBySide ? BarState.Auto : BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          if (this.favoriteError.length > 0) {
            this.partialError(this.favoriteError, () => this.retryFavorites())
          }
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private readingHistoryPreview() {
    Column({ space: 16 }) {
      if (this.historyLoading && this.historyCount === 0) {
        this.loadingState('正在读取阅读记录…')
      } else if (this.historyError.length > 0 && this.historyCount === 0) {
        TerminalErrorState({
          message: this.historyError,
          onRetry: () => this.retryHistory()
        })
      } else {
        if (this.resumeEntries.length > 0) {
          TerminalReadingHistoryList({
            entries: this.resumeEntries,
            continueReading: true,
            materialEnabled: this.isImmersiveMaterialEnabled(),
            onOpenContent: (content: LibraryContentRef) => this.onOpenContent(content)
          })
        }

        if (this.historyCount === 0 || this.recentCount > 0) {
          Column({ space: 12 }) {
            TerminalLibrarySectionTitle({
              symbol: $r('sys.symbol.clock_fill'),
              title: '最近浏览',
              count: this.recentCount,
              showMore: this.recentCount > 4,
              onOpen: () => this.onOpenCollection(LibraryCollectionMode.RECENT)
            })
            if (this.historyCount === 0) {
              this.emptyState(
                $r('sys.symbol.clock'),
                '暂无阅读记录',
                '打开任意档案、故事或手册后，最近浏览会显示在这里。'
              )
            } else {
              TerminalReadingHistoryList({
                entries: this.recentEntries,
                continueReading: false,
                materialEnabled: this.isImmersiveMaterialEnabled(),
                onOpenContent: (content: LibraryContentRef) => this.onOpenContent(content)
              })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        if (this.historyError.length > 0) {
          this.partialError(this.historyError, () => this.retryHistory())
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private personalLibrary() {
    Column({ space: 20 }) {
      Column() {
        this.sectionHeader('个人资料库', '收藏、阅读进度与近期访问都保存在本地')
      }
      .width('100%')
      .padding({ left: PHONE_PAGE_MARGIN, right: PHONE_PAGE_MARGIN })

      this.favoritesPreview()

      Column() {
        this.readingHistoryPreview()
      }
      .width('100%')
      .padding({ left: PHONE_PAGE_MARGIN, right: PHONE_PAGE_MARGIN })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private knowledgeRow(item: FoundationKnowledgeItem) {
    Row({ space: 12 }) {
      Column() {
        SymbolGlyph(this.knowledgeIcon(item.icon))
          .fontSize(21)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .width(42)
      .height(42)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(13)

      Column({ space: 3 }) {
        Text(item.title)
          .fontSize(AppTypography.BODY_M)
          .fontWeight(FontWeight.Medium)
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

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([$r('sys.color.icon_secondary')])
    }
    .width('100%')
    .constraintSize({ minHeight: 70 })
    .alignItems(VerticalAlign.Center)
    .padding({ left: 14, right: 14, top: 11, bottom: 11 })
    .onClick(() => this.onOpenContent(item.content))
    .accessibilityText(`打开基金会手册，${item.title}`)
  }

  @Builder
  private knowledgeGroup(section: FoundationKnowledgeSection) {
    Column({ space: 10 }) {
      Column({ space: 2 }) {
        Text(section.title)
          .fontSize(AppTypography.SUBTITLE_M)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font'))
        Text(section.subtitle)
          .fontSize(AppTypography.CAPTION_M)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column() {
        ForEach(section.items, (item: FoundationKnowledgeItem, index: number) => {
          Column() {
            this.knowledgeRow(item)
            if (index < section.items.length - 1) {
              Divider()
                .strokeWidth(0.5)
                .color($r('sys.color.comp_divider'))
                .margin({ left: 68, right: 14 })
            }
          }
          .width('100%')
        }, (item: FoundationKnowledgeItem) => item.key)
      }
      .width('100%')
      .backgroundColor(this.isImmersiveMaterialEnabled() ?
        Color.Transparent : $r('sys.color.comp_background_primary'))
      .borderRadius(18)
      .clip(true)
      .backgroundBlurStyle(this.isImmersiveMaterialEnabled() ? BlurStyle.COMPONENT_REGULAR : undefined)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private foundationManual() {
    Column({ space: 18 }) {
      this.sectionHeader('基金会手册', '从基本设定、制度与组织开始认识基金会')
      ForEach(FOUNDATION_KNOWLEDGE_SECTIONS, (section: FoundationKnowledgeSection) => {
        this.knowledgeGroup(section)
      }, (section: FoundationKnowledgeSection) => section.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: SECTION_SPACE }) {
        Column() {
          ResearchProfileCard({
            level: this.researchSnapshot.level,
            title: this.researchSnapshot.rankTitle,
            experience: this.researchSnapshot.experience,
            currentLevelXp: this.researchSnapshot.levelThreshold,
            nextLevelXp: this.researchSnapshot.nextLevelThreshold,
            progressPercent: this.researchProgressPercent(),
            effectiveActiveMs: this.researchSnapshot.creditedActiveMs,
            studiedCount: this.researchSnapshot.researchedContentCount,
            favoriteCount: this.favoriteCount,
            historyCount: this.historyCount,
            favoriteReady: this.favoriteReady,
            historyReady: this.historyReady,
            loading: this.researchLoading ||
              (this.viewModel.loading && !this.researchReady && this.researchError.trim().length === 0),
            error: !this.researchReady && !this.researchLoading ? this.researchError : '',
            notice: this.researchReady ? this.researchError : '',
            materialEnabled: this.isImmersiveMaterialEnabled(),
            onRetry: () => this.retryResearch()
          })
        }
        .width('100%')
        .padding({ left: PHONE_PAGE_MARGIN, right: PHONE_PAGE_MARGIN })

        Flex({ direction: this.sideBySide ? FlexDirection.Row : FlexDirection.Column, alignItems: ItemAlign.Start }) {
          Column() {
            this.personalLibrary()
          }
          .width(this.sideBySide ? '56%' : '100%')
          .margin({ bottom: this.sideBySide ? 0 : SECTION_SPACE })

          Column() {
            this.foundationManual()
          }
          .width(this.sideBySide ? '44%' : '100%')
          .padding({ left: this.sideBySide ? SECTION_SPACE : PHONE_PAGE_MARGIN, right: PHONE_PAGE_MARGIN })
        }
        .width('100%')

        Blank()
          .width('100%')
          .height(136)
      }
      .width('100%')
      .constraintSize({ maxWidth: this.sideBySide ? TERMINAL_WIDE_CONTENT_MAX_WIDTH : PHONE_TAB_CONTENT_MAX_WIDTH })
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
      if (viewportWidth > 0) {
        this.sideBySide = viewportWidth >= TERMINAL_TWO_COLUMN_MIN_WIDTH;
      }
    })
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
