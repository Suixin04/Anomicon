import { SettingsPageBuilder } from '../SettingsPage';
import { AboutPageBuilder } from '../AboutPage';
import { ContentLicensePageBuilder } from '../ContentLicensePage';
import { ScpArticlePageBuilder } from '../ScpArticlePage';
import { ScpSearchPageBuilder } from '../ScpSearchPage';
import { LibraryCollectionPageBuilder } from '../LibraryCollectionPage';
import { ExploreCollectionPageBuilder } from '../ExploreCollectionPage';
import {
  Scp3DArchivePageBuilder,
  Scp3DArchiveSceneSourceResolver
} from '../Scp3DArchivePage';
import {
  Scp3DArchiveGalleryPageBuilder,
  Scp3DArchiveInstallActions,
  Scp3DArchiveInstallState
} from '../Scp3DArchiveGalleryPage';
import { AppContainer } from '../../composition/AppContainer';
import {
  ArchiveModelInstallSnapshot,
  ArchiveModelInstallState,
  ArchiveSceneSource,
  Scp3DAssetDelivery,
  Scp3DAssetManifestEntry,
  Scp3DModelAsset,
  describeScp3DAsset,
  hasScp3DModel,
  resolveScp3DModelAsset
} from 'archive3d';

/**
 * Route adapters are deliberately boring: route_map only knows these product
 * builders, while each feature page remains free to evolve its ViewModel.
 * Screen-scoped ViewModels and cross-cutting ports are assembled here from
 * the product composition root; page components receive only those narrow
 * capabilities and never reach into AppContainer themselves.
 */
@Builder
export function SettingsRouteAdapter() {
  SettingsPageBuilder(
    AppContainer.getInstance().settings(),
    AppContainer.getInstance().appInfo(),
    AppContainer.getInstance().createHapticFeedback(),
    AppContainer.getInstance().createSettingsStorageActions()
  );
}
@Builder
export function AboutRouteAdapter() {
  AboutPageBuilder(AppContainer.getInstance().appInfo());
}

@Builder
export function ContentLicenseRouteAdapter() {
  ContentLicensePageBuilder();
}

@Builder
export function ArticleRouteAdapter() {
  ScpArticlePageBuilder(
    AppContainer.getInstance().createArticleViewModel(),
    AppContainer.getInstance().createImagePreviewActions(),
    AppContainer.getInstance().createHapticFeedback(),
    AppContainer.getInstance().settings(),
    AppContainer.getInstance().researchProfile(),
    AppContainer.getInstance().storySeries(),
    (contentId: string): boolean => hasScp3DModel(contentId),
    AppContainer.getInstance().networkBoost()
  );
}

@Builder
export function SearchRouteAdapter() {
  ScpSearchPageBuilder(
    AppContainer.getInstance().createCatalogSearchViewModel(),
    AppContainer.getInstance().settings()
  );
}

@Builder
export function LibraryCollectionRouteAdapter() {
  LibraryCollectionPageBuilder(AppContainer.getInstance().createLibraryCollectionVM());
}

@Builder
export function ExploreCollectionRouteAdapter() {
  ExploreCollectionPageBuilder(AppContainer.getInstance().createExploreCollectionVM());
}

@Builder
export function Scp3DArchiveRouteAdapter() {
  Scp3DArchivePageBuilder(
    resolveArchive3DSceneSource,
    AppContainer.getInstance().settings()
  );
}

/**
 * Resolve a viewer source through the application-owned package repository.
 * A remote URL is never handed to ArkGraphics3D: the repository first checks
 * the content-addressed, hash-verified private cache.
 */
const resolveArchive3DSceneSource: Scp3DArchiveSceneSourceResolver =
  async (asset: Scp3DModelAsset): Promise<ArchiveSceneSource> => {
    const descriptor = describeScp3DAsset(asset, asset.downloadUrl);
    return AppContainer.getInstance().archive3DModels().resolve(descriptor);
  };

/**
 * Keep repository/domain objects out of the gallery component.  This adapter
 * translates immutable archive snapshots into the small UI state enum and
 * derives descriptors only at the product composition edge.
 */
class Archive3DInstallActionsAdapter implements Scp3DArchiveInstallActions {
  private readonly useCase = AppContainer.getInstance().archive3DModels();
  private readonly states: Map<string, Scp3DArchiveInstallState> = new Map();

  status(entry: Scp3DAssetManifestEntry): Scp3DArchiveInstallState {
    return this.states.get(entry.assetId) ??
      (entry.delivery === Scp3DAssetDelivery.BUNDLED ?
        Scp3DArchiveInstallState.BUNDLED : Scp3DArchiveInstallState.NOT_INSTALLED);
  }

  subscribe(
    entry: Scp3DAssetManifestEntry,
    listener: (state: Scp3DArchiveInstallState) => void
  ): () => void {
    const descriptor = this.descriptor(entry);
    const unsubscribe = this.useCase.subscribe(descriptor, (snapshot: ArchiveModelInstallSnapshot): void => {
      const state = this.mapState(snapshot);
      this.states.set(entry.assetId, state);
      listener(state);
    });
    this.useCase.snapshot(descriptor).catch((): void => {
      // An unavailable request-agent service should not make the gallery
      // route fail; the card simply remains in its previous state.
    });
    return unsubscribe;
  }

  install(entry: Scp3DAssetManifestEntry): Promise<void> {
    return this.useCase.install(this.descriptor(entry));
  }

  remove(entry: Scp3DAssetManifestEntry): Promise<void> {
    return this.useCase.remove(this.descriptor(entry));
  }

  private descriptor(entry: Scp3DAssetManifestEntry) {
    const asset = resolveScp3DModelAsset(entry.contentId);
    if (asset === undefined) {
      throw new Error('三维档案清单条目不存在');
    }
    return describeScp3DAsset(asset, entry.downloadUrl);
  }

  private mapState(snapshot: ArchiveModelInstallSnapshot): Scp3DArchiveInstallState {
    switch (snapshot.state) {
      case ArchiveModelInstallState.BUNDLED: return Scp3DArchiveInstallState.BUNDLED;
      case ArchiveModelInstallState.READY: return Scp3DArchiveInstallState.READY;
      case ArchiveModelInstallState.QUEUED: return Scp3DArchiveInstallState.QUEUED;
      case ArchiveModelInstallState.WAITING: return Scp3DArchiveInstallState.WAITING;
      case ArchiveModelInstallState.PAUSED: return Scp3DArchiveInstallState.DOWNLOADING;
      case ArchiveModelInstallState.DOWNLOADING: return Scp3DArchiveInstallState.DOWNLOADING;
      case ArchiveModelInstallState.VERIFYING: return Scp3DArchiveInstallState.VERIFYING;
      case ArchiveModelInstallState.FAILED: return Scp3DArchiveInstallState.FAILED;
      default: return Scp3DArchiveInstallState.NOT_INSTALLED;
    }
  }
}

/** Archive index with application-scoped install/delete actions. */
@Builder
export function Scp3DArchiveGalleryRouteAdapter() {
  Scp3DArchiveGalleryPageBuilder(
    undefined,
    undefined,
    new Archive3DInstallActionsAdapter(),
    AppContainer.getInstance().settings()
  );
}
