import { ArchiveModelDescriptor, ArchiveSceneSource } from './ArchiveModelDescriptor';

/** The verified on-demand package is absent; the reader can acquire it from the gallery. */
export class ArchiveModelNotInstalledError extends Error {
  constructor() {
    super('三维模型尚未下载');
  }
}

/** Installation state is separate from the viewer's scene-load state. */
export enum ArchiveModelInstallState {
  UNKNOWN = 'unknown',
  BUNDLED = 'bundled',
  NOT_INSTALLED = 'not_installed',
  QUEUED = 'queued',
  WAITING = 'waiting',
  DOWNLOADING = 'downloading',
  PAUSED = 'paused',
  VERIFYING = 'verifying',
  READY = 'ready',
  FAILED = 'failed'
}

/** Immutable snapshot safe for gallery and detail ViewModels. */
export class ArchiveModelInstallSnapshot {
  readonly assetId: string;
  readonly assetVersion: number;
  readonly state: ArchiveModelInstallState;
  readonly processedBytes: number;
  readonly totalBytes: number;
  readonly taskId: string;
  readonly message: string;
  readonly sceneSource: ArchiveSceneSource | undefined;
  readonly updatedAt: number;

  constructor(
    model: ArchiveModelDescriptor,
    state: ArchiveModelInstallState,
    processedBytes: number = 0,
    totalBytes: number = model.byteLength,
    taskId: string = '',
    message: string = '',
    sceneSource: ArchiveSceneSource | undefined = undefined,
    updatedAt: number = Date.now()
  ) {
    this.assetId = model.assetId;
    this.assetVersion = model.assetVersion;
    this.state = state;
    this.processedBytes = Math.max(0, processedBytes);
    this.totalBytes = totalBytes > 0 ? totalBytes : model.byteLength;
    this.taskId = taskId;
    this.message = message;
    this.sceneSource = sceneSource;
    this.updatedAt = updatedAt;
  }

  isAvailable(): boolean {
    return (this.state === ArchiveModelInstallState.BUNDLED ||
      this.state === ArchiveModelInstallState.READY) && this.sceneSource !== undefined;
  }

  progress(): number {
    if (this.totalBytes <= 0) {
      return 0;
    }
    return Math.min(1, this.processedBytes / this.totalBytes);
  }
}

export type ArchiveModelInstallListener = (snapshot: ArchiveModelInstallSnapshot) => void;

/** Business-facing package port; no request.agent or file handles cross it. */
export interface ArchiveModelPackageRepository {
  initialize(models: ArchiveModelDescriptor[]): Promise<void>;
  snapshot(model: ArchiveModelDescriptor): Promise<ArchiveModelInstallSnapshot>;
  subscribe(assetId: string, listener: ArchiveModelInstallListener): () => void;
  install(model: ArchiveModelDescriptor): Promise<void>;
  pause(model: ArchiveModelDescriptor): Promise<void>;
  resume(model: ArchiveModelDescriptor): Promise<void>;
  cancel(model: ArchiveModelDescriptor): Promise<void>;
  remove(model: ArchiveModelDescriptor): Promise<void>;
  resolve(model: ArchiveModelDescriptor): Promise<ArchiveSceneSource>;
}
