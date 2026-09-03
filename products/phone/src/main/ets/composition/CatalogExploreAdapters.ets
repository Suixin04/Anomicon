import {
  ArticleHtmlRepository,
  CatalogPreview,
  PreviewRepository as CatalogPreviewRepository,
  ScpHtmlRequestPriority,
  ScpHtmlSource
} from 'catalog';
import {
  ExploreFeatureDependencies,
  ExploreFetchedPage,
  ExploreHtmlLoadResult,
  ExploreHtmlRepository,
  ExploreHtmlSource,
  ExplorePreview,
  ExploreRecommendationPageGateway,
  ExploreTitleResolver,
  PreviewRepository as ExplorePreviewRepository
} from 'explore';

/** Product-owned mapping from Catalog HTML semantics to Explore's ports. */
class CatalogExploreHtmlAdapter
  implements ExploreHtmlRepository, ExploreRecommendationPageGateway {
  private readonly repository: ArticleHtmlRepository;

  constructor(repository: ArticleHtmlRepository) {
    this.repository = repository;
  }

  async loadHtml(sourceUrl: string, forceNetwork: boolean = false): Promise<ExploreHtmlLoadResult> {
    const result = await this.repository.loadHtml(
      sourceUrl,
      forceNetwork,
      ScpHtmlRequestPriority.USER_INITIATED
    );
    return new ExploreHtmlLoadResult(
      result.html,
      this.toExploreSource(result.source),
      result.fetchedAt
    );
  }

  discard(sourceUrl: string): Promise<void> {
    return this.repository.discard(sourceUrl);
  }

  async fetchPage(sourceUrl: string): Promise<ExploreFetchedPage> {
    const result = await this.repository.loadHtml(
      sourceUrl,
      true,
      ScpHtmlRequestPriority.USER_INITIATED
    );
    // Random recommendations must be validated by a server response. A stale
    // fallback must not masquerade as a newly sampled recommendation.
    if (result.source === ScpHtmlSource.STALE_CACHE) {
      throw new Error('推荐候选没有可用的网络响应');
    }
    return new ExploreFetchedPage(result.html, result.fetchedAt);
  }

  private toExploreSource(source: ScpHtmlSource): ExploreHtmlSource {
    switch (source) {
      case ScpHtmlSource.FRESH_CACHE:
        return ExploreHtmlSource.FRESH_CACHE;
      case ScpHtmlSource.STALE_CACHE:
        return ExploreHtmlSource.STALE_CACHE;
      default:
        return ExploreHtmlSource.NETWORK;
    }
  }
}

/** Product-owned mapping from Catalog preview values to Explore values. */
class CatalogExplorePreviewAdapter implements ExplorePreviewRepository {
  private readonly repository: CatalogPreviewRepository;

  constructor(repository: CatalogPreviewRepository) {
    this.repository = repository;
  }

  async getPreview(itemId: string): Promise<ExplorePreview> {
    return this.toExplorePreview(await this.repository.getPreview(itemId));
  }

  async resolveFetchedHtml(
    itemId: string,
    html: string,
    fetchedAt: number = Date.now()
  ): Promise<ExplorePreview> {
    return this.toExplorePreview(
      await this.repository.resolveFetchedHtml(itemId, html, fetchedAt)
    );
  }

  private toExplorePreview(preview: CatalogPreview): ExplorePreview {
    return new ExplorePreview(
      preview.path,
      preview.aspect,
      preview.description,
      preview.url,
      preview.fetchedAt,
      preview.stale,
      preview.error
    );
  }
}

/**
 * Adapts exactly the three Catalog capabilities required by Explore. The full
 * CatalogFeatureGraph remains owned by AppContainer and never enters Explore.
 */
export class CatalogExploreDependenciesAdapter implements ExploreFeatureDependencies {
  readonly htmlRepository: ExploreHtmlRepository;
  readonly recommendationPageGateway: ExploreRecommendationPageGateway;
  readonly previewRepository: ExplorePreviewRepository;
  readonly titleResolver: ExploreTitleResolver;
  private readonly initializer: () => Promise<void>;

  constructor(
    articleHtmlRepository: ArticleHtmlRepository,
    previewRepository: CatalogPreviewRepository,
    initializer: () => Promise<void>,
    titleResolver: ExploreTitleResolver
  ) {
    const htmlAdapter = new CatalogExploreHtmlAdapter(articleHtmlRepository);
    this.htmlRepository = htmlAdapter;
    this.recommendationPageGateway = htmlAdapter;
    this.previewRepository = new CatalogExplorePreviewAdapter(previewRepository);
    this.titleResolver = titleResolver;
    this.initializer = initializer;
  }

  initialize(): Promise<void> {
    return this.initializer();
  }
}
