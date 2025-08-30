import { VibrationUtils } from 'utils'
import { CustomButtonView } from './CustomButton'

/**
 * 系列选择组件 - 提供SCP系列筛选功能
 * @param selectedSeries 当前选中的系列号
 * @param onSeriesSelect 系列选择回调函数
 */
@ComponentV2
export struct SeriesSelectionView {
  @Param selectedSeries: number = 0
  @Param onSeriesSelect: (series: number) => void = () => {
  }

  build() {
    Scroll() {
      Row({ space: 10 }) {
        Row() {
          CustomButtonView({ text: '全部', isSelected: this.selectedSeries === 0 })
        }
        .onClick(() => {
          VibrationUtils.lightTap()
          this.onSeriesSelect(0)
        })

        ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9], (series: number) => {
          Row() {
            CustomButtonView({ text: `Series ${series}`, isSelected: this.selectedSeries === series })
          }
          .onClick(() => {
            VibrationUtils.lightTap()
            this.onSeriesSelect(series)
          })
        }, (series: number) => series.toString())
      }
      .padding({ left: 25, right: 25 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }
}