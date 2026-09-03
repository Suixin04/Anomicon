import { common } from '@kit.AbilityKit';
import {
  ArticleContentGateway,
  ArticleFavoritePort,
  ArticleDocumentParserPort,
  ArticleHistoryPort,
  ArticleHtmlPort,
  ArticleMetadataPort,
  ArticleViewStatePort,
  ReadingSessionPort
} from '../domain/ArticleContracts';
import {
  ScpDocumentMapper,
  ScpExtractPayload
} from '../data/ScpDocumentMapper';
import { parseNativeArticleHtml } from '../data/ScpNativeHtmlParseTask';
import { ScpArticleDocument } from '../domain/ScpDocument';
import { ContentGateway } from '../data/ContentGateway';
import { RdbArticleDocumentCache } from '../data/RdbArticleDocumentCache';
import { ArticleViewStateRepo } from '../data/ArticleViewStateRepo';
import { ArticleContentUseCase } from '../application/ArticleContentUseCase';
import { ArticleViewModel } from '../presentation/viewmodel/ArticleViewModel';

/** Product-supplied capabilities. Article owns its model and persistence. */
export interface ArticleFeatureDependencies {
  readonly html: ArticleHtmlPort;
  /** Shared-library history is adapted at the product composition root. */
  readonly history?: ArticleHistoryPort;
  readonly metadata?: ArticleMetadataPort;
}

/**
 * Public Article graph. Only domain ports and a screen-VM factory are
 * exposed; RDB/cache implementations and parser payloads stay private.
 */
export interface ArticleFeatureGraph {
  initialize(): Promise<void>;
  createViewModel(
    readingSession?: ReadingSessionPort,
    favoritePort?: ArticleFavoritePort
  ): ArticleViewModel;
}

class ArticleFeatureGraphImpl implements ArticleFeatureGraph {
  private readonly useCase: ArticleContentUseCase;
  private readonly viewState: ArticleViewStatePort;
  private readonly history: ArticleHistoryPort | undefined;
  private readonly initializer: () => Promise<void>;

  constructor(
    contentGateway: ArticleContentGateway,
    viewState: ArticleViewStatePort,
    initializer: () => Promise<void>,
    metadata?: ArticleMetadataPort,
    history?: ArticleHistoryPort
  ) {
    this.viewState = viewState;
    this.useCase = new ArticleContentUseCase(contentGateway, metadata);
    this.initializer = initializer;
    this.history = history;
  }

  initialize(): Promise<void> {
    return this.initializer();
  }

  createViewModel(
    readingSession?: ReadingSessionPort,
    favoritePort?: ArticleFavoritePort
  ): ArticleViewModel {
    return new ArticleViewModel(
      this.useCase,
      this.viewState,
      readingSession,
      favoritePort,
      this.history
    );
  }
}

/** Parser implementation remains a data-side adapter behind a domain port. */
class ArticleDocumentParserAdapter implements ArticleDocumentParserPort {
  private readonly mapper: ScpDocumentMapper = new ScpDocumentMapper();

  parse(
    payloadText: string,
    sourceUrl: string,
    fetchedAt: number
  ): ScpArticleDocument {
    // The compatibility extractor transports a JavaScript string as JSON. The
    // extractor itself returns JSON.stringify(out), so runJavaScript may
    // deliver one additional JSON string layer. Unwrap at most that one layer
    // and keep the mapper's strict schema validation as the final gate.
    let decoded: Object | string = JSON.parse(payloadText) as Object | string;
    if (typeof decoded === 'string') {
      decoded = JSON.parse(decoded) as Object | string;
    }
    if (decoded === null || typeof decoded !== 'object' || Array.isArray(decoded)) {
      throw new Error('正文解析结果不是对象');
    }
    const payload = decoded as ScpExtractPayload;
    return this.mapper.toDocument(payload, sourceUrl, fetchedAt);
  }

  parseHtmlPayload(html: string): Promise<string> {
    return parseNativeArticleHtml(html);
  }

  currentSchemaVersion(): number {
    return ScpArticleDocument.CURRENT_SCHEMA_VERSION;
  }
}

/** Create a stateless parser adapter for one Article graph. */
export function createArticleDocumentParser(): ArticleDocumentParserPort {
  return new ArticleDocumentParserAdapter();
}

/**
 * Build the Article graph for one Ability. The product supplies only raw HTML
 * and cross-feature business ports; Article constructs and initializes its
 * own document cache and fold-state repository with the current context.
 */
export function createArticleFeatureGraph(
  context: common.UIAbilityContext,
  dependencies: ArticleFeatureDependencies
): ArticleFeatureGraph {
  const parser = createArticleDocumentParser();
  const cache = new RdbArticleDocumentCache(context);
  const gateway = new ContentGateway(dependencies.html, cache, parser);
  const viewState = new ArticleViewStateRepo(context);
  let initialization: Promise<void> | undefined = undefined;

  const initialize = (): Promise<void> => {
    if (initialization !== undefined) {
      return initialization;
    }
    const attempt = cache.initialize();
    initialization = attempt.catch((error: Object): void => {
      initialization = undefined;
      const message = error instanceof Error ? error.message :
        'Article feature initialization failed';
      throw new Error(message);
    });
    return initialization;
  };

  return new ArticleFeatureGraphImpl(
    gateway,
    viewState,
    initialize,
    dependencies.metadata,
    dependencies.history
  );
}
