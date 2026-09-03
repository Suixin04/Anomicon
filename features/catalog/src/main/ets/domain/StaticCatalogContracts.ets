/** 系列目录静态解析器的原始条目结构。 */
export interface ScpCatalogRawEntry {
  itemId: string;
  title: string;
  description?: string;
}

/** 系列目录静态解析器的输出版本；变更时使旧派生缓存失效。 */
// v5 extends the accepted identity set to original CN SCP pages (for example
// SCP-CN-2000) so their catalog titles can be used by the article chrome.
export const SCP_CATALOG_PARSER_VERSION: number = 5;

export interface ScpCatalogPayload {
  parserVersion: number;
  ok: boolean;
  error: string;
  entries: ScpCatalogRawEntry[];
}

/** 故事列表静态解析器的原始条目结构。 */
export interface TaleRawEntry {
  id: string;
  title: string;
}

/** 故事列表静态解析器的输出版本；变更时使旧派生缓存失效。 */
// v4 merges the translated index with the separate Chinese-original tales
// index, so v3 caches must be rebuilt once on upgrade.
export const TALE_LIST_PARSER_VERSION: number = 4;

export interface TalePayload {
  parserVersion: number;
  ok: boolean;
  error: string;
  tales: TaleRawEntry[];
}
