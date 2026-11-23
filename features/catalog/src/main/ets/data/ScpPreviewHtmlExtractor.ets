import { ExternalUrlPolicy } from 'anomiconbasic';

export interface ScpPreviewExtractionPayload {
  readonly imageUrl: string;
  readonly aspect: number;
  readonly description: string;
  readonly error: string;
}

class ScpPreviewImageCandidate {
  readonly url: string;
  readonly aspect: number;

  constructor(url: string, aspect: number) {
    this.url = url;
    this.aspect = aspect;
  }
}

class ScpPreviewImageResult {
  readonly candidate: ScpPreviewImageCandidate;
  readonly error: string;

  constructor(candidate: ScpPreviewImageCandidate, error: string = '') {
    this.candidate = candidate;
    this.error = error;
  }
}

/**
 * Pure static HTML extractor for catalog preview cards (first image,
 * declared aspect ratio, and lead description).
 */
export class ScpPreviewHtmlExtractor {
  static extractPreview(html: string): ScpPreviewExtractionPayload {
    const imageResult = ScpPreviewHtmlExtractor.extractFirstImage(html);
    if (imageResult.error.length > 0) {
      return {
        imageUrl: '',
        aspect: 0,
        description: '',
        error: imageResult.error
      };
    }
    return {
      imageUrl: imageResult.candidate.url,
      aspect: imageResult.candidate.aspect,
      description: ScpPreviewHtmlExtractor.extractDescription(html),
      error: ''
    };
  }

  /** 静态提取正文首图及 HTML 已声明的比例；缺尺寸时由 Image.onComplete 补全。 */
  static extractFirstImage(html: string): ScpPreviewImageResult {
    if (typeof html !== 'string' || html.trim().length === 0) {
      return new ScpPreviewImageResult(
        new ScpPreviewImageCandidate('', 0),
        '预览解析失败：文章正文为空'
      );
    }
    const markerPattern: RegExp = /<[^>]*\bid\s*=\s*(["'])page-content\1[^>]*>/i;
    const markerMatch = markerPattern.exec(html);
    if (markerMatch === null || markerMatch.index === undefined) {
      return new ScpPreviewImageResult(
        new ScpPreviewImageCandidate('', 0),
        '预览解析失败：未找到正文节点'
      );
    }
    const unbounded: string = html.substring(markerMatch.index);
    const end: number = unbounded.search(/<div[^>]+(?:id="page-info-break"|class="page-tags")/i);
    const region: string = end >= 0 ? unbounded.substring(0, end) : unbounded;
    const pattern: RegExp = /<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["'][^>]*>/gi;
    let match = pattern.exec(region);
    let sawContentImage: boolean = false;
    while (match !== null) {
      const src = (match[1] as string).trim();
      const tag = match[0] as string;
      if (src.length > 0 && ScpPreviewHtmlExtractor.isContentImage(tag, src)) {
        sawContentImage = true;
        try {
          const imageUrl = ExternalUrlPolicy.resolveImageHttps(src);
          const lowerTag = tag.toLowerCase();
          const width = ScpPreviewHtmlExtractor.numericImageAttribute(lowerTag, 'width');
          const height = ScpPreviewHtmlExtractor.numericImageAttribute(lowerTag, 'height');
          const rawAspect = width > 0 && height > 0 ? width / height : 0;
          const aspect = rawAspect >= 0.05 && rawAspect <= 20 ? rawAspect : 0;
          return new ScpPreviewImageResult(new ScpPreviewImageCandidate(imageUrl, aspect));
        } catch (_error) {
          // 当前候选地址无效时继续扫描，避免坏图遮住后续合法正文图。
        }
      }
      match = pattern.exec(region);
    }
    if (sawContentImage) {
      return new ScpPreviewImageResult(
        new ScpPreviewImageCandidate('', 0),
        '预览解析失败：正文图片地址无效'
      );
    }
    return new ScpPreviewImageResult(new ScpPreviewImageCandidate('', 0));
  }

  /**
   * 静态提取正文首段描述：#page-content 剥标签后，优先取「描述：」小节之后的
   * 内容（标准文档结构），否则取第一个「长度足够」的完整句；过短的片段
   * （如图片说明）会被跳过。上限约 140 字，卡片端由 maxLines + 省略号截断。
   */
  static extractDescription(html: string): string {
    if (typeof html !== 'string' || html.length === 0) {
      return '';
    }
    const marker: string = 'id="page-content"';
    const tagStart: number = html.indexOf(marker);
    if (tagStart < 0) {
      return '';
    }
    // 从 id 属性之后的 '>' 开始取内容，避免属性文本泄漏进描述。
    const contentStart: number = html.indexOf('>', tagStart);
    const region: string = contentStart >= 0 ? html.substring(contentStart + 1) : '';
    const text = region
      .replace(/<(script|style)[\s\S]*?<\/\1>/gi, ' ')
      .replace(/<[^>]+>/g, ' ')
      .replace(/\[\[[^\]]*\]\]/g, ' ')
      .replace(/&[a-zA-Z0-9#]+;/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    if (text.length === 0) {
      return '';
    }
    // 标准文档结构：描述内容在「描述：」小节之后。
    const descMarker1 = text.indexOf('描述：');
    const descMarker2 = text.indexOf('描述:');
    let candidate = text;
    if (descMarker1 >= 0) {
      candidate = text.substring(descMarker1 + 3);
    } else if (descMarker2 >= 0) {
      candidate = text.substring(descMarker2 + 3);
    }
    return ScpPreviewHtmlExtractor.pickSentence(candidate, text);
  }

  /** 取首句：优先候选片段，不足 16 字的短句（图片说明等）丢弃并顺延。 */
  private static pickSentence(candidate: string, fallback: string): string {
    const enders: string = '。！？!?';
    let sentence: string = '';
    for (let index: number = 0; index < candidate.length && sentence.length < 140; index++) {
      const ch = candidate.charAt(index);
      sentence += ch;
      if (enders.includes(ch)) {
        if (sentence.trim().length >= 16) {
          return sentence.trim();
        }
        sentence = '';
      }
    }
    if (sentence.trim().length >= 16) {
      return sentence.trim();
    }
    // 候选片段不足：退回全文（例如没有「描述：」小节的页面）。
    if (candidate !== fallback) {
      return ScpPreviewHtmlExtractor.pickSentence(fallback, fallback);
    }
    return '';
  }

  private static isContentImage(tag: string, src: string): boolean {
    if (src.startsWith('data:')) {
      return false;
    }
    const lower: string = src.toLowerCase();
    const lowerTag: string = tag.toLowerCase();
    if (lower.indexOf('avatar.php') >= 0 ||
      lower.indexOf('userkarma.php') >= 0 ||
      lower.indexOf('/avatar') >= 0 ||
      lower.indexOf('/rating') >= 0 ||
      lower.indexOf('icon') >= 0 ||
      lower.indexOf('logo') >= 0 ||
      lower.indexOf('printer') >= 0 ||
      lower.indexOf('license') >= 0 ||
      lower.indexOf('/component:') >= 0 ||
      lower.indexOf('/component%3a') >= 0 ||
      lower.indexOf('classified-bar') >= 0 ||
      lower.indexOf('classified-decoration') >= 0 ||
      lower.indexOf('/local--files/theme:') >= 0 ||
      lower.indexOf('/local--files/theme%3a') >= 0 ||
      lowerTag.indexOf('class="small"') >= 0 ||
      lowerTag.indexOf("class='small'") >= 0) {
      return false;
    }
    const width = ScpPreviewHtmlExtractor.numericImageAttribute(lowerTag, 'width');
    const height = ScpPreviewHtmlExtractor.numericImageAttribute(lowerTag, 'height');
    if (width > 0 && height > 0 && width <= 96 && height <= 96) {
      return false;
    }
    return true;
  }

  private static numericImageAttribute(tag: string, name: string): number {
    const pattern = new RegExp(`(?:^|\\s)${name}\\s*=\\s*["']?([0-9]+)`, 'i');
    const match = pattern.exec(tag);
    return match === null ? 0 : Number(match[1]);
  }
}
