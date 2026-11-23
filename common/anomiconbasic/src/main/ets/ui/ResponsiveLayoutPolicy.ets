/**
 * Pure responsive breakpoint, margin and multi-pane layout policy.
 *
 * Kept free of UIContext/Window imports so breakpoint math stays deterministic
 * and directly testable under host unit tests.
 */
export enum AppWidthBreakpoint {
  SM = 'sm',
  MD = 'md',
  LG = 'lg',
  XL = 'xl'
}

export const BREAKPOINT_MD_MIN_WIDTH: number = 600;
export const BREAKPOINT_LG_MIN_WIDTH: number = 840;
export const BREAKPOINT_XL_MIN_WIDTH: number = 1200;

export const READING_CONTENT_MAX_WIDTH: number = 740;
export const WIDE_CONTENT_MAX_WIDTH: number = 1280;
export const CATALOG_CONTENT_MAX_WIDTH: number = 1440;

export const SPLIT_NAVIGATION_MIN_WIDTH: number = 840;
export const SPLIT_NAV_BAR_WIDTH: number = 380;
export const SPLIT_NAV_BAR_MIN_WIDTH: number = 340;
export const SPLIT_NAV_BAR_MAX_WIDTH: number = 440;
export const SPLIT_CONTENT_MIN_WIDTH: number = 500;

export const ARTICLE_SIDEBAR_MIN_WIDTH: number = 680;
export const ARTICLE_SIDEBAR_AUTO_OPEN_MIN_WIDTH: number = 960;
export const ARCHIVE_3D_WORKBENCH_MIN_WIDTH: number = 800;

const PAGE_MARGIN_SM: number = 16;
const PAGE_MARGIN_MD: number = 24;
const PAGE_MARGIN_LG: number = 32;

/** Classify a container or window width (vp) into the app width breakpoint. */
export function resolveWidthBreakpoint(widthVp: number): AppWidthBreakpoint {
  if (!Number.isFinite(widthVp) || widthVp < BREAKPOINT_MD_MIN_WIDTH) {
    return AppWidthBreakpoint.SM;
  }
  if (widthVp < BREAKPOINT_LG_MIN_WIDTH) {
    return AppWidthBreakpoint.MD;
  }
  if (widthVp < BREAKPOINT_XL_MIN_WIDTH) {
    return AppWidthBreakpoint.LG;
  }
  return AppWidthBreakpoint.XL;
}

/**
 * Align page content horizontal margins with HarmonyOS HdsTitleBar padding
 * across SM (16vp), MD (24vp), and LG+ (32vp) container widths.
 */
export function adaptivePageMarginForWidth(widthVp: number): number {
  if (!Number.isFinite(widthVp) || widthVp <= 0) {
    return PAGE_MARGIN_SM;
  }
  const breakpoint = resolveWidthBreakpoint(widthVp);
  switch (breakpoint) {
    case AppWidthBreakpoint.MD:
      return PAGE_MARGIN_MD;
    case AppWidthBreakpoint.LG:
    case AppWidthBreakpoint.XL:
      return PAGE_MARGIN_LG;
    default:
      return PAGE_MARGIN_SM;
  }
}

/** Decide whether a collection/index List renders in 1 or 2 lanes for its measured width. */
export function adaptiveListLanesForWidth(
  widthVp: number,
  minTwoColumnWidth: number = 680
): number {
  if (!Number.isFinite(widthVp) || widthVp <= 0) {
    return 1;
  }
  return widthVp >= minTwoColumnWidth ? 2 : 1;
}

/** Main HdsNavigation switches to Split mode once window width reaches 840vp. */
export function supportsSplitNavigation(windowWidthVp: number): boolean {
  return Number.isFinite(windowWidthVp) && windowWidthVp >= SPLIT_NAVIGATION_MIN_WIDTH;
}

/** Article research side panel can appear starting from 680vp pane width. */
export function supportsArticleSidePanel(containerWidthVp: number): boolean {
  return Number.isFinite(containerWidthVp) && containerWidthVp >= ARTICLE_SIDEBAR_MIN_WIDTH;
}

/** Wide full-screen article canvas (>= 960vp) opens the research panel automatically. */
export function autoOpenArticleSidePanel(containerWidthVp: number): boolean {
  return Number.isFinite(containerWidthVp) && containerWidthVp >= ARTICLE_SIDEBAR_AUTO_OPEN_MIN_WIDTH;
}

/** Sheets prefer centered compact presentation on medium/wide windows (>= 600vp). */
export function shouldUseCenterSheet(windowWidthVp: number): boolean {
  return Number.isFinite(windowWidthVp) && windowWidthVp >= BREAKPOINT_MD_MIN_WIDTH;
}

/** Sidebar width scales modestly between split-pane (288vp) and full-screen (336vp). */
export function resolveArticleSidebarWidth(containerWidthVp: number): number {
  if (!Number.isFinite(containerWidthVp) || containerWidthVp < ARTICLE_SIDEBAR_AUTO_OPEN_MIN_WIDTH) {
    return 288;
  }
  return 336;
}
