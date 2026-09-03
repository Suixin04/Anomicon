/** 可进入统一阅读页的内容类型。 */
export enum LibraryContentKind {
  SCP = 'scp',
  TALE = 'tale',
  WIKI = 'wiki',
  KNOWLEDGE = 'knowledge'
}

/**
 * 统一内容身份。
 *
 * 当前资料库只接入 SCP 中文维基主站，因此 `key` 只由站点与规范化后的页面
 * slug 组成。`kind` 仅描述展示与路由语义；同一页面从探索、图鉴、故事或手册
 * 入口进入时仍是同一份内容，标题或入口分类变化都不会制造重复收藏与历史。
 * 该模型保持为只读值对象，既可安全写入路由参数，也可直接持久化。
 */
export class LibraryContentRef {
  readonly key: string;
  readonly id: string;
  readonly title: string;
  readonly kind: LibraryContentKind;

  constructor(kind: LibraryContentKind, id: string, title: string) {
    const normalizedId = normalizeLibraryContentId(id);
    this.kind = kind;
    this.id = normalizedId;
    this.title = title.trim().length > 0 ? title.trim() : normalizedId;
    this.key = libraryContentKey(normalizedId);
  }
}

/** 一条收藏记录；收藏内容本身保持不可变，变更通过数组整体替换发布。 */
export class LibraryFavorite {
  readonly content: LibraryContentRef;
  readonly favoritedAt: number;

  constructor(content: LibraryContentRef, favoritedAt: number) {
    this.content = content;
    this.favoritedAt = favoritedAt;
  }
}

export function createLibraryContentRef(
  kind: LibraryContentKind,
  id: string,
  title: string
): LibraryContentRef {
  return new LibraryContentRef(kind, id, title);
}

/** 空标题和仅重复页面编号的标题都只是占位值，不应覆盖已有的可读名称。 */
export function isLibraryContentTitlePlaceholder(id: string, title: string): boolean {
  const normalizedTitle = title.trim().toLowerCase();
  return normalizedTitle.length === 0 || normalizedTitle === normalizeLibraryContentId(id);
}

/** Recognize main-site SCP slugs, including original CN and alphanumeric joke ids. */
export function isLibraryScpId(id: string): boolean {
  return /^scp-(?:(?:[a-z]{2,4}-)?\d+|[a-z0-9]*\d+[a-z0-9]*)(?:-[a-z0-9]+)*$/i.test(id.trim());
}

/**
 * 写入同一内容的新快照时保留质量更高的旧标题。
 * 类型与编号采用本次入口语义，只有标题允许从旧快照回退。
 */
export function preferLibraryContentMetadata(
  incoming: LibraryContentRef,
  existing: LibraryContentRef | undefined
): LibraryContentRef {
  if (existing === undefined || existing.key !== incoming.key ||
    !isLibraryContentTitlePlaceholder(incoming.id, incoming.title) ||
    isLibraryContentTitlePlaceholder(existing.id, existing.title)) {
    return incoming;
  }
  return new LibraryContentRef(incoming.kind, incoming.id, existing.title);
}

/** 生成主站页面稳定身份。入口分类只影响展示，不制造重复记录。 */
function libraryContentKey(id: string): string {
  return `main:${normalizeLibraryContentId(id)}`;
}

/** 将数据库字符串收窄回已知内容类型；未知值由调用方忽略。 */
export function parseLibraryContentKind(value: string): LibraryContentKind | undefined {
  switch (value) {
    case LibraryContentKind.SCP:
      return LibraryContentKind.SCP;
    case LibraryContentKind.TALE:
      return LibraryContentKind.TALE;
    case LibraryContentKind.WIKI:
      return LibraryContentKind.WIKI;
    case LibraryContentKind.KNOWLEDGE:
      return LibraryContentKind.KNOWLEDGE;
    default:
      return undefined;
  }
}

function normalizeLibraryContentId(id: string): string {
  // Routes and parsed wiki links may supply either `scp-173` or
  // `/scp-173`.  They identify the same main-site page, so path separators
  // at the boundary must not become part of the persistence key.  Collapse
  // repeated leading slashes as well to keep old/imported route payloads
  // deterministic without changing meaningful slashes inside a slug.
  let normalized = id.trim().toLowerCase();
  while (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  if (normalized.length === 0) {
    throw new Error('内容标识不能为空');
  }
  return normalized;
}
