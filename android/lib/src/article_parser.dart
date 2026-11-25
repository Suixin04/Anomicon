import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import 'models.dart';

Uri? articleHttpUrl(Uri base, String raw) {
  if (raw.trim().isEmpty) return null;
  final location = Uri.tryParse(raw.trim());
  if (location == null) return null;
  final uri = base.resolveUri(location);
  return (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

/// Expand Wikidot HTML includes before caching the body. Resolve assets/links
/// against the frame rather than against the parent article.
Future<String> expandArticleFrames(
  String source,
  Uri uri,
  Future<String> Function(Uri) fetch,
) async {
  final document = html.parse(source);
  final page = document.getElementById('page-content') ?? document.body!;
  for (final frame in page.querySelectorAll('iframe.html-block-iframe[src]')) {
    final target = articleHttpUrl(uri, frame.attributes['src']!);
    if (target == null ||
        target.origin != uri.origin ||
        !(target.path.startsWith('/html/') || target.path.contains('/html/'))) {
      continue;
    }
    final body = html.parse(await fetch(target)).body!;
    for (final item in body.querySelectorAll('a[href], img[src]')) {
      final attribute = item.localName == 'a' ? 'href' : 'src';
      final value = item.attributes[attribute]!;
      if (attribute == 'href' && value.startsWith('#')) continue;
      final resolved = articleHttpUrl(target, value);
      if (resolved != null) item.attributes[attribute] = resolved.toString();
    }
    final replacement = Element.tag('div')..nodes.addAll(body.nodes.toList());
    frame.replaceWith(replacement);
  }
  return document.outerHtml;
}

ArticleDocument parseNativeArticle(
  ContentRef content,
  String source,
  int fetchedAt,
) {
  final address = articleUrlOf(content.id);
  final root = html.parse(source);
  final page = root.getElementById('page-content') ?? root.body!;
  for (final item in page.querySelectorAll(
    'script,style,noscript,iframe,form,.page-options,.footer-wikiwalk-nav,#page-info',
  )) {
    item.remove();
  }
  final parser = _NativeParser(Uri.parse(address))..visit(page);
  return ArticleDocument(
    content: content,
    sourceUrl: address,
    fetchedAt: fetchedAt,
    blocks: parser.blocks,
    anchors: parser.anchors,
    links: parser.links,
    footnotes: parser.footnotes,
    folds: parser.folds,
  );
}

String _clean(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

class _NativeParser {
  _NativeParser(this.base);

  final Uri base;
  final blocks = <ArticleBlock>[];
  final anchors = <String, int>{};
  final links = <int, List<ArticleInlineLink>>{};
  final footnotes = <String, ArticleFootnote>{};
  final folds = <ArticleFold>[];
  static const _containers = {
    'div',
    'section',
    'article',
    'main',
    'li',
    'center',
    'dl',
    'dd',
    'dt',
  };
  static const _textTags = {
    'p',
    'pre',
    'blockquote',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
  };

  void visit(Element item) {
    final start = blocks.length;
    final tag = item.localName!;
    final id = item.id;
    if (id.startsWith('footnote:')) return; // reference is rendered inline
    if (id.startsWith('footnote-') &&
        item.classes.contains('footnote-footer')) {
      final label = _clean(
        item.querySelector('a[href]')?.text ?? id.substring(9),
      );
      final text = _clean(item.text).replaceFirst(RegExp(r'^\d+\.?\s*'), '');
      footnotes[id] = ArticleFootnote(id, label, text);
      return;
    }
    if (item.classes.contains('footnotes-footer')) {
      for (final child in item.querySelectorAll('.footnote-footer')) {
        visit(child);
      }
      return;
    }
    final caption = item.classes.contains('scp-image-block')
        ? _clean(item.querySelector('.scp-image-caption')?.text ?? '')
        : '';
    if (caption.isNotEmpty) {
      for (final image in item.querySelectorAll('img')) {
        _image(image, caption: caption);
      }
    } else if (item.classes.contains('collapsible-block') || tag == 'details') {
      final content = item.querySelector('.collapsible-block-content');
      final label = _clean(
        item.querySelector('summary,.collapsible-block-link')?.text ?? '折叠内容',
      );
      if (content != null) {
        visit(content);
      } else {
        for (final child in item.children.where(
          (child) => child.localName != 'summary',
        )) {
          visit(child);
        }
      }
      if (start < blocks.length) {
        folds.add(ArticleFold(label, start, blocks.length));
      }
    } else if (tag == 'img') {
      _image(item);
    } else if (tag == 'hr') {
      blocks.add(const ArticleDivider());
    } else if (tag == 'table') {
      for (final row in item.querySelectorAll('tr')) {
        _text(row, ArticleParagraph.new);
      }
    } else if (tag == 'ul' || tag == 'ol') {
      var ordinal = 0;
      for (final child in item.children.where(
        (child) => child.localName == 'li',
      )) {
        final marker = tag == 'ol' ? '${++ordinal}. ' : '• ';
        _text(child, ArticleParagraph.new, prefix: marker);
      }
    } else if (_textTags.contains(tag)) {
      final heading = tag.startsWith('h');
      _text(
        item,
        heading
            ? (text) => ArticleHeading(text, int.parse(tag.substring(1)))
            : tag == 'blockquote'
            ? ArticleQuote.new
            : ArticleParagraph.new,
      );
    } else if (item.children.any(
      (child) =>
          _containers.contains(child.localName) ||
          _textTags.contains(child.localName) ||
          const {
            'img',
            'table',
            'ol',
            'ul',
            'hr',
            'details',
          }.contains(child.localName),
    )) {
      // Preserve standalone text and links between block-level children.
      var inline = Element.tag('span');
      for (final child in item.nodes.toList()) {
        if (child is Element &&
            (_containers.contains(child.localName) ||
                _textTags.contains(child.localName) ||
                const {
                  'img',
                  'table',
                  'ol',
                  'ul',
                  'hr',
                  'details',
                }.contains(child.localName))) {
          _text(inline, ArticleParagraph.new);
          inline = Element.tag('span');
          visit(child);
        } else {
          inline.append(child.clone(true));
        }
      }
      _text(inline, ArticleParagraph.new);
    } else {
      _text(item, ArticleParagraph.new);
    }
    if (id.isNotEmpty) anchors.putIfAbsent(id, () => start);
  }

  void _image(Element image, {String caption = ''}) {
    final url = articleHttpUrl(base, image.attributes['src'] ?? '');
    if (url != null) {
      blocks.add(
        ArticleImage(
          url.toString(),
          _clean(image.attributes['alt'] ?? ''),
          caption: caption,
        ),
      );
    }
  }

  void _text(
    Element item,
    ArticleBlock Function(String) create, {
    String prefix = '',
  }) {
    for (final image in item.querySelectorAll('img')) {
      _image(image);
    }
    final text = StringBuffer(prefix);
    final inlineLinks = <({Uri target, int start, int end})>[];
    var hasText = false;
    var pendingSpace = false;

    void append(Node node) {
      if (node is Text) {
        for (final match in _inlineRuns.allMatches(node.data)) {
          final word = match.group(1);
          if (word == null) {
            pendingSpace = hasText;
            continue;
          }
          if (pendingSpace) text.write(' ');
          text.write(word);
          hasText = true;
          pendingSpace = false;
        }
      } else if (node is Element) {
        final start = text.length;
        for (final child in node.nodes) {
          append(child);
        }
        final href = node.localName == 'a' ? node.attributes['href'] : null;
        if (href != null && text.length > start) {
          final target = articleHttpUrl(base, href);
          if (target != null) {
            inlineLinks.add((target: target, start: start, end: text.length));
          }
        }
      }
    }

    append(item);
    final index = blocks.length;
    for (final child in item.querySelectorAll('[id], a[name]')) {
      final anchor = child.id.isNotEmpty ? child.id : child.attributes['name']!;
      anchors.putIfAbsent(anchor, () => index);
    }
    if (!hasText) return;
    final rendered = text.toString();
    blocks.add(create(rendered));
    if (inlineLinks.isNotEmpty) {
      links[index] = [
        for (final link in inlineLinks)
          ArticleInlineLink(
            rendered.substring(_linkStart(rendered, link.start), link.end),
            link.target,
            _linkStart(rendered, link.start),
          ),
      ];
    }
  }
}

final _inlineRuns = RegExp(r'(\S+)|\s+');

int _linkStart(String rendered, int start) =>
    rendered[start] == ' ' ? start + 1 : start;
