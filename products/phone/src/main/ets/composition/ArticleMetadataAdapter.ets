import {
  ArticleMetadataPort,
  ArticleRelatedTale,
  ArticleRelatedTaleSource
} from 'article';
import {
  CatalogTitleResolver,
  matchesExactScpReference,
  ScpHtmlRequestPriority,
  SeriesRelatedTaleEntry,
  SeriesTalesRepository,
  TaleRepository
} from 'catalog';
import {
  LibraryContentKind,
  LibraryContentRef,
  isLibraryScpId
} from 'library';

const FALLBACK_RELATED_TALES_LIMIT: number = 12;

/**
 * Product composition adapter for the catalog metadata shown by the Article chrome.
 * Prefers Wiki curated `scp-series-*-tales-edition` links before falling back to
 * boundary-safe title/slug matching against the global tale index.
 */
export class ArticleMetadataAdapter implements ArticleMetadataPort {
  private readonly titleResolver: CatalogTitleResolver;
  private readonly taleRepository: TaleRepository;
  private readonly seriesTalesRepository?: SeriesTalesRepository;

  constructor(
    titleResolver: CatalogTitleResolver,
    taleRepository: TaleRepository,
    seriesTalesRepository?: SeriesTalesRepository
  ) {
    this.titleResolver = titleResolver;
    this.taleRepository = taleRepository;
    this.seriesTalesRepository = seriesTalesRepository;
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

    if (this.seriesTalesRepository !== undefined) {
      try {
        const curated: SeriesRelatedTaleEntry[] =
          await this.seriesTalesRepository.listCuratedTalesForScp(
            content.id,
            ScpHtmlRequestPriority.BACKGROUND
          );
        if (curated.length > 0) {
          const cap = Math.min(limit, curated.length);
          const curatedResult: ArticleRelatedTale[] = [];
          for (let index: number = 0; index < cap; index++) {
            const tale = curated[index];
            curatedResult.push({
              id: tale.id,
              title: tale.title,
              source: ArticleRelatedTaleSource.SERIES_TALES_EDITION
            });
          }
          return curatedResult;
        }
      } catch (_error) {
        // Curated lookup failure falls back smoothly to the local/global tale index.
      }
    }

    // A cold article must not depend on another screen having populated the
    // tales cache first.  Use the catalog's normal load path when no snapshot
    // exists; it still returns immediately from cache when one is available.
    const cached = await this.taleRepository.getCached();
    const snapshot = cached ?? await this.taleRepository.load(ScpHtmlRequestPriority.BACKGROUND);
    const needle = content.id.trim().toLowerCase();
    const fallbackCap = Math.min(limit, FALLBACK_RELATED_TALES_LIMIT);
    const result: ArticleRelatedTale[] = [];
    for (let index: number = 0; index < snapshot.tales.length && result.length < fallbackCap; index++) {
      const tale = snapshot.tales[index];
      const taleId = tale.id.toLowerCase();
      if (taleId === needle) {
        continue;
      }
      if (matchesExactScpReference(taleId, needle) || matchesExactScpReference(tale.title, needle)) {
        result.push({
          id: tale.id,
          title: tale.title,
          source: ArticleRelatedTaleSource.TITLE_INDEX_FALLBACK
        });
      }
    }
    return result;
  }
}
