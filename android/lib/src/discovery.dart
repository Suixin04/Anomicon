import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'repository.dart';
import 'seed_data.dart';

const originalSeries = [
  CatalogSeriesDescriptor(
    'scp-series-cn',
    'CN-I',
    '$wikiBaseUrl/scp-series-cn',
  ),
  CatalogSeriesDescriptor(
    'scp-series-cn-2',
    'CN-II',
    '$wikiBaseUrl/scp-series-cn-2',
  ),
  CatalogSeriesDescriptor(
    'scp-series-cn-3',
    'CN-III',
    '$wikiBaseUrl/scp-series-cn-3',
  ),
  CatalogSeriesDescriptor(
    'scp-series-cn-4',
    'CN-IV',
    '$wikiBaseUrl/scp-series-cn-4',
  ),
  CatalogSeriesDescriptor(
    'scp-series-cn-5',
    'CN-V',
    '$wikiBaseUrl/scp-series-cn-5',
  ),
];
const discoverySeries = [...scpSeriesDescriptors, ...originalSeries];
const _talePaths = ['tales-by-page-name', 'tales-cn-by-page-name'];

final _scpSlug = RegExp(r'^scp-(?:cn-)?(?:\d{3,4}|\d{3,4}-[a-z0-9-]+)$');
final _number = RegExp(
  r'^(?:scp[\s-]*)?(?:(cn)[\s-]*)?(\d{1,4})(?:[\s-]+(j|ex))?$',
  caseSensitive: false,
);
final _wikiUri = Uri.parse(wikiBaseUrl);

ContentRef? directDiscoveryTarget(String query) {
  final match = _number.firstMatch(query.trim());
  if (match == null) return null;
  final cn = match[1] != null;
  final number = match[2]!.padLeft(3, '0');
  if (cn && int.parse(number) > 4999) return null;
  final suffix = match[3] == null ? '' : '-${match[3]!.toLowerCase()}';
  final id = 'scp-${cn ? 'cn-' : ''}$number$suffix';
  return ContentRef.create(ContentKind.scp, id, id.toUpperCase());
}

String? _wikiSlug(dom.Element link) {
  final uri = _wikiUri.resolve(link.attributes['href']!);
  if (uri.host != _wikiUri.host || uri.pathSegments.length != 1) return null;
  final slug = uri.pathSegments.single.toLowerCase();
  return RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(slug) ? slug : null;
}

String _text(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

List<CatalogEntry> parseDiscoveryCatalog(
  String source, {
  required bool original,
}) {
  final page = html.parse(source).getElementById('page-content');
  if (page == null) return [];
  final panels = page.querySelectorAll('.content-panel.series');
  final entries = <String, CatalogEntry>{};
  for (final panel in panels.isEmpty ? [page] : panels) {
    for (final link in panel.querySelectorAll('a[href]')) {
      final slug = _wikiSlug(link);
      if (slug == null ||
          !_scpSlug.hasMatch(slug) ||
          slug.startsWith('scp-cn-') != original) {
        continue;
      }
      final id = slug.toUpperCase();
      final prefix = RegExp(
        '^${RegExp.escape(id)}[\\s:：—–-]*',
        caseSensitive: false,
      );
      final title = _text(link.text).replaceFirst(prefix, '');
      var row = link.parent;
      while (row != null && row.localName != 'li' && row != panel) {
        row = row.parent;
      }
      if (row == panel) row = link.parent;
      final label = title.isNotEmpty
          ? title
          : _text(row?.text ?? '').replaceFirst(prefix, '');
      entries.putIfAbsent(
        id,
        () => CatalogEntry(
          itemId: id,
          title: label,
          hasArchive3D: SeedData.hasArchiveAsset(slug),
        ),
      );
    }
  }
  return entries.values.toList();
}

List<TaleEntry> parseDiscoveryTales(String source) {
  final page = html.parse(source).getElementById('page-content');
  if (page == null) return [];
  final entries = <String, TaleEntry>{};
  for (final link in page.querySelectorAll(
    'li a[href], .list-pages-item a[href], td a[href]',
  )) {
    final slug = _wikiSlug(link);
    final title = _text(link.text);
    if (slug == null ||
        title.isEmpty ||
        _scpSlug.hasMatch(slug) ||
        slug == 'main' ||
        slug == 'foundation-tales' ||
        slug == 'tales-cn' ||
        slug.startsWith('tales-by-') ||
        slug.startsWith('tales-cn-by-') ||
        slug.startsWith('scp-series') ||
        slug.endsWith('-hub') && title.length == 1) {
      continue;
    }
    entries.putIfAbsent(slug, () => TaleEntry(id: slug, title: title));
  }
  return entries.values.toList()..sort((a, b) => a.id.compareTo(b.id));
}

class DiscoverySnapshot<T> {
  const DiscoverySnapshot(
    this.entries, {
    this.stale = false,
    this.failed = false,
  });
  final List<T> entries;
  final bool stale;
  final bool failed;
}

typedef DiscoveryRead = Future<CachedContent?> Function(String, String);
typedef DiscoveryWrite = Future<void> Function(String, String, String);

class DiscoveryRepository {
  DiscoveryRepository({
    required this._read,
    required this._write,
    required this._parser,
    required this._client,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static final _instances = Expando<DiscoveryRepository>();
  static DiscoveryRepository of(AnomiconRepository repository) =>
      _instances[repository] ??= DiscoveryRepository(
        read: repository.contentCache.read,
        write: repository.contentCache.write,
        parser: repository.wikiGateway,
        client: http.Client(),
      );

  final DiscoveryRead _read;
  final DiscoveryWrite _write;
  final WikiGateway _parser;
  final http.Client _client;
  final DateTime Function() _now;
  final _pending = <String, Future<Object>>{};
  static const _ttl = Duration(hours: 6);
  static const _timeout = Duration(seconds: 8);

  Future<DiscoverySnapshot<CatalogEntry>> cachedCatalog(
    CatalogSeriesDescriptor series,
  ) => _cached(
    series.id,
    (body) => parseDiscoveryCatalog(
      body,
      original: series.id.startsWith('scp-series-cn'),
    ),
  );

  Future<DiscoverySnapshot<CatalogEntry>> catalog(
    CatalogSeriesDescriptor series, {
    bool force = false,
  }) => _load(
    series.id,
    Uri.parse(series.url),
    (body) => parseDiscoveryCatalog(
      body,
      original: series.id.startsWith('scp-series-cn'),
    ),
    force: force,
  );

  Future<List<DiscoverySnapshot<TaleEntry>>> taleSources({
    bool force = false,
  }) => Future.wait([
    for (final path in _talePaths)
      _load(
        path,
        _wikiUri.resolve('/$path'),
        parseDiscoveryTales,
        force: force,
      ),
  ]);

  List<TaleEntry> mergeTales(List<DiscoverySnapshot<TaleEntry>> sources) {
    final merged = <String, TaleEntry>{};
    for (final source in sources) {
      for (final entry in source.entries) {
        merged.putIfAbsent(entry.id, () => entry);
      }
    }
    return merged.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<DiscoveryExplore> explore({bool force = false, int round = 0}) async {
    final date = dayKey(_now());
    final snapshots = await Future.wait([
      for (final source in ExploreSource.values)
        _load(
          'explore:${source.name}',
          Uri.parse(source.url),
          (body) => _parser.parseExplore(source, body),
          force: force,
        ),
      _load(
        'explore:jokeScpsCn',
        _wikiUri.resolve('/joke-scps-cn'),
        (body) => _parser.parseExplore(ExploreSource.jokeScps, body),
        force: force,
      ),
    ]);
    final sources = {
      for (var index = 0; index < ExploreSource.values.length; index++)
        ExploreSource.values[index]: snapshots[index].entries,
    };
    final rated = sources[ExploreSource.topRated]!;
    final translated = sources[ExploreSource.recentTranslated]!;
    final original = sources[ExploreSource.recentOriginal]!;
    final recent = _uniqueExplore([
      for (final entry in translated)
        ExploreContentItem(entry, _kind(entry, ContentKind.wiki), '近期翻译'),
      for (final entry in original)
        ExploreContentItem(entry, _kind(entry, ContentKind.wiki), '近期原创'),
    ])..sort((a, b) => b.entry.date.compareTo(a.entry.date));
    final jokes = dailyDiscoveryOrder(
      _uniqueExplore([
        for (final entry in sources[ExploreSource.jokeScps]!)
          ExploreContentItem(entry, ContentKind.scp, '搞笑 SCP'),
        for (final entry in snapshots.last.entries)
          ExploreContentItem(entry, ContentKind.scp, '原创搞笑 SCP'),
        for (final entry in sources[ExploreSource.jokeTales]!)
          ExploreContentItem(entry, ContentKind.tale, '搞笑故事'),
      ]),
      'jokes:$date',
    );
    final recommendationPool = _uniqueExplore([
      for (final entry in [...translated, ...original, ...rated])
        if (_scpSlug.hasMatch(entry.normalizedId))
          ExploreContentItem(entry, ContentKind.scp, ''),
      for (final entry in SeedData.fallbackRecommendations)
        ExploreContentItem(entry, ContentKind.scp, ''),
    ]);
    final recommendationOrder = dailyDiscoveryOrder(
      recommendationPool,
      '$date:$round',
    );
    final wiki = recommendationOrder
        .where((entry) => !entry.entry.normalizedId.startsWith('scp-cn-'))
        .iterator;
    final cn = recommendationOrder
        .where((entry) => entry.entry.normalizedId.startsWith('scp-cn-'))
        .iterator;
    final recommendations = <ExploreEntry>[];
    while (recommendations.length < 6) {
      final count = recommendations.length;
      if (wiki.moveNext()) recommendations.add(wiki.current.entry);
      if (recommendations.length < 6 && wiki.moveNext()) {
        recommendations.add(wiki.current.entry);
      }
      if (recommendations.length < 6 && cn.moveNext()) {
        recommendations.add(cn.current.entry);
      }
      if (recommendations.length == count) break;
    }
    return DiscoveryExplore(
      ExploreHomeData(
        topRated: rated,
        recent: recent,
        jokes: jokes,
        recommendations: recommendations,
      ),
      hasSourceFailure: snapshots.any((source) => source.failed),
    );
  }

  Future<DiscoverySnapshot<T>> _cached<T>(
    String key,
    List<T> Function(String) parse,
  ) async {
    final file = await _read('discovery:$key', 'json');
    if (file == null) return DiscoverySnapshot<T>([]);
    final entity = jsonDecode(file.body) as Map<String, dynamic>;
    return DiscoverySnapshot(
      parse(entity['html'] as String),
      stale: _expired(file),
    );
  }

  bool _expired(CachedContent file) =>
      _now().millisecondsSinceEpoch - file.fetchedAt >= _ttl.inMilliseconds;

  Future<DiscoverySnapshot<T>> _load<T>(
    String key,
    Uri uri,
    List<T> Function(String) parse, {
    required bool force,
  }) async {
    final loading = _pending[key];
    if (loading != null) return await loading as DiscoverySnapshot<T>;
    final future = _fetchIndex(key, uri, parse, force: force);
    _pending[key] = future;
    try {
      return await future;
    } finally {
      _pending.remove(key);
    }
  }

  Future<DiscoverySnapshot<T>> _fetchIndex<T>(
    String key,
    Uri uri,
    List<T> Function(String) parse, {
    required bool force,
  }) async {
    final cacheKey = 'discovery:$key';
    final disk = await _read(cacheKey, 'json');
    final entity = disk == null
        ? null
        : jsonDecode(disk.body) as Map<String, dynamic>;
    final old = entity == null ? <T>[] : parse(entity['html'] as String);
    if (!force && disk != null && !_expired(disk) && old.isNotEmpty) {
      return DiscoverySnapshot(old);
    }
    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {
              'User-Agent': 'Anomicon-Flutter-Android/1.0',
              if (entity?['etag'] case final String tag) 'If-None-Match': tag,
              if (entity?['modified'] case final String date)
                'If-Modified-Since': date,
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      return DiscoverySnapshot(old, stale: old.isNotEmpty, failed: true);
    } on http.ClientException {
      return DiscoverySnapshot(old, stale: old.isNotEmpty, failed: true);
    } on SocketException {
      return DiscoverySnapshot(old, stale: old.isNotEmpty, failed: true);
    }
    if (response.statusCode == 304 && old.isNotEmpty) {
      await _write(cacheKey, 'json', disk!.body);
      return DiscoverySnapshot(old);
    }
    if (response.statusCode != 200) {
      return DiscoverySnapshot(old, stale: old.isNotEmpty, failed: true);
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final entries = parse(body);
    if (entries.isEmpty) {
      return DiscoverySnapshot(old, stale: old.isNotEmpty, failed: true);
    }
    await _write(
      cacheKey,
      'json',
      jsonEncode({
        'html': body,
        'etag': response.headers['etag'],
        'modified': response.headers['last-modified'],
      }),
    );
    return DiscoverySnapshot(entries);
  }
}

class DiscoveryHistory {
  static const _key = 'discovery.searchHistory';
  static const _starterKey = 'discovery.starterDismissed';

  static Future<bool> starterDismissed() async =>
      (await SharedPreferences.getInstance()).getBool(_starterKey) ?? false;

  static Future<void> dismissStarter() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_starterKey, true)) {
      throw const FileSystemException('未能保存入门指引状态');
    }
  }

  static final revision = ValueNotifier<int>(0);
  static Future<void> _tail = Future.value();

  static Future<List<String>> load() async =>
      (await SharedPreferences.getInstance()).getStringList(_key) ?? [];

  static Future<void> remember(String raw) => _mutate((history) {
    final query = raw.trim();
    return query.isEmpty
        ? history
        : [
            query,
            ...history.where(
              (value) => value.toLowerCase() != query.toLowerCase(),
            ),
          ].take(20).toList();
  });

  static Future<void> clear() => _mutate((_) => []);

  static Future<void> _mutate(List<String> Function(List<String>) update) {
    final action = _tail.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setStringList(
        _key,
        update(prefs.getStringList(_key) ?? []),
      );
      if (!saved) throw const FileSystemException('未能保存搜索历史');
      revision.value++;
    });
    _tail = action.then<void>((_) {}, onError: (Object _) {});
    return action;
  }
}

List<ContentRef> discoveryMatches(Iterable<ContentRef> entries, String query) {
  final text = query.trim().toLowerCase();
  final matches = <String, ContentRef>{};
  for (final row in entries) {
    if (row.id.contains(text) || row.title.toLowerCase().contains(text)) {
      matches.putIfAbsent(row.key, () => row);
    }
  }
  final direct = directDiscoveryTarget(query);
  return [
    if (direct != null) matches.remove(direct.key) ?? direct,
    ...matches.values,
  ];
}

List<T> dailyDiscoveryOrder<T>(Iterable<T> entries, String salt) {
  final seed = salt.codeUnits.fold(
    0,
    (hash, char) => (hash * 31 + char) & 0x7fffffff,
  );
  return entries.toList()..shuffle(Random(seed));
}

class DiscoveryExplore {
  const DiscoveryExplore(this.data, {required this.hasSourceFailure});
  final ExploreHomeData data;
  final bool hasSourceFailure;
}

List<ExploreContentItem> _uniqueExplore(Iterable<ExploreContentItem> entries) {
  final byId = <String, ExploreContentItem>{};
  for (final entry in entries) {
    byId.putIfAbsent(entry.entry.normalizedId, () => entry);
  }
  return byId.values.toList();
}

ContentKind _kind(ExploreEntry entry, ContentKind fallback) =>
    _scpSlug.hasMatch(entry.normalizedId) ? ContentKind.scp : fallback;

ContentRef discoveryContent(
  String id,
  String title, {
  ContentKind fallback = ContentKind.tale,
}) => ContentRef.create(
  _scpSlug.hasMatch(id) ? ContentKind.scp : fallback,
  id,
  title,
);

const antimemeticsGroups = <(String, bool, List<(String, String)>)>[
  ('核心背景读物', true, [('scp-055', 'SCP-055')]),
  (
    '这里没有逆模因部',
    true,
    [
      ('we-need-to-talk-about-fifty-five', '谈谈055'),
      ('introductory-antimemetics', '逆模因学入门'),
      ('unforgettable-that-s-what-you-are', '难忘的你'),
      ('case-colourless-green', '无色之绿事件'),
      ('your-last-first-day', '你最后一个第一天'),
    ],
  ),
  ('幕间休息', true, [('scp-2256', 'SCP-2256')]),
  (
    '五-五-五-五-五',
    true,
    [
      ('scp-3125', 'SCP-3125'),
      ('where-have-you-been-all-my-life', '我一生里，你在何处'),
      ('fresh-hell', '活地狱'),
      ('ojai', '奥哈伊'),
      ('immemorial', '忘念碑'),
      ('case-hate-red', '憎恨之红事件'),
      ('ara-orun', 'Ará Orún'),
      ('unthreaded', '了无牵挂'),
      ('the-wild-light', '狂光'),
      ('blood-brain', '血/脑'),
      ('tombstone', '墓碑'),
      ('champions-of-nothing', '尾声：胜冠徒然'),
    ],
  ),
  (
    '逝者所知',
    false,
    [
      ('scp-2111', 'SCP-2111'),
      ('in-the-trenches-with-the-dead', '与亡者共战'),
      ('a-thin-dangerous-line', '生死一息间'),
    ],
  ),
  ('以供参阅', false, [('antimemetics-division-timeline', '逆模因部系列时间线')]),
  (
    '先驱创作',
    false,
    [
      ('scp-033', 'SCP-033'),
      ('revenants', '归来者'),
      ('scp-1425', 'SCP-1425'),
      ('scp-2828', 'SCP-2828'),
      ('scp-2358', 'SCP-2358'),
    ],
  ),
  (
    '进一步阅读',
    false,
    [
      ('scp-scp-033', 'SCP-SCP-033'),
      ('numbers-lie', '数字会说谎'),
      ('scp-3393', 'SCP-3393'),
      ('scp-3211', 'SCP-3211'),
      ('scp-4773', 'SCP-4773'),
      ('note-your-name-is-nobody', '速记：你的名字是“Nobody”'),
    ],
  ),
  (
    '中国分部原创的相关故事',
    false,
    [
      ('memory-maze', '记忆迷宫'),
      ('tell-you-tales', '说个故事吧'),
      ('diary', '不，这不是你第一天上班。还有：记得写日记'),
      ('rainy-stars-with-the-thunderstorm', '霆霓飘霖，星陨如雨'),
      ('antimeme-guide', '简单易懂的逆模因识别指南（节选）'),
      ('antimemetic-speech', 'ONXY的逆模因讲座：认识，假设与对抗'),
      ('who-is-the-knife-who-is-the-fish', '谁为刀俎，谁为鱼肉？'),
      ('black-hairs-black-eyes', '黑发，黑眸'),
      ('through-calamity', '跨越末日'),
      ('train', '失忆症'),
      ('going-downward-and-pasting-through-translation', '螺旋而下，迭代前行'),
      ('the-spirit-is-shining-among-us', '有黄金从裂缝中渗出'),
      ('wandering-ghost', '游魂'),
      ('arememnber', '也许你能铭记一切，但你仍不能战胜遗忘'),
      ('endro-reversi', '勇者与魔王'),
      ('for-forgotten-memories', '东方忘却碑 ～ For Forgotten Memories.'),
      ('the-self-help-guide-of-antimemetics-division', '逆模因部自救指南'),
      ('therefore-the-red-flood-arose', '熄梦之网'),
      ('nimoyinburenzhenshicanhhh', '于逆模因囹圄之下'),
      ('anon-unknown-nobody', '无人知晓千早爱音'),
      ('scp-cn-3215', 'SCP-CN-3215 - 虚构扩大器'),
      ('locked-room-mystery', '个人梦盒站点：「无隙困室」事件（23.1.17留档）'),
      ('unknown-and-rana', '乐奈救赎乌有之人'),
      ('the-wind-up-bird-chihaya-anon-i', '深红色的拧发条鸟'),
      ('gharfa-ruh', '如是点燃千早爱音'),
      ('welcome-to-vanguard-threshold-must-die', '惊天秘密！为什么你应该成为现实扭曲者或逆模因'),
    ],
  ),
];

ContentRef? nextAntimemeticsChapter(bool Function(String) isRead) {
  for (final (_, isMainline, chapters) in antimemeticsGroups) {
    if (!isMainline) continue;
    for (final (id, title) in chapters) {
      if (!isRead(id)) return discoveryContent(id, title);
    }
  }
  return null;
}
