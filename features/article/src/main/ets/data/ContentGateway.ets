import {
  ArticleContentGateway,
  ArticleContentSource,
  ArticleLoadResult,
  PendingExtraction,
  ArticleDocumentCachePort,
  ArticleDocumentCacheRecord,
  ArticleDocumentParserPort,
  ArticleHtmlPort,
  ArticleHtmlSource
} from '../domain/ArticleContracts';
import { ArticleOfflineStoragePort } from '../domain/ArticleOfflineContracts';
import { LibraryContentRef } from 'library';
import { ScpArticleDocument } from '../domain/ScpDocument';

const WIKI_BASE_URL: string = 'https://scp-wiki-cn.wikidot.com';

/**
 * data adapter for the existing cache/HTML pipeline.  The
 * application layer only sees ArticleContentGateway; RDB and parser details
 * stay here until the catalog data implementation is physically moved.
 */
export class ContentGateway implements ArticleContentGateway {
  private readonly htmlPort: ArticleHtmlPort;
  private readonly documentCache: ArticleDocumentCachePort;
  private readonly parser: ArticleDocumentParserPort;
  private readonly offlineStore: ArticleOfflineStoragePort | undefined;

  constructor(
    htmlPort: ArticleHtmlPort,
    documentCache: ArticleDocumentCachePort,
    parser: ArticleDocumentParserPort,
    offlineStore?: ArticleOfflineStoragePort
  ) {
    this.htmlPort = htmlPort;
    this.documentCache = documentCache;
    this.parser = parser;
    this.offlineStore = offlineStore;
  }

  async load(
    content: LibraryContentRef,
    requestId: number,
    forceNetwork: boolean = false
  ): Promise<ArticleLoadResult> {
    const itemId = content.id;
    const sourceUrl = this.urlOf(itemId);
    // Explicit retry/revalidation bypasses the derived document cache; the
    // raw HTML repository still applies conditional requests and can return
    // a stale HTML snapshot when offline.
    if (!forceNetwork) {
      try {
        const stored = await this.documentCache.get(itemId);
        if (stored !== undefined) {
          const document = this.documentFromStored(stored, sourceUrl);
          if (document !== undefined) {
            return new ArticleLoadResult(
              document,
              undefined,
              ArticleContentSource.DOCUMENT_CACHE,
              stored.parsedAt,
              !this.documentCache.isFresh(stored),
              '',
              stored.json
            );
          }
        }
      } catch (_error) {
        // A derived document cache is optional; fall through to offline vault / source HTML.
      }
      if (this.offlineStore !== undefined) {
        try {
          const offline = await this.offlineStore.loadDocument(content);
          if (offline !== undefined) {
            return new ArticleLoadResult(
              offline.document,
              undefined,
              ArticleContentSource.OFFLINE_ARCHIVE,
              offline.savedAt,
              false,
              '',
              offline.rawPayloadJson
            );
          }
        } catch (_offlineError) {
          // Fall through to HTML pipeline if permanent offline lookup fails.
        }
      }
    }

    try {
      const html = await this.htmlPort.load(sourceUrl, forceNetwork);
      // A number of original CN pages are published through Wikidot's
      // `html-block-iframe`: the outer article contains only a title, rating,
      // and an iframe while the actual document lives at a generated `/html/`
      // URL. Resolve that small, same-site indirection before native parsing
      // so the reader receives normal paragraphs/tables instead of a dead
      // "在浏览器中打开" placeholder.
      const expandedHtml = await this.expandHtmlBlockFrames(
        html.html,
        sourceUrl,
        forceNetwork
      );
      // The native parser owns document-shell filtering after it builds the
      // HTML tree. Keep the source intact here so quoted/unquoted attributes
      // and nested wrappers are handled uniformly by one semantic pass.
      const articleHtml = expandedHtml;
      const source = this.toSource(html.source);
      // Native-first: normal SCP pages are parsed in ArkTS and do not create
      // an off-screen ArkWeb instance. Keep the old handshake as a compatibility
      // fallback for unusual widgets not covered by the native parser yet.
      if (this.parser.parseHtmlPayload !== undefined) {
        try {
          const payload = await this.parser.parseHtmlPayload(articleHtml);
          const document = this.parser.parse(payload, sourceUrl, html.fetchedAt);
          const record: ArticleDocumentCacheRecord = {
            itemId: content.id,
            json: payload,
            schemaVersion: this.parser.currentSchemaVersion(),
            parsedAt: html.fetchedAt
          };
          this.documentCache.put(record).catch((): void => {
            // Cache persistence is best effort after a valid document is published.
          });
          return new ArticleLoadResult(
            document,
            undefined,
            source,
            html.fetchedAt,
            html.source === ArticleHtmlSource.STALE_CACHE,
            '',
            payload
          );
        } catch (_error) {
          // Fall through to the legacy extraction handshake.
        }
      }
      return new ArticleLoadResult(
        undefined,
        new PendingExtraction(
          requestId,
          content.key,
          itemId,
          sourceUrl,
          articleHtml,
          html.fetchedAt,
          html.source === ArticleHtmlSource.STALE_CACHE
        ),
        source,
        html.fetchedAt,
        html.source === ArticleHtmlSource.STALE_CACHE
      );
    } catch (error) {
      if (this.offlineStore !== undefined) {
        try {
          const offline = await this.offlineStore.loadDocument(content);
          if (offline !== undefined) {
            return new ArticleLoadResult(
              offline.document,
              undefined,
              ArticleContentSource.OFFLINE_ARCHIVE,
              offline.savedAt,
              false,
              '',
              offline.rawPayloadJson
            );
          }
        } catch (_offlineFallbackError) {
        }
      }
      return new ArticleLoadResult(
        undefined,
        undefined,
        ArticleContentSource.NETWORK,
        0,
        false,
        error instanceof Error ? error.message : '档案内容加载失败'
      );
    }
  }

  async completeExtraction(
    content: LibraryContentRef,
    pending: PendingExtraction,
    payloadText: string
  ): Promise<ScpArticleDocument> {
    if (pending.contentKey !== content.key || pending.itemId !== content.id) {
      throw new Error('正文提取请求与当前内容不匹配');
    }
    const document = this.parser.parse(payloadText, pending.sourceUrl, pending.fetchedAt);
    const record: ArticleDocumentCacheRecord = {
      itemId: content.id,
      json: payloadText,
      schemaVersion: this.parser.currentSchemaVersion(),
      parsedAt: pending.fetchedAt
    };
    this.documentCache.put(record).catch((): void => {
      // Cache persistence is best effort after a valid document is published.
    });
    return document;
  }

  private documentFromStored(
    stored: ArticleDocumentCacheRecord,
    sourceUrl: string
  ): ScpArticleDocument | undefined {
    try {
      if (stored.schemaVersion <= 0 || stored.schemaVersion > this.parser.currentSchemaVersion()) {
        return undefined;
      }
      return this.parser.parse(
        stored.json,
        sourceUrl,
        stored.parsedAt
      );
    } catch (_error) {
      return undefined;
    }
  }

  private toSource(source: ArticleHtmlSource): ArticleContentSource {
    switch (source) {
      case ArticleHtmlSource.FRESH_CACHE:
        return ArticleContentSource.FRESH_HTML_CACHE;
      case ArticleHtmlSource.STALE_CACHE:
        return ArticleContentSource.STALE_HTML_CACHE;
      default:
        return ArticleContentSource.NETWORK;
    }
  }

  private urlOf(itemId: string): string {
    return `${WIKI_BASE_URL}/${itemId.toLowerCase()}`;
  }

  private async expandHtmlBlockFrames(
    html: string,
    sourceUrl: string,
    forceNetwork: boolean,
    depth: number = 0
  ): Promise<string> {
    if (depth >= 2 || html.length === 0 || html.toLowerCase().indexOf('html-block-iframe') < 0) {
      return html;
    }
    const framePattern: RegExp = /<iframe\b[\s\S]*?(?:<\/iframe\s*>|\/\s*>)/gi;
    const matches: RegExpExecArray[] = [];
    let match: RegExpExecArray | null = framePattern.exec(html);
    while (match !== null) {
      matches.push(match);
      match = framePattern.exec(html);
    }
    if (matches.length === 0) {
      return html;
    }
    let output = html;
    for (let index = matches.length - 1; index >= 0; index--) {
      const frame = matches[index];
      const markup = frame[0];
      const classMatch = /\bclass\s*=\s*(["'])([^"']*)\1/i.exec(markup);
      if (classMatch === null || (` ${classMatch[2]} `).toLowerCase().indexOf(' html-block-iframe ') < 0) {
        continue;
      }
      const srcMatch = /\bsrc\s*=\s*(["'])([^"']+)\1/i.exec(markup);
      if (srcMatch === null) {
        continue;
      }
      const lowerSource = srcMatch[2].toLowerCase();
      if (lowerSource.indexOf('interwiki.scpwikicn.com') >= 0 ||
        lowerSource.indexOf('interwiki.scpwiki.com') >= 0 ||
        lowerSource.indexOf('styleframe') >= 0 ||
        lowerSource.indexOf('credit%3abackmodule') >= 0 ||
        lowerSource.indexOf('credit%253abackmodule') >= 0 ||
        lowerSource.indexOf('credit:backmodule') >= 0) {
        // Navigation/theme/credit helper frames are not article content and are
        // intentionally left untouched so the native parser strips them cleanly.
        continue;
      }
      const frameUrl = this.resolveFrameUrl(srcMatch[2], sourceUrl);
      if (frameUrl.length === 0) {
        continue;
      }
      try {
        const nested = await this.htmlPort.load(frameUrl, forceNetwork);
        const replacement = await this.buildFrameReplacement(nested.html, frameUrl, forceNetwork, depth);
        output = output.substring(0, frame.index) +
          replacement +
          output.substring(frame.index + markup.length);
      } catch (error) {
        // Keep the original iframe when the generated endpoint is unavailable;
        // the native renderer can still offer its browser fallback.
        console.warn(`Expand embedded article frame failed (${frameUrl}): ${error instanceof Error ? error.message : 'unknown error'}`);
      }
    }
    return output;
  }

  private async buildFrameReplacement(
    rawHtml: string,
    frameUrl: string,
    forceNetwork: boolean,
    depth: number
  ): Promise<string> {
    const realContent = this.elementInnerById(rawHtml, 'realcontent');
    if (realContent.length > 0) {
      const cleaned = this.cleanEmbeddedFragment(realContent);
      const expanded = await this.expandHtmlBlockFrames(cleaned, frameUrl, forceNetwork, depth + 1);
      return `<div class="anomicon-embedded-html" data-interactive="true">${expanded}</div>`;
    }
    if (this.isInteractiveWidgetFrame(rawHtml)) {
      return `<iframe class="html-block-iframe anomicon-interactive-frame" data-interactive="true" src="${frameUrl}"></iframe>`;
    }
    const cleaned = this.cleanEmbeddedFragment(rawHtml);
    const expanded = await this.expandHtmlBlockFrames(cleaned, frameUrl, forceNetwork, depth + 1);
    return `<div class="anomicon-embedded-html">${expanded}</div>`;
  }

  private cleanEmbeddedFragment(rawHtml: string): string {
    return this.stripInlineStyleAndScript(rawHtml)
      .replace(/<head\b[\s\S]*?<\/head\s*>/gi, '')
      .replace(/<!DOCTYPE[^>]*>/gi, '')
      .replace(/<\/?(?:html|body)\b[^>]*>/gi, '')
      .trim();
  }

  private isInteractiveWidgetFrame(html: string): boolean {
    if (!/<script\b/i.test(html)) {
      return false;
    }
    return /<(?:input|button|canvas|audio|video)\b/i.test(html) ||
      /\bclass\s*=\s*["'][^"']*(?:keypad|classified-info)[^"']*["']/i.test(html) ||
      /\bonclick\s*=|\baddEventListener\s*\(/i.test(html);
  }

  private stripInlineStyleAndScript(html: string): string {
    return html
      .replace(/<script\b[\s\S]*?<\/script\s*>/gi, '')
      .replace(/<style\b[\s\S]*?<\/style\s*>/gi, '');
  }

  private elementInnerById(html: string, id: string): string {
    const openPattern = new RegExp(`<div\\b[^>]*\\bid=["']${id}["'][^>]*>`, 'i');
    const open = openPattern.exec(html);
    if (open === null || open.index === undefined) {
      return '';
    }
    const start = open.index + open[0].length;
    const tagPattern: RegExp = /<\/?div\b[^>]*>/gi;
    tagPattern.lastIndex = start;
    let depth = 1;
    let token: RegExpExecArray | null = tagPattern.exec(html);
    while (token !== null) {
      if (/^<\s*\/div/i.test(token[0])) {
        depth--;
        if (depth === 0) {
          return html.substring(start, token.index);
        }
      } else if (!/\/\s*>$/.test(token[0])) {
        depth++;
      }
      token = tagPattern.exec(html);
    }
    return html.substring(start);
  }

  private resolveFrameUrl(value: string, sourceUrl: string): string {
    const src = value.trim();
    if (src.length === 0 || src.startsWith('javascript:') || src.startsWith('about:')) {
      return '';
    }
    if (src.startsWith('https://') || src.startsWith('http://')) {
      return src;
    }
    if (src.startsWith('//')) {
      return `https:${src}`;
    }
    if (src.startsWith('/')) {
      const originMatch = /^(https?:\/\/[^/]+)/i.exec(sourceUrl);
      return `${originMatch === null ? WIKI_BASE_URL : originMatch[1]}${src}`;
    }
    return `${WIKI_BASE_URL}/${src.replace(/^\/+/, '')}`;
  }
}
