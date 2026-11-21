import { ExploreRecommendation } from '../domain/ExploreContracts';
import { ExploreRecommendationProgress, RecommendationRepository } from '../domain/ExploreRepositories';

/** 每日推荐编排用例；候选生成和预览提取由 data adapter 负责。 */
export class RecommendationUseCase {
  private readonly repository: RecommendationRepository;

  constructor(repository: RecommendationRepository) {
    this.repository = repository;
  }

  loadDaily(
    batchIndex: number,
    dayKey: string,
    progress?: ExploreRecommendationProgress
  ): Promise<ExploreRecommendation[]> {
    return this.repository.loadDaily(batchIndex, dayKey, progress);
  }
}
