import { LibraryContentRef } from 'library';
import {
  ArticleContentGateway,
  ArticleLoadResult,
  PendingExtraction,
  ArticleMetadataPort,
  ArticleRelatedTale
} from '../domain/ArticleContracts';
import {
  ArticleOfflineSaveProgress,
  ArticleOfflineSnapshot,
  ArticleOfflineStoragePort
} from '../domain/ArticleOfflineContracts';
import { ScpArticleDocument } from '../domain/ScpDocument';

/** Coordinates cache hit, HTML retrieval, permanent offline vault and native-first document projection. */
export class ArticleContentUseCase {
  private readonly gateway: ArticleContentGateway;
  private readonly metadata: ArticleMetadataPort | undefined;
  private readonly offlineStore: ArticleOfflineStoragePort | undefined;

  constructor(
    gateway: ArticleContentGateway,
    metadata?: ArticleMetadataPort,
    offlineStore?: ArticleOfflineStoragePort
  ) {
    this.gateway = gateway;
    this.metadata = metadata;
    this.offlineStore = offlineStore;
  }

  load(
    content: LibraryContentRef,
    requestId: number,
    forceNetwork: boolean = false
  ): Promise<ArticleLoadResult> {
    return Promise.resolve().then(() => this.gateway.load(content, requestId, forceNetwork));
  }

  completeExtraction(
    content: LibraryContentRef,
    pending: PendingExtraction,
    payload: string
  ): Promise<ScpArticleDocument> {
    return Promise.resolve().then(() => this.gateway.completeExtraction(content, pending, payload));
  }

  /** Resolve an optional display title without making metadata a load failure. */
  resolveTitle(content: LibraryContentRef): Promise<string> {
    return Promise.resolve().then(() => this.metadata === undefined ? '' :
      this.metadata.resolveTitle(content));
  }

  /** Load the bounded related-tale projection through the injected port. */
  listRelatedTales(content: LibraryContentRef, limit: number): Promise<ArticleRelatedTale[]> {
    return Promise.resolve().then(() => this.metadata === undefined ? [] :
      this.metadata.listRelatedTales(content, limit));
  }

  /** Inspect persisted offline availability on disk for one article. */
  inspectOffline(content: LibraryContentRef): Promise<ArticleOfflineSnapshot | undefined> {
    return Promise.resolve().then(() => this.offlineStore === undefined ?
      undefined : this.offlineStore.inspect(content));
  }

  /** Save article text and validated images into permanent offline storage. */
  saveOffline(
    content: LibraryContentRef,
    document: ScpArticleDocument,
    rawPayloadJson: string,
    onProgress?: (progress: ArticleOfflineSaveProgress) => void
  ): Promise<ArticleOfflineSnapshot | undefined> {
    if (this.offlineStore === undefined) {
      return Promise.resolve(undefined);
    }
    return Promise.resolve().then(() =>
      this.offlineStore!.save(content, document, rawPayloadJson, onProgress));
  }

  /** Remove one article's permanent offline files and metadata. */
  removeOffline(contentKey: string): Promise<void> {
    if (this.offlineStore === undefined) {
      return Promise.resolve();
    }
    return Promise.resolve().then(() => this.offlineStore!.remove(contentKey));
  }
}
