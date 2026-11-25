import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'article_parser.dart';
import 'models.dart';

class OfflineArticleInfo {
  const OfflineArticleInfo(this.content, this.savedAt);

  factory OfflineArticleInfo.fromJson(Map<String, dynamic> json) =>
      OfflineArticleInfo(
        ContentRef.fromJson(json['content'] as Map<String, dynamic>),
        DateTime.fromMillisecondsSinceEpoch(json['savedAt'] as int),
      );

  final ContentRef content;
  final DateTime savedAt;

  Map<String, Object> toJson() => {
    'content': content.toJson(),
    'savedAt': savedAt.millisecondsSinceEpoch,
  };
}

class OfflineArticle {
  const OfflineArticle(this.document, this.images);

  final ArticleDocument document;
  final Map<String, Uint8List> images;
}

/// A published file consists of a shelf header followed by the complete article
/// bundle. An atomic rename publishes the body and all images together.
class OfflineArticleStore {
  OfflineArticleStore(this.root);

  static Future<OfflineArticleStore> open() async {
    final documents = await getApplicationDocumentsDirectory();
    return OfflineArticleStore(
      Directory('${documents.path}/offline-articles/v1'),
    );
  }

  final Directory root;
  final _saving = <String>{};

  File _file(ContentRef content) =>
      File('${root.path}/${sha256.convert(utf8.encode(content.key))}.article');

  Future<bool> contains(ContentRef content) => _file(content).exists();

  Future<List<OfflineArticleInfo>> list() async {
    if (!await root.exists()) return [];
    final result = <OfflineArticleInfo>[];
    await for (final entity in root.list()) {
      if (entity is! File || !entity.path.endsWith('.article')) continue;
      final header = await entity
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first;
      result.add(
        OfflineArticleInfo.fromJson(jsonDecode(header) as Map<String, dynamic>),
      );
    }
    result.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return result;
  }

  Future<OfflineArticle> read(ContentRef content) async {
    final file = _file(content);
    if (!await file.exists()) throw StateError('此档案没有离线副本');
    final raw = await file.readAsString();
    final newline = raw.indexOf('\n');
    final info = OfflineArticleInfo.fromJson(
      jsonDecode(raw.substring(0, newline)) as Map<String, dynamic>,
    );
    final payload =
        jsonDecode(raw.substring(newline + 1)) as Map<String, dynamic>;
    return OfflineArticle(
      parseNativeArticle(
        info.content,
        payload['html'] as String,
        info.savedAt.millisecondsSinceEpoch,
      ),
      (payload['images'] as Map<String, dynamic>).map(
        (url, data) => MapEntry(url, base64Decode(data as String)),
      ),
    );
  }

  Future<void> save(
    ContentRef content, {
    required Future<String> Function(ContentRef) fetchArticle,
    required Future<List<int>> Function(String) fetchImage,
  }) async {
    if (!_saving.add(content.key)) throw StateError('此档案正在保存');
    Directory? staging;
    try {
      final html = await fetchArticle(content);
      final now = DateTime.now();
      final article = parseNativeArticle(
        content,
        html,
        now.millisecondsSinceEpoch,
      );
      if (article.blocks.isEmpty) throw const FormatException('原文没有可保存的正文');
      final assets = article.blocks
          .whereType<ArticleImage>()
          .map((image) => image.url)
          .toSet();
      final images = <String, String>{};
      var payloadBytes = utf8.encode(html).length;
      for (final url in assets) {
        final bytes = await fetchImage(url);
        payloadBytes += bytes.length;
        if (payloadBytes > 64 * 1024 * 1024) {
          throw const FormatException('离线副本超过 64 MiB');
        }
        final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
        try {
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
        images[url] = base64Encode(bytes);
      }
      await root.create(recursive: true);
      staging = await root.createTemp('.staging-');
      final bundle = File('${staging.path}/bundle');
      await bundle.writeAsString(
        '${jsonEncode(OfflineArticleInfo(content, now).toJson())}\n'
        '${jsonEncode({'html': html, 'images': images})}',
        flush: true,
      );
      await bundle.rename(_file(content).path);
    } finally {
      _saving.remove(content.key);
      if (staging != null) await staging.delete(recursive: true);
    }
  }

  Future<void> remove(ContentRef content) async {
    if (_saving.contains(content.key)) throw StateError('此档案正在保存');
    await _file(content).delete();
  }
}
