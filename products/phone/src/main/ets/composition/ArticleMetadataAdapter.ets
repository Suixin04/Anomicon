import {
  ArticleMetadataPort,
  ArticleRelatedTale
} from 'article';
import {
  CatalogTitleResolver,
  TaleRepository,
  ScpHtmlRequestPriority
} from 'catalog';
import {
  LibraryContentKind,
  LibraryContentRef,
  isLibraryScpId
} from 'library';

/**
 * Product composition adapter for the small amount of catalog metadata shown
 * by the Article chrome.  Article receives only ArticleMetadataPort; the
 * catalog snapshot and resolver remain behind this product-to-feature seam.
 */
export class ArticleMetadataAdapter implements ArticleMetadataPort {
  private readonly titleResolver: CatalogTitleResolver;
  private readonly taleRepository: TaleRepository;

  constructor(titleResolver: CatalogTitleResolver, taleRepository: TaleRepository) {
    this.titleResolver = titleResolver;
    this.taleRepository = taleRepository;
  }

  resolveTitle(content: LibraryContentRef): Promise<string> {
    if (content.kind !== LibraryContentKind.SCP && !isLibraryScpId(content.id)) {
      return Promise.resolve('');
    }
    return this.titleResolver.resolve(content.id).catch((): string => '');
  }

  async listRelatedTales(
    content: LibraryContentRef,
    limit: number
  ): Promise<ArticleRelatedTale[]> {
    if ((content.kind !== LibraryContentKind.SCP && !isLibraryScpId(content.id)) || limit <= 0) {
      return [];
    }
    // A cold article must not depend on another screen having populated the
    // tales cache first.  Use the catalog's normal load path when no snapshot
    // exists; it still returns immediately from cache when one is available.
    const cached = await this.taleRepository.getCached();
    const snapshot = cached ?? await this.taleRepository.load(ScpHtmlRequestPriority.BACKGROUND);
    const needle = content.id.toLowerCase();
    const result: ArticleRelatedTale[] = [];
    for (let index: number = 0; index < snapshot.tales.length && result.length < limit; index++) {
      const tale = snapshot.tales[index];
      const taleId = tale.id.toLowerCase();
      if (taleId === needle) {
        continue;
      }
      if (taleId.includes(needle) || tale.title.toLowerCase().includes(needle)) {
        result.push({ id: tale.id, title: tale.title });
      }
    }
    return result;
  }
}
