/** Network quality tier derived from platform link telemetry. */
export enum NetworkQualityTier {
  GOOD = 'good',
  NORMAL = 'normal',
  WEAK = 'weak',
  SUSPENDED = 'suspended'
}

/** High-level network traffic scenario reported to the platform scheduler. */
export enum NetworkBoostScene {
  BROWSER = 'browser',
  DOWNLOAD = 'download'
}

/** Observed transmission quality reported back to NetworkBoostKit. */
export enum NetworkQoeStatus {
  GOOD = 'good',
  HIGH_LATENCY = 'highLatency',
  SERVER_ERROR = 'serverErr',
  NO_DATA = 'noData'
}

/** Immutable snapshot of the device's current network condition. */
export interface NetworkConditionSnapshot {
  readonly tier: NetworkQualityTier;
  readonly weakSignalPredicted: boolean;
  readonly handoverActive: boolean;
  readonly handoverEpoch: number;
}

export type NetworkConditionListener = (snapshot: NetworkConditionSnapshot) => void;

/** Capability-gated port over platform network boost and handover APIs. */
export interface NetworkBoostPort {
  start(): void;
  stop(): void;
  currentCondition(): NetworkConditionSnapshot;
  subscribe(listener: NetworkConditionListener): () => void;
  enterScene(scene: NetworkBoostScene): () => void;
  reportQoe(scene: NetworkBoostScene, status: NetworkQoeStatus): void;
  setLowPowerMode(enabled: boolean): void;
}
