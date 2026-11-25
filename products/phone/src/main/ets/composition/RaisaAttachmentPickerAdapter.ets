import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo, picker } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { IdGeneratorPort } from 'anomiconbasic';
import {
  RAISA_MAX_ATTACHMENT_BYTES,
  RAISA_MAX_ATTACHMENTS,
  RaisaAttachmentPickerPort,
  RaisaFeedbackAttachment
} from 'library';

const MAX_IMAGE_SOURCE_READ_BYTES: number = 24 * 1024 * 1024;
const IMAGE_COMPRESSION_THRESHOLD_BYTES: number = 800 * 1024;
const IMAGE_MAX_DIMENSION_PX: number = 1600;
const DOCUMENT_SUFFIX_FILTERS: string[] = [
  '图片 (.png, .jpg, .webp, .gif)|.png,.jpg,.jpeg,.webp,.gif',
  '日志与文档 (.txt, .log, .json, .md, .pdf)|.txt,.log,.json,.md,.pdf'
];

interface NormalizedAttachmentBytes {
  readonly bytes: Uint8Array;
  readonly mimeType: string;
  readonly fileName: string;
  readonly isImage: boolean;
}

function clampSelectCount(maxCount: number): number {
  return Math.max(1, Math.min(RAISA_MAX_ATTACHMENTS, Math.floor(maxCount)));
}

function extractFileNameFromUri(uri: string, fallbackName: string): string {
  const withoutQuery = uri.split('?')[0].split('#')[0];
  const slashIndex = withoutQuery.lastIndexOf('/');
  const tail = slashIndex >= 0 ? withoutQuery.slice(slashIndex + 1) : withoutQuery;
  if (tail.trim().length === 0) {
    return fallbackName;
  }
  try {
    const decoded = decodeURIComponent(tail).trim();
    return decoded.length > 0 ? decoded : fallbackName;
  } catch (_error) {
    return tail.trim();
  }
}

function inferDocumentMimeAndImageFlag(fileName: string): [string, boolean] {
  const lower = fileName.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return ['image/jpeg', true];
  }
  if (lower.endsWith('.png')) {
    return ['image/png', true];
  }
  if (lower.endsWith('.webp')) {
    return ['image/webp', true];
  }
  if (lower.endsWith('.gif')) {
    return ['image/gif', true];
  }
  if (lower.endsWith('.pdf')) {
    return ['application/pdf', false];
  }
  if (lower.endsWith('.json')) {
    return ['application/json', false];
  }
  if (lower.endsWith('.md')) {
    return ['text/markdown', false];
  }
  if (lower.endsWith('.log')) {
    return ['text/plain', false];
  }
  if (lower.endsWith('.txt')) {
    return ['text/plain', false];
  }
  return ['', false];
}

function replaceFileExtension(fileName: string, nextExtension: string): string {
  const dotIndex = fileName.lastIndexOf('.');
  const stem = dotIndex > 0 ? fileName.slice(0, dotIndex) : fileName;
  return `${stem}.${nextExtension}`;
}

/**
 * Product-owned platform adapter bridging HarmonyOS PhotoViewPicker, DocumentViewPicker,
 * ImageKit compression, and Base64 encoding to the device-independent RAISA feedback view.
 */
export class RaisaAttachmentPickerAdapter implements RaisaAttachmentPickerPort {
  private readonly context: common.UIAbilityContext;
  private readonly idGenerator: IdGeneratorPort;
  private readonly base64: util.Base64Helper = new util.Base64Helper();

  constructor(context: common.UIAbilityContext, idGenerator: IdGeneratorPort) {
    this.context = context;
    this.idGenerator = idGenerator;
  }

  async pickImages(maxCount: number): Promise<RaisaFeedbackAttachment[]> {
    const limit = clampSelectCount(maxCount);
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = limit;

    let uris: string[] = [];
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result = await photoPicker.select(options);
      uris = result.photoUris ?? [];
    } catch (error) {
      const detail = error instanceof Error ? error.message : '无法打开系统图库';
      throw new Error(`选择图片失败：${detail}`);
    }

    const attachments: RaisaFeedbackAttachment[] = [];
    for (let index: number = 0; index < uris.length && attachments.length < limit; index++) {
      const uri = uris[index];
      if (uri.trim().length > 0) {
        attachments.push(await this.buildAttachmentFromUri(uri, true));
      }
    }
    return attachments;
  }

  async pickDocuments(maxCount: number): Promise<RaisaFeedbackAttachment[]> {
    const limit = clampSelectCount(maxCount);
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = DOCUMENT_SUFFIX_FILTERS;
    options.maxSelectNumber = limit;

    let uris: string[] = [];
    try {
      const documentPicker = new picker.DocumentViewPicker(this.context);
      uris = await documentPicker.select(options);
    } catch (error) {
      const detail = error instanceof Error ? error.message : '无法打开文件选择器';
      throw new Error(`选择文件失败：${detail}`);
    }

    const attachments: RaisaFeedbackAttachment[] = [];
    for (let index: number = 0; index < uris.length && attachments.length < limit; index++) {
      const uri = uris[index];
      if (uri.trim().length > 0) {
        attachments.push(await this.buildAttachmentFromUri(uri, false));
      }
    }
    return attachments;
  }

  private async buildAttachmentFromUri(
    uri: string,
    fromPhotoPicker: boolean
  ): Promise<RaisaFeedbackAttachment> {
    const fallbackName = fromPhotoPicker ? 'screenshot.jpg' : 'attachment.txt';
    const rawFileName = extractFileNameFromUri(uri, fallbackName);
    const inferred = inferDocumentMimeAndImageFlag(rawFileName);
    const isImage = fromPhotoPicker || inferred[1];
    const initialMime = fromPhotoPicker && inferred[0].length === 0 ? 'image/jpeg' : inferred[0];

    if (!isImage && initialMime.length === 0) {
      throw new Error(`不支持的文件格式：${rawFileName}（仅支持图片及 txt/log/json/md/pdf）`);
    }

    const maxReadBytes = isImage ? MAX_IMAGE_SOURCE_READ_BYTES : RAISA_MAX_ATTACHMENT_BYTES;
    const rawBuffer = this.readUriBytes(uri, rawFileName, maxReadBytes);
    const normalized = isImage ?
      await this.normalizeImageAttachment(rawBuffer, rawFileName, initialMime) :
      this.normalizeDocumentAttachment(rawBuffer, rawFileName, initialMime);

    if (normalized.bytes.byteLength <= 0 || normalized.bytes.byteLength > RAISA_MAX_ATTACHMENT_BYTES) {
      throw new Error(`附件处理后仍超过 2 MB 上限：${normalized.fileName}`);
    }

    let encoded = '';
    try {
      encoded = this.base64.encodeToStringSync(normalized.bytes);
    } catch (_error) {
      throw new Error(`附件编码失败：${normalized.fileName}`);
    }

    return new RaisaFeedbackAttachment(
      this.idGenerator.generate(),
      normalized.fileName,
      normalized.mimeType,
      normalized.bytes.byteLength,
      normalized.isImage,
      uri,
      encoded
    );
  }

  private readUriBytes(uri: string, fileName: string, maxAllowedBytes: number): ArrayBuffer {
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      if (stat.size <= 0) {
        throw new Error(`文件内容为空：${fileName}`);
      }
      if (stat.size > maxAllowedBytes) {
        throw new Error(
          maxAllowedBytes === RAISA_MAX_ATTACHMENT_BYTES ?
            `文件过大（超过 2 MB 上限）：${fileName}` :
            `图片体积过大（超过 24 MB）：${fileName}`
        );
      }
      const buffer = new ArrayBuffer(stat.size);
      const bytesRead = fileIo.readSync(file.fd, buffer);
      return bytesRead === stat.size ? buffer : buffer.slice(0, bytesRead);
    } catch (error) {
      if (error instanceof Error && (error.message.includes('文件') || error.message.includes('图片'))) {
        throw error;
      }
      throw new Error(`无法读取所选文件：${fileName}`);
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file);
        } catch (_closeError) {
        }
      }
    }
  }

  private normalizeDocumentAttachment(
    buffer: ArrayBuffer,
    fileName: string,
    mimeType: string
  ): NormalizedAttachmentBytes {
    return {
      bytes: new Uint8Array(buffer),
      mimeType: mimeType,
      fileName: fileName,
      isImage: false
    };
  }

  private async normalizeImageAttachment(
    buffer: ArrayBuffer,
    fileName: string,
    fallbackMime: string
  ): Promise<NormalizedAttachmentBytes> {
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    let packer: image.ImagePacker | undefined = undefined;
    try {
      imageSource = image.createImageSource(buffer);
      const info = await imageSource.getImageInfo();
      const width = info.size.width;
      const height = info.size.height;
      const detectedMime = info.mimeType.trim().length > 0 ?
        info.mimeType.trim().toLowerCase() : fallbackMime;
      const keepOriginalGif = detectedMime === 'image/gif' && buffer.byteLength <= RAISA_MAX_ATTACHMENT_BYTES;
      const needsCompression = !keepOriginalGif && (
        width > IMAGE_MAX_DIMENSION_PX ||
        height > IMAGE_MAX_DIMENSION_PX ||
        buffer.byteLength > IMAGE_COMPRESSION_THRESHOLD_BYTES ||
        detectedMime.length === 0
      );

      if (!needsCompression && buffer.byteLength <= RAISA_MAX_ATTACHMENT_BYTES) {
        return {
          bytes: new Uint8Array(buffer),
          mimeType: detectedMime.length > 0 ? detectedMime : 'image/jpeg',
          fileName: fileName,
          isImage: true
        };
      }

      pixelMap = await imageSource.createPixelMap();
      const maxSide = Math.max(width, height);
      if (maxSide > IMAGE_MAX_DIMENSION_PX) {
        const scale = IMAGE_MAX_DIMENSION_PX / maxSide;
        await pixelMap.scale(scale, scale);
      }

      packer = image.createImagePacker();
      const packed = await packer.packToData(pixelMap, {
        format: 'image/jpeg',
        quality: 82
      });
      return {
        bytes: new Uint8Array(packed),
        mimeType: 'image/jpeg',
        fileName: replaceFileExtension(fileName, 'jpg'),
        isImage: true
      };
    } catch (error) {
      if (buffer.byteLength <= RAISA_MAX_ATTACHMENT_BYTES && fallbackMime.startsWith('image/')) {
        return {
          bytes: new Uint8Array(buffer),
          mimeType: fallbackMime,
          fileName: fileName,
          isImage: true
        };
      }
      const detail = error instanceof Error ? error.message : '图片解析失败';
      throw new Error(`图片处理失败（${fileName}）：${detail}`);
    } finally {
      if (packer !== undefined) {
        try {
          await packer.release();
        } catch (_error) {
        }
      }
      if (pixelMap !== undefined) {
        try {
          await pixelMap.release();
        } catch (_error) {
        }
      }
      if (imageSource !== undefined) {
        try {
          await imageSource.release();
        } catch (_error) {
        }
      }
    }
  }
}
