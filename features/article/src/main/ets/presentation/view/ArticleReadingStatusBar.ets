import { uiMaterial } from '@kit.ArkUI';
import {
  accentPillBackgroundColor,
  accentPillForegroundColor,
  adaptivePageMarginForWidth,
  AppMotion,
  AppTypography,
  pressAnimation,
  READING_CONTENT_MAX_WIDTH,
  windowWidthVp
} from 'anomiconbasic';

/** 文章标题栏下方阅读状态区高度；正文顶部留白必须同步计入。 */
export const ARTICLE_READING_STATUS_HEIGHT: number = 40;

/**
 * 阅读状态只消费已确认状态：圆环表示本文阅读进度，右侧显示账本派生的等级与总经验。
 * 组件本身使用沉浸系统材质；bottomBuilder 只负责把它接入 HDS 标题栏。
 */
@ComponentV2
export struct ArticleReadingStatusBar {
  @Require @Param progress: number;
  @Require @Param level: number;
  @Require @Param experience: number;
  @Require @Param contentReady: boolean;
  @Param compactProfile: boolean = false;
  @Param materialEnabled: boolean = true;
  @Param sidePanelAvailable: boolean = false;
  @Param sidePanelOpen: boolean = false;
  @Param sidePanelLabel: string = '';
  @Param revealHiddenActive: boolean = false;
  @Param webModeActive: boolean = false;
  @Event onToggleSidePanel: () => void = () => {};
  @Event onDisableRevealHidden: () => void = () => {};
  @Event onExitWebMode: () => void = () => {};

  @Local private barContainerWidth: number = 0;

  private readonly material: uiMaterial.ImmersiveMaterial =
    new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      applyShadow: false
    });

  private normalizedProgress(): number {
    if (!Number.isFinite(this.progress)) {
      return 0;
    }
    return Math.max(0, Math.min(100, Math.round(this.progress)));
  }

  private normalizedInteger(value: number, minimum: number = 0): number {
    if (!Number.isFinite(value)) {
      return minimum;
    }
    return Math.max(minimum, Math.floor(value));
  }

  private horizontalMargin(): number {
    const measured = this.barContainerWidth > 0 ? this.barContainerWidth : windowWidthVp();
    return adaptivePageMarginForWidth(measured);
  }

  build() {
    Row() {
      Row({ space: 8 }) {
        if (this.webModeActive) {
          SymbolGlyph($r('sys.symbol.website'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_emphasize')])

          Text('原版网页模式')
            .fontSize(AppTypography.CAPTION_L)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font'))
            .maxLines(1)
        } else {
          Progress({
            value: this.contentReady ? this.normalizedProgress() : 0,
            total: 100,
            type: ProgressType.Ring
          })
            .width(24)
            .height(24)
            .color($r('sys.color.icon_emphasize'))
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .style({
              strokeWidth: 3,
              enableSmoothEffect: true,
              shadow: false
            })

          Text(this.contentReady ? `已读 ${this.normalizedProgress()}%` : '正在准备正文')
            .fontSize(AppTypography.CAPTION_L)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font'))
            .maxLines(1)
        }

        Blank()

        if (this.webModeActive) {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.doc_text'))
              .fontSize(13)
              .fontColor([accentPillForegroundColor()])
            Text('返回原生')
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Medium)
              .fontColor(accentPillForegroundColor())
              .maxLines(1)
          }
          .height(24)
          .padding({ left: 8, right: 8 })
          .borderRadius(12)
          .backgroundColor(accentPillBackgroundColor())
          .transition(AppMotion.fadeTransition(AppMotion.MICRO_DURATION))
          .onClick(() => this.onExitWebMode())
          .accessibilityText('返回原生阅读模式')
        } else if (this.revealHiddenActive) {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.eye'))
              .fontSize(13)
              .fontColor(['#B45309'])
            Text('透视中')
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Medium)
              .fontColor('#B45309')
              .maxLines(1)
          }
          .height(24)
          .padding({ left: 8, right: 8 })
          .borderRadius(12)
          .backgroundColor('#22F59E0B')
          .transition(AppMotion.fadeTransition(AppMotion.MICRO_DURATION))
          .onClick(() => this.onDisableRevealHidden())
          .accessibilityText('关闭反白透视')
        }

        if (this.compactProfile) {
          Text(`Lv.${this.normalizedInteger(this.level, 1)} · ${this.normalizedInteger(this.experience)} XP`)
            .fontSize(AppTypography.CAPTION_M)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
        } else {
          Text(`Lv.${this.normalizedInteger(this.level, 1)}`)
            .fontSize(AppTypography.CAPTION_L)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_emphasize'))
            .maxLines(1)

          Text(`${this.normalizedInteger(this.experience)} XP`)
            .fontSize(AppTypography.CAPTION_L)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
        }

        if (this.sidePanelAvailable && !this.webModeActive) {
          Divider()
            .vertical(true)
            .height(14)
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))
            .margin({ left: 2, right: 2 })

          Row({ space: 4 }) {
            SymbolGlyph(this.sidePanelOpen ? $r('sys.symbol.close_sidebar') : $r('sys.symbol.open_sidebar'))
              .fontSize(14)
              .fontColor([this.sidePanelOpen ? accentPillForegroundColor() : $r('sys.color.icon_emphasize')])
            Text(this.sidePanelLabel.length > 0 ? this.sidePanelLabel : '研读')
              .fontSize(AppTypography.CAPTION_M)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.sidePanelOpen ? accentPillForegroundColor() : $r('sys.color.font_emphasize'))
              .maxLines(1)
          }
          .height(24)
          .padding({ left: 8, right: 8 })
          .borderRadius(12)
          .backgroundColor(this.sidePanelOpen ?
            accentPillBackgroundColor() : $r('sys.color.comp_background_tertiary'))
          .animation(pressAnimation())
          .onClick(() => this.onToggleSidePanel())
          .accessibilityText(this.sidePanelOpen ? '收起研读侧栏' : '展开研读侧栏')
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: READING_CONTENT_MAX_WIDTH })
      .height(32)
      .padding({ left: 12, right: (this.sidePanelAvailable && !this.webModeActive) ? 4 : 12 })
      .borderRadius(16)
      .backgroundColor(this.materialEnabled ?
        Color.Transparent : $r('sys.color.comp_background_primary'))
      .systemMaterial(this.materialEnabled ? this.material : undefined)
      .accessibilityText(
        this.webModeActive ?
          `正在浏览原版网页模式，等级${this.normalizedInteger(this.level, 1)}，` +
            `总经验${this.normalizedInteger(this.experience)}` :
          (this.contentReady ?
            `本文已读${this.normalizedProgress()}%，等级${this.normalizedInteger(this.level, 1)}，` +
              `总经验${this.normalizedInteger(this.experience)}` :
            '正在准备正文阅读状态')
      )
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .height(ARTICLE_READING_STATUS_HEIGHT)
    .padding({
      left: this.horizontalMargin(),
      right: this.horizontalMargin(),
      bottom: 8
    })
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const measured = Number(newArea.width);
      if (Number.isFinite(measured) && measured > 0) {
        this.barContainerWidth = measured;
      }
    })
  }
}
