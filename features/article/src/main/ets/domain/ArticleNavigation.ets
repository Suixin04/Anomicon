import {
  ScpArticleDocument,
  ScpBlockType,
  ScpContentBlock,
  ScpFootnote,
  ScpTextStyle
} from './ScpDocument';

const NOISE_ANCHOR_EXACT: string[] = [
  'page-content',
  'page-title',
  'page-info',
  'ads',
  'adend',
  'toc-action-bar',
  'toc-list',
  'u-credit-view',
  'u-credit-otherwise',
  'u-adult-warning'
];

const MAX_TOC_ITEMS: number = 200;

export function normalizeArticleAnchor(raw: string): string {
  let trimmed = raw.trim();
  while (trimmed.startsWith('#')) {
    trimmed = trimmed.substring(1).trim();
  }
  if (trimmed.length === 0) {
    return '';
  }
  let decoded = trimmed;
  try {
    decoded = decodeURIComponent(trimmed);
  } catch (_error) {
    decoded = trimmed;
  }
  return decoded.trim().toLowerCase();
}

export function isNoiseArticleAnchor(normalized: string): boolean {
  if (normalized.length === 0 || normalized.length > 128) {
    return true;
  }
  if (NOISE_ANCHOR_EXACT.indexOf(normalized) >= 0) {
    return true;
  }
  return normalized.indexOf('prw') === 0 ||
    normalized.indexOf('footnote-') === 0 ||
    normalized.indexOf('footnoteref-') === 0;
}

export function extractUrlAnchorFragment(rawUrl: string): string {
  const hashIndex = rawUrl.indexOf('#');
  if (hashIndex < 0) {
    return '';
  }
  return normalizeArticleAnchor(rawUrl.substring(hashIndex + 1));
}

export enum ArticleTocKind {
  HEADING = 'heading',
  COLLAPSIBLE = 'collapsible',
  FOOTNOTES = 'footnotes'
}

export class ArticleTabTarget {
  readonly tabsBlockKey: string;
  readonly tabIndex: number;

  constructor(tabsBlockKey: string, tabIndex: number) {
    this.tabsBlockKey = tabsBlockKey;
    this.tabIndex = tabIndex;
  }
}

export class ArticleBlockLocation {
  readonly sectionIndex: number;
  readonly blockKey: string;
  readonly expandCollapsibleKeys: string[];
  readonly tabTargets: ArticleTabTarget[];

  constructor(
    sectionIndex: number,
    blockKey: string,
    expandCollapsibleKeys: string[] = [],
    tabTargets: ArticleTabTarget[] = []
  ) {
    this.sectionIndex = sectionIndex;
    this.blockKey = blockKey;
    this.expandCollapsibleKeys = expandCollapsibleKeys;
    this.tabTargets = tabTargets;
  }
}

export class ArticleTocItem {
  readonly key: string;
  readonly title: string;
  readonly level: number;
  readonly kind: ArticleTocKind;
  readonly location: ArticleBlockLocation;

  constructor(
    key: string,
    title: string,
    level: number,
    kind: ArticleTocKind,
    location: ArticleBlockLocation
  ) {
    this.key = key;
    this.title = title;
    this.level = level;
    this.kind = kind;
    this.location = location;
  }
}

export class ArticleSearchHit {
  readonly key: string;
  readonly blockKey: string;
  readonly snippet: string;
  readonly contextLabel: string;
  readonly isFootnote: boolean;
  readonly footnoteIndex: number;
  readonly footnoteId: string;
  readonly location: ArticleBlockLocation;

  constructor(
    key: string,
    blockKey: string,
    snippet: string,
    contextLabel: string,
    isFootnote: boolean,
    footnoteIndex: number,
    footnoteId: string,
    location: ArticleBlockLocation
  ) {
    this.key = key;
    this.blockKey = blockKey;
    this.snippet = snippet;
    this.contextLabel = contextLabel;
    this.isFootnote = isFootnote;
    this.footnoteIndex = footnoteIndex;
    this.footnoteId = footnoteId;
    this.location = location;
  }
}

export class HighlightedTextSegment {
  readonly text: string;
  readonly matched: boolean;

  constructor(text: string, matched: boolean) {
    this.text = text;
    this.matched = matched;
  }
}

export interface ArticleIndexSectionInput {
  readonly sectionIndex: number;
  readonly block: ScpContentBlock;
  readonly extraAnchors?: string[];
}

export class ArticleNavigationIndex {
  readonly anchorMap: Map<string, ArticleBlockLocation>;
  readonly locationByBlockKey: Map<string, ArticleBlockLocation>;
  readonly tocItems: ArticleTocItem[];

  constructor(
    anchorMap: Map<string, ArticleBlockLocation>,
    locationByBlockKey: Map<string, ArticleBlockLocation>,
    tocItems: ArticleTocItem[]
  ) {
    this.anchorMap = anchorMap;
    this.locationByBlockKey = locationByBlockKey;
    this.tocItems = tocItems;
  }
}

class RawTocCandidate {
  readonly key: string;
  readonly title: string;
  readonly rawLevel: number;
  readonly kind: ArticleTocKind;
  readonly isCredit: boolean;
  readonly location: ArticleBlockLocation;

  constructor(
    key: string,
    title: string,
    rawLevel: number,
    kind: ArticleTocKind,
    isCredit: boolean,
    location: ArticleBlockLocation
  ) {
    this.key = key;
    this.title = title;
    this.rawLevel = rawLevel;
    this.kind = kind;
    this.isCredit = isCredit;
    this.location = location;
  }
}

export function buildArticleNavigationIndex(
  sections: ArticleIndexSectionInput[],
  footnotes: ScpFootnote[],
  footnotesSectionIndex: number
): ArticleNavigationIndex {
  const anchorMap: Map<string, ArticleBlockLocation> = new Map();
  const locationByBlockKey: Map<string, ArticleBlockLocation> = new Map();
  const rawTocCandidates: RawTocCandidate[] = [];

  const registerAnchors = (anchors: string[] | undefined, location: ArticleBlockLocation): void => {
    if (anchors === undefined) {
      return;
    }
    for (let index = 0; index < anchors.length; index++) {
      const normalized = normalizeArticleAnchor(anchors[index]);
      if (normalized.length > 0 && !isNoiseArticleAnchor(normalized) && !anchorMap.has(normalized)) {
        anchorMap.set(normalized, location);
      }
    }
  };

  const visitBlock = (
    block: ScpContentBlock,
    sectionIndex: number,
    expandKeys: string[],
    tabTargets: ArticleTabTarget[],
    extraAnchors: string[] | undefined
  ): void => {
    const location = new ArticleBlockLocation(
      sectionIndex,
      block.key,
      expandKeys.slice(),
      tabTargets.slice()
    );
    if (!locationByBlockKey.has(block.key)) {
      locationByBlockKey.set(block.key, location);
    }
    registerAnchors(extraAnchors, location);
    registerAnchors(block.anchors, location);

    if (block.type === ScpBlockType.HEADING) {
      const title = readableHeadingText(block);
      if (title.length > 0) {
        const clampedLevel = Math.max(1, Math.min(4, block.level > 0 ? block.level : 2));
        rawTocCandidates.push(new RawTocCandidate(
          `toc:${block.key}`,
          title,
          clampedLevel,
          ArticleTocKind.HEADING,
          false,
          location
        ));
      }
    } else if (block.type === ScpBlockType.COLLAPSIBLE) {
      const title = block.caption.replace(/\s+/g, ' ').trim();
      const isCredit = block.key.endsWith(':__credits__');
      if (title.length > 0) {
        rawTocCandidates.push(new RawTocCandidate(
          `toc:${block.key}`,
          title,
          0,
          ArticleTocKind.COLLAPSIBLE,
          isCredit,
          location
        ));
      }
    }

    if (block.type === ScpBlockType.TABS) {
      for (let tabIndex = 0; tabIndex < block.children.length; tabIndex++) {
        const panel = block.children[tabIndex];
        const nextTabs = tabTargets.concat([new ArticleTabTarget(block.key, tabIndex)]);
        visitBlock(panel, sectionIndex, expandKeys, nextTabs, undefined);
      }
      return;
    }

    const nextExpand = block.type === ScpBlockType.COLLAPSIBLE ?
      expandKeys.concat([block.key]) : expandKeys;
    for (let childIndex = 0; childIndex < block.children.length; childIndex++) {
      visitBlock(block.children[childIndex], sectionIndex, nextExpand, tabTargets, undefined);
    }
  };

  for (let index = 0; index < sections.length; index++) {
    const entry = sections[index];
    visitBlock(entry.block, entry.sectionIndex, [], [], entry.extraAnchors);
  }

  let hasNonCredit = false;
  let hasHeadings = false;
  let minHeadingLevel = 4;
  for (let index = 0; index < rawTocCandidates.length; index++) {
    const candidate = rawTocCandidates[index];
    if (!candidate.isCredit) {
      hasNonCredit = true;
    }
    if (candidate.kind === ArticleTocKind.HEADING) {
      hasHeadings = true;
      if (candidate.rawLevel < minHeadingLevel) {
        minHeadingLevel = candidate.rawLevel;
      }
    }
  }

  const tocItems: ArticleTocItem[] = [];
  for (let index = 0; index < rawTocCandidates.length && tocItems.length < MAX_TOC_ITEMS; index++) {
    const candidate = rawTocCandidates[index];
    if (candidate.isCredit && hasNonCredit) {
      continue;
    }
    const level = candidate.kind === ArticleTocKind.HEADING ?
      Math.max(1, Math.min(4, candidate.rawLevel - minHeadingLevel + 1)) :
      (hasHeadings ? 2 : 1);
    tocItems.push(new ArticleTocItem(
      candidate.key,
      candidate.title,
      level,
      candidate.kind,
      candidate.location
    ));
  }

  if (footnotes.length > 0 && footnotesSectionIndex >= 0 && tocItems.length > 0 &&
    tocItems.length < MAX_TOC_ITEMS) {
    tocItems.push(new ArticleTocItem(
      'toc:__footnotes__',
      `脚注 (${footnotes.length})`,
      1,
      ArticleTocKind.FOOTNOTES,
      new ArticleBlockLocation(footnotesSectionIndex, '__footnotes_header__', [], [])
    ));
  }

  return new ArticleNavigationIndex(anchorMap, locationByBlockKey, tocItems);
}

export function resolveAnchorLocation(
  index: ArticleNavigationIndex,
  rawAnchor: string
): ArticleBlockLocation | undefined {
  const target = normalizeArticleAnchor(rawAnchor);
  if (target.length === 0) {
    return undefined;
  }
  const direct = index.anchorMap.get(target);
  if (direct !== undefined) {
    return direct;
  }
  if (!target.startsWith('u-')) {
    const prefixed = index.anchorMap.get(`u-${target}`);
    if (prefixed !== undefined) {
      return prefixed;
    }
  } else if (target.length > 2) {
    const unprefixed = index.anchorMap.get(target.substring(2));
    if (unprefixed !== undefined) {
      return unprefixed;
    }
  }
  return undefined;
}

export function searchArticleDocument(
  document: ScpArticleDocument,
  index: ArticleNavigationIndex,
  rawQuery: string,
  maxHits: number = 120
): ArticleSearchHit[] {
  const trimmed = rawQuery.trim();
  if (trimmed.length === 0 || maxHits <= 0) {
    return [];
  }
  const needle = trimmed.toLowerCase();
  const hits: ArticleSearchHit[] = [];

  const appendMatchIfFound = (
    text: string,
    blockKey: string,
    contextLabel: string,
    isFootnote: boolean,
    footnoteIndex: number,
    footnoteId: string,
    fallbackSectionIndex: number
  ): void => {
    if (hits.length >= maxHits || text.length === 0) {
      return;
    }
    const lower = text.toLowerCase();
    const matchPos = lower.indexOf(needle);
    if (matchPos < 0) {
      return;
    }
    const location = index.locationByBlockKey.get(blockKey) ??
      new ArticleBlockLocation(fallbackSectionIndex, blockKey, [], []);
    hits.push(new ArticleSearchHit(
      `hit:${hits.length}:${blockKey}`,
      blockKey,
      buildSearchSnippet(text, matchPos, needle.length),
      contextLabel,
      isFootnote,
      footnoteIndex,
      footnoteId,
      location
    ));
  };

  const searchBlocks = (blocks: ScpContentBlock[], contextLabel: string): void => {
    for (let i = 0; i < blocks.length && hits.length < maxHits; i++) {
      const block = blocks[i];
      if (block.type === ScpBlockType.COLLAPSIBLE) {
        const nextLabel = block.caption.trim().length > 0 ?
          `折叠：${block.caption.trim()}` : contextLabel;
        appendMatchIfFound(
          block.caption,
          block.key,
          contextLabel,
          false,
          -1,
          '',
          0
        );
        searchBlocks(block.children, nextLabel);
      } else if (block.type === ScpBlockType.TABS) {
        for (let tabIdx = 0; tabIdx < block.children.length && hits.length < maxHits; tabIdx++) {
          const panel = block.children[tabIdx];
          const tabLabel = panel.caption.trim().length > 0 ?
            `标签：${panel.caption.trim()}` : `标签 ${tabIdx + 1}`;
          appendMatchIfFound(
            panel.caption,
            panel.key,
            tabLabel,
            false,
            -1,
            '',
            0
          );
          searchBlocks(panel.children, tabLabel);
        }
      } else if (block.type === ScpBlockType.IMAGE) {
        appendMatchIfFound(block.caption, block.key, contextLabel, false, -1, '', 0);
      } else if (block.type === ScpBlockType.ACS_HEADER && block.acs !== undefined) {
        const acsText = [
          block.acs.itemNumber.length > 0 ? `SCP-${block.acs.itemNumber}` : '',
          block.acs.containmentClass,
          block.acs.secondaryClass,
          block.acs.disruptionClass,
          block.acs.riskClass
        ].filter((part: string): boolean => part.length > 0).join(' ');
        appendMatchIfFound(acsText, block.key, contextLabel, false, -1, '', 0);
      } else if (block.spans.length > 0 || block.children.length > 0) {
        if (block.spans.length > 0) {
          appendMatchIfFound(spansTextOf(block), block.key, contextLabel, false, -1, '', 0);
        }
        if (block.children.length > 0) {
          searchBlocks(block.children, contextLabel);
        }
      }
    }
  };

  searchBlocks(document.blocks, '正文');

  if (document.creditBlocks.length > 0 && hits.length < maxHits) {
    searchBlocks(document.creditBlocks, '著作信息');
  }

  for (let fnIdx = 0; fnIdx < document.footnotes.length && hits.length < maxHits; fnIdx++) {
    const fn = document.footnotes[fnIdx];
    const fnDisplayNumber = fn.index > 0 ? fn.index : fnIdx + 1;
    const combinedText = flattenBlocksPlainText(fn.blocks);
    const lower = combinedText.toLowerCase();
    const matchPos = lower.indexOf(needle);
    if (matchPos >= 0) {
      const fnLocation = resolveAnchorLocation(index, `footnote-${fn.id}`) ??
        index.locationByBlockKey.get(fn.blocks.length > 0 ? fn.blocks[0].key : '') ??
        new ArticleBlockLocation(0, `fn:${fn.id}`, [], []);
      hits.push(new ArticleSearchHit(
        `hit:${hits.length}:fn:${fn.id}`,
        fnLocation.blockKey,
        buildSearchSnippet(combinedText, matchPos, needle.length),
        `脚注 ${fnDisplayNumber}`,
        true,
        fnIdx,
        fn.id,
        fnLocation
      ));
    }
  }

  return hits;
}

export function splitTextForSearchHighlight(
  text: string,
  rawQuery: string
): HighlightedTextSegment[] {
  const needle = rawQuery.trim().toLowerCase();
  if (needle.length === 0 || text.length === 0) {
    return text.length > 0 ? [new HighlightedTextSegment(text, false)] : [];
  }
  const lower = text.toLowerCase();
  const segments: HighlightedTextSegment[] = [];
  let cursor = 0;
  while (cursor < text.length) {
    const found = lower.indexOf(needle, cursor);
    if (found < 0) {
      segments.push(new HighlightedTextSegment(text.substring(cursor), false));
      break;
    }
    if (found > cursor) {
      segments.push(new HighlightedTextSegment(text.substring(cursor, found), false));
    }
    segments.push(new HighlightedTextSegment(text.substring(found, found + needle.length), true));
    cursor = found + needle.length;
  }
  return segments;
}

function readableHeadingText(block: ScpContentBlock): string {
  let raw = '';
  for (let index = 0; index < block.spans.length; index++) {
    if (block.spans[index].style !== ScpTextStyle.FOOTNOTE_REFERENCE) {
      raw += block.spans[index].text;
    }
  }
  return raw.replace(/\s+/g, ' ').trim();
}

function spansTextOf(block: ScpContentBlock): string {
  let text = '';
  for (let index = 0; index < block.spans.length; index++) {
    const span = block.spans[index];
    if (span.style !== ScpTextStyle.FOOTNOTE_REFERENCE) {
      text += span.text;
    }
  }
  return text;
}

function flattenBlocksPlainText(blocks: ScpContentBlock[]): string {
  const parts: string[] = [];
  for (let index = 0; index < blocks.length; index++) {
    const block = blocks[index];
    const spanText = spansTextOf(block).trim();
    if (spanText.length > 0) {
      parts.push(spanText);
    }
    if (block.children.length > 0) {
      const childText = flattenBlocksPlainText(block.children);
      if (childText.length > 0) {
        parts.push(childText);
      }
    }
  }
  return parts.join(' ');
}

function buildSearchSnippet(text: string, matchPos: number, matchLen: number): string {
  const singleLine = text.replace(/\s+/g, ' ');
  const normalizedMatchPos = singleLine.toLowerCase().indexOf(
    text.substring(matchPos, matchPos + matchLen).replace(/\s+/g, ' ').toLowerCase()
  );
  const center = normalizedMatchPos >= 0 ? normalizedMatchPos :
    Math.min(Math.max(0, matchPos), Math.max(0, singleLine.length - 1));
  const start = Math.max(0, center - 18);
  const end = Math.min(singleLine.length, start + 64);
  const prefix = start > 0 ? '…' : '';
  const suffix = end < singleLine.length ? '…' : '';
  return `${prefix}${singleLine.substring(start, end).trim()}${suffix}`;
}
