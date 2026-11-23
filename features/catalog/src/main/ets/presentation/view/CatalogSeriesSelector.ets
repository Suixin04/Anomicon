import {
  ChipGroupV2,
  ChipGroupV2ItemConfig,
  ChipGroupV2Items,
  ChipGroupV2ItemStyle,
  ChipGroupV2Padding,
  ChipGroupV2Space,
  ChipV2Size,
  uiMaterial
} from '@kit.ArkUI';
import {
  ALL_SERIES_ID,
  ALL_SERIES_LABEL,
  SCP_SERIES,
  ScpSeriesDescriptor
} from '../../domain/ScpSeriesItem';

function createSeriesItems(includeAll: boolean): ChipGroupV2Items {
  const configs: ChipGroupV2ItemConfig[] = [];
  if (includeAll) {
    configs.push({
      label: { text: ALL_SERIES_LABEL },
      accessibilityDescription: '切换检索范围为全部 SCP 系列',
      accessibilityLevel: 'yes'
    });
  }
  SCP_SERIES.forEach((series: ScpSeriesDescriptor): void => {
    configs.push({
      label: { text: series.label },
      accessibilityDescription: `切换图鉴到 SCP 系列 ${series.label}`,
      accessibilityLevel: 'yes'
    });
  });
  return new ChipGroupV2Items(configs);
}

/**
 * API 26 native selector for the SCP series.
 *
 * ChipGroupV2 owns horizontal scrolling, single-selection semantics, state
 * effects, font-scale adaptation and accessibility exposure. Product hosts
 * only receive the selected series identity and keep their own side effects.
 */
@ComponentV2
export struct CatalogSeriesSelector {
  @Require @Param selectedSeriesId: string;
  @Param includeAll: boolean = false;
  @Event onSelect: (seriesId: string) => void = (_seriesId: string): void => {};

  @Local private items: ChipGroupV2Items = createSeriesItems(false);
  private readonly itemSpace: ChipGroupV2Space = new ChipGroupV2Space({
    itemSpace: 8,
    startSpace: 16,
    endSpace: 16
  });
  private readonly verticalPadding: ChipGroupV2Padding = new ChipGroupV2Padding({
    top: 2,
    bottom: 2
  });
  private readonly normalMaterial: uiMaterial.ImmersiveMaterial =
    new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      applyShadow: false,
      interactive: true
    });
  private readonly selectedMaterial: uiMaterial.ImmersiveMaterial =
    new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: false,
      interactive: true
    });
  private readonly itemStyle: ChipGroupV2ItemStyle = new ChipGroupV2ItemStyle({
    // Use the native size enum instead of fixed dimensions so font-scale
    // adaptation remains available while fitting the 48 vp title toolbar.
    size: ChipV2Size.SMALL,
    backgroundSystemMaterial: this.normalMaterial,
    selectedBackgroundSystemMaterial: this.selectedMaterial
  });

  aboutToAppear(): void {
    this.items = createSeriesItems(this.includeAll);
  }

  private selectedIndexes(): number[] {
    if (this.includeAll) {
      if (this.selectedSeriesId === ALL_SERIES_ID) {
        return [0];
      }
      for (let index: number = 0; index < SCP_SERIES.length; index++) {
        if (SCP_SERIES[index].id === this.selectedSeriesId) {
          return [index + 1];
        }
      }
      return [0];
    }
    for (let index: number = 0; index < SCP_SERIES.length; index++) {
      if (SCP_SERIES[index].id === this.selectedSeriesId) {
        return [index];
      }
    }
    return [0];
  }

  private select(indexes: number[]): void {
    if (indexes.length === 0) {
      return;
    }
    const index = indexes[0];
    if (this.includeAll) {
      const maxIndex = SCP_SERIES.length;
      if (index < 0 || index > maxIndex) {
        return;
      }
      const seriesId = index === 0 ? ALL_SERIES_ID : SCP_SERIES[index - 1].id;
      if (seriesId !== this.selectedSeriesId) {
        this.onSelect(seriesId);
      }
      return;
    }
    if (index < 0 || index >= SCP_SERIES.length) {
      return;
    }
    const seriesId = SCP_SERIES[index].id;
    if (seriesId !== this.selectedSeriesId) {
      this.onSelect(seriesId);
    }
  }

  build() {
    ChipGroupV2({
      items: this.items,
      itemStyle: this.itemStyle,
      selectedIndexes: this.selectedIndexes(),
      multiple: false,
      chipGroupSpace: this.itemSpace,
      chipGroupPadding: this.verticalPadding,
      onChange: (indexes: number[]) => this.select(indexes)
    })
  }
}
