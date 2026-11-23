import {
  BackgroundDownloadClient,
  BackgroundDownloadError,
  BackgroundDownloadErrorKind,
  BackgroundDownloadRequest,
  BackgroundDownloadSnapshot,
  BackgroundDownloadState,
  BackgroundDownloadTask,
  IdGeneratorPort
} from 'anomiconbasic';
import {
  ArchiveModelDescriptor,
  ArchiveModelDelivery,
  ArchiveSceneSource
} from '../domain/ArchiveModelDescriptor';
import {
  ArchiveModelInstallListener,
  ArchiveModelInstallSnapshot,
  ArchiveModelInstallState,
  ArchiveModelPackageRepository
} from '../domain/ArchiveModelInstall';
import {
  ArchiveModelFileStore,
  ArchiveModelStore,
  PendingModelDownloadRecord
} from './ArchiveModelFileStore';

/**
 * Application-scoped package repository.
 *
 * request.agent keeps transfers alive after a page leaves. This repository
 * owns the one callback per task that verifies and publishes the completed
 * GLB; screen ViewModels only subscribe to immutable business snapshots.
 */
export class SandboxArchiveModelPackageRepository implements ArchiveModelPackageRepository {
  private readonly downloads: BackgroundDownloadClient;
  private readonly ids: IdGeneratorPort;
  private readonly files: ArchiveModelStore;
  private readonly snapshots: Map<string, ArchiveModelInstallSnapshot> = new Map();
  private readonly models: Map<string, ArchiveModelDescriptor> = new Map();
  private readonly tasks: Map<string, BackgroundDownloadTask> = new Map();
  private readonly taskUnsubscribers: Map<string, () => void> = new Map();
  private readonly listeners: Map<string, ArchiveModelInstallListener[]> = new Map();
  private readonly finalizeGenerations: Map<string, number> = new Map();
  private readonly finalizingAssets: Map<string, boolean> = new Map();
  private readonly restorePromises: Map<string, Promise<boolean>> = new Map();
  private readonly restoredFingerprints: Map<string, string> = new Map();
  /**
   * Mutating operations for one asset must never overlap.  In particular,
   * request.agent writes directly into the staging path, so two install calls
   * cannot safely share it (the system API explicitly warns against that).
   * The tails are intentionally kept for the lifetime of the process; the
   * manifest is bounded and this also makes a late callback unable to race a
   * newly queued operation.
   */
  private readonly mutationTails: Map<string, Promise<void>> = new Map();
  private initialization: Promise<void> | undefined = undefined;

  constructor(
    filesDir: string,
    downloads: BackgroundDownloadClient,
    ids: IdGeneratorPort,
    files?: ArchiveModelStore
  ) {
    this.downloads = downloads;
    this.ids = ids;
    this.files = files ?? new ArchiveModelFileStore(filesDir);
  }

  initialize(models: ArchiveModelDescriptor[]): Promise<void> {
    if (this.initialization !== undefined) {
      return this.initialization;
    }
    const task = this.initializeModels(models);
    this.initialization = task;
    task.catch((): void => {
      if (this.initialization === task) {
        this.initialization = undefined;
      }
    });
    return task;
  }

  async snapshot(model: ArchiveModelDescriptor): Promise<ArchiveModelInstallSnapshot> {
    this.models.set(model.assetId, model);
    if (model.delivery === ArchiveModelDelivery.BUNDLED) {
      const bundled = this.snapshots.get(model.assetId);
      if (bundled !== undefined && bundled.assetVersion === model.assetVersion && bundled.isAvailable()) {
        return bundled;
      }
      return this.publish(new ArchiveModelInstallSnapshot(
        model,
        ArchiveModelInstallState.BUNDLED,
        model.byteLength,
        model.byteLength,
        '',
        '',
        ArchiveSceneSource.bundled(model)
      ));
    }
    await this.ensureRestored(model);
    const restored = this.snapshots.get(model.assetId);
    if (restored !== undefined && restored.assetVersion === model.assetVersion) {
      return restored;
    }
    return this.publish(new ArchiveModelInstallSnapshot(model, ArchiveModelInstallState.NOT_INSTALLED));
  }

  subscribe(assetId: string, listener: ArchiveModelInstallListener): () => void {
    let items = this.listeners.get(assetId);
    if (items === undefined) {
      items = [];
      this.listeners.set(assetId, items);
    }
    if (items.indexOf(listener) < 0) {
      items.push(listener);
    }
    const current = this.snapshots.get(assetId);
    if (current !== undefined) {
      listener(current);
    }
    return (): void => {
      const currentItems = this.listeners.get(assetId);
      if (currentItems === undefined) {
        return;
      }
      const index = currentItems.indexOf(listener);
      if (index >= 0) {
        currentItems.splice(index, 1);
      }
      if (currentItems.length === 0) {
        this.listeners.delete(assetId);
      }
    };
  }

  install(model: ArchiveModelDescriptor): Promise<void> {
    return this.enqueueMutation(model.assetId, (): Promise<void> => this.installInternal(model));
  }

  private async installInternal(model: ArchiveModelDescriptor): Promise<void> {
    this.models.set(model.assetId, model);
    if (model.delivery === ArchiveModelDelivery.BUNDLED) {
      await this.snapshot(model);
      return;
    }
    // Force one reconciliation on explicit retry.  A transient request-agent
    // management error must never be interpreted as permission to create a
    // second task for the same durable sidecar.
    await this.ensureRestored(model, true);
    const current = await this.snapshot(model);
    if (current.isAvailable() || this.isTransferActive(current.state)) {
      return;
    }
    const existingTask = this.tasks.get(model.assetId);
    if (existingTask !== undefined) {
      if (await this.resumeExistingTaskForInstall(model, existingTask)) {
        return;
      }
    }
    const durableRecord = await this.files.readPending(model);
    if (durableRecord !== undefined) {
      const message = this.snapshots.get(model.assetId)?.message ?? '后台下载任务状态暂不可用，请稍后重试';
      throw new Error(message.length > 0 ? message : '后台下载任务状态暂不可用，请稍后重试');
    }

    const stagingPath = await this.files.prepareStaging(model);
    const token = `archive3d-${this.ids.generate()}`;
    const displayId: string = (model.contentId.length > 0 ? model.contentId : model.assetId).toUpperCase();
    const requestConfig: BackgroundDownloadRequest = {
      url: model.location,
      destinationPath: stagingPath,
      title: `正在下载 ${displayId} 三维档案`,
      description: '完成后即可离线观察',
      token: token,
      expectedBytes: model.byteLength,
      allowMetered: false
    };

    let task: BackgroundDownloadTask;
    try {
      task = await this.downloads.create(requestConfig);
    } catch (error) {
      const message = error instanceof Error ? error.message : '后台下载任务创建失败';
      this.publish(new ArchiveModelInstallSnapshot(
        model, ArchiveModelInstallState.FAILED, 0, model.byteLength, '', message
      ));
      throw new Error(message);
    }

    const record = PendingModelDownloadRecord.create(model, task.id, token, stagingPath);
    try {
      await this.files.writePending(
        model,
        record
      );
    } catch (error) {
      try {
        await this.stopDetachedTask(task);
      } catch (stopError) {
        // Storage failure plus an indeterminate remove is the only case where
        // no durable recovery is possible. Keep the handle bound in-process
        // and surface the stronger error instead of deleting a live target.
        this.bindTask(model, task);
        const message = stopError instanceof Error ? stopError.message : '无法取消未记录的后台下载任务';
        this.publish(new ArchiveModelInstallSnapshot(
          model, ArchiveModelInstallState.FAILED, 0, model.byteLength, task.id, message
        ));
        throw new Error(message);
      }
      await this.files.removeStaging(model);
      const message = error instanceof Error ? error.message : '后台下载任务创建失败';
      this.publish(new ArchiveModelInstallSnapshot(
        model,
        ArchiveModelInstallState.FAILED,
        0,
        model.byteLength,
        '',
        message
      ));
      throw new Error(message);
    }

    this.bindTask(model, task);
    this.publish(new ArchiveModelInstallSnapshot(
      model,
      ArchiveModelInstallState.QUEUED,
      0,
      model.byteLength,
      task.id
    ));
    try {
      await task.start();
    } catch (error) {
      // The sidecar is already durable. Preserve the task and partial file so
      // a later explicit retry or process restart can call start() again.
      const message = error instanceof Error ? error.message : '后台下载任务启动失败';
      this.publish(new ArchiveModelInstallSnapshot(
        model, ArchiveModelInstallState.FAILED, 0, model.byteLength, task.id, message
      ));
      throw new Error(message);
    }
  }

  pause(model: ArchiveModelDescriptor): Promise<void> {
    return this.enqueueMutation(model.assetId, (): Promise<void> => this.pauseInternal(model));
  }

  private async pauseInternal(model: ArchiveModelDescriptor): Promise<void> {
    if (model.delivery === ArchiveModelDelivery.BUNDLED) {
      await this.snapshot(model);
      return;
    }
    await this.ensureRestored(model, true);
    const task = this.tasks.get(model.assetId);
    if (task === undefined) {
      throw new Error('当前没有可暂停的三维模型下载');
    }
    await task.pause();
  }

  resume(model: ArchiveModelDescriptor): Promise<void> {
    return this.enqueueMutation(model.assetId, (): Promise<void> => this.resumeInternal(model));
  }

  private async resumeInternal(model: ArchiveModelDescriptor): Promise<void> {
    if (model.delivery === ArchiveModelDelivery.BUNDLED) {
      await this.snapshot(model);
      return;
    }
    await this.ensureRestored(model, true);
    const task = this.tasks.get(model.assetId);
    if (task === undefined) {
      throw new Error('当前没有可恢复的三维模型下载');
    }
    await task.resume();
  }

  cancel(model: ArchiveModelDescriptor): Promise<void> {
    return this.enqueueMutation(model.assetId, (): Promise<void> => this.cancelInternal(model));
  }

  private async cancelInternal(model: ArchiveModelDescriptor): Promise<void> {
    if (model.delivery === ArchiveModelDelivery.BUNDLED) {
      await this.snapshot(model);
      return;
    }
    // Cancellation/removal invalidates any cached reconciliation result.  A
    // subsequent snapshot must inspect the sidecar and object again instead
    // of trusting a fingerprint that describes the pre-cancel state.
    this.restoredFingerprints.delete(model.assetId);
    this.nextFinalizeGeneration(model.assetId);
    this.finalizingAssets.delete(model.assetId);
    const boundTask = this.tasks.get(model.assetId);
    let pending: PendingModelDownloadRecord | undefined;
    // An in-process task gives us a trustworthy cancellation handle even if a
    // sidecar became unreadable.  When no handle is bound, refuse to guess a
    // task id: deleting the staging file while request.agent still owns it
    // could leave an untracked writer. The failure is published only for this
    // model and can be retried after storage recovers.
    if (boundTask === undefined) {
      try {
        pending = await this.files.readPending(model);
      } catch (error) {
        this.publish(new ArchiveModelInstallSnapshot(
          model,
          ArchiveModelInstallState.FAILED,
          this.snapshots.get(model.assetId)?.processedBytes ?? 0,
          model.byteLength,
          '',
          this.reconciliationErrorMessage(error, '三维下载任务记录损坏或本地存储暂不可用，请重试')
        ));
        throw this.errorValue(error as Object, '三维下载任务记录不可用');
      }
    }
    if (boundTask !== undefined) {
      await this.discardTask(model.assetId, true);
    } else if (pending !== undefined) {
      await this.stopPersistedTask(pending);
    }
    // Only clear durable identity and files after remove succeeded or the
    // platform explicitly reported 21900006 (already absent).
    await this.files.removePending(model);
    if (pending !== undefined) {
      await this.files.removeRecordedStaging(pending);
    } else {
      await this.files.removeStaging(model);
    }
    const installed = await this.files.locate(model, false);
    this.publish(new ArchiveModelInstallSnapshot(
      model,
      installed === undefined ? ArchiveModelInstallState.NOT_INSTALLED : ArchiveModelInstallState.READY,
      installed === undefined ? 0 : model.byteLength,
      model.byteLength,
      '',
      '',
      installed
    ));
  }

  remove(model: ArchiveModelDescriptor): Promise<void> {
    return this.enqueueMutation(model.assetId, (): Promise<void> => this.removeInternal(model));
  }

  private async removeInternal(model: ArchiveModelDescriptor): Promise<void> {
    if (model.delivery === ArchiveModelDelivery.BUNDLED) {
      await this.snapshot(model);
      return;
    }
    // We already hold the per-asset mutation lane; calling the public
    // `cancel()` here would enqueue behind this operation and deadlock.
    await this.cancelInternal(model);
    await this.files.removeInstalled(model);
    this.publish(new ArchiveModelInstallSnapshot(model, ArchiveModelInstallState.NOT_INSTALLED));
  }

  async resolve(model: ArchiveModelDescriptor): Promise<ArchiveSceneSource> {
    if (model.delivery === ArchiveModelDelivery.BUNDLED) {
      return ArchiveSceneSource.bundled(model);
    }
    await this.ensureRestored(model);
    // Re-check the digest at the parse boundary.  The cache is private, but
    // files can still be truncated or modified after the last reconciliation
    // (for example after a restore from backup); never hand an unchecked GLB
    // to ArkGraphics3D.
    const source = await this.files.locate(model, true);
    if (source === undefined) {
      throw new Error('三维模型尚未下载');
    }
    return source;
  }

  private async initializeModels(models: ArchiveModelDescriptor[]): Promise<void> {
    let storageReady = true;
    try {
      await this.files.initialize();
    } catch (error) {
      storageReady = false;
      // The directory setup may fail transiently (for example while the
      // ability is being restored). Continue with bundled rows and expose a
      // per-model failure for remote rows instead of aborting the whole graph.
      const message = this.reconciliationErrorMessage(error, '三维模型本地存储暂不可用，请稍后重试');
      for (let index: number = 0; index < models.length; index++) {
        const model = models[index];
        this.models.set(model.assetId, model);
        if (model.delivery === ArchiveModelDelivery.REMOTE) {
          this.publish(new ArchiveModelInstallSnapshot(
            model,
            ArchiveModelInstallState.FAILED,
            0,
            model.byteLength,
            '',
            message
          ));
        }
      }
    }
    for (let index: number = 0; index < models.length; index++) {
      const model = models[index];
      this.models.set(model.assetId, model);
      if (model.delivery === ArchiveModelDelivery.BUNDLED) {
        await this.snapshot(model);
      } else if (storageReady) {
        try {
          await this.ensureRestored(model);
        } catch (error) {
          // Keep initialization best-effort per asset even if a custom store
          // implementation throws outside the normal reconciliation path.
          this.publish(new ArchiveModelInstallSnapshot(
            model,
            ArchiveModelInstallState.FAILED,
            0,
            model.byteLength,
            '',
            this.reconciliationErrorMessage(error, '三维模型恢复失败')
          ));
        }
      }
    }
  }

  private async ensureRestored(model: ArchiveModelDescriptor, force: boolean = false): Promise<boolean> {
    const fingerprint = this.modelFingerprint(model);
    if (!force && this.restoredFingerprints.get(model.assetId) === fingerprint) {
      return true;
    }
    const existing = this.restorePromises.get(model.assetId);
    if (existing !== undefined) {
      return existing;
    }
    const restore = this.restoreRemoteModel(model);
    this.restorePromises.set(model.assetId, restore);
    try {
      const stable = await restore;
      if (stable) {
        this.restoredFingerprints.set(model.assetId, fingerprint);
      } else {
        this.restoredFingerprints.delete(model.assetId);
      }
      return stable;
    } catch (error) {
      // A malformed sidecar or a storage fault is local to this model. Do not
      // let one unreadable record abort initialization of every other asset.
      // Stable local failures are remembered until an explicit retry (which
      // passes force=true); temporary request-agent failures remain retryable.
      const temporary = error instanceof BackgroundDownloadError &&
        error.kind === BackgroundDownloadErrorKind.TEMPORARILY_UNAVAILABLE;
      if (temporary) {
        this.restoredFingerprints.delete(model.assetId);
      } else {
        this.restoredFingerprints.set(model.assetId, fingerprint);
      }
      const previous = this.snapshots.get(model.assetId);
      this.publish(new ArchiveModelInstallSnapshot(
        model,
        ArchiveModelInstallState.FAILED,
        previous?.processedBytes ?? 0,
        model.byteLength,
        previous?.taskId ?? '',
        this.reconciliationErrorMessage(error, '三维模型恢复失败')
      ));
      return !temporary;
    } finally {
      if (this.restorePromises.get(model.assetId) === restore) {
        this.restorePromises.delete(model.assetId);
      }
    }
  }

  private async restoreRemoteModel(model: ArchiveModelDescriptor): Promise<boolean> {
    const installed = await this.files.locate(model, true);
    if (installed !== undefined) {
      this.publish(new ArchiveModelInstallSnapshot(
        model,
        ArchiveModelInstallState.READY,
        model.byteLength,
        model.byteLength,
        '',
        '',
        installed
      ));
      this.cleanupCommittedInstall(model);
      return true;
    }

    let pending: PendingModelDownloadRecord | undefined;
    try {
      pending = await this.files.readPending(model);
    } catch (error) {
      // Keep the corrupt/temporarily unreadable sidecar in place.  We do not
      // guess a task id or delete a staging file that request.agent could
      // still be writing; an explicit retry can reconcile it safely later.
      this.publish(new ArchiveModelInstallSnapshot(
        model,
        ArchiveModelInstallState.FAILED,
        this.snapshots.get(model.assetId)?.processedBytes ?? 0,
        model.byteLength,
        this.snapshots.get(model.assetId)?.taskId ?? '',
        this.reconciliationErrorMessage(error, '三维下载任务记录损坏或本地存储暂不可用，请重试')
      ));
      return true;
    }
    if (pending === undefined) {
      this.publish(new ArchiveModelInstallSnapshot(model, ArchiveModelInstallState.NOT_INSTALLED));
      return true;
    }
    if (!pending.matches(model)) {
      try {
        await this.stopPersistedTask(pending);
      } catch (error) {
        this.publishReconciliationFailure(model, pending.taskId, error as Object);
        return false;
      }
      await this.files.removeRecordedStaging(pending);
      await this.files.removePending(model);
      this.publish(new ArchiveModelInstallSnapshot(model, ArchiveModelInstallState.NOT_INSTALLED));
      return true;
    }
    try {
      const task = await this.downloads.reconnect(pending.taskId, pending.token);
      this.bindTask(model, task);
      const download = await task.inspect();
      this.applyDownloadSnapshot(model, download, task);
      // The task identity is persisted before start so it can never become an
      // untracked system transfer.  If the process died in that narrow window,
      // explicitly start the reattached INITIALIZED task during reconciliation.
      if (download.state === BackgroundDownloadState.INITIALIZED) {
        await task.start();
      }
      return true;
    } catch (error) {
      if (this.isTaskNotFound(error as Object)) {
        return this.recoverMissingTask(model, pending);
      }
      this.publishReconciliationFailure(model, pending.taskId, error as Object);
      return false;
    }
  }

  private bindTask(model: ArchiveModelDescriptor, task: BackgroundDownloadTask): void {
    const existing = this.taskUnsubscribers.get(model.assetId);
    if (existing !== undefined) {
      existing();
    }
    const oldTask = this.tasks.get(model.assetId);
    if (oldTask !== undefined && oldTask !== task) {
      oldTask.dispose();
    }
    this.tasks.set(model.assetId, task);
    const unsubscribe = task.subscribe((download: BackgroundDownloadSnapshot): void => {
      // A platform callback can be queued after dispose/off. Ignore it when
      // this task is no longer the current task for the asset; otherwise an
      // old completion could finalize a newer task's staging file.
      if (this.tasks.get(model.assetId) !== task || download.id !== task.id) {
        return;
      }
      this.applyDownloadSnapshot(model, download, task);
    });
    this.taskUnsubscribers.set(model.assetId, unsubscribe);
  }

  private applyDownloadSnapshot(
    model: ArchiveModelDescriptor,
    download: BackgroundDownloadSnapshot,
    expectedTask: BackgroundDownloadTask | undefined = undefined
  ): void {
    if (expectedTask !== undefined &&
      (this.tasks.get(model.assetId) !== expectedTask || download.id !== expectedTask.id)) {
      return;
    }
    const processed = Math.max(0, download.processedBytes);
    const total = download.totalBytes > 0 ? download.totalBytes : model.byteLength;
    switch (download.state) {
      case BackgroundDownloadState.INITIALIZED:
        this.publish(new ArchiveModelInstallSnapshot(
          model, ArchiveModelInstallState.QUEUED, processed, total, download.id
        ));
        return;
      case BackgroundDownloadState.WAITING:
        this.publish(new ArchiveModelInstallSnapshot(
          model, ArchiveModelInstallState.WAITING, processed, total, download.id, download.reason
        ));
        return;
      case BackgroundDownloadState.RUNNING:
      case BackgroundDownloadState.RETRYING:
        this.publish(new ArchiveModelInstallSnapshot(
          model, ArchiveModelInstallState.DOWNLOADING, processed, total, download.id, download.reason
        ));
        return;
      case BackgroundDownloadState.PAUSED:
        this.publish(new ArchiveModelInstallSnapshot(
          model, ArchiveModelInstallState.PAUSED, processed, total, download.id, download.reason
        ));
        return;
      case BackgroundDownloadState.COMPLETED:
        // request.agent can deliver both the completed event and the result of
        // the follow-up touch().  Finalization performs a rename, so it must be
        // single-flight or a duplicate callback could mistake the moved
        // staging file for an integrity failure.
        if (this.finalizingAssets.get(model.assetId) === true ||
          this.snapshots.get(model.assetId)?.state === ArchiveModelInstallState.READY) {
          return;
        }
        this.publish(new ArchiveModelInstallSnapshot(
          model, ArchiveModelInstallState.VERIFYING, processed, total, download.id
        ));
        this.finalizeDownload(model);
        return;
      case BackgroundDownloadState.FAILED:
      case BackgroundDownloadState.STOPPED:
        this.publish(new ArchiveModelInstallSnapshot(
          model,
          ArchiveModelInstallState.FAILED,
          processed,
          total,
          download.id,
          download.reason.length > 0 ? download.reason : '三维模型下载失败'
        ));
        return;
      case BackgroundDownloadState.REMOVED:
        if (this.snapshots.get(model.assetId)?.state !== ArchiveModelInstallState.READY) {
          this.publish(new ArchiveModelInstallSnapshot(model, ArchiveModelInstallState.NOT_INSTALLED));
        }
        return;
      default:
        return;
    }
  }

  private finalizeDownload(model: ArchiveModelDescriptor): void {
    if (this.finalizingAssets.get(model.assetId) === true) {
      return;
    }
    this.finalizingAssets.set(model.assetId, true);
    const generation = this.nextFinalizeGeneration(model.assetId);
    const task = this.tasks.get(model.assetId);
    // Read the exact persisted path so a restored task cannot publish a file
    // chosen by a stale callback or a changed catalog entry.
    this.files.readPending(model).then((record: PendingModelDownloadRecord | undefined): Promise<ArchiveSceneSource> => {
      if (record === undefined || !record.matches(model)) {
        throw new Error('三维模型下载记录已失效');
      }
      return this.files.verifyAndPublish(model, record.stagingPath);
    }).then((source: ArchiveSceneSource): void => {
      if (generation !== this.finalizeGenerations.get(model.assetId)) {
        return;
      }
      if (task !== undefined && this.tasks.get(model.assetId) !== task) {
        return;
      }
      this.finalizingAssets.delete(model.assetId);
      this.detachTask(model.assetId);
      // Do not remove a completed system task immediately: request.agent owns
      // the completion notification configured by the common adapter.  We only
      // detach in-process callbacks and let the system retire its task record.
      task?.dispose();
      this.publish(new ArchiveModelInstallSnapshot(
        model,
        ArchiveModelInstallState.READY,
        model.byteLength,
        model.byteLength,
        '',
        '',
        source
      ));
      // The content-addressed rename above is the commit point.  Cleanup is
      // idempotent compensation and must never downgrade an installed model if
      // deleting the sidecar fails transiently.
      this.cleanupCommittedInstall(model);
    }).catch(async (error: Object): Promise<void> => {
      if (generation !== this.finalizeGenerations.get(model.assetId)) {
        return;
      }
      if (task !== undefined && this.tasks.get(model.assetId) !== task) {
        // A newer task has taken ownership of this asset. Never cancel or
        // clean up that task from a stale completion/finalization callback.
        return;
      }
      this.finalizingAssets.delete(model.assetId);
      const message = error instanceof Error ? error.message : '三维模型完整性校验失败';
      try {
        await this.discardTask(model.assetId, true);
      } catch (stopError) {
        const stopMessage = stopError instanceof Error ? stopError.message : '后台下载任务清理失败';
        this.publish(new ArchiveModelInstallSnapshot(
          model,
          ArchiveModelInstallState.FAILED,
          0,
          model.byteLength,
          task?.id ?? '',
          `${message}；${stopMessage}`
        ));
        return;
      }
      await this.files.removePending(model);
      await this.files.removeStaging(model);
      this.publish(new ArchiveModelInstallSnapshot(
        model,
        ArchiveModelInstallState.FAILED,
        0,
        model.byteLength,
        '',
        message
      ));
    });
  }

  private async recoverMissingTask(
    model: ArchiveModelDescriptor,
    record: PendingModelDownloadRecord
  ): Promise<boolean> {
    // 21900006 is the only management error that proves no platform writer
    // remains. A fully written staging GLB may still be recoverable.
    await this.discardTask(model.assetId, false);
    try {
      const source = await this.files.verifyAndPublish(model, record.stagingPath);
      this.publish(new ArchiveModelInstallSnapshot(
        model,
        ArchiveModelInstallState.READY,
        model.byteLength,
        model.byteLength,
        '',
        '',
        source
      ));
      this.cleanupCommittedInstall(model);
      return true;
    } catch (_error) {
    }
    await this.files.removePending(model);
    await this.files.removeRecordedStaging(record);
    this.publish(new ArchiveModelInstallSnapshot(
      model,
      ArchiveModelInstallState.FAILED,
      0,
      model.byteLength,
      '',
      '后台下载任务已失效，请重新下载'
    ));
    return true;
  }

  /** Serialize destructive/download mutations while preserving caller errors. */
  private enqueueMutation(assetId: string, operation: () => Promise<void>): Promise<void> {
    const previous: Promise<void> = this.mutationTails.get(assetId) ?? Promise.resolve();
    // The rejection handler keeps the queue alive after a failed operation;
    // `next` is still returned unchanged so the caller observes that failure.
    const next: Promise<void> = previous.then(operation, operation);
    this.mutationTails.set(assetId, next.catch((): void => {
      // Intentionally swallow only in the stored tail. The original `next`
      // promise remains rejected for the operation's caller.
    }));
    return next;
  }

  private publish(snapshot: ArchiveModelInstallSnapshot): ArchiveModelInstallSnapshot {
    this.snapshots.set(snapshot.assetId, snapshot);
    const items = this.listeners.get(snapshot.assetId)?.slice() ?? [];
    for (let index: number = 0; index < items.length; index++) {
      try {
        items[index](snapshot);
      } catch (_error) {
      }
    }
    return snapshot;
  }

  private isTransferActive(state: ArchiveModelInstallState): boolean {
    return state === ArchiveModelInstallState.QUEUED ||
      state === ArchiveModelInstallState.WAITING ||
      state === ArchiveModelInstallState.DOWNLOADING ||
      state === ArchiveModelInstallState.PAUSED ||
      state === ArchiveModelInstallState.VERIFYING;
  }

  private nextFinalizeGeneration(assetId: string): number {
    const generation = (this.finalizeGenerations.get(assetId) ?? 0) + 1;
    this.finalizeGenerations.set(assetId, generation);
    return generation;
  }

  private async discardTask(assetId: string, removeFromSystem: boolean): Promise<void> {
    const task = this.tasks.get(assetId);
    if (task === undefined) {
      return;
    }
    if (removeFromSystem) {
      try {
        await task.cancel();
      } catch (error) {
        if (!this.isTaskNotFound(error as Object)) {
          // Keep callbacks and durable identity intact; the system may still be
          // writing to the staging path after an indeterminate service error.
          throw this.errorValue(error as Object, '无法移除后台下载任务');
        }
      }
    }
    this.detachTask(assetId);
    task.dispose();
  }

  private async stopPersistedTask(record: PendingModelDownloadRecord): Promise<void> {
    try {
      await this.downloads.remove(record.taskId);
    } catch (error) {
      if (!this.isTaskNotFound(error as Object)) {
        throw this.errorValue(error as Object, '无法恢复后台下载任务');
      }
    }
  }

  private async stopDetachedTask(task: BackgroundDownloadTask): Promise<void> {
    try {
      await task.cancel();
    } catch (error) {
      if (!this.isTaskNotFound(error as Object)) {
        throw this.errorValue(error as Object, '无法移除后台下载任务');
      }
    }
    task.dispose();
  }

  private async resumeExistingTaskForInstall(
    model: ArchiveModelDescriptor,
    task: BackgroundDownloadTask
  ): Promise<boolean> {
    let download: BackgroundDownloadSnapshot;
    try {
      download = await task.inspect();
    } catch (error) {
      if (this.isTaskNotFound(error as Object)) {
        const pending = await this.files.readPending(model);
        if (pending !== undefined) {
          const recovered = await this.recoverMissingTask(model, pending);
          return recovered && (this.snapshots.get(model.assetId)?.isAvailable() ?? false);
        }
        await this.discardTask(model.assetId, false);
        return false;
      }
      this.publishReconciliationFailure(model, task.id, error as Object);
      throw this.errorValue(error as Object, '无法读取后台下载任务');
    }
    this.applyDownloadSnapshot(model, download, task);
    switch (download.state) {
      case BackgroundDownloadState.INITIALIZED:
      case BackgroundDownloadState.FAILED:
      case BackgroundDownloadState.STOPPED:
        try {
          await task.start();
          return true;
        } catch (error) {
          const message = error instanceof Error ? error.message : '后台下载任务无法重新启动';
          this.publish(new ArchiveModelInstallSnapshot(
            model,
            ArchiveModelInstallState.FAILED,
            Math.max(0, download.processedBytes),
            download.totalBytes > 0 ? download.totalBytes : model.byteLength,
            task.id,
            message
          ));
          throw new Error(message);
        }
      case BackgroundDownloadState.PAUSED:
        await task.resume();
        return true;
      case BackgroundDownloadState.WAITING:
      case BackgroundDownloadState.RUNNING:
      case BackgroundDownloadState.RETRYING:
      case BackgroundDownloadState.COMPLETED:
        return true;
      case BackgroundDownloadState.REMOVED:
        await this.discardTask(model.assetId, false);
        await this.files.removePending(model);
        await this.files.removeStaging(model);
        return false;
      default:
        throw new Error('后台下载任务处于未知状态，请稍后重试');
    }
  }

  private isTaskNotFound(error: Object): boolean {
    return error instanceof BackgroundDownloadError &&
      error.kind === BackgroundDownloadErrorKind.TASK_NOT_FOUND;
  }

  private errorValue(error: Object, fallback: string): Error {
    return error instanceof Error ? error : new Error(fallback);
  }

  private publishReconciliationFailure(
    model: ArchiveModelDescriptor,
    taskId: string,
    error: Object
  ): void {
    const message = error instanceof BackgroundDownloadError &&
      error.kind === BackgroundDownloadErrorKind.TEMPORARILY_UNAVAILABLE ?
      '后台下载服务暂时不可用，任务会保留，请稍后重试' :
      (error instanceof Error && error.message.length > 0 ? error.message : '无法恢复后台下载任务');
    this.publish(new ArchiveModelInstallSnapshot(
      model,
      ArchiveModelInstallState.FAILED,
      this.snapshots.get(model.assetId)?.processedBytes ?? 0,
      model.byteLength,
      taskId,
      message
    ));
  }

  private reconciliationErrorMessage(error: Object, fallback: string): string {
    if (error instanceof BackgroundDownloadError &&
      error.kind === BackgroundDownloadErrorKind.TEMPORARILY_UNAVAILABLE) {
      return '后台下载服务暂时不可用，任务会保留，请稍后重试';
    }
    const detail = error instanceof Error ? error.message.trim() : '';
    return detail.length > 0 ? `${fallback}：${detail}` : fallback;
  }

  private cleanupCommittedInstall(model: ArchiveModelDescriptor): void {
    this.files.removePending(model).catch((): void => {
    });
    this.files.removeStaging(model).catch((): void => {
    });
  }

  private modelFingerprint(model: ArchiveModelDescriptor): string {
    return `${model.assetVersion}|${model.delivery}|${model.location}|${model.byteLength}|${model.sha256}`;
  }

  private detachTask(assetId: string): void {
    const unsubscribe = this.taskUnsubscribers.get(assetId);
    this.taskUnsubscribers.delete(assetId);
    if (unsubscribe !== undefined) {
      unsubscribe();
    }
    this.tasks.delete(assetId);
  }
}
