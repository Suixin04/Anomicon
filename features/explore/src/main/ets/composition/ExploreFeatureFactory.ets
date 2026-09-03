import { common } from '@kit.AbilityKit';
import {
  ExploreFeatureDependencies,
  ExploreFeatureGraph
} from './ExploreFeatureGraph';
import { ExploreContentUseCase } from '../application/ExploreContentUseCase';
import { RecommendationUseCase } from '../application/RecommendationUseCase';
import { RecommendationService } from '../data/RecommendationService';
import { ExploreListService } from '../data/ExploreListService';
import { ExploreRepo } from '../data/ExploreRepo';
import { RecommendationRepo } from '../data/RecommendationRepo';
import { RetryableInitialization } from '../data/RetryableInitialization';

class ExploreFeatureGraphImpl implements ExploreFeatureGraph {
  readonly contentUseCase: ExploreContentUseCase;
  readonly recommendationUseCase: RecommendationUseCase;
  private readonly initializer: () => Promise<void>;

  constructor(
    contentUseCase: ExploreContentUseCase,
    recommendationUseCase: RecommendationUseCase,
    initializer: () => Promise<void>
  ) {
    this.contentUseCase = contentUseCase;
    this.recommendationUseCase = recommendationUseCase;
    this.initializer = initializer;
  }

  initialize(): Promise<void> {
    return this.initializer();
  }
}

/** Build one product-scoped Explore graph; initialization is idempotent. */
export function createExploreFeatureGraph(
  context: common.UIAbilityContext,
  dependencies: ExploreFeatureDependencies
): ExploreFeatureGraph {
  const listService = new ExploreListService(dependencies.htmlRepository);
  const listRepository = new ExploreRepo(listService);
  const previewRepository = dependencies.previewRepository;
  const recommendationService = new RecommendationService(
    dependencies.recommendationPageGateway,
    previewRepository,
    dependencies.titleResolver
  );
  const recommendationRepository = new RecommendationRepo(recommendationService);
  const contentUseCase = new ExploreContentUseCase(
    listRepository,
    dependencies.titleResolver
  );
  const recommendationUseCase = new RecommendationUseCase(recommendationRepository);
  const initialization = new RetryableInitialization();
  const initialize = (): Promise<void> => {
    return initialization.run(async (): Promise<void> => {
      await Promise.all([
        dependencies.initialize(),
        listRepository.initialize(context)
      ]);
    });
  };
  return new ExploreFeatureGraphImpl(
    contentUseCase,
    recommendationUseCase,
    initialize
  );
}
