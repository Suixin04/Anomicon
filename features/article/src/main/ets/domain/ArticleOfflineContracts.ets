import { LibraryContentKind, LibraryContentRef } from 'library';
import {
  ScpArticleDocument,
  ScpBlockType,
  ScpContentBlock
} from './ScpDocument';

const DEFAULT_WIKI_ORIGIN: string = 'https://scp-wiki-cn.wikidot.com';
const DEFAULT_WIKI_BASE: string = `${DEFAULT_WIKI_ORIGIN}/`;

/** Offline package availability classification displayed directly to the reader. */
export enum ArticleOfflineStatus {
  READY = 'ready',
  MISSING_IMAGES = 'missing_images',
  INTERACTIVE_NEEDS_NETWORK = 'interactive_needs_network',
  MISSING_IMAGES_AND_INTERACTIVE = 'missing_images_and_interactive'
}

/** One persisted image entry stored in the article's offline manifest. */
export interface ArticleOfflineImageEntry {
  readonly url: string;
  readonly fileName: string;
  readonly bytes: number;
  readonly saved: boolean;
}

/** Reader-facing readiness summary computed from on-disk verification. */
export interface ArticleOfflineReadiness {
  readonly status: ArticleOfflineStatus;
  readonly badgeText: string;
  readonly detailText: string;
  readonly missingImages: number;
}

/** Full offline archive state for the article page & image resolver. */
export class ArticleOfflineSnapshot {
  readonly contentKey: string;
  readonly contentKind: LibraryContentKind;
  readonly itemId: string;
  readonly title: string;
  readonly sourceUrl: string;
  readonly savedAt: number;
  readonly totalBytes: number;
  readonly totalImages: number;
  readonly savedImages: number;
  readonly missingImages: number;
  readonly requiresNetworkInteractive: boolean;
  readonly status: ArticleOfflineStatus;
  readonly badgeText: string;
  readonly detailText: string;
  readonly localImageUris: Map<string, string>;

  constructor(
    contentKey: string,
    contentKind: LibraryContentKind,
    itemId: string,
    title: string,
    sourceUrl: string,
    savedAt: number,
    totalBytes: number,
    totalImages: number,
    savedImages: number,
    missingImages: number,
    requiresNetworkInteractive: boolean,
    status: ArticleOfflineStatus,
    badgeText: string,
    detailText: string,
    localImageUris: Map<string, string>
  ) {
    this.contentKey = contentKey;
    this.contentKind = contentKind;
    this.itemId = itemId;
    this.title = title;
    this.sourceUrl = sourceUrl;
    this.savedAt = savedAt;
    this.totalBytes = totalBytes;
    this.totalImages = totalImages;
    this.savedImages = savedImages;
    this.missingImages = missingImages;
    this.requiresNetworkInteractive = requiresNetworkInteractive;
    this.status = status;
    this.badgeText = badgeText;
    this.detailText = detailText;
    this.localImageUris = localImageUris;
  }
}

/** Lightweight summary row for Terminal shelf and Settings storage inspection. */
export class ArticleOfflineSummary {
  readonly contentKey: string;
  readonly contentKind: LibraryContentKind;
  readonly itemId: string;
  readonly title: string;
  readonly sourceUrl: string;
  readonly savedAt: number;
  readonly totalBytes: number;
  readonly totalImages: number;
  readonly savedImages: number;
  readonly missingImages: number;
  readonly requiresNetworkInteractive: boolean;
  readonly status: ArticleOfflineStatus;
  readonly badgeText: string;
  readonly detailText: string;

  constructor(
    contentKey: string,
    contentKind: LibraryContentKind,
    itemId: string,
    title: string,
    sourceUrl: string,
    savedAt: number,
    totalBytes: number,
    totalImages: number,
    savedImages: number,
    missingImages: number,
    requiresNetworkInteractive: boolean,
    status: ArticleOfflineStatus,
    badgeText: string,
    detailText: string
  ) {
    this.contentKey = contentKey;
    this.contentKind = contentKind;
    this.itemId = itemId;
    this.title = title;
    this.sourceUrl = sourceUrl;
    this.savedAt = savedAt;
    this.totalBytes = totalBytes;
    this.totalImages = totalImages;
    this.savedImages = savedImages;
    this.missingImages = missingImages;
    this.requiresNetworkInteractive = requiresNetworkInteractive;
    this.status = status;
    this.badgeText = badgeText;
    this.detailText = detailText;
  }
}

export interface ArticleOfflineSaveProgress {
  readonly completedImages: number;
  readonly totalImages: number;
}

export interface ArticleOfflineDocumentRecord {
  readonly document: ScpArticleDocument;
  readonly rawPayloadJson: string;
  readonly savedAt: number;
  readonly snapshot: ArticleOfflineSnapshot;
}

/** Narrow port for downloading one validated image into cache before copying to offline vault. */
export interface ArticleOfflineImageFetcher {
  fetchToLocalFile(url: string): Promise<string>;
}

export type ArticleOfflineStoreListener = () => void;

/** Permanent per-article offline persistence boundary, isolated from temporary caches. */
export interface ArticleOfflineStoragePort {
  initialize(): Promise<void>;
  inspect(content: LibraryContentRef): Promise<ArticleOfflineSnapshot | undefined>;
  loadDocument(content: LibraryContentRef): Promise<ArticleOfflineDocumentRecord | undefined>;
  save(
    content: LibraryContentRef,
    document: ScpArticleDocument,
    rawPayloadJson: string,
    onProgress?: (progress: ArticleOfflineSaveProgress) => void
  ): Promise<ArticleOfflineSnapshot>;
  remove(contentKey: string): Promise<void>;
  listSummaries(): Promise<ArticleOfflineSummary[]>;
  subscribe(listener: ArticleOfflineStoreListener): () => void;
}

/**
 * Pure string URL normalizer for article images.
 * Strips control whitespace (e.g. CR/LF in Wikidot HTML), upgrades HTTP/protocol-relative URLs
 * to HTTPS, resolves relative paths against baseUrl, strips `#fragment`, and rejects non-HTTP(S)
 * or URLs with credentials/custom ports.
 */
export function normalizeOfflineImageUrl(
  rawUrl: string,
  baseUrl: string = DEFAULT_WIKI_BASE
): string {
  let candidate = rawUrl.replace(/[\r\n\t]/g, '').trim();
  if (candidate.length === 0) {
    return '';
  }
  const hashIndex = candidate.indexOf('#');
  if (hashIndex >= 0) {
    candidate = candidate.substring(0, hashIndex).trim();
  }
  if (candidate.length === 0) {
    return '';
  }
  const lower = candidate.toLowerCase();
  if (lower.startsWith('javascript:') ||
    lower.startsWith('data:') ||
    lower.startsWith('blob:') ||
    lower.startsWith('file:') ||
    lower.startsWith('mailto:') ||
    lower.startsWith('about:') ||
    lower.startsWith('tel:')) {
    return '';
  }
  if (candidate.startsWith('//')) {
    candidate = `https:${candidate}`;
  } else if (lower.startsWith('http://')) {
    candidate = `https://${candidate.substring(7)}`;
  } else if (lower.startsWith('https://')) {
    candidate = `https://${candidate.substring(8)}`;
  } else if (/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(candidate)) {
    return '';
  } else {
    const resolvedBase = resolveOriginAndDirectory(baseUrl);
    if (candidate.startsWith('/')) {
      candidate = `${resolvedBase.origin}${candidate}`;
    } else if (candidate.startsWith('?')) {
      candidate = `${resolvedBase.basePath}${candidate}`;
    } else {
      const cleanedRelative = candidate.startsWith('./') ? candidate.substring(2) : candidate;
      candidate = `${resolvedBase.directory}${cleanedRelative}`;
    }
  }

  const parsed = /^https:\/\/([^/?#]+)([\s\S]*)$/i.exec(candidate);
  if (parsed === null) {
    return '';
  }
  const authority = parsed[1] as string;
  if (authority.length === 0 || authority.indexOf('@') >= 0 || authority.indexOf(':') >= 0) {
    return '';
  }
  const rest = (parsed[2] as string).length > 0 ? (parsed[2] as string) : '/';
  return `https://${authority.toLowerCase()}${rest}`;
}

interface ResolvedBaseUrl {
  readonly origin: string;
  readonly directory: string;
  readonly basePath: string;
}

function resolveOriginAndDirectory(baseUrl: string): ResolvedBaseUrl {
  let cleanBase = baseUrl.replace(/[\r\n\t]/g, '').trim();
  if (cleanBase.length === 0) {
    return {
      origin: DEFAULT_WIKI_ORIGIN,
      directory: DEFAULT_WIKI_BASE,
      basePath: DEFAULT_WIKI_BASE
    };
  }
  const hashIdx = cleanBase.indexOf('#');
  if (hashIdx >= 0) {
    cleanBase = cleanBase.substring(0, hashIdx);
  }
  const lower = cleanBase.toLowerCase();
  if (lower.startsWith('http://')) {
    cleanBase = `https://${cleanBase.substring(7)}`;
  } else if (lower.startsWith('//')) {
    cleanBase = `https:${cleanBase}`;
  } else if (!lower.startsWith('https://')) {
    return {
      origin: DEFAULT_WIKI_ORIGIN,
      directory: DEFAULT_WIKI_BASE,
      basePath: DEFAULT_WIKI_BASE
    };
  }
  const match = /^https:\/\/([^/?#]+)([^?#]*)/i.exec(cleanBase);
  if (match === null) {
    return {
      origin: DEFAULT_WIKI_ORIGIN,
      directory: DEFAULT_WIKI_BASE,
      basePath: DEFAULT_WIKI_BASE
    };
  }
  const origin = `https://${(match[1] as string).toLowerCase()}`;
  const pathPart = (match[2] as string).length > 0 ? (match[2] as string) : '/';
  const lastSlash = pathPart.lastIndexOf('/');
  const dirPart = lastSlash >= 0 ? pathPart.substring(0, lastSlash + 1) : '/';
  return {
    origin,
    directory: `${origin}${dirPart}`,
    basePath: `${origin}${pathPart}`
  };
}

/** Collect all deduplicated HTTPS image URLs referenced anywhere inside a parsed article document. */
export function collectArticleImageUrls(document: ScpArticleDocument): string[] {
  const baseUrl = document.sourceUrl.length > 0 ? document.sourceUrl : DEFAULT_WIKI_BASE;
  const collected: string[] = [];
  const seen: Set<string> = new Set();

  const appendUrl = (rawUrl: string): void => {
    const normalized = normalizeOfflineImageUrl(rawUrl, baseUrl);
    if (normalized.length > 0 && !seen.has(normalized)) {
      seen.add(normalized);
      collected.push(normalized);
    }
  };

  const walkBlocks = (blocks: ScpContentBlock[]): void => {
    for (let index: number = 0; index < blocks.length; index++) {
      const block = blocks[index];
      if (block.type === ScpBlockType.IMAGE && block.source.length > 0) {
        appendUrl(block.source);
      }
      if (block.children.length > 0) {
        walkBlocks(block.children);
      }
    }
  };

  for (let index: number = 0; index < document.images.length; index++) {
    appendUrl(document.images[index].source);
  }
  walkBlocks(document.blocks);
  for (let index: number = 0; index < document.footnotes.length; index++) {
    walkBlocks(document.footnotes[index].blocks);
  }
  walkBlocks(document.creditBlocks);
  return collected;
}

/** Detect interactive embeds, multi-page listpages, or unsupported media requiring live network/WebView. */
export function requiresNetworkForInteractiveDocument(document: ScpArticleDocument): boolean {
  const warnings = document.parserWarnings;
  for (let index: number = 0; index < warnings.length; index++) {
    const warning = warnings[index];
    if (warning === 'interactive:html-block-iframe' ||
      warning === 'interactive:listpages-offset' ||
      warning === 'unsupported:audio' ||
      warning === 'unsupported:video' ||
      warning === 'unsupported:canvas' ||
      warning === 'unsupported:svg' ||
      warning === 'unsupported:object' ||
      warning === 'unsupported:math') {
      return true;
    }
  }
  if (containsInteractiveBlock(document.blocks) || containsInteractiveBlock(document.creditBlocks)) {
    return true;
  }
  for (let index: number = 0; index < document.footnotes.length; index++) {
    if (containsInteractiveBlock(document.footnotes[index].blocks)) {
      return true;
    }
  }
  return false;
}

function containsInteractiveBlock(blocks: ScpContentBlock[]): boolean {
  for (let index: number = 0; index < blocks.length; index++) {
    const block = blocks[index];
    if (block.type === ScpBlockType.EMBED || block.type === ScpBlockType.UNSUPPORTED) {
      return true;
    }
    if (block.children.length > 0 && containsInteractiveBlock(block.children)) {
      return true;
    }
  }
  return false;
}

/** Compute reader-facing offline readiness labels strictly from verified image counts & interactive flags. */
export function evaluateOfflineReadiness(
  totalImages: number,
  savedImages: number,
  requiresNetworkInteractive: boolean
): ArticleOfflineReadiness {
  const normalizedTotal = Math.max(0, Math.floor(totalImages));
  const normalizedSaved = Math.max(0, Math.min(normalizedTotal, Math.floor(savedImages)));
  const missingImages = Math.max(0, normalizedTotal - normalizedSaved);

  if (missingImages > 0 && requiresNetworkInteractive) {
    return {
      status: ArticleOfflineStatus.MISSING_IMAGES_AND_INTERACTIVE,
      badgeText: `仍缺 ${missingImages} 张图 · 互动部分需联网`,
      detailText: `正文已保存，配图 ${normalizedSaved}/${normalizedTotal} 张，互动模块需联网`,
      missingImages
    };
  }
  if (missingImages > 0) {
    return {
      status: ArticleOfflineStatus.MISSING_IMAGES,
      badgeText: `仍缺 ${missingImages} 张图`,
      detailText: `正文已保存，配图 ${normalizedSaved}/${normalizedTotal} 张`,
      missingImages
    };
  }
  if (requiresNetworkInteractive) {
    return {
      status: ArticleOfflineStatus.INTERACTIVE_NEEDS_NETWORK,
      badgeText: '互动部分需联网',
      detailText: normalizedTotal > 0 ?
        `正文与 ${normalizedSaved} 张配图已保存，互动模块需联网` :
        '正文已保存，互动模块需联网',
      missingImages: 0
    };
  }
  return {
    status: ArticleOfflineStatus.READY,
    badgeText: normalizedTotal > 0 ? '正文与图片已就绪' : '正文已就绪',
    detailText: normalizedTotal > 0 ?
      `正文与 ${normalizedSaved} 张配图已离线就绪` :
      '正文已离线就绪（无配图）',
    missingImages: 0
  };
}

export function formatOfflineBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) {
    return '0 B';
  }
  if (bytes < 1024) {
    return `${Math.round(bytes)} B`;
  }
  const kb = bytes / 1024;
  if (kb < 1024) {
    return `${kb < 10 ? kb.toFixed(1) : Math.round(kb)} KB`;
  }
  const mb = kb / 1024;
  if (mb < 1024) {
    return `${mb.toFixed(1)} MB`;
  }
  const gb = mb / 1024;
  return `${gb.toFixed(2)} GB`;
}
