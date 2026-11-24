import { FavoriteRepository, ReadingHistoryRepository } from './LibraryRepositories';
import { ResearchActivityRepo } from './ResearchActivityRepo';
import { StorySeriesRepository } from './StorySeriesContracts';

/**
 * Product-facing library dependency graph.
 *
 * Only domain ports cross the feature boundary; RDB stores and helper
 * implementations remain details of the feature composition factory.
 */
export interface LibraryFeatureGraph {
  readonly favoriteRepository: FavoriteRepository;
  readonly readingHistoryRepository: ReadingHistoryRepository;
  readonly researchActivityRepository: ResearchActivityRepo;
  readonly storySeriesRepository: StorySeriesRepository;
  /** Opens/migrates library persistence once. Safe to call repeatedly. */
  initialize(): Promise<void>;
}
