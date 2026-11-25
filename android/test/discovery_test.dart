import 'package:anomicon/src/discovery.dart';
import 'package:anomicon/src/models.dart';
import 'package:anomicon/src/repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'directory branches, native numbers and story search share content routing',
    () {
      const index = '''<div id="page-content"><ul>
    <li><a href="/scp-173">SCP-173</a> - 雕像</li>
    <li><a href="/scp-cn-2000">SCP-CN-2000</a> - 辉光</li></ul></div>''';
      final translated = parseDiscoveryCatalog(index, original: false).single;
      final original = parseDiscoveryCatalog(index, original: true).single;
      expect(translated.title, '雕像');
      expect(translated.hasArchive3D, isTrue);
      expect(original.itemId, 'SCP-CN-2000');
      expect(directDiscoveryTarget('CN 5')?.id, 'scp-cn-005');
      expect(discoverySeries.length, 15);
      final tale = ContentRef.create(ContentKind.tale, 'ghost-story', '白日之梦');
      expect(discoveryMatches([tale], '白日').single.kind, ContentKind.tale);
      expect(
        discoveryMatches([original.contentRef], 'SCP-CN-2000').single.title,
        '辉光',
      );
    },
  );

  test('503 and empty source preserve last good content until retry', () async {
    final cache = <String, CachedContent>{};
    var current = DateTime(2026, 11, 25);
    var translatedOk = true;
    var originalOk = true;
    int catalogStatus = 200;
    final repository = DiscoveryRepository(
      read: (key, _) async => cache[key],
      write: (key, _, body) async =>
          cache[key] = CachedContent(body, current.millisecondsSinceEpoch),
      parser: WikiGateway(),
      now: () => current,
      client: MockClient((request) async {
        final path = request.url.path;
        if (path == '/scp-series') {
          if (catalogStatus == 304) {
            expect(request.headers['If-None-Match'], 'v1');
          }
          if (catalogStatus != 200) return http.Response('', catalogStatus);
          return http.Response(
            '<div id="page-content"><li><a href="/scp-173">SCP-173</a> - Statue</li></div>',
            200,
            headers: {'etag': 'v1'},
          );
        }
        if (path == '/tales-by-page-name') {
          if (!translatedOk) return http.Response('', 503);
          return http.Response(
            '<div id="page-content"><li><a href="/ghost-story">Ghost story</a></li></div>',
            200,
          );
        }
        expect(path, '/tales-cn-by-page-name');
        if (!originalOk) {
          return http.Response('<div id="page-content"></div>', 200);
        }
        return http.Response(
          '<div id="page-content"><li><a href="/original-story">Original story</a></li></div>',
          200,
        );
      }),
    );
    final series = scpSeriesDescriptors.first;
    expect((await repository.catalog(series)).entries.single.itemId, 'SCP-173');
    expect(repository.mergeTales(await repository.taleSources()).length, 2);
    current = current.add(const Duration(hours: 7));
    expect((await repository.cachedCatalog(series)).stale, isTrue);
    translatedOk = false;
    originalOk = false;
    catalogStatus = 503;
    final failed = await repository.catalog(series);
    expect(failed.failed, isTrue);
    expect(failed.entries.single.itemId, 'SCP-173');
    final tales = await repository.taleSources();
    expect(tales.every((source) => source.failed), isTrue);
    expect(repository.mergeTales(tales).map((entry) => entry.id), [
      'ghost-story',
      'original-story',
    ]);
    catalogStatus = 304;
    expect((await repository.catalog(series, force: true)).failed, isFalse);
    expect((await repository.cachedCatalog(series)).stale, isFalse);
  });

  test(
    'daily recommendations are repeatable and include Chinese originals',
    () async {
      final cache = <String, CachedContent>{};
      final day = DateTime(2026, 11, 25);
      final repository = DiscoveryRepository(
        read: (key, _) async => cache[key],
        write: (key, _, body) async =>
            cache[key] = CachedContent(body, day.millisecondsSinceEpoch),
        now: () => day,
        parser: WikiGateway(),
        client: MockClient((request) async {
          final path = request.url.path;
          final row = switch (path) {
            '/most-recently-created-cn' => '<tr><td><a href="/scp-cn-2000">Original article</a></td><td>25 Nov 2026</td></tr>',
            '/most-recently-created-translated' => '<tr><td><a href="/scp-173">Translated article</a></td><td>24 Nov 2026</td></tr>',
            '/top-rated-pages' => '<tr><td><a href="/scp-cn-2000">Original article</a></td><td>100</td></tr>',
            _ => '',
          };
          return http.Response(
            '<div id="page-content"><table>$row</table></div>',
            200,
          );
        }),
      );
      final first = (await repository.explore()).data;
      final second = (await repository.explore()).data;
      expect(first.recent.map((row) => row.entry.normalizedId).toSet(), {
        'scp-173',
        'scp-cn-2000',
      });
      expect(
        first.recommendations.map((row) => row.normalizedId),
        second.recommendations.map((row) => row.normalizedId),
      );
      expect(
        first.recommendations.any((row) => row.normalizedId == 'scp-cn-2000'),
        isTrue,
      );
    },
  );

  test('search history is deduplicated, persisted and cleared', () async {
    SharedPreferences.setMockInitialValues({});
    await DiscoveryHistory.remember('SCP-173');
    await DiscoveryHistory.remember('雕像');
    await DiscoveryHistory.remember('scp-173');
    expect(await DiscoveryHistory.load(), ['scp-173', '雕像']);
    await DiscoveryHistory.clear();
    expect(await DiscoveryHistory.load(), isEmpty);
  });
}
