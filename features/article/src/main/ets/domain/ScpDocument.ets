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
  UNSUPPORTED = 'unsupported',
  ACS_HEADER = 'acs_header',
  TABS = 'tabs',
  TAB_PANEL = 'tab_panel',
  CALLOUT = 'callout',
  CODE_BLOCK = 'code_block',
  LIST = 'list',
  LIST_ITEM = 'list_item'
}

export enum ScpCalloutTone {
  NEUTRAL = 'neutral',
  TERMINAL = 'terminal',
  WARNING = 'warning',
  NOTE = 'note'
}

export class ScpAcsMetadata {
  readonly itemNumber: string;
  readonly clearanceLevel: string;
  readonly containmentClass: string;
  readonly secondaryClass: string;
  readonly disruptionClass: string;
  readonly riskClass: string;
  readonly memoUrl: string;

  constructor(
    itemNumber: string = '',
    clearanceLevel: string = '',
    containmentClass: string = '',
    secondaryClass: string = '',
    disruptionClass: string = '',
    riskClass: string = '',
    memoUrl: string = ''
  ) {
    this.itemNumber = itemNumber;
    this.clearanceLevel = clearanceLevel;
    this.containmentClass = containmentClass;
    this.secondaryClass = secondaryClass;
    this.disruptionClass = disruptionClass;
    this.riskClass = riskClass;
    this.memoUrl = memoUrl;
  }
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

export enum ScpTextAlign {
  DEFAULT = 'default',
  START = 'start',
  CENTER = 'center',
  END = 'end',
  JUSTIFY = 'justify'
}

export enum ScpHiddenTextKind {
  NONE = 'none',
  WHITE_EASTER_EGG = 'white_easter_egg',
  ZERO_SIZE_WHISPER = 'zero_size_whisper',
  BLACKBOX = 'blackbox'
}

/** 行内结构：链接、强调、复合样式与彩蛋状态由统一 HTML 提取协议填充。 */
export class ScpTextSpan {
  readonly style: ScpTextStyle;
  readonly text: string;
  readonly target: string;
  readonly referenceId: string;
  readonly bold: boolean;
  readonly italic: boolean;
  readonly deleted: boolean;
  readonly underline: boolean;
  readonly monospace: boolean;
  readonly superscript: boolean;
  readonly subscript: boolean;
  readonly color: string;
  readonly fontScale: number;
  readonly hiddenKind: ScpHiddenTextKind;

  constructor(
    style: ScpTextStyle,
    text: string,
    target: string = '',
    referenceId: string = '',
    bold: boolean = false,
    italic: boolean = false,
    deleted: boolean = false,
    underline: boolean = false,
    monospace: boolean = false,
    superscript: boolean = false,
    subscript: boolean = false,
    color: string = '',
    fontScale: number = 1,
    hiddenKind: ScpHiddenTextKind = ScpHiddenTextKind.NONE
  ) {
    this.style = style;
    this.text = text;
    this.target = target;
    this.referenceId = referenceId;
    this.bold = bold || style === ScpTextStyle.STRONG;
    this.italic = italic || style === ScpTextStyle.EMPHASIS;
    this.deleted = deleted || style === ScpTextStyle.DELETED;
    this.underline = underline;
    this.monospace = monospace || style === ScpTextStyle.CODE;
    this.superscript = superscript;
    this.subscript = subscript;
    this.color = color;
    this.fontScale = Number.isFinite(fontScale) && fontScale > 0 ? fontScale : 1;
    this.hiddenKind = hiddenKind;
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
  readonly closeCaption: string;
  readonly initiallyExpanded: boolean;
  readonly ordered: boolean;
  readonly isHeader: boolean;
  readonly calloutTone: ScpCalloutTone;
  readonly preferredWidth: number;
  readonly acs: ScpAcsMetadata | undefined;
  readonly textAlign: ScpTextAlign;
  readonly anchors: string[];

  constructor(
    key: string,
    type: ScpBlockType,
    spans: ScpTextSpan[] = [],
    source: string = '',
    caption: string = '',
    level: number = 0,
    children: ScpContentBlock[] = [],
    closeCaption: string = '',
    initiallyExpanded: boolean = false,
    ordered: boolean = false,
    isHeader: boolean = false,
    calloutTone: ScpCalloutTone = ScpCalloutTone.NEUTRAL,
    preferredWidth: number = 0,
    acs: ScpAcsMetadata | undefined = undefined,
    textAlign: ScpTextAlign = ScpTextAlign.DEFAULT,
    anchors: string[] = []
  ) {
    this.key = key;
    this.type = type;
    this.spans = spans;
    this.source = source;
    this.caption = caption;
    this.level = level;
    this.children = children;
    this.closeCaption = closeCaption;
    this.initiallyExpanded = initiallyExpanded;
    this.ordered = ordered;
    this.isHeader = isHeader;
    this.calloutTone = calloutTone;
    this.preferredWidth = preferredWidth;
    this.acs = acs;
    this.textAlign = textAlign;
    this.anchors = anchors;
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
  /** v9：保留原文锚点 id/name，支持章节目录与锚点/查找定位。 */
  static readonly CURRENT_SCHEMA_VERSION: number = 9;
  static readonly CURRENT_PARSER_VERSION: number = 9;

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
  readonly creditBlocks: ScpContentBlock[];

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
    images: ScpContentBlock[] = [],
    creditBlocks: ScpContentBlock[] = []
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
    this.creditBlocks = creditBlocks;
  }
}
