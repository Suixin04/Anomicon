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
      const source = this.toSource(html.source);
      // Native-first: normal SCP pages are parsed in ArkTS and do not create
      // an off-screen ArkWeb instance. Keep the old handshake as a compatibility
      // fallback for unusual widgets not covered by the native parser yet.
      if (this.parser.parseHtmlPayload !== undefined) {
        try {
          const payload = await this.parser.parseHtmlPayload(html.html);
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
          html.html,
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
}
