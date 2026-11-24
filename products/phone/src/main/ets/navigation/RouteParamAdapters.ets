import {
  ExploreCollectionMode
} from 'explore';
import {
  LibraryCollectionMode,
  LibraryContentRef,
  RaisaFeedbackContext,
  emptyRaisaFeedbackContext,
  normalizeAssessmentExamId,
  normalizeSeriesPageId,
  parseRaisaFeedbackCategory
} from 'library';
import { normalizeArticleAnchor } from 'article';
import {
  ExploreCollectionRouteParams,
  FoundationAssessmentRouteParams,
  LibraryCollectionRouteParams,
  RaisaFeedbackRouteParams,
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

export function parseArticleRouteOfflineCopy(param: Object | null | undefined): boolean {
  return param !== null && typeof param === 'object' && (param as ScpArticleRouteParams).offlineCopy === true;
}

export function parseArticleRouteAnchor(
  param: Object | null | undefined
): string {
  if (param === undefined || param === null || typeof param !== 'object') {
    return '';
  }
  const candidate = param as ScpArticleRouteParams;
  if (typeof candidate.anchor !== 'string') {
    return '';
  }
  return normalizeArticleAnchor(candidate.anchor);
}

export function parseArticleRouteSeriesId(
  param: Object | null | undefined
): string {
  if (param === undefined || param === null || typeof param !== 'object') {
    return '';
  }
  const candidate = param as ScpArticleRouteParams;
  if (typeof candidate.seriesId !== 'string') {
    return '';
  }
  return normalizeSeriesPageId(candidate.seriesId);
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

export function parseAssessmentRouteExamId(
  param: Object | null | undefined
): string {
  if (param === undefined || param === null || typeof param !== 'object') {
    return '';
  }
  const candidate = param as FoundationAssessmentRouteParams;
  if (typeof candidate.examId !== 'string') {
    return '';
  }
  return normalizeAssessmentExamId(candidate.examId);
}

export function parseFeedbackRouteContext(
  param: Object | null | undefined
): RaisaFeedbackContext {
  if (param === undefined || param === null || typeof param !== 'object') {
    return emptyRaisaFeedbackContext('settings');
  }
  const candidate = param as RaisaFeedbackRouteParams;
  const entrySource = typeof candidate.entrySource === 'string' && candidate.entrySource.trim().length > 0 ?
    candidate.entrySource.trim() : 'settings';
  const initialCategory = typeof candidate.initialCategory === 'string' ?
    parseRaisaFeedbackCategory(candidate.initialCategory) :
    emptyRaisaFeedbackContext(entrySource).initialCategory;
  const articleId = typeof candidate.articleId === 'string' ? candidate.articleId.trim() : '';
  const articleTitle = typeof candidate.articleTitle === 'string' ? candidate.articleTitle.trim() : '';
  const articleKind = typeof candidate.articleKind === 'string' ? candidate.articleKind.trim() : '';
  const articleUrl = typeof candidate.articleUrl === 'string' ? candidate.articleUrl.trim() : '';
  const renderMode = typeof candidate.renderMode === 'string' ? candidate.renderMode.trim() : '';
  const revealHiddenText = candidate.revealHiddenText === true;
  return new RaisaFeedbackContext(
    entrySource,
    initialCategory,
    articleId,
    articleTitle,
    articleKind,
    articleUrl,
    renderMode,
    revealHiddenText
  );
}
