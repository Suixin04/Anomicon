import {
  LibraryContentRef,
  createLibraryContentRef,
  LibraryCollectionMode,
  parseLibraryContentKind
} from 'library';
import { ExploreCollectionMode } from 'explore';

export { ExploreCollectionMode } from 'explore';
export { LibraryCollectionMode } from 'library';

/** Stable product route names; values are kept compatible with route_map.json. */
export class AppRoutes {
  static readonly SETTINGS: string = 'settings';
  static readonly ABOUT: string = 'about';
  static readonly CONTENT_LICENSE: string = 'contentLicense';
  static readonly ARTICLE: string = 'article';
  static readonly SEARCH: string = 'search';
  static readonly LIBRARY_COLLECTION: string = 'libraryCollection';
  static readonly EXPLORE_COLLECTION: string = 'exploreCollection';
  static readonly ARCHIVE_3D: string = 'archive3d';
  /** Manifest-only index for browsing available three-dimensional archives. */
  static readonly ARCHIVE_3D_GALLERY: string = 'archive3dGallery';
}

export interface ExploreCollectionRouteParams {
  mode: ExploreCollectionMode;
}

export interface LibraryCollectionRouteParams {
  mode: LibraryCollectionMode;
}

/** Strict, serializable payload for the independent three-dimensional view. */
export interface Scp3DArchiveRouteParams {
  readonly content: LibraryContentRef;
}

/** Unified article route payload. Every article route carries one content ref. */
export interface ScpArticleRouteParams {
  readonly content: LibraryContentRef;
}

interface SerializedArticleRouteContent {
  readonly kind?: string;
  readonly id?: string;
  readonly title?: string;
}

/** Rebuild the value object at the route boundary after NavPathStack serialization. */
export function resolveArticleRouteContent(params: ScpArticleRouteParams): LibraryContentRef {
  const raw = params.content as Object | undefined;
  if (raw === undefined || typeof raw !== 'object') {
    throw new Error('内容路由参数无效');
  }
  const candidate = raw as SerializedArticleRouteContent;
  if (candidate.kind === undefined || candidate.id === undefined || candidate.title === undefined) {
    throw new Error('内容路由参数无效');
  }
  const kind = parseLibraryContentKind(candidate.kind);
  if (kind === undefined || candidate.id.trim().length === 0) {
    throw new Error('内容路由参数无效');
  }
  return createLibraryContentRef(kind, candidate.id, candidate.title);
}
