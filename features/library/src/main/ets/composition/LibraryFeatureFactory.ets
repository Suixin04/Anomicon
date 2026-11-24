import { common } from '@kit.AbilityKit';
import { LibraryFeatureGraph } from '../domain/LibraryFeaturePorts';
import { FavoriteRepository } from '../domain/LibraryRepositories';
import { ReadingHistoryRepository } from '../domain/LibraryRepositories';
import { ResearchActivityRepo as ResearchActivityRepoPort } from '../domain/ResearchActivityRepo';
import { StorySeriesRepository } from '../domain/StorySeriesContracts';
import { FoundationAssessmentRepository } from '../domain/FoundationAssessmentContracts';
import { RdbFavoriteRepository } from '../data/RdbFavoriteRepository';
import { ReadingHistoryRepo } from '../data/ReadingHistoryRepo';
import { ResearchActivityRepo } from '../data/ResearchActivityRepo';
import { StorySeriesRepo } from '../data/StorySeriesRepo';
import { FoundationAssessmentRepo } from '../data/FoundationAssessmentRepo';

class LibraryFeatureGraphImpl implements LibraryFeatureGraph {
  readonly favoriteRepository: FavoriteRepository;
  readonly readingHistoryRepository: ReadingHistoryRepository;
  readonly researchActivityRepository: ResearchActivityRepoPort;
  readonly storySeriesRepository: StorySeriesRepository;
  readonly foundationAssessmentRepository: FoundationAssessmentRepository;
  private readonly initializer: () => Promise<void>;

  constructor(
    favoriteRepository: FavoriteRepository,
    readingHistoryRepository: ReadingHistoryRepository,
    researchActivityRepository: ResearchActivityRepoPort,
    storySeriesRepository: StorySeriesRepository,
    foundationAssessmentRepository: FoundationAssessmentRepository,
    initializer: () => Promise<void>
  ) {
    this.favoriteRepository = favoriteRepository;
    this.readingHistoryRepository = readingHistoryRepository;
    this.researchActivityRepository = researchActivityRepository;
    this.storySeriesRepository = storySeriesRepository;
    this.foundationAssessmentRepository = foundationAssessmentRepository;
    this.initializer = initializer;
  }

  initialize(): Promise<void> {
    return this.initializer();
  }
}

/**
 * Creates the library graph for one product context. Concrete RDB adapters
 * are intentionally not exported from this module's public surface.
 */
export function createLibraryFeatureGraph(context: common.UIAbilityContext): LibraryFeatureGraph {
  const favorites = new RdbFavoriteRepository(context);
  const history = new ReadingHistoryRepo(context);
  const assessments = new FoundationAssessmentRepo(context);
  const research = new ResearchActivityRepo(
    context,
    (): Promise<number> => assessments.totalAwardedXp()
  );
  const storySeries = new StorySeriesRepo(context);
  let initialization: Promise<void> | undefined = undefined;
  const initialize = (): Promise<void> => {
    if (initialization !== undefined) {
      return initialization;
    }
    const attempt = (async (): Promise<void> => {
      await Promise.all([
        favorites.initialize(),
        history.initialize(),
        assessments.initialize(),
        research.initialize(),
        storySeries.initialize()
      ]);
    })();
    // Persistence is a core part of the Library feature, not an optional
    // cache.  Preserve the rejection and clear the attempt so a later screen
    // retry can genuinely reopen the repositories.
    initialization = attempt.catch((error: Object): void => {
      initialization = undefined;
      throw error instanceof Error ? error : new Error('资料库初始化失败');
    });
    return initialization;
  };
  return new LibraryFeatureGraphImpl(
    favorites,
    history,
    research,
    storySeries,
    assessments,
    initialize
  );
}
