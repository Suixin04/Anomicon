import { ExploreContentUseCase } from '../application/ExploreContentUseCase';
import { RecommendationUseCase } from '../application/RecommendationUseCase';
import {
  ExploreHtmlRepository,
  ExploreRecommendationPageGateway,
  PreviewRepository,
  ExploreTitleResolver
} from '../domain/ExploreRepositories';

/**
 * Product-supplied capabilities required to assemble Explore.
 *
 * Every member is owned by Explore's domain contract. The product layer may
 * adapt another feature's public ports, but neither that feature graph nor its
 * concrete data implementation crosses this composition seam.
 */
export interface ExploreFeatureDependencies {
  readonly htmlRepository: ExploreHtmlRepository;
  readonly recommendationPageGateway: ExploreRecommendationPageGateway;
  readonly previewRepository: PreviewRepository;
  readonly titleResolver?: ExploreTitleResolver;
  initialize(): Promise<void>;
}

/**
 * Product-facing composition graph for the Explore feature.
 *
 * This interface belongs to composition because it intentionally groups domain
 * ports with application use cases. Keeping it out of domain preserves the
 * domain -> application dependency direction.
 */
export interface ExploreFeatureGraph {
  readonly contentUseCase: ExploreContentUseCase;
  readonly recommendationUseCase: RecommendationUseCase;
  initialize(): Promise<void>;
}
