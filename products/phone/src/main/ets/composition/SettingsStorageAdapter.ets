import { fileIo as fs } from '@kit.CoreFileKit';
import { ArticleFeatureGraph } from 'article';
import { CatalogFeatureGraph, SearchHistoryRepository } from 'catalog';
import { SettingsStorageActions, SettingsStorageUsage } from 'settings';

const MAX_TRAVERSAL_DEPTH: number = 4;

/** Product storage adapter measuring disposable caches and forwarding cleanup actions. */
export class SettingsStorageAdapter implements SettingsStorageActions {
  private readonly cacheDir: string;
  private readonly filesDir: string;
  private readonly articleGraph: ArticleFeatureGraph;
  private readonly catalogGraph: CatalogFeatureGraph;
  private readonly searchHistory: SearchHistoryRepository;

  constructor(
    cacheDir: string,
    filesDir: string,
    articleGraph: ArticleFeatureGraph,
    catalogGraph: CatalogFeatureGraph,
    searchHistory: SearchHistoryRepository
  ) {
    this.cacheDir = cacheDir;
    this.filesDir = filesDir;
    this.articleGraph = articleGraph;
    this.catalogGraph = catalogGraph;
    this.searchHistory = searchHistory;
  }

  async inspect(): Promise<SettingsStorageUsage> {
    const cacheDirs: string[] = this.cacheDir.length > 0 ? [
      `${this.cacheDir}/scp_document_text_cache`,
      `${this.cacheDir}/scp_page_text_cache`,
      `${this.cacheDir}/scp_images`
    ] : [];
    const tempSizes = await Promise.all(
      cacheDirs.map((dirPath: string): Promise<number> => this.measureDirectoryBytes(dirPath, 0))
    );
    let tempCacheBytes: number = 0;
    for (let index = 0; index < tempSizes.length; index++) {
      tempCacheBytes += tempSizes[index];
    }
    const archive3DBytes = this.filesDir.length > 0 ?
      await this.measureDirectoryBytes(`${this.filesDir}/archive3d/v1/objects`, 0) : 0;
    const offlineArticlesBytes = this.filesDir.length > 0 ?
      await this.measureDirectoryBytes(`${this.filesDir}/offline_articles/v1`, 0) : 0;
    let offlineArticlesCount: number = 0;
    try {
      offlineArticlesCount = (await this.articleGraph.listOfflineArticles()).length;
    } catch (_offlineListError) {
      offlineArticlesCount = 0;
    }
    return {
      tempCacheBytes,
      archive3DBytes,
      offlineArticlesBytes,
      offlineArticlesCount,
      searchHistoryCount: this.searchHistory.list().length
    };
  }

  async clearTempCaches(): Promise<SettingsStorageUsage> {
    await Promise.all([
      this.articleGraph.clearDocumentCache(),
      this.catalogGraph.clearTemporaryCaches()
    ]);
    return this.inspect();
  }

  async clearSearchHistory(): Promise<SettingsStorageUsage> {
    this.searchHistory.clear();
    return this.inspect();
  }

  private async measureDirectoryBytes(dirPath: string, depth: number): Promise<number> {
    if (depth > MAX_TRAVERSAL_DEPTH || dirPath.length === 0) {
      return 0;
    }
    try {
      if (!(await fs.access(dirPath))) {
        return 0;
      }
      const rootStat = await fs.lstat(dirPath);
      if (rootStat.isSymbolicLink() || !rootStat.isDirectory()) {
        return 0;
      }
      const names = await fs.listFile(dirPath);
      let total: number = 0;
      for (let index = 0; index < names.length; index++) {
        const entryPath = `${dirPath}/${names[index]}`;
        try {
          const stat = await fs.lstat(entryPath);
          if (stat.isSymbolicLink()) {
            continue;
          }
          if (stat.isFile()) {
            total += stat.size;
          } else if (stat.isDirectory()) {
            total += await this.measureDirectoryBytes(entryPath, depth + 1);
          }
        } catch (_entryError) {
        }
      }
      return total;
    } catch (_dirError) {
      return 0;
    }
  }
}
