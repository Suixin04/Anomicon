/** 系列目录静态解析器的原始条目结构。 */
export interface ScpCatalogRawEntry {
  itemId: string;
  title: string;
  description?: string;
}

/** 系列目录静态解析器的输出版本；变更时使旧派生缓存失效。 */
export const SCP_CATALOG_PARSER_VERSION: number = 4;

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
export const TALE_LIST_PARSER_VERSION: number = 3;

export interface TalePayload {
  parserVersion: number;
  ok: boolean;
  error: string;
  tales: TaleRawEntry[];
}
