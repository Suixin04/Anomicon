import { pasteboard } from '@kit.BasicServicesKit';
import { ClipboardPort } from './PlatformPorts';

/** HarmonyOS system pasteboard adapter. */
export class ClipboardAdapter implements ClipboardPort {
  async copyText(text: string): Promise<void> {
    const normalized = text.trim();
    if (normalized.length === 0) {
      throw new Error('没有可复制的内容');
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, normalized);
      await pasteboard.getSystemPasteboard().setData(data);
    } catch (_error) {
      throw new Error('写入系统剪贴板失败');
    }
  }
}
