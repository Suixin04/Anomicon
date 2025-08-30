import vibrator from '@ohos.vibrator';

/**
 * 振动工具类 - 提供各种振动反馈功能
 * 支持轻触反馈、成功反馈、警告反馈等多种振动模式
 */
export class VibrationUtils {
  /**
   * 轻触振动 - 用于按钮点击、tab切换等轻量交互
   * 持续时间短，强度较轻
   */
  static async lightTap(): Promise<void> {
    try {
      await vibrator.startVibration({
        type: 'time',
        duration: 15
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (error) {
      console.error('轻触振动失败:', error);
    }
  }

  /**
   * 中等强度振动 - 用于下拉刷新、重要操作确认
   * 持续时间适中，强度中等
   */
  static async mediumTap(): Promise<void> {
    try {
      await vibrator.startVibration({
        type: 'time',
        duration: 30
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (error) {
      console.error('中等振动失败:', error);
    }
  }

  /**
   * 成功反馈振动 - 用于操作成功提示
   * 双重短振动，表示成功完成
   */
  static async successFeedback(): Promise<void> {
    try {
      // 第一次短振动
      await vibrator.startVibration({
        type: 'time',
        duration: 20
      }, {
        id: 0,
        usage: 'notification'
      });

      // 短暂停顿
      await new Promise<void>(resolve => setTimeout(resolve, 50));

      // 第二次短振动
      await vibrator.startVibration({
        type: 'time',
        duration: 20
      }, {
        id: 0,
        usage: 'notification'
      });
    } catch (error) {
      console.error('成功反馈振动失败:', error);
    }
  }

  /**
   * 警告反馈振动 - 用于错误提示、警告信息
   * 较长的单次振动，表示需要注意
   */
  static async warningFeedback(): Promise<void> {
    try {
      await vibrator.startVibration({
        type: 'time',
        duration: 100
      }, {
        id: 0,
        usage: 'alarm'
      });
    } catch (error) {
      console.error('警告反馈振动失败:', error);
    }
  }

  /**
   * 刷新开始振动 - 用于下拉刷新开始时的反馈
   * 轻微的振动提示用户刷新操作已触发
   */
  static async refreshStart(): Promise<void> {
    try {
      await vibrator.startVibration({
        type: 'time',
        duration: 25
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (error) {
      console.error('刷新开始振动失败:', error);
    }
  }

  /**
   * 刷新完成振动 - 用于下拉刷新完成时的反馈
   * 成功完成刷新的确认振动
   */
  static async refreshComplete(): Promise<void> {
    try {
      await vibrator.startVibration({
        type: 'time',
        duration: 40
      }, {
        id: 0,
        usage: 'notification'
      });
    } catch (error) {
      console.error('刷新完成振动失败:', error);
    }
  }

  /**
   * 停止所有振动
   */
  static async stopVibration(): Promise<void> {
    try {
      await vibrator.stopVibration(vibrator.VibratorStopMode.VIBRATOR_STOP_MODE_TIME);
    } catch (error) {
      console.error('停止振动失败:', error);
    }
  }

  /**
   * 检查设备是否支持振动
   * @returns Promise<boolean> 是否支持振动
   */
  static async isSupportEffect(): Promise<boolean> {
    try {
      return await vibrator.isSupportEffect('time');
    } catch (error) {
      console.error('检查振动支持失败:', error);
      return false;
    }
  }
}