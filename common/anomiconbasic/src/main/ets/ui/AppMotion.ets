import { curves } from '@kit.ArkUI';
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

/** Per-destination animated transform state driven by customNavContentTransition. */
@ObservedV2
export class DestinationMotionState {
  @Trace opacity: number = 1;
  @Trace translateX: number = 0;
  @Trace translateY: number = 0;
  @Trace scaleX: number = 1;
  @Trace scaleY: number = 1;

  reset(): void {
    this.opacity = 1;
    this.translateX = 0;
    this.translateY = 0;
    this.scaleX = 1;
    this.scaleY = 1;
  }
}

/** Coordinates NavDestination transform states with Navigation.customNavContentTransition. */
export class NavigationTransitionRegistry {
  private static readonly states: Map<string, DestinationMotionState> = new Map();

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
  }

  static get(id: string | undefined): DestinationMotionState | undefined {
    if (id === undefined || id.length === 0) {
      return undefined;
    }
    return NavigationTransitionRegistry.states.get(id);
  }
}
