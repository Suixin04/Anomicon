import {
  CatalogEntry,
  CatalogPreview,
  CatalogSnapshot,
  CatalogTaleEntry,
  TaleSnapshot
} from './CatalogContracts';
import { ScpHtmlRequestPriority } from './ArticleHtmlRepository';
import { ScpSeriesDescriptor } from './ScpSeriesItem';

export type CatalogSnapshotListener = (snapshot: CatalogSnapshot) => void;

/** 系列目录持久化/网络端口。实现可使用 RDB、RCP 和 TaskPool。 */
export interface CatalogRepository {
  getCached(seriesId: string): Promise<CatalogSnapshot | undefined>;
  load(series: ScpSeriesDescriptor, priority?: ScpHtmlRequestPriority): Promise<CatalogSnapshot>;
  refresh(series: ScpSeriesDescriptor, priority?: ScpHtmlRequestPriority): Promise<CatalogSnapshot>;
  subscribe(seriesId: string, listener: CatalogSnapshotListener): () => void;
}

export type TaleSnapshotListener = (snapshot: TaleSnapshot) => void;

/** 故事目录端口。读取和重验分开，便于 application 表达 stale-while-revalidate。 */
export interface TaleRepository {
  getCached(): Promise<TaleSnapshot | undefined>;
  load(priority?: ScpHtmlRequestPriority): Promise<TaleSnapshot>;
  refresh(priority?: ScpHtmlRequestPriority): Promise<TaleSnapshot>;
  subscribe(listener: TaleSnapshotListener): () => void;
}

export type PreviewRefreshListener = (preview: CatalogPreview) => void;

/** 卡片预览端口；图片下载和安全校验不向 ViewModel 泄漏。 */
export interface PreviewRepository {
  getPreview(
    itemId: string,
    onRefreshed?: PreviewRefreshListener,
    priority?: ScpHtmlRequestPriority,
    forceRefresh?: boolean
  ): Promise<CatalogPreview>;

  /** Build a preview from HTML the caller has already fetched. */
  resolveFetchedHtml(
    itemId: string,
    html: string,
    fetchedAt?: number
  ): Promise<CatalogPreview>;

  prefetch(itemIds: string[]): void;
  cancelQueuedPrefetch(itemIds: string[]): void;
}

/** 搜索历史端口，保持最多十条、去重和显式清空语义。 */
export interface SearchHistoryRepository {
  list(): string[];
  add(query: string): void;
  clear(): void;
}

/** 正文/终端标题解析端口；只消费已持久化的目录派生缓存。 */
export interface CatalogTitleResolver {
  resolve(itemId: string): Promise<string>;
  resolveMany(itemIds: string[]): Promise<Map<string, string>>;
}

function compactSearchToken(value: string): string {
  return value.toLowerCase().replace(/[\s-]+/g, '');
}

/** 供纯 application 用例过滤，避免把 UI DTO 放入 domain；按精确/前缀/包含分段保持稳定排序。 */
export function filterCatalogEntries(entries: CatalogEntry[], query: string): CatalogEntry[] {
  const normalized = query.trim().toLowerCase();
  if (normalized.length === 0) {
    return entries.slice();
  }
  const compact = compactSearchToken(normalized);
  if (compact.length === 0) {
    return entries.slice();
  }
  const prefixedCompact = compact.startsWith('scp') ? compact : `scp${compact}`;
  const exactBucket: CatalogEntry[] = [];
  const idPrefixBucket: CatalogEntry[] = [];
  const titlePrefixBucket: CatalogEntry[] = [];
  const containsBucket: CatalogEntry[] = [];

  for (let index = 0; index < entries.length; index++) {
    const entry = entries[index];
    const idLower = entry.itemId.toLowerCase();
    const titleLower = entry.title.toLowerCase();
    const compactId = compactSearchToken(idLower);

    if (
      idLower === normalized ||
      titleLower === normalized ||
      compactId === compact ||
      compactId === prefixedCompact
    ) {
      exactBucket.push(entry);
      continue;
    }
    if (
      idLower.startsWith(normalized) ||
      compactId.startsWith(compact) ||
      compactId.startsWith(prefixedCompact)
    ) {
      idPrefixBucket.push(entry);
      continue;
    }
    if (titleLower.startsWith(normalized)) {
      titlePrefixBucket.push(entry);
      continue;
    }
    if (
      idLower.includes(normalized) ||
      titleLower.includes(normalized) ||
      compactId.includes(compact)
    ) {
      containsBucket.push(entry);
    }
  }
  return exactBucket
    .concat(idPrefixBucket)
    .concat(titlePrefixBucket)
    .concat(containsBucket);
}

export function filterTaleEntries(
  tales: CatalogTaleEntry[],
  query: string,
  letter: string
): CatalogTaleEntry[] {
  const normalizedQuery = query.trim().toLowerCase();
  const normalizedLetter = letter.trim().toUpperCase();
  const compactQuery = compactSearchToken(normalizedQuery);
  const exactBucket: CatalogTaleEntry[] = [];
  const prefixBucket: CatalogTaleEntry[] = [];
  const containsBucket: CatalogTaleEntry[] = [];

  for (let index = 0; index < tales.length; index++) {
    const tale = tales[index];
    if (normalizedLetter.length > 0 && tale.id.charAt(0).toUpperCase() !== normalizedLetter) {
      continue;
    }
    if (normalizedQuery.length === 0) {
      exactBucket.push(tale);
      continue;
    }
    const idLower = tale.id.toLowerCase();
    const titleLower = tale.title.toLowerCase();
    const compactId = compactSearchToken(idLower);
    if (idLower === normalizedQuery || titleLower === normalizedQuery) {
      exactBucket.push(tale);
    } else if (idLower.startsWith(normalizedQuery) || titleLower.startsWith(normalizedQuery)) {
      prefixBucket.push(tale);
    } else if (
      idLower.includes(normalizedQuery) ||
      titleLower.includes(normalizedQuery) ||
      (compactQuery.length > 0 && compactId.includes(compactQuery))
    ) {
      containsBucket.push(tale);
    }
  }
  return exactBucket.concat(prefixBucket).concat(containsBucket);
}
