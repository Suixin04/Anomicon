/**
 * Article 正文的块类型。使用可扩展的标记结构，避免为每种 Wikidot 组件制造一套继承层级。
 */
export enum ScpBlockType {
  PARAGRAPH = 'paragraph',
  HEADING = 'heading',
  IMAGE = 'image',
  QUOTE = 'quote',
  COLLAPSIBLE = 'collapsible',
  TABLE = 'table',
  TABLE_ROW = 'table_row',
  TABLE_CELL = 'table_cell',
  DIVIDER = 'divider',
  EMBED = 'embed',
  UNSUPPORTED = 'unsupported'
}

export enum ScpTextStyle {
  PLAIN = 'plain',
  STRONG = 'strong',
  EMPHASIS = 'emphasis',
  DELETED = 'deleted',
  CODE = 'code',
  LINK = 'link',
  FOOTNOTE_REFERENCE = 'footnote_reference'
}

/** 行内结构：链接、强调与脚注引用由统一 HTML 提取协议填充。 */
export class ScpTextSpan {
  readonly style: ScpTextStyle;
  readonly text: string;
  readonly target: string;
  readonly referenceId: string;

  constructor(
    style: ScpTextStyle,
    text: string,
    target: string = '',
    referenceId: string = ''
  ) {
    this.style = style;
    this.text = text;
    this.target = target;
    this.referenceId = referenceId;
  }
}

/** 单一正文节点。 */
export class ScpContentBlock {
  readonly key: string;
  readonly type: ScpBlockType;
  readonly spans: ScpTextSpan[];
  readonly source: string;
  readonly caption: string;
  readonly level: number;
  readonly children: ScpContentBlock[];

  constructor(
    key: string,
    type: ScpBlockType,
    spans: ScpTextSpan[] = [],
    source: string = '',
    caption: string = '',
    level: number = 0,
    children: ScpContentBlock[] = []
  ) {
    this.key = key;
    this.type = type;
    this.spans = spans;
    this.source = source;
    this.caption = caption;
    this.level = level;
    this.children = children;
  }
}

export class ScpFootnote {
  readonly id: string;
  readonly index: number;
  readonly blocks: ScpContentBlock[];

  constructor(id: string, index: number, blocks: ScpContentBlock[]) {
    this.id = id;
    this.index = index;
    this.blocks = blocks;
  }
}

export class ScpArticleDocument {
  /** v5：增加原创 CN 双语标记投影，避免隐藏的繁体分支重复进入正文。 */
  static readonly CURRENT_SCHEMA_VERSION: number = 5;
  static readonly CURRENT_PARSER_VERSION: number = 5;

  readonly schemaVersion: number;
  readonly itemId: string;
  readonly title: string;
  readonly objectClass: string;
  readonly rating: string;
  readonly tags: string[];
  readonly pageVersion: string;
  readonly images: ScpContentBlock[];
  readonly sourceUrl: string;
  readonly sourceRevision: string;
  readonly fetchedAt: number;
  readonly blocks: ScpContentBlock[];
  readonly footnotes: ScpFootnote[];
  readonly parserWarnings: string[];

  constructor(
    itemId: string,
    title: string,
    objectClass: string,
    sourceUrl: string,
    fetchedAt: number,
    blocks: ScpContentBlock[],
    footnotes: ScpFootnote[] = [],
    sourceRevision: string = '',
    parserWarnings: string[] = [],
    rating: string = '',
    tags: string[] = [],
    pageVersion: string = '',
    images: ScpContentBlock[] = []
  ) {
    this.schemaVersion = ScpArticleDocument.CURRENT_SCHEMA_VERSION;
    this.itemId = itemId;
    this.title = title;
    this.objectClass = objectClass;
    this.rating = rating;
    this.tags = tags;
    this.pageVersion = pageVersion;
    this.images = images;
    this.sourceUrl = sourceUrl;
    this.sourceRevision = sourceRevision;
    this.fetchedAt = fetchedAt;
    this.blocks = blocks;
    this.footnotes = footnotes;
    this.parserWarnings = parserWarnings;
  }
}
