import { ExploreRecommendation } from '../domain/ExploreContracts';
import { ExploreRecommendationProgress, RecommendationRepository } from '../domain/ExploreRepositories';
import { RecommendationService } from './RecommendationService';

export class RecommendationRepo implements RecommendationRepository {
  private readonly service: RecommendationService;

  constructor(service: RecommendationService) {
    this.service = service;
  }

  loadDaily(
    batchIndex: number,
    dayKey?: string,
    progress?: ExploreRecommendationProgress
  ): Promise<ExploreRecommendation[]> {
    return this.service.loadDaily(batchIndex, dayKey, progress);
  }
}
