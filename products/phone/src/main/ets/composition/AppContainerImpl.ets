import { common } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { ImagePreviewActions } from 'anomiconbasic';
import { RequestAgentBackgroundDownloadAdapter } from 'anomiconbasic';
import { AppInfoAdapter } from 'anomiconbasic';
import { AppInfoPort } from 'anomiconbasic';
import { HapticFeedbackPort } from 'anomiconbasic';
import { HapticFeedbackAdapter } from 'anomiconbasic';
import { IdGeneratorAdapter } from 'anomiconbasic';
import { IdGeneratorPort } from 'anomiconbasic';
import { RuntimeClockAdapter } from 'anomiconbasic';
import { RuntimeClockPort } from 'anomiconbasic';
import {
  ReadingActivityCoord
} from 'library';
import {
  LibraryFeatureGraph,
  createLibraryFeatureGraph
} from 'library';
import { FavoritesViewModel } from 'library';
import {
  ReadingHistoryViewModel
} from 'library';
import { LibraryCollectionVM } from 'library';
import {
  ResearchProfileViewModel
} from 'library';
import {
  SettingsFeatureGraph,
  createSettingsFeatureGraph
} from 'settings';
import { SettingsViewModel } from 'settings';
import {
  ExploreContentUseCase,
  ExploreCollectionVM,
  ExploreHomeViewModel,
  RecommendationUseCase,
  ExploreFeatureGraph,
  createExploreFeatureGraph
} from 'explore';
import {
  CatalogContentUseCase,
  CatalogPreviewUseCase,
  CatalogSearchUseCase,
  CatalogViewModel,
  CatalogSearchViewModel,
  CatalogRepository,
  PreviewRepository,
  SearchHistoryUseCase,
  SearchHistoryRepository,
  TaleRepository,
  TaleContentUseCase,
  TaleListViewModel
} from 'catalog';
import {
  CatalogFeatureGraph,
  createCatalogFeatureGraph
} from 'catalog';
import {
  ArticleViewModel,
  ArticleMetadataPort,
  ArticleFeatureGraph,
  createArticleFeatureGraph
} from 'article';
import {
  ArticleFavoriteAdapter,
  ArticleHistoryAdapter,
  ReadingSessionAdapter
} from './ArticleAdapters';
import { ArticleMetadataAdapter } from './ArticleMetadataAdapter';
import { CatalogArticleHtmlAdapter } from './CatalogArticleHtmlAdapter';
import { CatalogExploreDependenciesAdapter } from './CatalogExploreAdapters';
import { TerminalViewModel } from 'terminal';
import {
  Archive3DFeatureGraph,
  ArchiveModelDescriptor,
  ArchiveModelUseCase,
  createArchive3DFeatureGraph,
  describeScp3DAsset,
  listScp3DModelAssets
} from 'archive3d';
import { AbilityScopeOwner } from './AbilityScopeOwner';
import {
  TerminalFavoritesAdapter,
  TerminalReadingHistoryAdapter,
  TerminalResearchProfileAdapter
} from './TerminalLibraryAdapters';

const FAVORITES_STORAGE_KEY: string = 'anomicon.library.favorites';
const READING_HISTORY_STORAGE_KEY: string = 'anomicon.library.readingHistory';
const RESEARCH_PROFILE_STORAGE_KEY: string = 'anomicon.research.profile';

/**
 * 应用级组合根。具体 Harmony 实现只在这里被组装，页面只取得已装配的展示状态。
 * 后续模块迁移时继续把依赖装配收敛到这里，而不是让 ViewModel new Service。
 */
export class AppContainer {
  private static readonly INSTANCE: AppContainer = new AppContainer();
  private settingsState: SettingsViewModel | undefined = undefined;
  private settingsGraph: SettingsFeatureGraph | undefined = undefined;
  private libraryGraph: LibraryFeatureGraph | undefined = undefined;
  private favoritesState: FavoritesViewModel | undefined = undefined;
  private readingHistoryState: ReadingHistoryViewModel | undefined = undefined;
  private researchState: ResearchProfileViewModel | undefined = undefined;
  private readingActivityState: ReadingActivityCoord | undefined = undefined;
  private articleGraph: ArticleFeatureGraph | undefined = undefined;
  /** Feature graphs are shared at the adapter/use-case level; screen VMs are factory-owned. */
  private exploreGraph: ExploreFeatureGraph | undefined = undefined;
  private exploreContentUseCase: ExploreContentUseCase | undefined = undefined;
  private exploreRecommendationUseCase: RecommendationUseCase | undefined = undefined;
  /** Catalog adapters are supplied as one feature graph; pages never see RDB classes. */
  private catalogGraph: CatalogFeatureGraph | undefined = undefined;
  private catalogRepository: CatalogRepository | undefined = undefined;
  private taleRepository: TaleRepository | undefined = undefined;
  private previewRepository: PreviewRepository | undefined = undefined;
  private searchHistoryRepository: SearchHistoryRepository | undefined = undefined;
  private imagePreviewActionsState: ImagePreviewActions | undefined = undefined;
  /** Application-scoped 3D package graph; request.agent survives page changes. */
  private archive3DGraph: Archive3DFeatureGraph | undefined = undefined;
  private archive3DUseCaseState: ArchiveModelUseCase | undefined = undefined;
  private readonly abilityScopeOwner: AbilityScopeOwner = new AbilityScopeOwner();
  private readonly appInfoCapability: AppInfoPort = new AppInfoAdapter();
  private readonly hapticFeedbackCapability: HapticFeedbackPort = new HapticFeedbackAdapter();
  private readonly runtimeClockCapability: RuntimeClockPort = new RuntimeClockAdapter();
  private readonly idGeneratorCapability: IdGeneratorPort = new IdGeneratorAdapter();

  private constructor() {
  }

  static getInstance(): AppContainer {
    return AppContainer.INSTANCE;
  }

  initialize(context: common.UIAbilityContext): void {
    if (!this.abilityScopeOwner.owns(context)) {
      if (this.abilityScopeOwner.hasOwner()) {
        // A new Ability may be created before an old asynchronous onDestroy
        // finishes.  Drop every context-bound reference before assembling the
        // replacement graph; the old persistence tasks keep their own narrow
        // references until they finish.
        this.replaceAbilityScope();
      }
      this.abilityScopeOwner.attach(context);
    }
    if (this.archive3DGraph === undefined) {
      const applicationContext = context.getApplicationContext();
      const downloads = new RequestAgentBackgroundDownloadAdapter(
        applicationContext,
        context.abilityInfo.bundleName,
        context.abilityInfo.name
      );
      const archiveModels: ArchiveModelDescriptor[] = listScp3DModelAssets().map(
        (asset): ArchiveModelDescriptor => describeScp3DAsset(asset, asset.downloadUrl)
      );
      this.archive3DGraph = createArchive3DFeatureGraph(
        applicationContext.filesDir,
        downloads,
        this.idGeneratorCapability,
        archiveModels
      );
      this.archive3DUseCaseState = new ArchiveModelUseCase(this.archive3DGraph.modelPackages);
      // Restore durable remote tasks and publish bundled snapshots once per
      // ability. Failures remain visible through per-card state and must not
      // prevent the rest of the application from starting.
      this.archive3DGraph.initialize().catch((): void => {
        console.error('Archive3D feature initialization failed');
      });
    }
    if (this.settingsGraph === undefined) {
      this.settingsGraph = createSettingsFeatureGraph(context);
    }
    if (this.libraryGraph === undefined) {
      this.libraryGraph = createLibraryFeatureGraph(context);
    }
    if (this.catalogGraph === undefined) {
      this.catalogGraph = createCatalogFeatureGraph(context);
      // All repositories originate from the feature graph; screen factories
      // receive only the narrow ports they need.
      this.catalogRepository = this.catalogGraph.catalogRepository;
      this.taleRepository = this.catalogGraph.taleRepository;
      this.previewRepository = this.catalogGraph.previewRepository;
      this.searchHistoryRepository = this.catalogGraph.searchHistoryRepository;
      this.imagePreviewActionsState = this.catalogGraph.imagePreviewActions;
      this.catalogGraph.initialize().catch((): void => {
        console.error('Catalog feature initialization failed');
      });
    }
    if (this.settingsState === undefined) {
      if (this.settingsGraph === undefined) {
        throw new Error('Settings feature graph is not initialized');
      }
      this.settingsState = new SettingsViewModel(
        this.settingsGraph.settingsRepository,
        this.settingsGraph.themeModeApplier
      );
    }

    if (this.favoritesState === undefined) {
      if (this.libraryGraph === undefined) {
        throw new Error('Library feature graph is not initialized');
      }
      this.favoritesState = AppStorageV2.connect(
        FavoritesViewModel,
        FAVORITES_STORAGE_KEY,
        () => new FavoritesViewModel(this.libraryGraph!.favoriteRepository)
      )!;
    }

    if (this.readingHistoryState === undefined) {
      if (this.libraryGraph === undefined) {
        throw new Error('Library feature graph is not initialized');
      }
      this.readingHistoryState = AppStorageV2.connect(
        ReadingHistoryViewModel,
        READING_HISTORY_STORAGE_KEY,
        () => new ReadingHistoryViewModel(this.libraryGraph!.readingHistoryRepository)
      )!;
    }

    if (this.researchState === undefined) {
      if (this.libraryGraph === undefined) {
        throw new Error('Library feature graph is not initialized');
      }
      this.researchState = AppStorageV2.connect(
        ResearchProfileViewModel,
        RESEARCH_PROFILE_STORAGE_KEY,
        () => new ResearchProfileViewModel(this.libraryGraph!.researchActivityRepository)
      )!;
    }
    // AppStorageV2 may return an existing shared profile when an ability is
    // recreated in the same process.  The activity coordinator is a separate
    // application service, so ensure it is rebuilt whenever its VM exists but
    // the coordinator itself has not yet been wired.
    if (this.readingActivityState === undefined && this.researchState !== undefined) {
      this.readingActivityState = new ReadingActivityCoord(
        this.researchState,
        this.runtimeClockCapability,
        this.idGeneratorCapability
      );
    }

    // Article's history adapter is wired only after the shared Library VMs
    // exist.  This ordering is important: AppStorageV2 may lazily create the
    // history VM, and the composition root must never read it through a
    // half-initialized accessor while assembling the feature graph.
    if (this.articleGraph === undefined) {
      if (this.catalogGraph === undefined) {
        throw new Error('Catalog feature graph is not initialized');
      }
      const articleMetadata: ArticleMetadataPort = new ArticleMetadataAdapter(
        this.catalogGraph.titleResolver,
        this.catalogGraph.taleRepository
      );
      // Article owns its gateway/parser/view-state adapters; the product only
      // supplies Catalog domain ports assembled above.
      this.articleGraph = createArticleFeatureGraph(context, {
        html: new CatalogArticleHtmlAdapter(this.catalogGraph.articleHtmlRepository),
        history: new ArticleHistoryAdapter(this.readingHistory()),
        metadata: articleMetadata
      });
    }

    // Build feature graphs once in the composition root.  These adapters retain
    // the existing cache tables and are deliberately not exposed to Views.
    if (this.exploreGraph === undefined) {
      if (this.catalogGraph === undefined) {
        throw new Error('Catalog feature graph is not initialized');
      }
      const catalogGraph = this.catalogGraph;
      const exploreDependencies = new CatalogExploreDependenciesAdapter(
        catalogGraph.articleHtmlRepository,
        catalogGraph.previewRepository,
        (): Promise<void> => catalogGraph.initialize(),
        (itemId: string): Promise<string> => catalogGraph.titleResolver.resolve(itemId)
      );
      this.exploreGraph = createExploreFeatureGraph(context, exploreDependencies);
      this.exploreContentUseCase = this.exploreGraph.contentUseCase;
      this.exploreRecommendationUseCase = this.exploreGraph.recommendationUseCase;
      this.exploreGraph.initialize().catch((): void => {
        console.error('Explore feature initialization failed');
      });
    }
    // Catalog repositories are created together by CatalogFeatureFactory above.
    // Keeping this guard as an invariant check prevents a partially assembled
    // product graph from silently falling back to ad-hoc adapters.
    if (this.catalogRepository === undefined || this.taleRepository === undefined ||
      this.previewRepository === undefined || this.searchHistoryRepository === undefined) {
      throw new Error('Catalog feature graph is not initialized');
    }
    if (this.imagePreviewActionsState === undefined) {
      throw new Error('Catalog image preview capability is not initialized');
    }

  }

  settings(): SettingsViewModel {
    if (this.settingsState === undefined) {
      throw new Error('AppContainer must be initialized before loading UI content');
    }
    return this.settingsState;
  }

  favorites(): FavoritesViewModel {
    if (this.favoritesState === undefined) {
      throw new Error('AppContainer must be initialized before loading favorites');
    }
    return this.favoritesState;
  }

  readingHistory(): ReadingHistoryViewModel {
    if (this.readingHistoryState === undefined) {
      throw new Error('AppContainer must be initialized before loading reading history');
    }
    return this.readingHistoryState;
  }

  researchProfile(): ResearchProfileViewModel {
    if (this.researchState === undefined) {
      throw new Error('AppContainer must be initialized before loading research profile');
    }
    return this.researchState;
  }

  readingActivity(): ReadingActivityCoord {
    if (this.readingActivityState === undefined) {
      throw new Error('AppContainer must be initialized before tracking reading activity');
    }
    return this.readingActivityState;
  }

  /** Create a screen-scoped Explore Home ViewModel with injected use cases. */
  createExploreHomeViewModel(): ExploreHomeViewModel {
    if (this.exploreContentUseCase === undefined || this.exploreRecommendationUseCase === undefined) {
      throw new Error('AppContainer must be initialized before creating Explore ViewModels');
    }
    return new ExploreHomeViewModel(this.exploreContentUseCase, this.exploreRecommendationUseCase);
  }

  /** Create a screen-scoped Explore collection VM; mode is supplied by the route adapter. */
  createExploreCollectionVM(): ExploreCollectionVM {
    if (this.exploreContentUseCase === undefined) {
      throw new Error('AppContainer must be initialized before creating Explore ViewModels');
    }
    return new ExploreCollectionVM(this.exploreContentUseCase);
  }

  createCatalogViewModel(): CatalogViewModel {
    if (this.catalogRepository === undefined || this.previewRepository === undefined) {
      throw new Error('AppContainer must be initialized before creating Catalog ViewModels');
    }
    return new CatalogViewModel(
      new CatalogContentUseCase(this.catalogRepository),
      new CatalogPreviewUseCase(this.previewRepository)
    );
  }

  createTaleListViewModel(): TaleListViewModel {
    if (this.taleRepository === undefined) {
      throw new Error('AppContainer must be initialized before creating Tale ViewModels');
    }
    return new TaleListViewModel(new TaleContentUseCase(this.taleRepository));
  }

  createCatalogSearchViewModel(): CatalogSearchViewModel {
    if (this.catalogRepository === undefined || this.searchHistoryRepository === undefined) {
      throw new Error('AppContainer must be initialized before creating Search ViewModels');
    }
    const catalogUseCase = new CatalogContentUseCase(this.catalogRepository);
    const historyUseCase = new SearchHistoryUseCase(this.searchHistoryRepository);
    return new CatalogSearchViewModel(new CatalogSearchUseCase(catalogUseCase, historyUseCase));
  }

  createArticleViewModel(): ArticleViewModel {
    if (this.articleGraph === undefined) {
      throw new Error('AppContainer must be initialized before creating Article ViewModels');
    }
    const readingSession = new ReadingSessionAdapter(
      this.readingActivity(),
      this.idGeneratorCapability
    );
    return this.articleGraph.createViewModel(
      readingSession,
      new ArticleFavoriteAdapter(this.favorites())
    );
  }

  /** Image side effects are injected into the Article View; the View never owns a UIContext. */
  createImagePreviewActions(): ImagePreviewActions {
    if (this.imagePreviewActionsState === undefined) {
      throw new Error('AppContainer must be initialized before creating image preview actions');
    }
    return this.imagePreviewActionsState;
  }

  /** Access the shared archive graph after initialize(context) has run. */
  archive3D(): Archive3DFeatureGraph {
    if (this.archive3DGraph === undefined) {
      throw new Error('AppContainer must be initialized before loading 3D archives');
    }
    return this.archive3DGraph;
  }

  /** Screen VMs receive this use case instead of constructing repositories. */
  archive3DModels(): ArchiveModelUseCase {
    if (this.archive3DUseCaseState === undefined) {
      throw new Error('AppContainer must be initialized before managing 3D archives');
    }
    return this.archive3DUseCaseState;
  }

  /** Register the current manifest descriptors and restore durable tasks. */
  initializeArchive3D(models: ArchiveModelDescriptor[]): Promise<void> {
    return this.archive3D().initialize(models);
  }

  /** Read-only app metadata is exposed as a port; platform bundle APIs stay in common. */
  appInfo(): AppInfoPort {
    return this.appInfoCapability;
  }

  /** Shared platform haptics are exposed as a capability, never as a page singleton. */
  createHapticFeedback(): HapticFeedbackPort {
    return this.hapticFeedbackCapability;
  }

  createLibraryCollectionVM(): LibraryCollectionVM {
    return new LibraryCollectionVM(this.favorites(), this.readingHistory());
  }

  createTerminalViewModel(): TerminalViewModel {
    if (this.catalogGraph === undefined) {
      throw new Error('AppContainer must be initialized before creating Terminal ViewModel');
    }
    const titleResolver = this.catalogGraph.titleResolver;
    return new TerminalViewModel(
      new TerminalFavoritesAdapter(this.favorites()),
      new TerminalReadingHistoryAdapter(this.readingHistory()),
      new TerminalResearchProfileAdapter(this.researchProfile()),
      (ids: string[]): Promise<Map<string, string>> => titleResolver.resolveMany(ids)
    );
  }

  whenFavoritesReady(): Promise<void> {
    return this.favorites().initialize();
  }

  whenReadingHistoryReady(): Promise<void> {
    return this.readingHistory().initialize();
  }

  whenResearchProfileReady(): Promise<void> {
    return this.researchProfile().initialize();
  }

  /**
   * Start non-first-screen persistence after the launch transition has drawn.
   * Catalog and Explore remain initialized in initialize() because Explore is
   * the visible first tab; Library and Article can warm lazily.
   */
  async warmUp(context: common.UIAbilityContext): Promise<void> {
    if (!this.abilityScopeOwner.owns(context)) {
      return;
    }
    const tasks: Promise<void>[] = [];
    if (this.articleGraph !== undefined) {
      tasks.push(this.articleGraph.initialize());
    }
    tasks.push(this.whenFavoritesReady());
    tasks.push(this.whenReadingHistoryReady());
    tasks.push(this.whenResearchProfileReady());
    await Promise.all(tasks);
  }

  ownsAbility(context: common.UIAbilityContext): boolean {
    return this.abilityScopeOwner.owns(context);
  }

  applyInitialTheme(context: common.UIAbilityContext): void {
    if (this.abilityScopeOwner.owns(context)) {
      this.settingsState?.applyThemeMode();
    }
  }

  setReadingActivityForeground(context: common.UIAbilityContext, foreground: boolean): void {
    if (this.abilityScopeOwner.owns(context)) {
      this.readingActivityState?.setAbilityForeground(foreground);
    }
  }

  resetAbility(context: common.UIAbilityContext): void {
    if (this.abilityScopeOwner.owns(context)) {
      this.resetReadingActivity();
    }
  }

  /**
   * Drain application-scoped persistence before an Ability is destroyed.
   * Settings and reading activity own independent queues; wait for both when
   * they have been initialized.
   */
  flushAbility(context: common.UIAbilityContext): Promise<void> {
    if (!this.abilityScopeOwner.owns(context)) {
      return Promise.resolve();
    }
    return this.flush();
  }

  private async flush(): Promise<void> {
    const settingsTask: Promise<void> = this.settingsState === undefined ?
      Promise.resolve() : this.settingsState.flush();
    const readingTask: Promise<void> = this.readingActivityState === undefined ?
      Promise.resolve() : this.readingActivityState.flush();
    await Promise.all([settingsTask, readingTask]);
  }

  /**
   * Flush and release only the graph owned by this exact Ability context.
   * Ownership is checked again after awaiting so a late teardown from Ability
   * A cannot clear a graph that has already been rebuilt for Ability B.
   */
  async releaseAbility(context: common.UIAbilityContext): Promise<void> {
    if (!this.abilityScopeOwner.owns(context)) {
      return;
    }
    this.resetReadingActivity();
    try {
      await this.flush();
    } finally {
      if (this.abilityScopeOwner.release(context)) {
        this.clearAbilityScopedGraph();
      }
    }
  }

  /** Handle a missed/overlapping teardown without retaining the first context. */
  private replaceAbilityScope(): void {
    this.resetReadingActivity();
    const oldFlush: Promise<void> = this.flush();
    this.clearAbilityScopedGraph();
    oldFlush.catch((error: Object): void => {
      console.error(`Ability replacement flush failed: ${this.errorMessage(error)}`);
    });
  }

  private resetReadingActivity(): void {
    this.readingActivityState?.resetAbility();
  }

  /** Remove every product object whose adapter graph was built from a context. */
  private clearAbilityScopedGraph(): void {
    this.settingsState?.dispose();
    this.catalogGraph?.dispose();

    this.settingsState = undefined;
    this.settingsGraph = undefined;
    this.libraryGraph = undefined;
    this.favoritesState = undefined;
    this.readingHistoryState = undefined;
    this.researchState = undefined;
    this.readingActivityState = undefined;
    this.articleGraph = undefined;
    this.exploreGraph = undefined;
    this.exploreContentUseCase = undefined;
    this.exploreRecommendationUseCase = undefined;
    this.catalogGraph = undefined;
    this.catalogRepository = undefined;
    this.taleRepository = undefined;
    this.previewRepository = undefined;
    this.searchHistoryRepository = undefined;
    this.imagePreviewActionsState = undefined;
    // Archive 3D retains only ApplicationContext/request.agent capabilities,
    // never the UIAbilityContext. Keep it process-scoped so an Ability
    // recreation can continue observing durable downloads without creating a
    // second repository or racing a completion callback.

    // AppStorageV2 otherwise keeps the old shared VMs and, through their
    // repositories, the first Ability context even after the container fields
    // are cleared.
    const sharedKeys: string[] = AppStorageV2.keys();
    this.removeSharedStateIfPresent(sharedKeys, FAVORITES_STORAGE_KEY);
    this.removeSharedStateIfPresent(sharedKeys, READING_HISTORY_STORAGE_KEY);
    this.removeSharedStateIfPresent(sharedKeys, RESEARCH_PROFILE_STORAGE_KEY);
  }

  private removeSharedStateIfPresent(keys: string[], key: string): void {
    if (keys.indexOf(key) >= 0) {
      AppStorageV2.remove(key);
    }
  }

  private errorMessage(error: Object): string {
    return error instanceof Error ? error.message : 'unknown error';
  }
}
