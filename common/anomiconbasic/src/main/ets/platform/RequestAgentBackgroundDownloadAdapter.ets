import { common, WantAgent, wantAgent } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { request } from '@kit.BasicServicesKit';
import {
  BackgroundDownloadClient,
  BackgroundDownloadError,
  BackgroundDownloadErrorKind,
  BackgroundDownloadListener,
  BackgroundDownloadRequest,
  BackgroundDownloadSnapshot,
  BackgroundDownloadState,
  BackgroundDownloadTask
} from './BackgroundDownloadContracts';
import { NetworkBoostPort, NetworkBoostScene } from './NetworkBoostContracts';

const UNKNOWN_TOTAL_BYTES: number = -1;
const REQUEST_TASK_NOT_FOUND: number = 21900006;
const REQUEST_SERVICE_UNAVAILABLE: number = 13400003;
const REQUEST_WRONG_TASK_STATE: number = 21900007;
const REQUEST_QUEUE_FULL: number = 21900004;
const REQUEST_PERMISSION_DENIED: number = 201;
const REQUEST_INVALID_PARAMETER: number = 401;
const REQUEST_INVALID_FILE: number = 13400001;
const REQUEST_INVALID_PATH: number = 13400002;
const REQUEST_WRONG_TASK_MODE: number = 21900005;
const MIN_TOKEN_LENGTH: number = 8;
const MAX_TOKEN_LENGTH: number = 2048;

function mapError(error: Object, fallback: string): BackgroundDownloadError {
  const businessError = error as BusinessError;
  const code = typeof businessError.code === 'number' ? businessError.code : 0;
  const message = error instanceof Error && error.message.length > 0 ? error.message : fallback;
  if (code === REQUEST_TASK_NOT_FOUND) {
    return new BackgroundDownloadError(message, BackgroundDownloadErrorKind.TASK_NOT_FOUND, code);
  }
  if (code === REQUEST_SERVICE_UNAVAILABLE || code === REQUEST_QUEUE_FULL) {
    return new BackgroundDownloadError(message, BackgroundDownloadErrorKind.TEMPORARILY_UNAVAILABLE, code);
  }
  if (code === REQUEST_WRONG_TASK_STATE) {
    return new BackgroundDownloadError(message, BackgroundDownloadErrorKind.INVALID_TASK_STATE, code);
  }
  if (code === REQUEST_PERMISSION_DENIED) {
    return new BackgroundDownloadError(message, BackgroundDownloadErrorKind.PERMISSION_DENIED, code);
  }
  if (code === REQUEST_INVALID_PARAMETER || code === REQUEST_INVALID_FILE ||
    code === REQUEST_INVALID_PATH || code === REQUEST_WRONG_TASK_MODE) {
    return new BackgroundDownloadError(message, BackgroundDownloadErrorKind.INVALID_REQUEST, code);
  }
  return new BackgroundDownloadError(message, BackgroundDownloadErrorKind.UNKNOWN, code);
}

function mapState(state: request.agent.State): BackgroundDownloadState {
  switch (state) {
    case request.agent.State.INITIALIZED:
      return BackgroundDownloadState.INITIALIZED;
    case request.agent.State.WAITING:
      return BackgroundDownloadState.WAITING;
    case request.agent.State.RUNNING:
      return BackgroundDownloadState.RUNNING;
    case request.agent.State.RETRYING:
      return BackgroundDownloadState.RETRYING;
    case request.agent.State.PAUSED:
      return BackgroundDownloadState.PAUSED;
    case request.agent.State.STOPPED:
      return BackgroundDownloadState.STOPPED;
    case request.agent.State.COMPLETED:
      return BackgroundDownloadState.COMPLETED;
    case request.agent.State.FAILED:
      return BackgroundDownloadState.FAILED;
    case request.agent.State.REMOVED:
      return BackgroundDownloadState.REMOVED;
    default:
      return BackgroundDownloadState.UNKNOWN;
  }
}

function mapWaitingReason(reason: request.agent.WaitingReason): string {
  switch (reason) {
    case request.agent.WaitingReason.TASK_QUEUE_FULL:
      return 'task_queue_full';
    case request.agent.WaitingReason.NETWORK_NOT_MATCH:
      return 'network_not_match';
    case request.agent.WaitingReason.APP_BACKGROUND:
      return 'app_background';
    case request.agent.WaitingReason.USER_INACTIVATED:
      return 'user_inactivated';
    default:
      return 'waiting';
  }
}

function totalBytes(progress: request.agent.Progress, expected: number): number {
  const index = progress.index;
  if (index >= 0 && index < progress.sizes.length && progress.sizes[index] >= 0) {
    return progress.sizes[index];
  }
  if (progress.sizes.length > 0 && progress.sizes[0] >= 0) {
    return progress.sizes[0];
  }
  return expected > 0 ? expected : UNKNOWN_TOTAL_BYTES;
}

/** Adapts one request.agent.Task while keeping the native object private. */
class RequestAgentTask implements BackgroundDownloadTask {
  readonly id: string;
  readonly token: string;

  private readonly nativeTask: request.agent.Task;
  private readonly destinationPath: string;
  private readonly expectedBytes: number;
  private readonly listeners: BackgroundDownloadListener[] = [];
  private readonly networkBoost: NetworkBoostPort | undefined;
  private leaveDownloadScene: (() => void) | undefined = undefined;
  private latest: BackgroundDownloadSnapshot;
  private disposed: boolean = false;
  private eventsAttached: boolean = false;

  private readonly onProgress = (value: request.agent.Progress): void => {
    this.publish(this.fromProgress(value));
  };
  private readonly onCompleted = (value: request.agent.Progress): void => {
    this.publish(this.fromProgress(value));
    this.refresh();
  };
  private readonly onFailed = (value: request.agent.Progress): void => {
    this.publish(this.fromProgress(value));
    this.refresh();
  };
  private readonly onPause = (value: request.agent.Progress): void => {
    this.publish(this.fromProgress(value));
  };
  private readonly onResume = (value: request.agent.Progress): void => {
    this.publish(this.fromProgress(value));
  };
  private readonly onRemove = (value: request.agent.Progress): void => {
    this.publish(this.fromProgress(value));
    this.detachEvents();
  };
  private readonly onFault = (fault: request.agent.Faults): void => {
    this.publish(this.makeSnapshot(
      this.latest.state,
      this.latest.processedBytes,
      this.latest.totalBytes,
      this.latest.reason,
      Number(fault)
    ));
    this.refresh();
  };
  private readonly onWait = (reason: request.agent.WaitingReason): void => {
    this.publish(this.makeSnapshot(
      BackgroundDownloadState.WAITING,
      this.latest.processedBytes,
      this.latest.totalBytes,
      mapWaitingReason(reason),
      this.latest.faultCode
    ));
  };

  constructor(
    nativeTask: request.agent.Task,
    token: string,
    destinationPath: string,
    expectedBytes: number,
    networkBoost?: NetworkBoostPort
  ) {
    this.nativeTask = nativeTask;
    this.id = nativeTask.tid;
    this.token = token;
    this.destinationPath = destinationPath;
    this.expectedBytes = expectedBytes;
    this.networkBoost = networkBoost;
    this.latest = this.makeSnapshot(
      BackgroundDownloadState.INITIALIZED,
      0,
      expectedBytes > 0 ? expectedBytes : UNKNOWN_TOTAL_BYTES,
      '',
      0
    );
    this.syncDownloadScene(this.latest.state);
    this.attachEvents();
  }

  async start(): Promise<void> {
    this.ensureActive();
    try {
      await this.nativeTask.start();
    } catch (error) {
      throw mapError(error as Object, '无法启动后台下载');
    }
    this.refresh();
  }

  async pause(): Promise<void> {
    this.ensureActive();
    try {
      await this.nativeTask.pause();
    } catch (error) {
      throw mapError(error as Object, '无法暂停后台下载');
    }
    this.refresh();
  }

  async resume(): Promise<void> {
    this.ensureActive();
    try {
      await this.nativeTask.resume();
    } catch (error) {
      throw mapError(error as Object, '无法恢复后台下载');
    }
    this.refresh();
  }

  async cancel(): Promise<void> {
    this.ensureActive();
    try {
      await request.agent.remove(this.id);
    } catch (error) {
      throw mapError(error as Object, '无法删除后台下载任务');
    }
    this.publish(this.makeSnapshot(
      BackgroundDownloadState.REMOVED,
      this.latest.processedBytes,
      this.latest.totalBytes,
      'cancelled',
      this.latest.faultCode
    ));
    this.detachEvents();
  }

  async inspect(): Promise<BackgroundDownloadSnapshot> {
    this.ensureActive();
    if (this.latest.state === BackgroundDownloadState.REMOVED) {
      return this.latest;
    }
    try {
      const info = await request.agent.touch(this.id, this.token);
      this.latest = this.fromTaskInfo(info);
      return this.latest;
    } catch (error) {
      throw mapError(error as Object, '无法读取后台下载任务');
    }
  }

  subscribe(listener: BackgroundDownloadListener): () => void {
    if (this.disposed) {
      return (): void => {};
    }
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
    listener(this.latest);
    return (): void => {
      const index = this.listeners.indexOf(listener);
      if (index >= 0) {
        this.listeners.splice(index, 1);
      }
    };
  }

  dispose(): void {
    if (this.disposed) {
      return;
    }
    this.disposed = true;
    this.releaseDownloadScene();
    this.detachEvents();
    this.listeners.splice(0, this.listeners.length);
  }

  private attachEvents(): void {
    // Mark before registration so a partial registration is still cleaned up
    // if one of the event names is unavailable on a device build.
    this.eventsAttached = true;
    try {
      this.nativeTask.on('progress', this.onProgress);
      this.nativeTask.on('completed', this.onCompleted);
      this.nativeTask.on('failed', this.onFailed);
      this.nativeTask.on('pause', this.onPause);
      this.nativeTask.on('resume', this.onResume);
      this.nativeTask.on('remove', this.onRemove);
      this.nativeTask.on('faultOccur', this.onFault);
      this.nativeTask.on('wait', this.onWait);
    } catch (_error) {
      this.detachEvents();
      throw new Error('无法订阅后台下载事件');
    }
  }

  private detachEvents(): void {
    if (!this.eventsAttached) {
      return;
    }
    this.eventsAttached = false;
    try { this.nativeTask.off('progress', this.onProgress); } catch (_error) {}
    try { this.nativeTask.off('completed', this.onCompleted); } catch (_error) {}
    try { this.nativeTask.off('failed', this.onFailed); } catch (_error) {}
    try { this.nativeTask.off('pause', this.onPause); } catch (_error) {}
    try { this.nativeTask.off('resume', this.onResume); } catch (_error) {}
    try { this.nativeTask.off('remove', this.onRemove); } catch (_error) {}
    try { this.nativeTask.off('faultOccur', this.onFault); } catch (_error) {}
    try { this.nativeTask.off('wait', this.onWait); } catch (_error) {}
  }

  private fromProgress(value: request.agent.Progress): BackgroundDownloadSnapshot {
    return this.makeSnapshot(
      mapState(value.state),
      value.processed,
      totalBytes(value, this.expectedBytes),
      this.latest.reason,
      this.latest.faultCode
    );
  }

  private fromTaskInfo(info: request.agent.TaskInfo): BackgroundDownloadSnapshot {
    return this.makeSnapshot(
      mapState(info.progress.state),
      info.progress.processed,
      totalBytes(info.progress, this.expectedBytes),
      info.reason,
      Number(info.faults)
    );
  }

  private makeSnapshot(
    state: BackgroundDownloadState,
    processedBytes: number,
    totalBytesValue: number,
    reason: string,
    faultCode: number
  ): BackgroundDownloadSnapshot {
    return {
      id: this.id,
      token: this.token,
      state: state,
      destinationPath: this.destinationPath,
      processedBytes: Math.max(0, processedBytes),
      totalBytes: totalBytesValue,
      expectedBytes: this.expectedBytes,
      reason: reason,
      faultCode: faultCode
    };
  }

  private publish(snapshot: BackgroundDownloadSnapshot): void {
    if (this.disposed) {
      return;
    }
    this.latest = snapshot;
    this.syncDownloadScene(snapshot.state);
    const listeners = this.listeners.slice();
    for (let index: number = 0; index < listeners.length; index++) {
      try {
        listeners[index](snapshot);
      } catch (_error) {
      }
    }
  }

  private syncDownloadScene(state: BackgroundDownloadState): void {
    if (this.disposed || this.networkBoost === undefined) {
      return;
    }
    const active = state === BackgroundDownloadState.INITIALIZED ||
      state === BackgroundDownloadState.RUNNING ||
      state === BackgroundDownloadState.RETRYING;
    if (active) {
      if (this.leaveDownloadScene === undefined) {
        this.leaveDownloadScene = this.networkBoost.enterScene(NetworkBoostScene.DOWNLOAD);
      }
    } else {
      this.releaseDownloadScene();
    }
  }

  private releaseDownloadScene(): void {
    if (this.leaveDownloadScene !== undefined) {
      const leave = this.leaveDownloadScene;
      this.leaveDownloadScene = undefined;
      leave();
    }
  }

  private refresh(): void {
    this.inspect().then((snapshot: BackgroundDownloadSnapshot): void => {
      this.publish(snapshot);
    }).catch((): void => {
    });
  }

  private ensureActive(): void {
    if (this.disposed) {
      throw new Error('后台下载任务已释放');
    }
  }
}

/** API 26 request.agent adapter used by application-scoped repositories. */
export class RequestAgentBackgroundDownloadAdapter implements BackgroundDownloadClient {
  private readonly applicationContext: common.ApplicationContext;
  private readonly notificationBundleName: string;
  private readonly notificationAbilityName: string;
  private readonly networkBoost: NetworkBoostPort | undefined;

  constructor(
    applicationContext: common.ApplicationContext,
    notificationBundleName: string,
    notificationAbilityName: string,
    networkBoost?: NetworkBoostPort
  ) {
    if (notificationBundleName.trim().length === 0 || notificationAbilityName.trim().length === 0) {
      throw new Error('必须提供下载通知的 bundleName 和 abilityName');
    }
    this.applicationContext = applicationContext;
    this.notificationBundleName = notificationBundleName;
    this.notificationAbilityName = notificationAbilityName;
    this.networkBoost = networkBoost;
  }

  async create(downloadRequest: BackgroundDownloadRequest): Promise<BackgroundDownloadTask> {
    this.validateRequest(downloadRequest);
    const agent: WantAgent = await this.createNotificationWantAgent();
    const notification: request.agent.Notification = {
      title: downloadRequest.title,
      text: downloadRequest.description,
      visibility: request.agent.VISIBILITY_PROGRESS | request.agent.VISIBILITY_COMPLETION,
      wantAgent: agent
    };
    const config: request.agent.Config = {
      action: request.agent.Action.DOWNLOAD,
      url: downloadRequest.url,
      title: downloadRequest.title,
      description: downloadRequest.description,
      mode: request.agent.Mode.BACKGROUND,
      overwrite: true,
      method: 'GET',
      saveas: downloadRequest.destinationPath,
      network: request.agent.Network.ANY,
      metered: downloadRequest.allowMetered,
      roaming: false,
      retry: true,
      redirect: true,
      gauge: true,
      precise: false,
      token: downloadRequest.token,
      notification: notification
    };
    try {
      const task = await request.agent.create(this.applicationContext, config);
      return new RequestAgentTask(
        task,
        downloadRequest.token,
        downloadRequest.destinationPath,
        downloadRequest.expectedBytes,
        this.networkBoost
      );
    } catch (error) {
      throw mapError(error as Object, '无法创建后台下载任务');
    }
  }

  async reconnect(id: string, token: string): Promise<BackgroundDownloadTask> {
    this.validateTaskIdentity(id, token);
    try {
      const task = await request.agent.getTask(this.applicationContext, id, token);
      const destination = task.config.saveas === undefined ? '' : task.config.saveas;
      return new RequestAgentTask(task, token, destination, 0, this.networkBoost);
    } catch (error) {
      throw mapError(error as Object, '无法恢复后台下载任务');
    }
  }

  async remove(id: string): Promise<void> {
    if (id.trim().length === 0) {
      throw new Error('后台下载任务 id 不能为空');
    }
    try {
      await request.agent.remove(id);
    } catch (error) {
      throw mapError(error as Object, '无法删除后台下载任务');
    }
  }

  private async createNotificationWantAgent(): Promise<WantAgent> {
    const info: wantAgent.WantAgentInfo = {
      wants: [{ bundleName: this.notificationBundleName, abilityName: this.notificationAbilityName }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    return wantAgent.getWantAgent(info);
  }

  private validateRequest(value: BackgroundDownloadRequest): void {
    if (!value.url.startsWith('https://')) {
      throw new Error('后台下载只允许 HTTPS 地址');
    }
    if (!Number.isSafeInteger(value.expectedBytes) || value.expectedBytes < 0) {
      throw new Error('expectedBytes 必须是非负安全整数');
    }
    this.validateTaskIdentity('new-task', value.token);
    this.validateDestinationPath(value.destinationPath);
  }

  private validateTaskIdentity(id: string, token: string): void {
    if (id.trim().length === 0) {
      throw new Error('后台下载任务 id 不能为空');
    }
    const tokenBytes = util.TextEncoder.create('utf-8').encodeInto(token).byteLength;
    if (tokenBytes < MIN_TOKEN_LENGTH || tokenBytes > MAX_TOKEN_LENGTH) {
      throw new Error('后台下载 token 必须包含 8 到 2048 个 UTF-8 字节');
    }
  }

  private validateDestinationPath(destinationPath: string): void {
    const prefix = `${this.applicationContext.filesDir}/`;
    if (!destinationPath.startsWith(prefix)) {
      throw new Error('后台下载目标必须位于应用 filesDir 下');
    }
    const relative = destinationPath.substring(prefix.length);
    const segments = relative.split('/');
    if (segments.length === 0 || segments.some((segment: string): boolean =>
      segment.length === 0 || segment === '.' || segment === '..')) {
      throw new Error('后台下载目标路径包含不安全片段');
    }
  }
}
