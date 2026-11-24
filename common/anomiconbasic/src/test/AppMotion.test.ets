import { describe, expect, it } from '@ohos/hypium';
import {
  CardHeroRect,
  CardHeroTransform,
  CardHeroTransitionSpec,
  computeCardHeroTransform,
  DestinationMotionState,
  isCardHeroRectVisible,
  NavigationTransitionRegistry
} from '../main/ets/ui/AppMotion';

export default function appMotionTest(): void {
  describe('AppMotionHeroGeometryAndRegistry', () => {
    it('computes centered hero transforms and radius scaling for normal cards', 0, () => {
      const rect: CardHeroRect = { x: 16, y: 120, width: 304, height: 372 };
      const transform: CardHeroTransform = computeCardHeroTransform(rect, 336, 744, 24);
      expect(Math.abs(transform.translateX)).assertLess(0.001);
      expect(Math.abs(transform.translateY - (-66))).assertLess(0.001);
      expect(Math.abs(transform.scaleX - (304 / 336))).assertLess(0.001);
      expect(Math.abs(transform.scaleY - 0.5)).assertLess(0.001);
      expect(transform.startRadius > 24 && transform.startRadius <= 96).assertTrue();
    });

    it('clamps extreme small scales and radius, and guards invalid inputs', 0, () => {
      const tinyRect: CardHeroRect = { x: 0, y: 0, width: 10, height: 10 };
      const clamped: CardHeroTransform = computeCardHeroTransform(tinyRect, 400, 800, 32);
      expect(clamped.scaleX).assertEqual(0.25);
      expect(clamped.scaleY).assertEqual(0.25);
      expect(clamped.startRadius).assertEqual(96);

      const zeroRect: CardHeroRect = { x: 10, y: 20, width: 0, height: 100 };
      const fallback: CardHeroTransform = computeCardHeroTransform(zeroRect, 400, 800, 24);
      expect(fallback.scaleX).assertEqual(1);
      expect(fallback.scaleY).assertEqual(1);
      expect(fallback.translateX).assertEqual(0);
      expect(fallback.translateY).assertEqual(0);
      expect(fallback.startRadius).assertEqual(0);
    });

    it('checks whether card hero rectangles remain visible in the viewport', 0, () => {
      expect(isCardHeroRectVisible({ x: 16, y: 100, width: 300, height: 220 }, 744, 336)).assertTrue();
      expect(isCardHeroRectVisible({ x: 16, y: -100, width: 300, height: 220 }, 744, 336)).assertTrue();
      expect(isCardHeroRectVisible({ x: 16, y: -220, width: 300, height: 220 }, 744, 336)).assertFalse();
      expect(isCardHeroRectVisible({ x: 16, y: 744, width: 300, height: 220 }, 744, 336)).assertFalse();
      expect(isCardHeroRectVisible({ x: 0, y: 0, width: 0, height: 100 }, 744, 336)).assertFalse();
    });

    it('resets DestinationMotionState fields back to rest values', 0, () => {
      const state: DestinationMotionState = new DestinationMotionState();
      state.opacity = 0.5;
      state.translateX = 12;
      state.translateY = -44;
      state.scaleX = 0.8;
      state.scaleY = 0.6;
      state.radius = 30;
      state.clipActive = true;

      state.reset();
      expect(state.opacity).assertEqual(1);
      expect(state.translateX).assertEqual(0);
      expect(state.translateY).assertEqual(0);
      expect(state.scaleX).assertEqual(1);
      expect(state.scaleY).assertEqual(1);
      expect(state.radius).assertEqual(0);
      expect(state.clipActive).assertFalse();
    });

    it('manages pending hero specs, route matching, and bound hero cleanup', 0, () => {
      NavigationTransitionRegistry.clearPendingHero();
      const spec: CardHeroTransitionSpec = {
        routeName: 'article',
        sourceId: 'explore-hero-card:scp-001',
        sourceRect: { x: 16, y: 100, width: 304, height: 320 },
        sourceRadius: 24
      };
      NavigationTransitionRegistry.armPendingHero(spec);
      expect(NavigationTransitionRegistry.peekPendingHero('article')?.sourceId).assertEqual(spec.sourceId);
      expect(NavigationTransitionRegistry.peekPendingHero('search') === undefined).assertTrue();

      const mismatched = NavigationTransitionRegistry.consumePendingHero('search');
      expect(mismatched === undefined).assertTrue();
      expect(NavigationTransitionRegistry.peekPendingHero() === undefined).assertTrue();

      NavigationTransitionRegistry.armPendingHero(spec);
      const matched = NavigationTransitionRegistry.consumePendingHero('article');
      expect(matched?.sourceId).assertEqual(spec.sourceId);
      expect(NavigationTransitionRegistry.peekPendingHero() === undefined).assertTrue();

      const state = new DestinationMotionState();
      NavigationTransitionRegistry.register('dest-1', state);
      NavigationTransitionRegistry.bindHero('dest-1', spec);
      expect(NavigationTransitionRegistry.get('dest-1') === state).assertTrue();
      expect(NavigationTransitionRegistry.getBoundHero('dest-1')?.sourceId).assertEqual(spec.sourceId);

      NavigationTransitionRegistry.unbindHero('dest-1');
      expect(NavigationTransitionRegistry.getBoundHero('dest-1') === undefined).assertTrue();

      NavigationTransitionRegistry.bindHero('dest-1', spec);
      NavigationTransitionRegistry.unregister('dest-1');
      expect(NavigationTransitionRegistry.get('dest-1') === undefined).assertTrue();
      expect(NavigationTransitionRegistry.getBoundHero('dest-1') === undefined).assertTrue();
    });
  });
}
