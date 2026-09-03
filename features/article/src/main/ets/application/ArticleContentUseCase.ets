import { LibraryContentRef } from 'library';
import {
  ArticleContentGateway,
  ArticleLoadResult,
  PendingExtraction,
  ArticleMetadataPort,
  ArticleRelatedTale
} from '../domain/ArticleContracts';
import { ScpArticleDocument } from '../domain/ScpDocument';

/** Coordinates cache hit, HTML retrieval and native-first document projection. */
export class ArticleContentUseCase {
  private readonly gateway: ArticleContentGateway;
  private readonly metadata: ArticleMetadataPort | undefined;

  constructor(gateway: ArticleContentGateway, metadata?: ArticleMetadataPort) {
    this.gateway = gateway;
    this.metadata = metadata;
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
}
