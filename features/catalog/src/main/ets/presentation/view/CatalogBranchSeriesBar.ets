import { uiMaterial } from '@kit.ArkUI';
import {
  accentPillBackgroundColor,
  accentPillForegroundColor,
  AppTypography,
  PHONE_PAGE_MARGIN,
  WIDE_CONTENT_MAX_WIDTH
} from 'anomiconbasic';
import { ScpCatalogBranch } from '../../domain/ScpSeriesItem';
import { CatalogSeriesSelector } from './CatalogSeriesSelector';

/**
 * 图鉴 Tab 顶部两段式导航条：上行切换「主站译文 / 中文原创」，
 * 下行展示对应分支的系列 chips（I–X 或 CN-I–CN-V）。
 */
@ComponentV2
export struct CatalogBranchSeriesBar {
  @Require @Param branch: ScpCatalogBranch;
  @Require @Param selectedSeriesId: string;
  @Param materialEnabled: boolean = true;
  @Param horizontalMargin: number = PHONE_PAGE_MARGIN;
  @Event onSelectBranch: (branch: ScpCatalogBranch) => void = (_branch: ScpCatalogBranch): void => {};
  @Event onSelectSeries: (seriesId: string) => void = (_seriesId: string): void => {};

  private readonly pillMaterial: uiMaterial.ImmersiveMaterial = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN,
    applyShadow: false,
    interactive: true
  });

  private isBranchSelected(target: ScpCatalogBranch): boolean {
    return this.branch === target;
  }

  @Builder
  private branchButton(label: string, target: ScpCatalogBranch) {
    Text(label)
      .fontSize(AppTypography.CAPTION_L)
      .fontWeight(this.isBranchSelected(target) ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.isBranchSelected(target) ?
        accentPillForegroundColor() : $r('sys.color.font_secondary'))
      .textAlign(TextAlign.Center)
      .height(30)
      .padding({ left: 14, right: 14 })
      .borderRadius(15)
      .backgroundColor(this.isBranchSelected(target) ?
        accentPillBackgroundColor() :
        (this.materialEnabled ? Color.Transparent : $r('sys.color.comp_background_tertiary')))
      .systemMaterial(!this.isBranchSelected(target) && this.materialEnabled ?
        this.pillMaterial : undefined)
      .onClick(() => {
        if (this.branch !== target) {
          this.onSelectBranch(target);
        }
      })
  }

  build() {
    Column({ space: 6 }) {
      Column() {
        Row({ space: 8 }) {
          this.branchButton('主站译文', ScpCatalogBranch.MAIN)
          this.branchButton('中文原创', ScpCatalogBranch.CN)
        }
        .width('100%')
        .padding({ left: this.horizontalMargin, right: this.horizontalMargin })
      }
      .width('100%')
      .constraintSize({ maxWidth: WIDE_CONTENT_MAX_WIDTH })
      .alignItems(HorizontalAlign.Center)

      CatalogSeriesSelector({
        selectedSeriesId: this.selectedSeriesId,
        branch: this.branch,
        includeAll: false,
        materialEnabled: this.materialEnabled,
        horizontalMargin: this.horizontalMargin,
        onSelect: (seriesId: string) => {
          this.onSelectSeries(seriesId);
        }
      })
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .alignItems(HorizontalAlign.Center)
  }
}
