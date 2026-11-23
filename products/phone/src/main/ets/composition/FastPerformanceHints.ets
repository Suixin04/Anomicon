import { schedulingOptimization } from '@kit.FASTKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'AnomiconFastKit';

/**
 * Best-effort wrapper for the API 26 FAST Kit performance hint.
 *
 * FAST Kit is advisory: the system can reject a hint when the device is
 * thermally constrained, in a power-saving mode, or when the call interval
 * does not meet the platform policy.  None of those conditions should make a
 * page or a renderer fail, so requests are serialized and failures are kept
 * at debug level.
 */
export class FastPerformanceHintScope {
  private readonly sceneType: schedulingOptimization.SceneType;
  private readonly durationType: schedulingOptimization.DurationType;
  private capabilityAvailable: boolean | undefined = undefined;
  private activeUsers: number = 0;
  private activeDispatched: boolean = false;
  private lastBeginAtMs: number = 0;
  private requestTail: Promise<void> = Promise.resolve();

  constructor(
    sceneType: schedulingOptimization.SceneType,
    durationType: schedulingOptimization.DurationType
  ) {
    this.sceneType = sceneType;
    this.durationType = durationType;
  }

  /**
   * Starts the hint when the first logical operation enters the scope.
   * Reference counting makes overlapping loads safe: a stale load finishing
   * cannot end a newer load's hint. Cooldown throttling prevents FAST Kit
   * interval errors during rapid navigation.
   */
  begin(): void {
    this.activeUsers++;
    if (this.activeUsers !== 1 || !this.isCapabilityAvailable()) {
      return;
    }
    const now = Date.now();
    if (this.lastBeginAtMs > 0 && now - this.lastBeginAtMs < this.minIntervalMs()) {
      return;
    }
    this.lastBeginAtMs = now;
    this.activeDispatched = true;
    this.enqueue(schedulingOptimization.SceneState.BEGIN);
  }

  /** Ends the hint after the last logical operation leaves the scope. */
  end(): void {
    if (this.activeUsers <= 0) {
      return;
    }
    this.activeUsers--;
    if (this.activeUsers !== 0 || !this.activeDispatched || !this.isCapabilityAvailable()) {
      return;
    }
    this.activeDispatched = false;
    this.enqueue(schedulingOptimization.SceneState.END);
  }

  private minIntervalMs(): number {
    switch (this.durationType) {
      case schedulingOptimization.DurationType.SHORT:
        return 3500;
      case schedulingOptimization.DurationType.MEDIUM:
        return 31000;
      case schedulingOptimization.DurationType.LONG:
      default:
        return 181000;
    }
  }

  private enqueue(sceneState: schedulingOptimization.SceneState): void {
    // FAST Kit is API 26+/device-capability gated.  Keep the import and the
    // feature path harmless on a device image that does not expose the
    // scheduling capability; the rest of the page must still render normally.
    if (!this.isCapabilityAvailable()) {
      return;
    }
    const config: schedulingOptimization.PerfHintConfig = {
      sceneType: this.sceneType,
      sceneState: sceneState,
      // The cold-start hand-off and GLB load are both well below ten seconds
      // on supported devices, matching FAST Kit's MEDIUM policy window.
      durationType: this.durationType,
      // Avoid explicit QoS thread promotion for these UI-owned operations;
      // the API accepts at most 16 entries when a future measured case needs
      // to provide thread IDs.
      tids: []
    };
    this.requestTail = this.requestTail
      .then(async (): Promise<void> => {
        try {
          await schedulingOptimization.perfHint(config);
        } catch (error) {
          const businessError = error as BusinessError;
          hilog.debug(
            DOMAIN,
            TAG,
            'perfHint skipped: %{public}d %{public}s',
            businessError.code,
            businessError.message
          );
        }
      })
      // A diagnostic/logging failure must not poison the queue and suppress
      // future BEGIN/END notifications.
      .catch((): void => {
      });
  }

  private isCapabilityAvailable(): boolean {
    if (this.capabilityAvailable !== undefined) {
      return this.capabilityAvailable;
    }
    try {
      this.capabilityAvailable = canIUse('SystemCapability.FAST.SchedulingOptimization');
    } catch (_error) {
      this.capabilityAvailable = false;
    }
    return this.capabilityAvailable;
  }
}
