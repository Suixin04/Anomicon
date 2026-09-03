import {
  ScpArticleDocument,
  ScpBlockType,
  ScpContentBlock,
  ScpFootnote,
  ScpTextSpan,
  ScpTextStyle
} from '../main/ets/domain/ScpDocument';

export const CURRENT_PAYLOAD: string = `{
  "parserVersion": 5,
  "ok": true,
  "error": "",
  "title": "SCP-173 - 雕像",
  "rating": "+321",
  "pageVersion": "页面版本：4",
  "tags": ["scp", "safe", "人形生物"],
  "images": [{"src": "https://example.com/archive.png", "caption": "档案图片"}],
  "blocks": [
    {
      "k": "paragraph",
      "spans": [
        {"s": "plain", "t": "项目等级：Safe"},
        {"s": "strong", "t": " 强调"},
        {"s": "link", "t": " 链接", "u": "/scp-682"},
        {"s": "footnote", "t": "1", "r": "note-1"}
      ]
    },
    {
      "k": "collapsible",
      "title": "展开记录",
      "blocks": [{"k": "paragraph", "spans": [{"s": "em", "t": "隐藏内容"}]}]
    },
    {
      "k": "table",
      "blocks": [{
        "k": "row",
        "blocks": [{"k": "cell", "spans": [{"s": "code", "t": "A1"}]}]
      }]
    },
    {"k": "image", "src": "https://example.com/inline.png", "caption": "行内图片"}
  ],
  "footnotes": [{
    "id": "note-1",
    "index": 1,
    "blocks": [{"k": "paragraph", "spans": [{"s": "plain", "t": "脚注正文"}]}]
  }],
  "warnings": ["degraded:test-warning", "degraded:test-warning"]
}`;

/** A structurally valid payload from a parser version this build does not support. */
export const UNSUPPORTED_PARSER_PAYLOAD: string = `{
  "parserVersion": 99,
  "ok": true,
  "error": "",
  "title": "SCP-173 unsupported payload",
  "rating": "",
  "pageVersion": "",
  "tags": [],
  "images": [],
  "blocks": [{"k": "paragraph", "spans": [{"s": "plain", "t": "项目等级：Safe"}]}],
  "footnotes": [],
  "warnings": []
}`;

export function createRendererDocument(fetchedAt: number = 100): ScpArticleDocument {
  const text = new ScpContentBlock(
    'scp-173:0:0',
    ScpBlockType.PARAGRAPH,
    [
      new ScpTextSpan(ScpTextStyle.PLAIN, 'A'),
      new ScpTextSpan(ScpTextStyle.STRONG, 'B'),
      new ScpTextSpan(ScpTextStyle.FOOTNOTE_REFERENCE, '1', '', 'note-1')
    ]
  );
  const child = new ScpContentBlock(
    'scp-173:0:1:0',
    ScpBlockType.PARAGRAPH,
    [new ScpTextSpan(ScpTextStyle.PLAIN, '隐藏内容')]
  );
  const collapsible = new ScpContentBlock(
    'scp-173:0:1',
    ScpBlockType.COLLAPSIBLE,
    [],
    '',
    '展开',
    0,
    [child]
  );
  const image = new ScpContentBlock(
    'scp-173:image:0',
    ScpBlockType.IMAGE,
    [],
    'https://example.com/archive.png',
    '档案图片'
  );
  return new ScpArticleDocument(
    'SCP-173',
    'SCP-173 - 雕像',
    'Safe',
    'https://scp-wiki-cn.wikidot.com/scp-173',
    fetchedAt,
    [text, collapsible],
    [new ScpFootnote('note-1', 1, [child])],
    '',
    [],
    '+321',
    ['scp'],
    '页面版本：4',
    [image]
  );
}
