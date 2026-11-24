import {
  ScpArticleDocument,
  ScpBlockType,
  ScpContentBlock,
  ScpFootnote,
  ScpHiddenTextKind,
  ScpTextStyle
} from '../../domain/ScpDocument';

/** Recommendation tier for switching an article into in-app original WebView mode. */
export enum ArticleWebModeRecommendation {
  NONE = 'none',
  RECOMMENDED = 'recommended',
  AUTO_DIRECT = 'auto_direct'
}

/** Result of inspecting a parsed document for interactive or format-screw complexity. */
export interface ArticleWebModeDecision {
  level: ArticleWebModeRecommendation;
  reason: string;
}

interface BodyComplexityStats {
  readableChars: number;
  inlineImageCount: number;
  hasEmbed: boolean;
}

/** Header text projected for the adaptive footnote sheet. */
export interface FootnoteSheetHeader {
  title: string;
  subtitle: string;
}

/**
 * Pure article-rendering projection helpers.
 *
 * ArkUI builders are deliberately kept at the page/view edge.  This class
 * contains the block/span decisions that can be tested without a WebView,
 * UIContext, database or navigation stack, and gives native block components
 * one stable input contract.
 */
export class ArticleRenderer {
  static textOf(block: ScpContentBlock): string {
    if (block.type === ScpBlockType.ACS_HEADER && block.acs !== undefined) {
      const parts: string[] = [];
      if (block.acs.itemNumber.length > 0) {
        parts.push(`SCP-${block.acs.itemNumber}`);
      }
      if (block.acs.containmentClass.length > 0) {
        parts.push(block.acs.containmentClass);
      }
      if (block.acs.secondaryClass.length > 0) {
        parts.push(block.acs.secondaryClass);
      }
      if (block.acs.disruptionClass.length > 0) {
        parts.push(block.acs.disruptionClass);
      }
      if (block.acs.riskClass.length > 0) {
        parts.push(block.acs.riskClass);
      }
      return parts.join(' ');
    }
    let result: string = '';
    for (let index = 0; index < block.spans.length; index++) {
      result += block.spans[index].text;
    }
    return result;
  }

  static footnoteReferenceIds(block: ScpContentBlock): string[] {
    const ids: string[] = [];
    for (let index = 0; index < block.spans.length; index++) {
      const span = block.spans[index];
      if (span.style === ScpTextStyle.FOOTNOTE_REFERENCE && span.referenceId.length > 0) {
        ids.push(span.referenceId);
      }
    }
    return ids;
  }

  /** Locate the zero-based footnote index by referenceId first, then numeric label fallback. */
  static findFootnoteIndex(
    footnotes: ScpFootnote[],
    referenceId: string,
    labelText: string = ''
  ): number {
    if (referenceId.length > 0) {
      for (let index = 0; index < footnotes.length; index++) {
        if (footnotes[index].id === referenceId) {
          return index;
        }
      }
    }
    const trimmed = labelText.trim();
    if (/^\d+$/.test(trimmed)) {
      const targetNumber = Number.parseInt(trimmed, 10);
      for (let index = 0; index < footnotes.length; index++) {
        if (footnotes[index].index === targetNumber) {
          return index;
        }
      }
    }
    return -1;
  }

  /** Clamp a previous/next footnote step within valid array bounds, or -1 when empty. */
  static stepFootnoteIndex(currentIndex: number, delta: number, total: number): number {
    if (total <= 0) {
      return -1;
    }
    const next = currentIndex + delta;
    return Math.max(0, Math.min(next, total - 1));
  }

  /** Build sheet title and optional order subtitle for a footnote item. */
  static footnoteSheetHeader(
    footnote: ScpFootnote,
    position: number,
    total: number
  ): FootnoteSheetHeader {
    const safeTotal = Math.max(1, total);
    const safePosition = Math.max(0, Math.min(position, safeTotal - 1));
    const displayNumber = footnote.index > 0 ? footnote.index : (safePosition + 1);
    if (displayNumber === safePosition + 1) {
      return {
        title: `脚注 ${displayNumber} / ${safeTotal}`,
        subtitle: ''
      };
    }
    return {
      title: `脚注 ${displayNumber}`,
      subtitle: `第 ${safePosition + 1} / ${safeTotal} 条`
    };
  }

  static isExpanded(expandedKeys: string[], blockKey: string): boolean {
    return expandedKeys.indexOf(blockKey) >= 0;
  }

  /** Return a new immutable key list after a collapsible block is toggled. */
  static toggleExpanded(expandedKeys: string[], blockKey: string): string[] {
    const next = expandedKeys.slice();
    const index = next.indexOf(blockKey);
    if (index >= 0) {
      next.splice(index, 1);
    } else {
      next.push(blockKey);
    }
    return next;
  }

  private static rgbToHsl(r: number, g: number, b: number): number[] {
    const rn = r / 255;
    const gn = g / 255;
    const bn = b / 255;
    const max = Math.max(rn, gn, bn);
    const min = Math.min(rn, gn, bn);
    const l = (max + min) / 2;
    if (max === min) {
      return [0, 0, l];
    }
    const d = max - min;
    const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    let h = 0;
    if (max === rn) {
      h = (gn - bn) / d + (gn < bn ? 6 : 0);
    } else if (max === gn) {
      h = (bn - rn) / d + 2;
    } else {
      h = (rn - gn) / d + 4;
    }
    return [h / 6, s, l];
  }

  private static hslToRgb(h: number, s: number, l: number): number[] {
    if (s <= 0) {
      const gray = Math.max(0, Math.min(255, Math.round(l * 255)));
      return [gray, gray, gray];
    }
    const hue2rgb = (p: number, q: number, t: number): number => {
      let tt = t;
      if (tt < 0) {
        tt += 1;
      }
      if (tt > 1) {
        tt -= 1;
      }
      if (tt < 1 / 6) {
        return p + (q - p) * 6 * tt;
      }
      if (tt < 1 / 2) {
        return q;
      }
      if (tt < 2 / 3) {
        return p + (q - p) * (2 / 3 - tt) * 6;
      }
      return p;
    };
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    return [
      Math.max(0, Math.min(255, Math.round(hue2rgb(p, q, h + 1 / 3) * 255))),
      Math.max(0, Math.min(255, Math.round(hue2rgb(p, q, h) * 255))),
      Math.max(0, Math.min(255, Math.round(hue2rgb(p, q, h - 1 / 3) * 255)))
    ];
  }

  private static formatHexRgb(r: number, g: number, b: number): string {
    const channel = (n: number): string => {
      const s = Math.max(0, Math.min(255, Math.round(n))).toString(16).toUpperCase();
      return s.length < 2 ? `0${s}` : s;
    };
    return `#${channel(r)}${channel(g)}${channel(b)}`;
  }

  /** Adjust inline author color so crimson/green/blue/yellow remain readable in dark or light mode. */
  static resolveAdaptiveSpanColor(hexColor: string, darkSurface: boolean): string {
    const trimmed = hexColor.trim();
    if (!/^#[0-9A-Fa-f]{6}$/.test(trimmed)) {
      return '';
    }
    const r = Number.parseInt(trimmed.substring(1, 3), 16);
    const g = Number.parseInt(trimmed.substring(3, 5), 16);
    const b = Number.parseInt(trimmed.substring(5, 7), 16);
    const lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

    if (darkSurface) {
      if (lum >= 0.44) {
        return trimmed.toUpperCase();
      }
      const hsl = ArticleRenderer.rgbToHsl(r, g, b);
      let targetL = Math.max(0.64, Math.min(0.78, hsl[2] + 0.38));
      let rgb = ArticleRenderer.hslToRgb(hsl[0], hsl[1], targetL);
      const nextLum = (0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]) / 255;
      if (nextLum < 0.44) {
        targetL = 0.74;
        rgb = ArticleRenderer.hslToRgb(hsl[0], hsl[1], targetL);
      }
      return ArticleRenderer.formatHexRgb(rgb[0], rgb[1], rgb[2]);
    }

    if (lum <= 0.70) {
      return trimmed.toUpperCase();
    }
    const hsl = ArticleRenderer.rgbToHsl(r, g, b);
    const targetL = Math.min(0.38, Math.max(0.24, hsl[2] - 0.36));
    const rgb = ArticleRenderer.hslToRgb(hsl[0], hsl[1], targetL);
    return ArticleRenderer.formatHexRgb(rgb[0], rgb[1], rgb[2]);
  }

  /** Whether a paragraph contains only `font-size: 0` hidden whispers. */
  static isPureWhisperBlock(block: ScpContentBlock): boolean {
    if (block.type !== ScpBlockType.PARAGRAPH || block.spans.length === 0) {
      return false;
    }
    let hasText = false;
    for (let index: number = 0; index < block.spans.length; index++) {
      const span = block.spans[index];
      if (span.text.trim().length === 0) {
        continue;
      }
      hasText = true;
      if (span.hiddenKind !== ScpHiddenTextKind.ZERO_SIZE_WHISPER) {
        return false;
      }
    }
    return hasText;
  }

  /** Count reader-discoverable hidden Easter egg segments across blocks and nested containers. */
  static countHiddenTextSegments(blocks: ScpContentBlock[]): number {
    let count: number = 0;
    for (let index: number = 0; index < blocks.length; index++) {
      const block = blocks[index];
      if (ArticleRenderer.isPureWhisperBlock(block)) {
        count++;
      } else {
        let activeKind: ScpHiddenTextKind = ScpHiddenTextKind.NONE;
        for (let spanIndex: number = 0; spanIndex < block.spans.length; spanIndex++) {
          const span = block.spans[spanIndex];
          if (span.text.trim().length === 0) {
            continue;
          }
          if (span.hiddenKind === ScpHiddenTextKind.NONE) {
            activeKind = ScpHiddenTextKind.NONE;
          } else if (span.hiddenKind !== activeKind) {
            count++;
            activeKind = span.hiddenKind;
          }
        }
      }
      if (block.children.length > 0) {
        count += ArticleRenderer.countHiddenTextSegments(block.children);
      }
    }
    return count;
  }

  private static collectComplexityStats(blocks: ScpContentBlock[], stats: BodyComplexityStats): void {
    for (let index: number = 0; index < blocks.length; index++) {
      const block = blocks[index];
      if (block.type === ScpBlockType.EMBED) {
        stats.hasEmbed = true;
      } else if (block.type === ScpBlockType.IMAGE) {
        stats.inlineImageCount++;
        stats.readableChars += block.caption.replace(/\s+/g, '').length;
      } else if (block.type !== ScpBlockType.ACS_HEADER) {
        for (let s: number = 0; s < block.spans.length; s++) {
          stats.readableChars += block.spans[s].text.replace(/\s+/g, '').length;
        }
      }
      if (block.children.length > 0) {
        ArticleRenderer.collectComplexityStats(block.children, stats);
      }
    }
  }

  private static hasUnsupportedMediaWarning(warnings: string[]): boolean {
    for (let index: number = 0; index < warnings.length; index++) {
      const w = warnings[index];
      if (w === 'unsupported:audio' || w === 'unsupported:video' ||
        w === 'unsupported:canvas' || w === 'unsupported:svg' ||
        w === 'unsupported:object' || w === 'unsupported:math') {
        return true;
      }
    }
    return false;
  }

  /**
   * Evaluate whether the parsed article should offer or auto-enter in-app
   * original web mode (`ArticleWebRenderer`), keeping normal prose articles
   * completely banner-free.
   */
  static evaluateWebModeRecommendation(document: ScpArticleDocument): ArticleWebModeDecision {
    const stats: BodyComplexityStats = {
      readableChars: 0,
      inlineImageCount: 0,
      hasEmbed: false
    };
    ArticleRenderer.collectComplexityStats(document.blocks, stats);

    const warnings = document.parserWarnings;
    const hasInteractiveIframe = warnings.indexOf('interactive:html-block-iframe') >= 0;
    const hasListPagesOffset = warnings.indexOf('interactive:listpages-offset') >= 0;
    const hasFormatScrewCss = warnings.indexOf('format-screw:custom-css') >= 0;
    const hasUnsupportedMedia = ArticleRenderer.hasUnsupportedMediaWarning(warnings);

    if ((stats.hasEmbed || hasInteractiveIframe) &&
      stats.readableChars < 120 &&
      stats.inlineImageCount < 2) {
      return {
        level: ArticleWebModeRecommendation.AUTO_DIRECT,
        reason: '正文为交互式网页组件，已自动切换原版网页体验'
      };
    }
    if (hasListPagesOffset) {
      return {
        level: ArticleWebModeRecommendation.RECOMMENDED,
        reason: '本文包含多迭代页面或动态切换，建议切换原版网页体验'
      };
    }
    if (hasInteractiveIframe || stats.hasEmbed || hasUnsupportedMedia) {
      return {
        level: ArticleWebModeRecommendation.RECOMMENDED,
        reason: '本文包含交互组件或富媒体，建议切换原版网页体验'
      };
    }
    if (hasFormatScrewCss) {
      return {
        level: ArticleWebModeRecommendation.RECOMMENDED,
        reason: '本文使用特殊视觉版式或动效，建议切换原版网页体验'
      };
    }
    return {
      level: ArticleWebModeRecommendation.NONE,
      reason: ''
    };
  }

  private constructor() {
  }
}
