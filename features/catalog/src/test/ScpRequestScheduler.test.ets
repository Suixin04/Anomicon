import { describe, expect, it } from '@ohos/hypium';
import { ScpHtmlRequestPriority } from '../main/ets/domain/ArticleHtmlRepository';
import { ScpRequestScheduler } from '../main/ets/data/ScpRequestScheduler';

class DeferredGate {
  readonly promise: Promise<void>;
  readonly release: () => void;

  constructor() {
    let resolver: () => void = (): void => {};
    this.promise = new Promise<void>((resolve: () => void): void => {
      resolver = resolve;
    });
    this.release = resolver;
  }
}

export default function scpRequestSchedulerTest(): void {
  describe('ScpRequestScheduler', () => {
    it('uses 4 total / 2 low-priority default concurrency', 0, (): void => {
      const scheduler = new ScpRequestScheduler();
      const policy = scheduler.getConcurrencyPolicy();
      expect(policy.maxConcurrent).assertEqual(4);
      expect(policy.maxLowPriority).assertEqual(2);
    });

    it('holds low-priority tasks under weak policy until raised', 0, async (): Promise<void> => {
      const scheduler = new ScpRequestScheduler();
      scheduler.setConcurrencyPolicy(2, 0);

      const started: string[] = [];
      const gate1 = new DeferredGate();
      const gate2 = new DeferredGate();
      const lowGate = new DeferredGate();

      const high1 = scheduler.run(async (): Promise<void> => {
        started.push('high1');
        await gate1.promise;
      }, ScpHtmlRequestPriority.USER_INITIATED, 'high1');
      const high2 = scheduler.run(async (): Promise<void> => {
        started.push('high2');
        await gate2.promise;
      }, ScpHtmlRequestPriority.VISIBLE, 'high2');
      const low = scheduler.run(async (): Promise<void> => {
        started.push('low');
        await lowGate.promise;
      }, ScpHtmlRequestPriority.PREFETCH, 'low');

      await Promise.resolve();
      expect(started.length).assertEqual(2);
      expect(started.indexOf('low')).assertEqual(-1);

      gate1.release();
      gate2.release();
      await Promise.all([high1, high2]);
      await Promise.resolve();
      // Even after high tasks finish, maxLowPriority=0 keeps PREFETCH waiting.
      expect(started.indexOf('low')).assertEqual(-1);

      scheduler.setConcurrencyPolicy(6, 2);
      await Promise.resolve();
      expect(started.indexOf('low') >= 0).assertTrue();

      lowGate.release();
      await low;
    });

    it('promotes queued prefetch tasks to user priority immediately', 0, async (): Promise<void> => {
      const scheduler = new ScpRequestScheduler(2, 0);
      const order: string[] = [];
      const gate1 = new DeferredGate();

      const blocker = scheduler.run(async (): Promise<void> => {
        order.push('blocker');
        await gate1.promise;
      }, ScpHtmlRequestPriority.USER_INITIATED, 'blocker');

      const queuedPrefetch = scheduler.run(async (): Promise<void> => {
        order.push('promoted');
      }, ScpHtmlRequestPriority.PREFETCH, 'target-url');

      await Promise.resolve();
      expect(order.indexOf('promoted')).assertEqual(-1);

      scheduler.promote('target-url', ScpHtmlRequestPriority.USER_INITIATED);
      await Promise.resolve();
      expect(order.indexOf('promoted') >= 0).assertTrue();

      gate1.release();
      await Promise.all([blocker, queuedPrefetch]);
    });
  });
}
