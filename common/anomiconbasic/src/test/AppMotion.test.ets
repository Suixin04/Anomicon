import { describe, expect, it } from '@ohos/hypium';
import {
  DestinationMotionState,
  NavigationTransitionRegistry
} from '../main/ets/ui/AppMotion';

export default function appMotionTest(): void {
  describe('AppMotionDestinationTransitionRegistry', () => {
    it('resets DestinationMotionState fields back to rest values', 0, () => {
      const state: DestinationMotionState = new DestinationMotionState();
      state.opacity = 0.5;
      state.translateX = 12;
      state.translateY = -44;
      state.scaleX = 0.8;
      state.scaleY = 0.6;

      state.reset();
      expect(state.opacity).assertEqual(1);
      expect(state.translateX).assertEqual(0);
      expect(state.translateY).assertEqual(0);
      expect(state.scaleX).assertEqual(1);
      expect(state.scaleY).assertEqual(1);
    });

    it('registers, resolves, and unregisters DestinationMotionState by id', 0, () => {
      const state: DestinationMotionState = new DestinationMotionState();
      NavigationTransitionRegistry.register('dest-1', state);
      expect(NavigationTransitionRegistry.get('dest-1') === state).assertTrue();
      expect(NavigationTransitionRegistry.get('') === undefined).assertTrue();
      expect(NavigationTransitionRegistry.get(undefined) === undefined).assertTrue();

      NavigationTransitionRegistry.unregister('dest-1');
      expect(NavigationTransitionRegistry.get('dest-1') === undefined).assertTrue();
    });
  });
}
