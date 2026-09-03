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

  constructor(
    htmlPort: ArticleHtmlPort,
    documentCache: ArticleDocumentCachePort,
    parser: ArticleDocumentParserPort
  ) {
    this.htmlPort = htmlPort;
    this.documentCache = documentCache;
    this.parser = parser;
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
              !this.documentCache.isFresh(stored)
            );
          }
        }
      } catch (_error) {
        // A derived document cache is optional; fall through to source HTML.
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
            html.source === ArticleHtmlSource.STALE_CACHE
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
        lowerSource.indexOf('styleframe') >= 0) {
        // Navigation/theme helper frames are not article content and are
        // intentionally left untouched (they are outside the page policy).
        continue;
      }
      const frameUrl = this.resolveFrameUrl(srcMatch[2], sourceUrl);
      if (frameUrl.length === 0) {
        continue;
      }
      try {
        const nested = await this.htmlPort.load(frameUrl, forceNetwork);
        const expanded = await this.expandHtmlBlockFrames(
          this.embeddedBody(nested.html),
          frameUrl,
          forceNetwork,
          depth + 1
        );
        output = output.substring(0, frame.index) +
          `<div class="anomicon-embedded-html">${expanded}</div>` +
          output.substring(frame.index + markup.length);
      } catch (error) {
        // Keep the original iframe when the generated endpoint is unavailable;
        // the native renderer can still offer its browser fallback.
        console.warn(`Expand embedded article frame failed (${frameUrl}): ${error instanceof Error ? error.message : 'unknown error'}`);
      }
    }
    return output;
  }

  private embeddedBody(html: string): string {
    // Original CN interactive pages keep their real document under
    // #realcontent and fill it with timer/ad scaffolding. Selecting that node
    // avoids the outer login shell; the native tree parser filters presentation
    // nodes such as ads while retaining the article text.
    const realContent = this.elementInnerById(html, 'realcontent');
    if (realContent.length > 0) {
      return realContent;
    }
    const body = /<body\b[^>]*>([\s\S]*?)<\/body>/i.exec(html);
    return body === null ? html : body[1];
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
