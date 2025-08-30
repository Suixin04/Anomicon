import { VibrationUtils } from './VibrationUtils'

export function roll2top(scroller: Scroller) {
  // 双击页面标题滚动到顶部
  scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 500, curve: Curve.EaseInOut } })
  VibrationUtils.lightTap()
}