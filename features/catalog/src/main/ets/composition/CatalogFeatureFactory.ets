import { common } from '@kit.AbilityKit';
import {
  ImagePreviewActions,
  NetworkBoostPort,
  NetworkBoostScene,
  NetworkConditionSnapshot,
  NetworkQoeStatus,
  NetworkQualityTier
} from 'anomiconbasic';
import { CatalogFeatureGraph } from '../domain/CatalogFeaturePorts';
import { ArticleHtmlRepository } from '../domain/ArticleHtmlRepository';
import {
  CatalogRepository,
  CatalogTitleResolver,
  PreviewRepository,
  SearchHistoryRepository,
  TaleRepository
} from '../domain/CatalogRepositories';
import { SeriesTalesRepository } from '../domain/SeriesTalesContracts';
import { ScpHtmlRequestPriority } from '../domain/ArticleHtmlRepository';
import {
  findCatalogSeriesById,
  ScpCatalogBranch,
  ScpSeriesDescriptor
} from '../domain/ScpSeriesItem';
import { ScpCatalogRawEntry } from '../domain/StaticCatalogContracts';
import { CachedArticleRepo } from '../data/CachedArticleRepo';
import { PreviewRepositoryAdapter } from '../data/PreviewRepositoryAdapter';
import { CatalogRepoAdapter } from '../data/CatalogRepoAdapter';
import { ScpCatalogCacheService, ScpStoredCatalog } from '../data/ScpCatalogCacheService';
import { ScpCatalogTitleResolver } from '../data/ScpCatalogTitleResolver';
import {
  SeriesTalesCacheRecord,
  SeriesTalesCacheStore,
  SeriesTalesRepositoryAdapter
} from '../data/SeriesTalesRepositoryAdapter';
import { ScpImageCacheService } from '../data/ScpImageCacheService';
import { ScpImagePrefetchService } from '../data/ScpImagePrefetchService';
import { PreviewActionsAdapter } from '../data/PreviewActionsAdapter';
import { ScpPageCacheService } from '../data/ScpPageCacheService';
import { ScpPageFetchService } from '../data/ScpPageFetchService';
import { ScpPreviewService } from '../data/ScpPreviewService';
import { ScpRequestScheduler } from '../data/ScpRequestScheduler';
import { ScpSearchHistoryService } from '../data/ScpSearchHistoryService';
import { StaticParserAdapter } from '../data/StaticParserAdapter';
import { TaleListService } from '../data/TaleListService';
import { TaleRepositoryAdapter } from '../data/TaleRepositoryAdapter';
import { SearchHistoryAdapter } from '../data/SearchHistoryAdapter';
import { TitleResolverAdapter } from '../data/TitleResolverAdapter';

const WIKI_BASE_URL: string = 'https://scp-wiki-cn.wikidot.com/';

/** Resolve both public Main/CN series descriptors and any future CN-6+ fallback. */
function titleSeriesDescriptor(seriesId: string): ScpSeriesDescriptor | undefined {
  if (seriesId.toLowerCase() === 'scp-joke-cn') {
    return new ScpSeriesDescriptor(
      'scp-joke-cn',
      '原创搞笑 SCP',
      `${WIKI_BASE_URL}joke-scps-cn`,
      ScpCatalogBranch.CN
    );
  }
  if (seriesId.toLowerCase() === 'scp-joke') {
    return new ScpSeriesDescriptor(
      'scp-joke',
      '搞笑 SCP',
      `${WIKI_BASE_URL}joke-scps`
    );
  }
  const knownSeries = findCatalogSeriesById(seriesId);
  if (knownSeries !== undefined) {
    return knownSeries;
  }
  const normalized = seriesId.toLowerCase();
  const cnMatch = /^scp-series-cn-([2-9][0-9]*)$/i.exec(normalized);
  if (normalized !== 'scp-series-cn' && cnMatch === null) {
    return undefined;
  }
  const number = cnMatch === null ? 1 : Number(cnMatch[1]);
  const descriptorId = number === 1 ? 'scp-series-cn' : `scp-series-cn-${number}`;
  return new ScpSeriesDescriptor(
    descriptorId,
    `CN ${number}`,
    `${WIKI_BASE_URL}${descriptorId}`,
    ScpCatalogBranch.CN
  );
}

class ScpSeriesTalesCacheStore implements SeriesTalesCacheStore {
  private readonly service: ScpCatalogCacheService;

  constructor(service: ScpCatalogCacheService) {
    this.service = service;
  }

  get(key: string): Promise<SeriesTalesCacheRecord | undefined> {
    return this.service.get(key);
  }

  put(record: SeriesTalesCacheRecord): Promise<void> {
    return this.service.put(new ScpStoredCatalog(record.seriesId, record.json, record.parsedAt));
  }
}

/** Explicit ArkTS object type for the graph returned to the product layer. */
class CatalogFeatureGraphImpl implements CatalogFeatureGraph {
  readonly catalogRepository: CatalogRepository;
  readonly taleRepository: TaleRepository;
  readonly seriesTalesRepository: SeriesTalesRepository;
  readonly previewRepository: PreviewRepository;
  readonly searchHistoryRepository: SearchHistoryRepository;
  readonly articleHtmlRepository: ArticleHtmlRepository;
  readonly titleResolver: CatalogTitleResolver;
  readonly imagePreviewActions: ImagePreviewActions;
  private readonly initializer: () => Promise<void>;
  private readonly temporaryCacheClearer: () => Promise<void>;
  private readonly disposer: () => void;

  constructor(
    catalogRepository: CatalogRepository,
    taleRepository: TaleRepository,
    seriesTalesRepository: SeriesTalesRepository,
    previewRepository: PreviewRepository,
    searchHistoryRepository: SearchHistoryRepository,
    articleHtmlRepository: ArticleHtmlRepository,
    titleResolver: CatalogTitleResolver,
    imagePreviewActions: ImagePreviewActions,
    initializer: () => Promise<void>,
    temporaryCacheClearer: () => Promise<void>,
    disposer: () => void
  ) {
    this.catalogRepository = catalogRepository;
    this.taleRepository = taleRepository;
    this.seriesTalesRepository = seriesTalesRepository;
    this.previewRepository = previewRepository;
    this.searchHistoryRepository = searchHistoryRepository;
    this.articleHtmlRepository = articleHtmlRepository;
    this.titleResolver = titleResolver;
    this.imagePreviewActions = imagePreviewActions;
    this.initializer = initializer;
    this.temporaryCacheClearer = temporaryCacheClearer;
    this.disposer = disposer;
  }

  initialize(): Promise<void> {
    return this.initializer();
  }

  clearTemporaryCaches(): Promise<void> {
    return this.temporaryCacheClearer();
  }

  dispose(): void {
    this.disposer();
  }
}

/**
 * Build the catalog graph once for a product.  The returned object contains
 * only domain ports and a single idempotent initializer; concrete RDB/RCP
 * services remain private to this file.
 */
export function createCatalogFeatureGraph(
  context: common.UIAbilityContext,
  networkBoost?: NetworkBoostPort
): CatalogFeatureGraph {
  // One graph owns one concrete pipeline.  Catalog, tales, previews, Article
  // and Explore therefore share the same request scheduler, HTML cache and
  // in-flight deduplication without relying on process-global service state.
  const requestScheduler = new ScpRequestScheduler();
  const pageCacheService = new ScpPageCacheService();
  const pageFetchService = new ScpPageFetchService(
    requestScheduler,
    networkBoost === undefined ? undefined :
      (latencyMs: number, statusCode: number, failed: boolean): void => {
        if (failed || statusCode >= 500) {
          const noData = statusCode === 1007900028 || statusCode === 1007900052;
          networkBoost.reportQoe(
            NetworkBoostScene.BROWSER,
            noData ? NetworkQoeStatus.NO_DATA : NetworkQoeStatus.SERVER_ERROR
          );
        } else if (latencyMs >= 3000) {
          networkBoost.reportQoe(NetworkBoostScene.BROWSER, NetworkQoeStatus.HIGH_LATENCY);
        } else if (statusCode >= 200 && statusCode < 400 && latencyMs <= 1200) {
          networkBoost.reportQoe(NetworkBoostScene.BROWSER, NetworkQoeStatus.GOOD);
        }
      }
  );
  const articleHtmlRepository = new CachedArticleRepo(
    pageFetchService,
    pageCacheService,
    requestScheduler
  );
  const catalogCacheService = new ScpCatalogCacheService();
  const imageCacheService = new ScpImageCacheService();
  const imagePrefetchService = new ScpImagePrefetchService();

  let lastHandoverEpoch: number = networkBoost?.currentCondition().handoverEpoch ?? 0;
  const applyNetworkCondition = (condition: NetworkConditionSnapshot): void => {
    switch (condition.tier) {
      case NetworkQualityTier.GOOD:
        requestScheduler.setConcurrencyPolicy(6, 2);
        imageCacheService.setMaxConcurrentDownloads(6);
        imagePrefetchService.setNetworkPolicy(6, false);
        break;
      case NetworkQualityTier.WEAK:
        requestScheduler.setConcurrencyPolicy(2, 0);
        imageCacheService.setMaxConcurrentDownloads(2);
        imagePrefetchService.setNetworkPolicy(2, true);
        break;
      case NetworkQualityTier.SUSPENDED:
        requestScheduler.setConcurrencyPolicy(1, 0);
        imageCacheService.setMaxConcurrentDownloads(1);
        imagePrefetchService.setNetworkPolicy(1, true);
        break;
      case NetworkQualityTier.NORMAL:
      default:
        requestScheduler.setConcurrencyPolicy(4, 2);
        imageCacheService.setMaxConcurrentDownloads(4);
        imagePrefetchService.setNetworkPolicy(6, false);
        break;
    }
    if (condition.handoverEpoch > lastHandoverEpoch) {
      lastHandoverEpoch = condition.handoverEpoch;
      pageFetchService.retireSessionForHandover();
      imageCacheService.retireSessionForHandover();
    }
  };
  let unsubscribeNetworkBoost: (() => void) | undefined = undefined;
  if (networkBoost !== undefined) {
    applyNetworkCondition(networkBoost.currentCondition());
    unsubscribeNetworkBoost = networkBoost.subscribe(applyNetworkCondition);
  }
  const searchHistoryService = new ScpSearchHistoryService();
  const taleListService = new TaleListService(articleHtmlRepository);
  const previewService = new ScpPreviewService(
    articleHtmlRepository,
    imageCacheService,
    imagePrefetchService
  );
  const parser = new StaticParserAdapter();
  const catalogRepository = new CatalogRepoAdapter(
    catalogCacheService,
    articleHtmlRepository,
    parser
  );
  const taleRepository = new TaleRepositoryAdapter(taleListService, parser);
  const seriesTalesRepository = new SeriesTalesRepositoryAdapter(
    articleHtmlRepository,
    new ScpSeriesTalesCacheStore(catalogCacheService)
  );
  const previewRepository = new PreviewRepositoryAdapter(previewService);
  const searchHistoryRepository = new SearchHistoryAdapter(searchHistoryService);
  const titleResolver = new TitleResolverAdapter(
    new ScpCatalogTitleResolver(
      catalogCacheService,
      async (seriesId: string): Promise<ScpCatalogRawEntry[]> => {
        const descriptor = titleSeriesDescriptor(seriesId);
        if (descriptor === undefined) {
          return [];
        }
        const snapshot = await catalogRepository.load(
          descriptor,
          ScpHtmlRequestPriority.BACKGROUND
        );
        const entries: ScpCatalogRawEntry[] = [];
        for (let index = 0; index < snapshot.entries.length; index++) {
          const entry = snapshot.entries[index];
          entries.push({ itemId: entry.itemId, title: entry.title, description: entry.description });
        }
        return entries;
      }
    )
  );
  const imagePreviewActions = new PreviewActionsAdapter(context, imageCacheService);
  let initialization: Promise<void> | undefined = undefined;

  const initialize = (): Promise<void> => {
    if (initialization !== undefined) {
      return initialization;
    }
    // Every concurrent caller observes the same attempt.  Individual stores
    // clear their own failed opening promise; this graph also clears its
    // in-flight attempt so the product can retry instead of caching a false
    // successful initialization forever.
    const tasks: Promise<void>[] = [
      Promise.resolve(searchHistoryService.initialize(context)),
      pageCacheService.initialize(context),
      catalogCacheService.initialize(context),
      previewService.initialize(context),
      taleListService.initialize(context),
      Promise.resolve(imageCacheService.initialize(context)),
      Promise.resolve(imagePrefetchService.initialize())
    ];
    const attempt = (async (): Promise<void> => {
      await Promise.all(tasks);
    })();
    initialization = attempt.catch((error: Object): void => {
      initialization = undefined;
      const message = error instanceof Error ? error.message : 'Catalog feature initialization failed';
      throw new Error(message);
    });
    return initialization;
  };

  const clearTemporaryCaches = async (): Promise<void> => {
    await initialize();
    await Promise.all([
      pageCacheService.clearAll(),
      imageCacheService.clearAll(),
      previewService.clearAll()
    ]);
  };

  return new CatalogFeatureGraphImpl(
    catalogRepository,
    taleRepository,
    seriesTalesRepository,
    previewRepository,
    searchHistoryRepository,
    articleHtmlRepository,
    titleResolver,
    imagePreviewActions,
    initialize,
    clearTemporaryCaches,
    (): void => {
      if (unsubscribeNetworkBoost !== undefined) {
        unsubscribeNetworkBoost();
        unsubscribeNetworkBoost = undefined;
      }
      pageFetchService.dispose();
      imageCacheService.dispose();
    }
  );
}
