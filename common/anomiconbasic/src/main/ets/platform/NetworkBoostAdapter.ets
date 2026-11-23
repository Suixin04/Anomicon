import { netBoost, netHandover, netQuality } from '@kit.NetworkBoostKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  NetworkBoostPort,
  NetworkBoostScene,
  NetworkConditionListener,
  NetworkConditionSnapshot,
  NetworkQoeStatus,
  NetworkQualityTier
} from './NetworkBoostContracts';

const DOMAIN: number = 0x0000;
const TAG: string = 'AnomiconNetworkBoost';
const QOE_REPORT_COOLDOWN_MS: number = 2000;

/**
 * Capability-gated HarmonyOS `@kit.NetworkBoostKit` adapter.
 *
 * Emulators or hardware builds that omit `SystemCapability.Communication.NetworkBoost.Core`
 * (or reject a sub-API at runtime) remain smoothly in `NetworkQualityTier.NORMAL`
 * without disrupting normal HTTP or download execution.
 */
export class NetworkBoostAdapter implements NetworkBoostPort {
  private capabilityAvailable: boolean | undefined = undefined;
  private started: boolean = false;
  private sceneSubscribed: boolean = false;
  private qosSubscribed: boolean = false;
  private handoverSubscribed: boolean = false;

  private sceneTier: NetworkQualityTier = NetworkQualityTier.NORMAL;
  private qosTier: NetworkQualityTier = NetworkQualityTier.NORMAL;
  private handoverTier: NetworkQualityTier = NetworkQualityTier.WEAK;
  private weakSignalPredicted: boolean = false;
  private handoverActive: boolean = false;
  private handoverEpoch: number = 0;

  private currentSnapshot: NetworkConditionSnapshot = {
    tier: NetworkQualityTier.NORMAL,
    weakSignalPredicted: false,
    handoverActive: false,
    handoverEpoch: 0
  };

  private readonly listeners: NetworkConditionListener[] = [];
  private readonly activeSceneCounts: Map<NetworkBoostScene, number> = new Map();
  private readonly lastQoeReportAt: Map<string, number> = new Map();

  private readonly sceneChangeCallback = (scenes: Array<netQuality.NetworkScene>): void => {
    this.handleSceneChange(scenes);
  };

  private readonly qosChangeCallback = (qosList: Array<netQuality.NetworkQos>): void => {
    this.handleQosChange(qosList);
  };

  private readonly handoverChangeCallback = (info: netHandover.HandoverInfo): void => {
    this.handleHandoverChange(info);
  };

  start(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    if (!this.isCapabilityAvailable()) {
      hilog.info(DOMAIN, TAG, '%{public}s', 'NetworkBoost capability unavailable; staying in NORMAL tier');
      return;
    }

    try {
      netQuality.on('netSceneChange', this.sceneChangeCallback);
      this.sceneSubscribed = true;
    } catch (error) {
      this.logUnavailable('netSceneChange', error as Object);
    }

    try {
      netQuality.on('netQosChange', this.qosChangeCallback);
      this.qosSubscribed = true;
    } catch (error) {
      this.logUnavailable('netQosChange', error as Object);
    }

    try {
      netHandover.on('handoverChange', this.handoverChangeCallback);
      this.handoverSubscribed = true;
    } catch (error) {
      this.logUnavailable('handoverChange', error as Object);
    }
  }

  stop(): void {
    if (!this.started) {
      return;
    }
    this.started = false;
    if (this.sceneSubscribed) {
      this.sceneSubscribed = false;
      try {
        netQuality.off('netSceneChange', this.sceneChangeCallback);
      } catch (_error) {
      }
    }
    if (this.qosSubscribed) {
      this.qosSubscribed = false;
      try {
        netQuality.off('netQosChange', this.qosChangeCallback);
      } catch (_error) {
      }
    }
    if (this.handoverSubscribed) {
      this.handoverSubscribed = false;
      try {
        netHandover.off('handoverChange', this.handoverChangeCallback);
      } catch (_error) {
      }
    }

    const activeScenes = Array.from(this.activeSceneCounts.entries());
    this.activeSceneCounts.clear();
    for (let index: number = 0; index < activeScenes.length; index++) {
      const scene = activeScenes[index][0];
      const count = activeScenes[index][1];
      if (count > 0) {
        this.sendSceneEvent(scene, netBoost.SceneEvent.SCENE_EVENT_LEAVE);
      }
    }
    this.lastQoeReportAt.clear();
  }

  currentCondition(): NetworkConditionSnapshot {
    return this.currentSnapshot;
  }

  subscribe(listener: NetworkConditionListener): () => void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
    try {
      listener(this.currentSnapshot);
    } catch (_error) {
    }
    return (): void => {
      const index = this.listeners.indexOf(listener);
      if (index >= 0) {
        this.listeners.splice(index, 1);
      }
    };
  }

  enterScene(scene: NetworkBoostScene): () => void {
    const previousCount = this.activeSceneCounts.get(scene) ?? 0;
    this.activeSceneCounts.set(scene, previousCount + 1);
    if (previousCount === 0 && this.isCapabilityAvailable()) {
      this.sendSceneEvent(scene, netBoost.SceneEvent.SCENE_EVENT_ENTER);
    }
    let released: boolean = false;
    return (): void => {
      if (released) {
        return;
      }
      released = true;
      const currentCount = this.activeSceneCounts.get(scene) ?? 0;
      if (currentCount <= 0) {
        return;
      }
      const nextCount = currentCount - 1;
      if (nextCount === 0) {
        this.activeSceneCounts.delete(scene);
        if (this.isCapabilityAvailable()) {
          this.sendSceneEvent(scene, netBoost.SceneEvent.SCENE_EVENT_LEAVE);
        }
      } else {
        this.activeSceneCounts.set(scene, nextCount);
      }
    };
  }

  reportQoe(scene: NetworkBoostScene, status: NetworkQoeStatus): void {
    if (!this.isCapabilityAvailable()) {
      return;
    }
    const now = Date.now();
    const cooldownKey = `${scene}:${status}`;
    const previousAt = this.lastQoeReportAt.get(cooldownKey) ?? 0;
    if (now - previousAt < QOE_REPORT_COOLDOWN_MS) {
      return;
    }
    this.lastQoeReportAt.set(cooldownKey, now);
    try {
      netQuality.reportQoe({
        serviceType: this.serviceTypeForScene(scene),
        qoeType: this.qoeTypeForStatus(status)
      });
    } catch (error) {
      this.logUnavailable('reportQoe', error as Object);
    }
  }

  setLowPowerMode(enabled: boolean): void {
    if (!this.isCapabilityAvailable()) {
      return;
    }
    try {
      netBoost.setLowPowerMode(enabled);
    } catch (error) {
      this.logUnavailable('setLowPowerMode', error as Object);
    }
  }

  private handleSceneChange(scenes: Array<netQuality.NetworkScene>): void {
    let nextSceneTier: NetworkQualityTier = NetworkQualityTier.NORMAL;
    let sawIncrease: boolean = false;
    let predictedWeak: boolean = false;

    for (let index: number = 0; index < scenes.length; index++) {
      const item = scenes[index];
      const prediction = item.weakSignalPrediction;
      if (prediction !== undefined && prediction.isLastPredictionValid && prediction.duration > 0) {
        predictedWeak = true;
      }
      if (item.recommendedAction === 'suspendData') {
        nextSceneTier = NetworkQualityTier.SUSPENDED;
        break;
      }
      if (item.scene === 'weakSignal' ||
        item.scene === 'congestion' ||
        item.scene === 'frequentHandover' ||
        item.recommendedAction === 'decreaseData' ||
        (prediction !== undefined &&
          prediction.isLastPredictionValid &&
          prediction.duration > 0 &&
          prediction.startTime <= 10)) {
        nextSceneTier = NetworkQualityTier.WEAK;
      } else if (item.scene === 'normal' && item.recommendedAction === 'increaseData') {
        sawIncrease = true;
      }
    }

    if (nextSceneTier === NetworkQualityTier.NORMAL && sawIncrease) {
      nextSceneTier = NetworkQualityTier.GOOD;
    }

    this.sceneTier = nextSceneTier;
    this.weakSignalPredicted = predictedWeak;
    this.publishIfChanged();
  }

  private handleQosChange(qosList: Array<netQuality.NetworkQos>): void {
    if (qosList.length === 0) {
      return;
    }
    let bestTier: NetworkQualityTier = NetworkQualityTier.WEAK;
    let evaluatedAny: boolean = false;

    for (let index: number = 0; index < qosList.length; index++) {
      const item = qosList[index];
      const rttMs = item.rttMs;
      const downBps = item.linkDownBandwidth;
      const candidateTier = this.evaluateQosTier(rttMs, downBps);
      if (!evaluatedAny || this.tierRank(candidateTier) > this.tierRank(bestTier)) {
        bestTier = candidateTier;
        evaluatedAny = true;
      }
    }

    if (!evaluatedAny) {
      return;
    }
    this.qosTier = bestTier;
    this.publishIfChanged();
  }

  private handleHandoverChange(info: netHandover.HandoverInfo): void {
    if (info.handoverStart !== undefined) {
      this.handoverActive = true;
      this.handoverTier =
        info.handoverStart.dataSpeedAction.dataSpeedSimpleAction === 'suspendData' ?
          NetworkQualityTier.SUSPENDED : NetworkQualityTier.WEAK;
      this.publishIfChanged();
      return;
    }

    if (info.handoverComplete !== undefined) {
      const complete = info.handoverComplete;
      this.handoverActive = false;
      if (complete.result === netHandover.ErrorResult.ERROR_NONE &&
        (complete.reEstAction !== netHandover.ReEstAction.NO_EST || complete.pathTypeChanged)) {
        this.handoverEpoch++;
      }
      this.qosTier = NetworkQualityTier.NORMAL;
      this.sceneTier = this.mapSpeedAction(complete.newDataSpeedAction.dataSpeedSimpleAction);
      this.publishIfChanged();
    }
  }

  private evaluateQosTier(rttMs: number, linkDownBandwidth: number): NetworkQualityTier {
    if (rttMs >= 600 || (linkDownBandwidth > 0 && linkDownBandwidth < 500 * netQuality.KBPS)) {
      return NetworkQualityTier.WEAK;
    }
    if (rttMs > 0 && rttMs <= 120 && linkDownBandwidth >= 10 * netQuality.MBPS) {
      return NetworkQualityTier.GOOD;
    }
    return NetworkQualityTier.NORMAL;
  }

  private mapSpeedAction(action: netQuality.DataSpeedSimpleAction): NetworkQualityTier {
    if (action === 'suspendData') {
      return NetworkQualityTier.SUSPENDED;
    }
    if (action === 'decreaseData') {
      return NetworkQualityTier.WEAK;
    }
    if (action === 'increaseData') {
      return NetworkQualityTier.GOOD;
    }
    return NetworkQualityTier.NORMAL;
  }

  private resolveEffectiveTier(): NetworkQualityTier {
    if (this.handoverActive) {
      return this.handoverTier;
    }
    if (this.sceneTier === NetworkQualityTier.SUSPENDED ||
      this.sceneTier === NetworkQualityTier.WEAK) {
      return this.sceneTier;
    }
    if (this.qosTier === NetworkQualityTier.WEAK) {
      return NetworkQualityTier.WEAK;
    }
    if (this.sceneTier === NetworkQualityTier.GOOD || this.qosTier === NetworkQualityTier.GOOD) {
      return NetworkQualityTier.GOOD;
    }
    return NetworkQualityTier.NORMAL;
  }

  private tierRank(tier: NetworkQualityTier): number {
    switch (tier) {
      case NetworkQualityTier.GOOD:
        return 3;
      case NetworkQualityTier.NORMAL:
        return 2;
      case NetworkQualityTier.WEAK:
        return 1;
      case NetworkQualityTier.SUSPENDED:
      default:
        return 0;
    }
  }

  private publishIfChanged(): void {
    const nextTier = this.resolveEffectiveTier();
    const prev = this.currentSnapshot;
    if (prev.tier === nextTier &&
      prev.weakSignalPredicted === this.weakSignalPredicted &&
      prev.handoverActive === this.handoverActive &&
      prev.handoverEpoch === this.handoverEpoch) {
      return;
    }
    const next: NetworkConditionSnapshot = {
      tier: nextTier,
      weakSignalPredicted: this.weakSignalPredicted,
      handoverActive: this.handoverActive,
      handoverEpoch: this.handoverEpoch
    };
    this.currentSnapshot = next;
    hilog.info(
      DOMAIN,
      TAG,
      'network condition: tier=%{public}s weakPred=%{public}s handover=%{public}s epoch=%{public}d',
      next.tier,
      String(next.weakSignalPredicted),
      String(next.handoverActive),
      next.handoverEpoch
    );
    const snapshotListeners = this.listeners.slice();
    for (let index: number = 0; index < snapshotListeners.length; index++) {
      try {
        snapshotListeners[index](next);
      } catch (_error) {
      }
    }
  }

  private sendSceneEvent(scene: NetworkBoostScene, sceneEvent: netBoost.SceneEvent): void {
    try {
      netBoost.setSceneDesc({
        scene: this.serviceTypeForScene(scene),
        sceneEvent: sceneEvent
      });
    } catch (error) {
      this.logUnavailable('setSceneDesc', error as Object);
    }
  }

  private serviceTypeForScene(scene: NetworkBoostScene): netQuality.ServiceType {
    return scene === NetworkBoostScene.DOWNLOAD ? 'download' : 'browser';
  }

  private qoeTypeForStatus(status: NetworkQoeStatus): netQuality.QoeType {
    switch (status) {
      case NetworkQoeStatus.GOOD:
        return 'good';
      case NetworkQoeStatus.HIGH_LATENCY:
        return 'highLatency';
      case NetworkQoeStatus.SERVER_ERROR:
        return 'serverErr';
      case NetworkQoeStatus.NO_DATA:
      default:
        return 'noData';
    }
  }

  private isCapabilityAvailable(): boolean {
    if (this.capabilityAvailable !== undefined) {
      return this.capabilityAvailable;
    }
    try {
      this.capabilityAvailable = canIUse('SystemCapability.Communication.NetworkBoost.Core');
    } catch (_error) {
      this.capabilityAvailable = false;
    }
    return this.capabilityAvailable;
  }

  private logUnavailable(apiName: string, error: Object): void {
    const businessError = error as BusinessError;
    const code = typeof businessError.code === 'number' ? businessError.code : -1;
    const message = error instanceof Error ? error.message : 'unknown error';
    hilog.info(DOMAIN, TAG, '%{public}s unavailable: code=%{public}d %{public}s',
      apiName, code, message);
  }
}
