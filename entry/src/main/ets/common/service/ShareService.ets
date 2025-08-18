/*
 * 分享服务类
 * 基于HarmonyOS ShareKit实现内容分享功能
 */

import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { SCP, Tale } from '../../utils/types';

export interface ShareOptions {
  title?: string;
  description?: string;
  content?: string;
  uri?: string;
  thumbnail?: Uint8Array;
}

export class ShareService {
  private static instance: ShareService;

  private constructor() {}

  public static getInstance(): ShareService {
    if (!ShareService.instance) {
      ShareService.instance = new ShareService();
    }
    return ShareService.instance;
  }

  /**
   * 分享文本内容
   * @param context UIAbility上下文
   * @param options 分享选项
   */
  public shareText(context: common.UIAbilityContext, options: ShareOptions): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        // 构造分享数据
        const shareData: systemShare.SharedData = new systemShare.SharedData({
          utd: utd.UniformDataType.PLAIN_TEXT,
          content: options.content || '',
          title: options.title || '分享内容',
          description: options.description || '',
          thumbnail: options.thumbnail
        });

        // 创建分享控制器
        const controller: systemShare.ShareController = new systemShare.ShareController(shareData);

        // 注册分享面板关闭监听
        controller.on('dismiss', () => {
          console.info('ShareService: Share panel closed');
          resolve();
        });

        // 显示分享面板
        controller.show(context, {
          selectionMode: systemShare.SelectionMode.SINGLE,
          previewMode: systemShare.SharePreviewMode.DEFAULT
        }).then(() => {
          console.info('ShareService: Share panel opened successfully');
        }).catch((error: BusinessError) => {
          console.error(`ShareService: Failed to open share panel. code: ${error.code}, message: ${error.message}`);
          this.showErrorToast('分享失败，请重试');
          reject(error);
        });
      } catch (error) {
        console.error('ShareService: Error in shareText:', error);
        this.showErrorToast('分享失败');
        reject(error);
      }
    });
  }

  /**
   * 分享超链接
   * @param context UIAbility上下文
   * @param options 分享选项
   */
  public shareLink(context: common.UIAbilityContext, options: ShareOptions): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        // 构造分享数据
        const shareData: systemShare.SharedData = new systemShare.SharedData({
          utd: utd.UniformDataType.HYPERLINK,
          content: options.content || '',
          title: options.title || '分享链接',
          description: options.description || '',
          thumbnail: options.thumbnail
        });

        // 创建分享控制器
        const controller: systemShare.ShareController = new systemShare.ShareController(shareData);

        // 注册分享面板关闭监听
        controller.on('dismiss', () => {
          console.info('ShareService: Share panel closed');
          resolve();
        });

        // 显示分享面板
        controller.show(context, {
          selectionMode: systemShare.SelectionMode.SINGLE,
          previewMode: systemShare.SharePreviewMode.DETAIL
        }).then(() => {
          console.info('ShareService: Share panel opened successfully');
        }).catch((error: BusinessError) => {
          console.error(`ShareService: Failed to open share panel. code: ${error.code}, message: ${error.message}`);
          this.showErrorToast('分享失败，请重试');
          reject(error);
        });
      } catch (error) {
        console.error('ShareService: Error in shareLink:', error);
        this.showErrorToast('分享失败');
        reject(error);
      }
    });
  }

  /**
   * 分享SCP项目内容
   * @param context UIAbility上下文
   * @param scpItem SCP项目数据
   */
  public shareSCP(context: common.UIAbilityContext, scpItem: SCP): Promise<void> {
    const shareContent = `SCP-${scpItem.id}: ${scpItem.title}\n\n${scpItem.description || ''}\n\n来自Anomicon应用`;
    
    return this.shareText(context, {
      title: `SCP-${scpItem.id}: ${scpItem.title}`,
      description: 'SCP基金会项目分享',
      content: shareContent
    });
  }

  /**
   * 分享Tale故事内容
   * @param context UIAbility上下文
   * @param tale Tale故事数据
   */
  public shareTale(context: common.UIAbilityContext, tale: Tale): Promise<void> {
    const shareContent = `${tale.title}\n\n${tale.content || ''}\n\n来自Anomicon应用`;
    
    return this.shareText(context, {
      title: tale.title,
      description: 'SCP基金会故事分享',
      content: shareContent
    });
  }

  /**
   * 显示错误提示
   * @param message 错误信息
   */
  private showErrorToast(message: string): void {
    try {
      promptAction.showToast({
        message: message,
        duration: 2000
      });
    } catch (error) {
      console.error('ShareService: Failed to show toast:', error);
    }
  }

  /**
   * 检查分享功能是否可用
   * @returns 是否支持分享
   */
  public isShareSupported(): boolean {
    try {
      // 简单检查ShareKit是否可用
      return true; // ShareKit在HarmonyOS中默认可用
    } catch (error) {
      console.error('ShareService: Share not supported:', error);
      return false;
    }
  }
}

// 导出单例实例
export default ShareService.getInstance();