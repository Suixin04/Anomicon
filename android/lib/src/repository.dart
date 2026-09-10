import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'seed_data.dart';

class CachedContent {
  const CachedContent(this.body, this.fetchedAt);

  final String body;
  final int fetchedAt;
}

class ArchiveDownloadProgress {
  const ArchiveDownloadProgress(this.downloadedBytes, this.totalBytes);

  final int downloadedBytes;
  final int totalBytes;

  double? get fraction =>
      totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : null;
}

class ContentCache {
  ContentCache._(this._root);

  static Future<ContentCache> create() async {
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory('${documents.path}/content-cache');
    await root.create(recursive: true);
    return ContentCache._(root);
  }

  final Directory _root;

  Future<CachedContent?> read(String key, String extension) async {
    final bodyFile = _fileFor(key, extension);
    final metadataFile = _fileFor(key, '$extension.meta');
    if (!await FileSystemEntity.isFile(bodyFile.path) || !await FileSystemEntity.isFile(metadataFile.path)) {
      return null;
    }
    try {
      final body = await bodyFile.readAsString();
      final fetchedAt = int.parse((await metadataFile.readAsString()).trim());
      return CachedContent(body, fetchedAt);
    } on Object {
      return null;
    }
  }

  Future<void> write(
    String key,
    String extension,
    String body, {
    int? fetchedAt,
  }) async {
    final timestamp = fetchedAt ?? DateTime.now().millisecondsSinceEpoch;
    await _writeAtomically(_fileFor(key, extension), utf8.encode(body));
    await _writeAtomically(_fileFor(key, '$extension.meta'), utf8.encode(timestamp.toString()));
  }

  Future<File?> readFile(String key, String extension) async {
    final file = _fileFor(key, extension);
    return await FileSystemEntity.isFile(file.path) ? file : null;
  }

  Future<File> writeBytes(
    String key,
    String extension,
    List<int> body, {
    int? fetchedAt,
  }) async {
    final timestamp = fetchedAt ?? DateTime.now().millisecondsSinceEpoch;
    final bodyFile = _fileFor(key, extension);
    await _writeAtomically(bodyFile, body);
    await _writeAtomically(_fileFor(key, '$extension.meta'), utf8.encode(timestamp.toString()));
    return bodyFile;
  }

  File _fileFor(String key, String extension) => File('${_root.path}/${_sha256Text(key)}.$extension');

  Future<void> _writeAtomically(File target, List<int> bytes) async {
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temporary.rename(target.path);
  }
}

class ArchiveAssetIntegrity {
  static Future<bool> isValid(ArchiveAsset asset, File file) async {
    if (!await FileSystemEntity.isFile(file.path)) {
      return false;
    }
    if (asset.byteLength > 0 && await file.length() != asset.byteLength) {
      return false;
    }
    return asset.sha256.trim().isEmpty || await sha256File(file) == asset.sha256.toLowerCase();
  }

  static Future<String> sha256File(File file) async {
    return sha256.convert(await file.readAsBytes()).toString();
  }
}

class ArchiveAssetStore {
  ArchiveAssetStore._(this._root, this._client);

  static Future<ArchiveAssetStore> create({http.Client? client}) async {
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory('${documents.path}/archive3d/v1/objects');
    await root.create(recursive: true);
    return ArchiveAssetStore._(root, client ?? http.Client());
  }

  final Directory _root;
  final http.Client _client;

  Future<File?> installedFile(ArchiveAsset asset) async {
    final target = _fileFor(asset);
    if (await ArchiveAssetIntegrity.isValid(asset, target)) {
      return target;
    }
    if (await target.exists()) {
      await target.delete();
    }
    return null;
  }

  Future<File> download(
    ArchiveAsset asset, {
    void Function(ArchiveDownloadProgress progress)? onProgress,
  }) async {
    if (asset.downloadUrl.trim().isEmpty) {
      throw StateError('三维模型没有可用下载地址');
    }
    final target = _fileFor(asset);
    if (await ArchiveAssetIntegrity.isValid(asset, target)) {
      onProgress?.call(ArchiveDownloadProgress(await target.length(), await target.length()));
      return target;
    }
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.download');
    if (await temporary.exists()) {
      await temporary.delete();
    }
    final request = http.Request('GET', Uri.parse(asset.downloadUrl))
      ..headers['User-Agent'] = 'Anomicon-Flutter-Android/1.0';
    final response = await _client.send(request).timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}: ${asset.downloadUrl}');
    }
    final totalBytes = asset.byteLength > 0 ? asset.byteLength : response.contentLength ?? 0;
    var downloadedBytes = 0;
    final sink = temporary.openWrite();
    try {
      await for (final chunk in response.stream) {
        downloadedBytes += chunk.length;
        sink.add(chunk);
        onProgress?.call(ArchiveDownloadProgress(downloadedBytes, totalBytes));
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (!await ArchiveAssetIntegrity.isValid(asset, temporary)) {
      await temporary.delete();
      throw const FileSystemException('三维模型校验失败：大小或 SHA-256 不匹配');
    }
    if (await target.exists()) {
      await target.delete();
    }
    return temporary.rename(target.path);
  }

  Future<bool> delete(ArchiveAsset asset) async {
    final target = _fileFor(asset);
    final temporary = File('${target.path}.download');
    if (await temporary.exists()) {
      await temporary.delete();
    }
    if (!await target.exists()) {
      return false;
    }
    await target.delete();
    return true;
  }

  File _fileFor(ArchiveAsset asset) {
    final hash = asset.sha256.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw ArgumentError('三维模型清单 SHA-256 无效');
    }
    return File('${_root.path}/${hash.substring(0, 2)}/$hash.glb');
  }
}

class AnomiconRepository {
  AnomiconRepository({
    required this.wikiGateway,
    required this.contentCache,
    required this.archiveAssetStore,
  });

  static Future<AnomiconRepository> create() async => AnomiconRepository(
    wikiGateway: WikiGateway(),
    contentCache: await ContentCache.create(),
    archiveAssetStore: await ArchiveAssetStore.create(),
  );

  final WikiGateway wikiGateway;
  final ContentCache contentCache;
  final ArchiveAssetStore archiveAssetStore;

  Future<File?> installedArchiveAsset(ArchiveAsset asset) => archiveAssetStore.installedFile(asset);

  Future<File> downloadArchiveAsset(
    ArchiveAsset asset, {
    void Function(ArchiveDownloadProgress progress)? onProgress,
  }) =>
      archiveAssetStore.download(asset, onProgress: onProgress);

  Future<bool> deleteArchiveAsset(ArchiveAsset asset) => archiveAssetStore.delete(asset);

  Future<List<CatalogEntry>> loadCatalog(String seriesId) async {
    try {
      final series = scpSeriesDescriptors.firstWhere(
        (item) => item.id == seriesId,
        orElse: () => scpSeriesDescriptors.first,
      );
      final network = await wikiGateway.loadCatalog(series);
      if (network.isNotEmpty) {
        await _writeCache('catalog:${series.id}', _encodeCatalog(network));
        return network;
      }
      return await _readCatalog(series.id) ?? SeedData.fallbackCatalog;
    } on Object {
      return await _readCatalog(seriesId) ?? SeedData.fallbackCatalog;
    }
  }

  Future<List<TaleEntry>> loadTales() async {
    try {
      final network = await wikiGateway.loadTales();
      if (network.isNotEmpty) {
        await _writeCache('tales', _encodeTales(network));
        return network;
      }
      return await _readTales() ?? SeedData.fallbackTales;
    } on Object {
      return await _readTales() ?? SeedData.fallbackTales;
    }
  }

  Future<ArticleDocument> loadArticle(ContentRef content) async {
    try {
      final fetchedAt = DateTime.now().millisecondsSinceEpoch;
      final body = await wikiGateway.loadArticleHtml(content);
      await _writeCache('article:${content.key}', body, extension: 'html', fetchedAt: fetchedAt);
      return wikiGateway.parseArticle(content, body, fetchedAt: fetchedAt);
    } on Object {
      final cached = await _readCache('article:${content.key}', extension: 'html');
      if (cached == null) {
        throw StateError('文章尚未缓存，且当前无法连接网络');
      }
      return wikiGateway.parseArticle(content, cached.body, fetchedAt: cached.fetchedAt);
    }
  }

  Future<File> loadImageFile(String url) async {
    final cached = await contentCache.readFile('image:$url', 'img');
    if (cached != null) {
      return cached;
    }
    try {
      final bytes = await wikiGateway.loadResource(url);
      return await contentCache.writeBytes('image:$url', 'img', bytes);
    } on Object {
      final fallback = await contentCache.readFile('image:$url', 'img');
      if (fallback != null) {
        return fallback;
      }
      rethrow;
    }
  }

  Future<ExploreHomeData> loadExplore({DateTime? date}) async {
    final currentDate = date ?? DateTime.now();
    final results = await Future.wait<List<ExploreEntry>>(<Future<List<ExploreEntry>>>[
      _loadExploreSource(ExploreSource.topRated),
      _loadExploreSource(ExploreSource.recentTranslated),
      _loadExploreSource(ExploreSource.recentOriginal),
      _loadExploreSource(ExploreSource.jokeScps),
      _loadExploreSource(ExploreSource.jokeTales),
    ]);
    final topRated = results[0].isEmpty ? SeedData.fallbackExplore : results[0];
    final recent = _combineRecent(results[1], results[2]);
    final jokes = _combineJokes(results[3], results[4], dayKey(currentDate));
    final recommendations = await _dailyRecommendations(topRated, currentDate);
    return ExploreHomeData(
      topRated: topRated,
      recent: recent.isEmpty
          ? SeedData.fallbackExplore.take(4).map((item) => ExploreContentItem(item, ContentKind.wiki, '本地回退')).toList()
          : recent,
      jokes: jokes.isEmpty
          ? SeedData.fallbackExplore.skip(3).map((item) => ExploreContentItem(item, ContentKind.scp, '本地回退')).toList()
          : jokes,
      recommendations: recommendations,
    );
  }

  Future<List<ExploreEntry>> _loadExploreSource(ExploreSource source) async {
    try {
      final network = await wikiGateway.loadExplore(source);
      if (network.isNotEmpty) {
        await _writeCache('explore:${source.name}', _encodeExplore(network));
        return network;
      }
      return await _readExplore(source) ?? <ExploreEntry>[];
    } on Object {
      return await _readExplore(source) ?? <ExploreEntry>[];
    }
  }

  Future<List<CatalogEntry>?> _readCatalog(String seriesId) async =>
      (await _readCache('catalog:$seriesId'))?.body.let(_decodeCatalog);

  Future<List<TaleEntry>?> _readTales() async => (await _readCache('tales'))?.body.let(_decodeTales);

  Future<List<ExploreEntry>?> _readExplore(ExploreSource source) async =>
      (await _readCache('explore:${source.name}'))?.body.let(_decodeExplore);

  Future<void> _writeCache(
    String key,
    String body, {
    String extension = 'json',
    int? fetchedAt,
  }) =>
      contentCache.write(key, extension, body, fetchedAt: fetchedAt);

  Future<CachedContent?> _readCache(String key, {String extension = 'json'}) =>
      contentCache.read(key, extension);

  String _encodeCatalog(List<CatalogEntry> entries) =>
      jsonEncode(entries.map((entry) => entry.toJson()).toList());

  List<CatalogEntry> _decodeCatalog(String raw) => _decodeList(raw, CatalogEntry.fromJson);

  String _encodeTales(List<TaleEntry> entries) =>
      jsonEncode(entries.map((entry) => entry.toJson()).toList());

  List<TaleEntry> _decodeTales(String raw) => _decodeList(raw, TaleEntry.fromJson);

  String _encodeExplore(List<ExploreEntry> entries) =>
      jsonEncode(entries.map((entry) => entry.toJson()).toList());

  List<ExploreEntry> _decodeExplore(String raw) => _decodeList(raw, ExploreEntry.fromJson);

  List<ExploreContentItem> _combineRecent(
    List<ExploreEntry> translated,
    List<ExploreEntry> original,
  ) {
    final seen = <String>{};
    final items = <ExploreContentItem>[];
    for (final entry in translated) {
      if (seen.add(entry.normalizedId)) {
        items.add(ExploreContentItem(entry, ContentKind.wiki, '翻译主站'));
      }
    }
    for (final entry in original) {
      if (seen.add(entry.normalizedId)) {
        items.add(ExploreContentItem(entry, ContentKind.wiki, '原创'));
      }
    }
    return items.take(20).toList();
  }

  List<ExploreContentItem> _combineJokes(
    List<ExploreEntry> scps,
    List<ExploreEntry> tales,
    String salt,
  ) {
    final pool = <ExploreContentItem>[
      ...scps.map((entry) => ExploreContentItem(entry, ContentKind.scp, '搞笑 SCP')),
      ...tales.map((entry) => ExploreContentItem(entry, ContentKind.tale, '搞笑故事')),
    ];
    return _stableShuffle(pool, salt).take(20).toList();
  }

  Future<List<ExploreEntry>> _dailyRecommendations(
    List<ExploreEntry> fallbackPool,
    DateTime date,
  ) async {
    final ids = _candidateIds(dayKey(date)).take(10);
    final resolved = await Future.wait(ids.map((id) async {
      try {
        return ExploreEntry(id: id.toLowerCase(), title: await wikiGateway.resolveTitle(id));
      } on Object {
        return null;
      }
    }));
    final recommendations = resolved.whereType<ExploreEntry>().take(6).toList();
    if (recommendations.isNotEmpty) {
      return recommendations;
    }
    if (fallbackPool.isNotEmpty) {
      return fallbackPool.take(6).toList();
    }
    return SeedData.fallbackRecommendations;
  }

  List<String> _candidateIds(String salt) => _stableShuffle(
    List<String>.generate(9999, (index) => 'SCP-${(index + 1).toString().padLeft(3, '0')}'),
    'wiki-random-recommendations:$salt',
  );
}

class WikiGateway {
  WikiGateway({http.Client? client}) : _client = client ?? http.Client();

  static const _wikiCn = wikiBaseUrl;
  static const _blockTags = <String>{'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p', 'blockquote', 'ul', 'ol', 'hr', 'table'};

  final http.Client _client;

  Future<List<CatalogEntry>> loadCatalog(CatalogSeriesDescriptor series) async =>
      parseCatalog(await _fetch(series.url));

  Future<List<TaleEntry>> loadTales() async => parseTales(await _fetch('$_wikiCn/tales-by-page-name'));

  Future<List<ExploreEntry>> loadExplore(ExploreSource source) async =>
      parseExplore(source, await _fetch(source.url));

  Future<String> resolveTitle(String itemId) async =>
      _extractTitle(await _fetch(articleUrlOf(itemId)), itemId.toUpperCase());

  Future<String> loadArticleHtml(ContentRef content) => _fetch(articleUrlOf(content.id));

  Future<List<int>> loadResource(String url) async {
    final response = await _client
        .get(Uri.parse(url), headers: <String, String>{'User-Agent': 'Anomicon-Flutter-Android/1.0'})
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}: $url');
    }
    return response.bodyBytes;
  }

  ArticleDocument parseArticle(
    ContentRef content,
    String html, {
    int? fetchedAt,
  }) {
    final document = html_parser.parse(html);
    final page = document.getElementById('page-content') ?? document.body;
    page?.querySelectorAll('script,style,noscript,iframe,form,.page-options,.footer-wikiwalk-nav,#page-info').forEach((item) {
      item.remove();
    });
    final blocks = <ArticleBlock>[];
    if (page != null) {
      _appendArticleBlocks(blocks, page, content);
    }
    return ArticleDocument(
      content: content,
      sourceUrl: articleUrlOf(content.id),
      fetchedAt: fetchedAt ?? DateTime.now().millisecondsSinceEpoch,
      blocks: blocks,
    );
  }

  List<CatalogEntry> parseCatalog(String html) {
    final content = html_parser.parse(html).getElementById('page-content');
    if (content == null) {
      return const <CatalogEntry>[];
    }
    final panel = content.querySelector('div.content-panel.series') ??
        content.querySelector('div.content-panel') ??
        content;
    final seen = <String>{};
    return panel.querySelectorAll('a[href]').map((link) {
      final href = _normalizeHref(link.attributes['href'] ?? '');
      final id = href.replaceFirst('/', '').toUpperCase();
      if (!RegExp(r'^SCP-\d{3,4}$').hasMatch(id) || !seen.add(id)) {
        return null;
      }
      final parentText = link.parent?.text ?? '';
      final linkTitle = _cleanCatalogTitle(_stripIdPrefix(link.text, id));
      final rawTitle = linkTitle.isNotEmpty ? linkTitle : _cleanCatalogTitle(_stripIdPrefix(parentText, id));
      return CatalogEntry(
        itemId: id,
        title: rawTitle,
        hasArchive3D: SeedData.hasArchiveAsset(id.toLowerCase()),
      );
    }).whereType<CatalogEntry>().toList();
  }

  List<TaleEntry> parseTales(String html) {
    final content = html_parser.parse(html).getElementById('page-content');
    if (content == null) {
      return const <TaleEntry>[];
    }
    final seen = <String>{};
    final tales = content.querySelectorAll('a[href]').map((link) {
      final href = _normalizeHref(link.attributes['href'] ?? '');
      final title = _cleanText(link.text);
      if (!_isTaleLink(href, title)) return null;
      final id = href.replaceFirst('/', '');
      if (!seen.add(id)) return null;
      return TaleEntry(id: id, title: title);
    }).whereType<TaleEntry>().toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return tales;
  }

  List<ExploreEntry> parseExplore(ExploreSource source, String html) {
    final content = html_parser.parse(html).getElementById('page-content');
    if (content == null) {
      return const <ExploreEntry>[];
    }
    return switch (source) {
      ExploreSource.topRated || ExploreSource.recentTranslated || ExploreSource.recentOriginal =>
        _parseExploreTable(source, content),
      ExploreSource.jokeScps || ExploreSource.jokeTales => _parseJokes(source, content),
    };
  }

  Future<String> _fetch(String url) async {
    final response = await _client
        .get(Uri.parse(url), headers: <String, String>{'User-Agent': 'Anomicon-Flutter-Android/1.0'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}: $url');
    }
    return utf8.decode(response.bodyBytes);
  }

  void _appendArticleBlocks(List<ArticleBlock> blocks, dom.Element element, ContentRef content) {
    for (final child in element.children) {
      final tag = child.localName?.toLowerCase() ?? '';
      switch (tag) {
        case 'h1':
        case 'h2':
        case 'h3':
        case 'h4':
        case 'h5':
        case 'h6':
          final text = _cleanText(child.text);
          if (text.isNotEmpty) {
            blocks.add(ArticleHeading(text, int.tryParse(tag.substring(1)) ?? 2));
          }
        case 'p':
          for (final image in child.querySelectorAll('img')) {
            _addImage(blocks, image, content);
          }
          final text = _cleanText(child.text);
          if (text.isNotEmpty) {
            blocks.add(ArticleParagraph(text));
          }
        case 'img':
          _addImage(blocks, child, content);
        case 'blockquote':
          final text = _cleanText(child.text);
          if (text.isNotEmpty) {
            blocks.add(ArticleQuote(text));
          }
        case 'ul':
        case 'ol':
          final items = child.children
              .where((item) => (item.localName ?? '').toLowerCase() == 'li')
              .map((item) => _cleanText(item.text))
              .where((item) => item.isNotEmpty)
              .toList();
          if (items.isNotEmpty) {
            blocks.add(ArticleListBlock(items, tag == 'ol'));
          }
        case 'hr':
          blocks.add(const ArticleDivider());
        case 'table':
          for (final row in child.querySelectorAll('tr')) {
            final text = _cleanText(row.text);
            if (text.isNotEmpty) {
              blocks.add(ArticleParagraph(text));
            }
          }
        default:
          final hasNestedBlocks = child.children.any(
            (nested) => _blockTags.contains((nested.localName ?? '').toLowerCase()),
          );
          if (hasNestedBlocks) {
            _appendArticleBlocks(blocks, child, content);
          } else {
            for (final image in child.querySelectorAll('img')) {
              _addImage(blocks, image, content);
            }
            final text = _cleanText(child.text);
            if (text.isNotEmpty) {
              blocks.add(ArticleParagraph(text));
            }
          }
      }
    }
  }

  void _addImage(List<ArticleBlock> blocks, dom.Element image, ContentRef content) {
    final rawUrl = image.attributes['src'] ?? '';
    final url = switch (rawUrl) {
      final value when value.startsWith('//') => 'https:$value',
      final value when value.startsWith('http://') || value.startsWith('https://') => value,
      final value when value.startsWith('/') => '$_wikiCn$value',
      final value when value.trim().isEmpty => '',
      final value => Uri.parse(articleUrlOf(content.id)).resolve(value).toString(),
    };
    if (url.isNotEmpty) {
      blocks.add(ArticleImage(url, _cleanText(image.attributes['alt'] ?? '')));
    }
  }

  List<ExploreEntry> _parseExploreTable(ExploreSource source, dom.Element content) {
    final seen = <String>{};
    return content.querySelectorAll('tr').map((row) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 2) return null;
      final link = cells[0].querySelector('a[href]');
      if (link == null) return null;
      final href = _normalizeHref(link.attributes['href'] ?? '');
      if (_isNavigation(href) || !seen.add(href)) return null;
      if (source == ExploreSource.topRated) {
        return ExploreEntry(
          id: href.replaceFirst('/', ''),
          title: _cleanText(link.text),
          score: int.tryParse(_cleanText(cells[1].text).replaceFirst('+', '')) ?? -1,
          comments: cells.length > 2 ? _cleanText(cells[2].text) : '',
        );
      }
      return ExploreEntry(
        id: href.replaceFirst('/', ''),
        title: _cleanText(link.text),
        date: _cleanText(cells[1].text),
        comments: cells.length > 2 ? _cleanText(cells[2].text) : '',
      );
    }).whereType<ExploreEntry>().take(40).toList();
  }

  List<ExploreEntry> _parseJokes(ExploreSource source, dom.Element content) {
    final listContent = source == ExploreSource.jokeScps
        ? content.querySelector('div.content-panel.standalone.series') ?? content
        : content;
    final seen = <String>{};
    final maxEntries = source == ExploreSource.jokeScps ? 240 : 180;
    return listContent.querySelectorAll('a[href]').map((link) {
      final href = _normalizeHref(link.attributes['href'] ?? '');
      final title = _cleanText(link.text);
      if (!_isJokeEntry(source, href, title) || !seen.add(href)) return null;
      return ExploreEntry(id: href.replaceFirst('/', ''), title: title);
    }).whereType<ExploreEntry>().take(maxEntries).toList();
  }

  String _extractTitle(String html, String fallback) {
    final doc = html_parser.parse(html);
    final pageTitle = _cleanText(doc.querySelector('.page-title')?.text ?? '');
    if (pageTitle.isNotEmpty) {
      return pageTitle;
    }
    final title = _cleanText(
      doc.querySelector('title')?.text.replaceAll(RegExp(r'\s*[-–—]\s*SCP(?:基金会| Foundation).*$', caseSensitive: false), '') ?? '',
    );
    return title.isEmpty ? fallback : title;
  }

  bool _isJokeEntry(ExploreSource source, String href, String title) {
    if (href.length < 2 || title.length < 2 || _isNavigation(href)) return false;
    final slug = href.replaceFirst('/', '').toLowerCase();
    final isScpPage = slug.startsWith('scp-') || slug.startsWith('spc-');
    final isJokePage = isScpPage && (slug.contains('-j') || title.toLowerCase().contains('-j'));
    return source == ExploreSource.jokeScps ? isJokePage : !isScpPage;
  }

  bool _isTaleLink(String href, String title) {
    if (title.length < 2 || href.length < 2 || !href.startsWith('/')) return false;
    final lowerHref = href.toLowerCase();
    if (lowerHref.startsWith('/system:') || lowerHref.startsWith('/_')) return false;
    return !lowerHref.contains('tales-by') &&
        !lowerHref.startsWith('/tale') &&
        !lowerHref.contains('foundation-tales') &&
        !lowerHref.contains('canon') &&
        !lowerHref.startsWith('/user:');
  }

  bool _isNavigation(String href) {
    if (!href.startsWith('/') || href.startsWith('//')) return true;
    final normalized = href.toLowerCase();
    return normalized.startsWith('/system:') ||
        normalized.startsWith('/_') ||
        normalized.contains('tales-by') ||
        normalized.contains('foundation-tales') ||
        normalized.contains('most-recently') ||
        normalized.contains('top-rated') ||
        normalized.contains('joke-scps') ||
        normalized.contains('explained-scps') ||
        normalized.contains('random:') ||
        normalized.contains('scp-series') ||
        normalized.startsWith('/forum') ||
        normalized.startsWith('/help') ||
        normalized == '/main' ||
        normalized == '/';
  }

  String _normalizeHref(String value) => html_parser.parseFragment(value).text
      ?.split('#')
      .first
      .split('?')
      .first
      .trim() ??
      '';

  String _stripIdPrefix(String value, String id) {
    final index = value.toUpperCase().indexOf(id);
    return index < 0 ? value : value.substring(index + id.length);
  }

  String _cleanCatalogTitle(String value) => _cleanText(value)
      .replaceFirst(RegExp(r'''^[\s\-–—:：'"‘’“”\[（(]+'''), '')
      .replaceFirst(RegExp(r'\[[^]]*]\s*$'), '')
      .replaceFirst(RegExp(r'''[\s\-–—:：'"‘’“”\]）)]+$'''), '')
      .trim();

  String _cleanText(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<T> _decodeList<T>(String raw, T Function(Map<String, Object?> json) decode) {
  try {
    final parsed = jsonDecode(raw);
    if (parsed is! List) {
      return <T>[];
    }
    return parsed
        .whereType<Map>()
        .map((item) => decode(item.cast<String, Object?>()))
        .toList();
  } on FormatException {
    return <T>[];
  }
}

List<T> _stableShuffle<T>(List<T> list, String salt) {
  final pairs = <({int hash, T item})>[];
  for (var index = 0; index < list.length; index++) {
    pairs.add((hash: _stableHash('$salt:$index:${list[index]}'), item: list[index]));
  }
  pairs.sort((left, right) => left.hash.compareTo(right.hash));
  return pairs.map((pair) => pair.item).toList();
}

int _stableHash(String value) {
  var hash = 1125899906842597;
  for (final codeUnit in value.codeUnits) {
    hash = (31 * hash + codeUnit) & 0x7fffffffffffffff;
  }
  return hash;
}

String _sha256Text(String value) => sha256.convert(utf8.encode(value)).toString();

extension _Let<T> on T {
  R let<R>(R Function(T value) block) => block(this);
}
