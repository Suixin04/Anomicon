import 'dart:io';

import 'package:anomicon/src/models.dart';
import 'package:anomicon/src/repository.dart';
import 'package:anomicon/src/wiki_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final page = Uri.parse('https://scp-wiki-cn.wikidot.com/scp-002');

  test('takes the first substantive image from the Wiki article body', () {
    final image = parseWikiPreviewImage('''
      <img src="/header-image.jpg">
      <div id="page-content">
        <img src="/local--files/theme:site/banner.jpg">
        <img src="/profile.jpg" width="48" height="48">
        <img src="data:image/png;base64,AA">
        <img src="//scp-wiki.wdfiles.com/local--files/scp-002/photo.jpg">
        <img src="/second-photo.jpg">
      </div>''', page);
    expect(
      image.toString(),
      'https://scp-wiki.wdfiles.com/local--files/scp-002/photo.jpg',
    );
  });

  test('resolves relative attachments and upgrades HTTP URLs', () {
    expect(
      parseWikiPreviewImage('''<div id="page-content">
      <img src="/local--files/scp-002/photo.jpg"></div>''', page),
      page.resolve('/local--files/scp-002/photo.jpg'),
    );
    expect(
      parseWikiPreviewImage(
        '''<div id="page-content">
      <img src="http://scp-wiki.wdfiles.com/attachment.jpg"></div>''',
        page,
      )?.scheme,
      'https',
    );
  });

  test(
    'completes concurrent preview requests and reuses the disk cache',
    () async {
      final cache = _PreviewCache();
      var networkCalls = 0;
      final client = MockClient((request) async {
        networkCalls++;
        if (request.url.path == '/scp-002') {
          return http.Response(
            '<div id="page-content"><img src="/photo.jpg"></div>',
            200,
          );
        }
        expect(request.url.path, '/photo.jpg');
        return http.Response.bytes([1, 2, 3], 200);
      });
      addTearDown(client.close);
      AnomiconRepository repository() => AnomiconRepository(
        wikiGateway: WikiGateway(client: client),
        contentCache: cache,
        archiveAssetStore: _UnusedArchiveStore(),
      );
      final content = ContentRef.create(ContentKind.scp, 'scp-002', '生活室');
      final first = repository();
      final previews = await Future.wait([
        first.loadPreviewImage(content),
        first.loadPreviewImage(content),
      ]).timeout(const Duration(seconds: 2));
      expect(previews, [cache.file, cache.file]);
      expect(await repository().loadPreviewImage(content), cache.file);
      expect(networkCalls, 2);
    },
  );

  test('leaves text-only articles without an image', () {
    expect(
      parseWikiPreviewImage('''<div id="page-content">
      <img src="/logo.png"><p>正文</p></div><img src="/footer.jpg">''', page),
      isNull,
    );
  });
}

class _UnusedArchiveStore extends Fake implements ArchiveAssetStore {}

class _PreviewCache extends Fake implements ContentCache {
  final _text = <String, CachedContent>{};
  final file = File('preview-fixture.jpg');
  bool _hasImage = false;

  @override
  Future<CachedContent?> read(String key, String extension) async =>
      _text['$key.$extension'];

  @override
  Future<void> write(
    String key,
    String extension,
    String body, {
    int? fetchedAt,
  }) async {
    _text['$key.$extension'] = CachedContent(body, fetchedAt ?? 0);
  }

  @override
  Future<File?> readFile(String key, String extension) async =>
      _hasImage ? file : null;

  @override
  Future<File> writeBytes(
    String key,
    String extension,
    List<int> body, {
    int? fetchedAt,
  }) async {
    _hasImage = true;
    return file;
  }
}
