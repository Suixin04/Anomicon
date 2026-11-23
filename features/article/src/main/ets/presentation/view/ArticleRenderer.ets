import {
  ScpContentBlock,
  ScpFootnote,
  ScpTextStyle
} from '../../domain/ScpDocument';

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

  private constructor() {
  }
}
