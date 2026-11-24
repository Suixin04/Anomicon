import {
  ExploreCollectionMode
} from 'explore';
import {
  LibraryCollectionMode,
  LibraryContentRef
} from 'library';
import {
  ArticleHeroPreview,
  ExploreCollectionRouteParams,
  LibraryCollectionRouteParams,
  ScpArticleRouteParams,
  Scp3DArchiveRouteParams,
  resolveArticleRouteContent
} from './AppRoutes';
import { LibraryContentKind } from 'library';

/**
 * Product-owned route boundary.
 *
 * Router payloads are untrusted serialized values.  These helpers normalize
 * and validate them before a destination activates a screen ViewModel.  They
 * deliberately return only domain values; no NavPathStack or UI object is
 * allowed to leak into feature code.
 */
export function parseExploreCollectionRoute(
  param: Object | null | undefined
): ExploreCollectionRouteParams | undefined {
  if (param === undefined || param === null || typeof param !== 'object') {
    return undefined;
  }
  const candidate = param as ExploreCollectionRouteParams;
  if (candidate.mode !== ExploreCollectionMode.RECENT &&
    candidate.mode !== ExploreCollectionMode.JOKE) {
    return undefined;
  }
  return { mode: candidate.mode };
}

export function parseLibraryCollectionRoute(
  param: Object | null | undefined
): LibraryCollectionRouteParams | undefined {
  if (param === undefined || param === null || typeof param !== 'object') {
    return undefined;
  }
  const candidate = param as LibraryCollectionRouteParams;
  if (candidate.mode !== LibraryCollectionMode.FAVORITES &&
    candidate.mode !== LibraryCollectionMode.CONTINUE_READING &&
    candidate.mode !== LibraryCollectionMode.RECENT) {
    return undefined;
  }
  return { mode: candidate.mode };
}

export function parseArticleRouteContent(
  param: Object | null | undefined
): LibraryContentRef | undefined {
  if (param === undefined || param === null || typeof param !== 'object') {
    return undefined;
  }
  const candidate = param as ScpArticleRouteParams;
  try {
    return resolveArticleRouteContent(candidate);
  } catch (_error) {
    return undefined;
  }
}

/**
 * Reuse the article value-object parser, then narrow the route to SCP items.
 * A malformed or non-SCP payload never reaches Scene.load or the renderer.
 */
export function parseScp3DArchiveRoute(
  param: Object | null | undefined
): Scp3DArchiveRouteParams | undefined {
  if (param === undefined || param === null || typeof param !== 'object') {
    return undefined;
  }
  const content = parseArticleRouteContent(param);
  if (content === undefined || content.kind !== LibraryContentKind.SCP) {
    return undefined;
  }
  return { content: content };
}

interface ArticleHeroPreviewCandidate {
  imageSource?: string;
  description?: string;
}

interface ArticleRouteHeroCandidate {
  heroPreview?: ArticleHeroPreviewCandidate;
}

/** Extracts optional hero cover/summary passed from Explore for synchronous Frame-0 landing. */
export function parseArticleRouteHeroPreview(
  param: Object | null | undefined
): ArticleHeroPreview | undefined {
  if (param === undefined || param === null || typeof param !== 'object') {
    return undefined;
  }
  const candidate = param as ArticleRouteHeroCandidate;
  const preview = candidate.heroPreview;
  if (preview === undefined || preview === null || typeof preview !== 'object') {
    return undefined;
  }
  const imageSource: string | undefined =
    typeof preview.imageSource === 'string' && preview.imageSource.length > 0
      ? preview.imageSource
      : undefined;
  const description: string | undefined =
    typeof preview.description === 'string' && preview.description.length > 0
      ? preview.description
      : undefined;
  if (imageSource === undefined && description === undefined) {
    return undefined;
  }
  return {
    imageSource: imageSource,
    description: description
  };
}
