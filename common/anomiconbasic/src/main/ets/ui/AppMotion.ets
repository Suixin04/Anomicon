import { componentUtils, curves, UIContext } from '@kit.ArkUI';
import { accessibility } from '@kit.AccessibilityKit';

/** Queries system reduce-motion preference safely; defaults to false if unavailable. */
export function isReduceMotionEnabled(): boolean {
  try {
    return accessibility.isAnimationReduceEnabledSync();
  } catch (_error) {
    return false;
  }
}

/**
 * Shared motion tokens and system reduce-motion helpers.
 *
 * HarmonyOS physics spring curves (`springMotion` / `responsiveSpringMotion`) ignore
 * `duration: 0`, so every helper explicitly falls back to a zero-duration linear curve
 * when reduce-motion is enabled.
 */
export class AppMotion {
  static readonly PRESS_DURATION: number = 140;
  static readonly MICRO_DURATION: number = 180;
  static readonly STANDARD_DURATION: number = 240;
  static readonly SPLIT_REPLACE_DURATION: number = 220;
  static readonly EMPHASIZED_DURATION: number = 300;

  static springSnappy(): ICurve {
    return curves.springMotion(0.28, 0.86);
  }

  static springGentle(): ICurve {
    return curves.springMotion(0.36, 0.88);
  }

  static springLayout(): ICurve {
    return curves.springMotion(0.38, 0.90);
  }

  static pressAnimateParam(): AnimateParam {
    if (isReduceMotionEnabled()) {
      return { duration: 0, curve: Curve.Linear };
    }
    return { curve: curves.responsiveSpringMotion(0.18, 0.88) };
  }

  static microAnimateParam(): AnimateParam {
    if (isReduceMotionEnabled()) {
      return { duration: 0, curve: Curve.Linear };
    }
    return { duration: AppMotion.MICRO_DURATION, curve: Curve.FastOutSlowIn };
  }

  static standardAnimateParam(duration: number = AppMotion.STANDARD_DURATION): AnimateParam {
    if (isReduceMotionEnabled()) {
      return { duration: 0, curve: Curve.Linear };
    }
    return { duration: duration, curve: Curve.FastOutSlowIn };
  }

  static springAnimateParam(gentle: boolean = true, onFinish?: () => void): AnimateParam {
    if (isReduceMotionEnabled()) {
      return { duration: 0, curve: Curve.Linear, onFinish: onFinish };
    }
    return {
      curve: gentle ? AppMotion.springGentle() : AppMotion.springSnappy(),
      onFinish: onFinish
    };
  }

  static layoutAnimateParam(onFinish?: () => void): AnimateParam {
    if (isReduceMotionEnabled()) {
      return { duration: 0, curve: Curve.Linear, onFinish: onFinish };
    }
    return { curve: AppMotion.springLayout(), onFinish: onFinish };
  }

  static fadeTransition(duration: number = AppMotion.MICRO_DURATION): TransitionEffect {
    if (isReduceMotionEnabled()) {
      return TransitionEffect.IDENTITY;
    }
    return TransitionEffect.OPACITY.animation({ duration: duration, curve: Curve.EaseOut });
  }

  static slideUpFadeTransition(
    offsetY: number = 8,
    duration: number = AppMotion.MICRO_DURATION
  ): TransitionEffect {
    if (isReduceMotionEnabled()) {
      return TransitionEffect.IDENTITY;
    }
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: offsetY }))
      .animation({ duration: duration, curve: Curve.FastOutSlowIn });
  }

  static panelEdgeTransition(edge: TransitionEdge): TransitionEffect {
    if (isReduceMotionEnabled()) {
      return TransitionEffect.IDENTITY;
    }
    return TransitionEffect.OPACITY
      .combine(TransitionEffect.move(edge))
      .animation(AppMotion.springAnimateParam(true));
  }
}

/** Window-coordinate rectangle (in vp) captured from an anchor component. */
export interface CardHeroRect {
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
}

/** Initial or target transform aligning a full-screen destination with a card rect. */
export interface CardHeroTransform {
  readonly translateX: number;
  readonly translateY: number;
  readonly scaleX: number;
  readonly scaleY: number;
  readonly startRadius: number;
}

/** Pending or active card-to-destination morph specification. */
export interface CardHeroTransitionSpec {
  readonly routeName: string;
  readonly sourceId: string;
  readonly sourceRect: CardHeroRect;
  readonly sourceRadius: number;
}

function clampHeroValue(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

/** Computes the transform that maps a viewport-sized page onto the given card rect. */
export function computeCardHeroTransform(
  rect: CardHeroRect,
  viewportWidth: number,
  viewportHeight: number,
  sourceRadius: number = 24
): CardHeroTransform {
  if (
    viewportWidth <= 0 ||
    viewportHeight <= 0 ||
    rect.width <= 0 ||
    rect.height <= 0
  ) {
    return {
      translateX: 0,
      translateY: 0,
      scaleX: 1,
      scaleY: 1,
      startRadius: 0
    };
  }
  const scaleX: number = clampHeroValue(rect.width / viewportWidth, 0.25, 1.0);
  const scaleY: number = clampHeroValue(rect.height / viewportHeight, 0.25, 1.0);
  const translateX: number = (rect.x + rect.width * 0.5) - viewportWidth * 0.5;
  const translateY: number = (rect.y + rect.height * 0.5) - viewportHeight * 0.5;
  const avgScale: number = (scaleX + scaleY) * 0.5;
  const startRadius: number =
    sourceRadius > 0 && avgScale > 0
      ? clampHeroValue(sourceRadius / avgScale, 0, 96)
      : 0;
  return {
    translateX: translateX,
    translateY: translateY,
    scaleX: scaleX,
    scaleY: scaleY,
    startRadius: startRadius
  };
}

/** Returns true when a captured card rectangle is still visible inside the viewport. */
export function isCardHeroRectVisible(
  rect: CardHeroRect,
  viewportHeight: number,
  viewportWidth: number = 0
): boolean {
  if (rect.width <= 1 || rect.height <= 1 || viewportHeight <= 0) {
    return false;
  }
  if (rect.y + rect.height <= 0 || rect.y >= viewportHeight) {
    return false;
  }
  if (viewportWidth > 0 && (rect.x + rect.width <= 0 || rect.x >= viewportWidth)) {
    return false;
  }
  return true;
}

/** Reads a mounted component's window rectangle in vp by id, or undefined on failure. */
export function captureWindowRectById(
  uiContext: UIContext,
  componentId: string
): CardHeroRect | undefined {
  if (componentId.length === 0) {
    return undefined;
  }
  try {
    const info: componentUtils.ComponentInfo =
      uiContext.getComponentUtils().getRectangleById(componentId);
    const width: number = uiContext.px2vp(info.size.width);
    const height: number = uiContext.px2vp(info.size.height);
    if (!(width > 1 && height > 1)) {
      return undefined;
    }
    const x: number = uiContext.px2vp(info.windowOffset.x);
    const y: number = uiContext.px2vp(info.windowOffset.y);
    return {
      x: x,
      y: y,
      width: width,
      height: height
    };
  } catch {
    return undefined;
  }
}

/** Per-destination animated transform state driven by customNavContentTransition. */
@ObservedV2
export class DestinationMotionState {
  @Trace opacity: number = 1;
  @Trace translateX: number = 0;
  @Trace translateY: number = 0;
  @Trace scaleX: number = 1;
  @Trace scaleY: number = 1;
  @Trace radius: number = 0;
  @Trace clipActive: boolean = false;

  reset(): void {
    this.opacity = 1;
    this.translateX = 0;
    this.translateY = 0;
    this.scaleX = 1;
    this.scaleY = 1;
    this.radius = 0;
    this.clipActive = false;
  }
}

/** Coordinates NavDestination transform states with Navigation.customNavContentTransition. */
export class NavigationTransitionRegistry {
  private static readonly states: Map<string, DestinationMotionState> = new Map();
  private static readonly boundHeroes: Map<string, CardHeroTransitionSpec> = new Map();
  private static pendingHero: CardHeroTransitionSpec | undefined = undefined;

  static register(id: string | undefined, state: DestinationMotionState): void {
    if (id === undefined || id.length === 0) {
      return;
    }
    NavigationTransitionRegistry.states.set(id, state);
  }

  static unregister(id: string | undefined): void {
    if (id === undefined || id.length === 0) {
      return;
    }
    NavigationTransitionRegistry.states.delete(id);
    NavigationTransitionRegistry.boundHeroes.delete(id);
  }

  static get(id: string | undefined): DestinationMotionState | undefined {
    if (id === undefined || id.length === 0) {
      return undefined;
    }
    return NavigationTransitionRegistry.states.get(id);
  }

  static armPendingHero(spec: CardHeroTransitionSpec): void {
    NavigationTransitionRegistry.pendingHero = spec;
  }

  static clearPendingHero(): void {
    NavigationTransitionRegistry.pendingHero = undefined;
  }

  static peekPendingHero(routeName?: string): CardHeroTransitionSpec | undefined {
    const current: CardHeroTransitionSpec | undefined =
      NavigationTransitionRegistry.pendingHero;
    if (current === undefined) {
      return undefined;
    }
    if (routeName !== undefined && current.routeName !== routeName) {
      return undefined;
    }
    return current;
  }

  static consumePendingHero(routeName: string): CardHeroTransitionSpec | undefined {
    const current: CardHeroTransitionSpec | undefined =
      NavigationTransitionRegistry.pendingHero;
    NavigationTransitionRegistry.pendingHero = undefined;
    if (current === undefined || current.routeName !== routeName) {
      return undefined;
    }
    return current;
  }

  static bindHero(navDestinationId: string | undefined, spec: CardHeroTransitionSpec): void {
    if (navDestinationId === undefined || navDestinationId.length === 0) {
      return;
    }
    NavigationTransitionRegistry.boundHeroes.set(navDestinationId, spec);
  }

  static getBoundHero(navDestinationId: string | undefined): CardHeroTransitionSpec | undefined {
    if (navDestinationId === undefined || navDestinationId.length === 0) {
      return undefined;
    }
    return NavigationTransitionRegistry.boundHeroes.get(navDestinationId);
  }

  static unbindHero(navDestinationId: string | undefined): void {
    if (navDestinationId === undefined || navDestinationId.length === 0) {
      return;
    }
    NavigationTransitionRegistry.boundHeroes.delete(navDestinationId);
  }
}
