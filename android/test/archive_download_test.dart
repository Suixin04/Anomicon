import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anomicon/src/anomicon_app.dart';
import 'package:anomicon/src/archive_download.dart';
import 'package:anomicon/src/models.dart';
import 'package:anomicon/src/seed_data.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'four bundled files match the manifest and six models are on demand',
    () async {
      final assets = SeedData.archiveAssets;
      final bundled = assets.where((asset) => asset.isReadyByDefault).toList();
      expect(bundled.map((asset) => asset.contentId), [
        'scp-106',
        'scp-049',
        'scp-173',
        'scp-939',
      ]);
      expect(
        assets
            .where((asset) => !asset.isReadyByDefault)
            .map((asset) => asset.contentId),
        ['scp-131', 'scp-3199', 'scp-650', 'scp-079', 'scp-178', 'scp-686'],
      );
      for (final asset in bundled) {
        final data = await rootBundle.load(asset.resourcePath);
        expect(data.lengthInBytes, asset.byteLength);
        expect(
          sha256.convert(Uint8List.sublistView(data)).toString(),
          asset.sha256,
        );
      }
      expect(
        SeedData.archiveAssetFor('SCP-131')?.assetId,
        'scp-131-orange-mobile-v1',
      );
      expect(SeedData.archiveAssetFor('SCP-999'), isNull);
    },
  );

  testWidgets(
    'narrow gallery card opens the matching record without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final asset = SeedData.archiveAssetFor('SCP-3199')!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Builder(
                builder: (context) => ArchiveGalleryCard(
                  asset: asset,
                  installed: true,
                  onOpenAsset: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: Text('三维档案 · ${asset.title}')),
                      ),
                    ),
                  ),
                  onOpenArticle: () {},
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('SCP-3199'));
      await tester.pumpAndSettle();
      expect(find.text('三维档案 · SCP-3199'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('已下载'), findsOneWidget);
    },
  );

  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('archive-model-test'),
  );
  tearDown(() => directory.delete(recursive: true));

  test(
    'pause keeps the prefix and a fresh store resumes then installs',
    () async {
      final bytes = _glb();
      final asset = _fixture(bytes);
      final store = ArchiveAssetStore(
        directory,
        _Client((request) {
          expect(request.headers[HttpHeaders.rangeHeader], isNull);
          return http.StreamedResponse(
            Stream.fromIterable([bytes.sublist(0, 20), bytes.sublist(20)]),
            200,
            contentLength: bytes.length,
          );
        }),
      );
      store.stateOf(asset).addListener(() {
        final state = store.stateOf(asset).value;
        if (state.downloading && state.progress?.downloadedBytes == 20) {
          store.pause(asset);
        }
      });
      await store.download(asset);
      expect(await store.installedFile(asset), isNull);
      expect(store.stateOf(asset).value.progress?.downloadedBytes, 20);

      final resumed = ArchiveAssetStore(
        directory,
        _Client((request) {
          expect(request.headers[HttpHeaders.rangeHeader], 'bytes=20-');
          return http.StreamedResponse(
            Stream.value(bytes.sublist(20)),
            206,
            contentLength: bytes.length - 20,
            headers: {
              'content-range': 'bytes 20-${bytes.length - 1}/${bytes.length}',
            },
          );
        }),
      );
      await resumed.restoreProgress(asset);
      expect(resumed.stateOf(asset).value.progress?.downloadedBytes, 20);
      await resumed.download(asset);
      final installed = await resumed.installedFile(asset);
      expect(await installed?.readAsBytes(), bytes);
      await resumed.delete(asset);
      expect(await resumed.installedFile(asset), isNull);
    },
  );

  test('a server that ignores Range can restart the download', () async {
    final bytes = _glb();
    final asset = _fixture(bytes);
    var attempt = 0;
    final store = ArchiveAssetStore(
      directory,
      _Client((request) {
        if (attempt++ == 0) {
          return http.StreamedResponse(Stream.value(bytes.sublist(0, 20)), 200);
        }
        expect(request.headers[HttpHeaders.rangeHeader], 'bytes=20-');
        return http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: bytes.length,
        );
      }),
    );
    await store.download(asset);
    expect(store.stateOf(asset).value.error, isNotNull);
    await store.download(asset);
    expect(await (await store.installedFile(asset))?.readAsBytes(), bytes);
  });

  test(
    'wrong length, GLB header or digest never publishes the model',
    () async {
      final bytes = _glb();
      final asset = _fixture(bytes);
      for (final responseBytes in [
        bytes.sublist(1),
        Uint8List.fromList(bytes)..[0] = 0,
        Uint8List.fromList(bytes)..[bytes.length - 1] = 9,
      ]) {
        final store = ArchiveAssetStore(
          directory,
          _Client(
            (request) => http.StreamedResponse(
              Stream.value(responseBytes),
              200,
              contentLength: responseBytes.length,
            ),
          ),
        );
        await store.download(asset);
        expect(await store.installedFile(asset), isNull);
        expect(store.stateOf(asset).value.error, isNotNull);
      }
    },
  );
}

Uint8List _glb() {
  final json = utf8.encode('{"asset":{"version":"2.0"}} ');
  final data = ByteData(20 + json.length)
    ..setUint32(0, 0x46546c67, Endian.little)
    ..setUint32(4, 2, Endian.little)
    ..setUint32(8, 20 + json.length, Endian.little)
    ..setUint32(12, json.length, Endian.little)
    ..setUint32(16, 0x4e4f534a, Endian.little);
  return Uint8List.sublistView(data)..setAll(20, json);
}

ArchiveAsset _fixture(Uint8List bytes) => ArchiveAsset(
  assetId: 'fixture',
  contentId: 'scp-131',
  resourcePath: '',
  source: ArchiveAssetSource.remote,
  delivery: ArchiveAssetDelivery.onDemand,
  version: '1',
  byteLength: bytes.length,
  sha256: sha256.convert(bytes).toString(),
  license: 'CC BY-SA 3.0',
  attribution: 'Fixture',
  contentAttribution: 'Fixture',
  sourceLabel: 'Test host',
  sourceUrl: 'https://example.test/',
  downloadUrl: 'https://example.test/model.glb',
  contentSourceUrl: 'https://example.test/article',
  description: 'Test model',
  objectClass: 'SAFE',
  notice: '',
  modificationNote: '',
  estimatedTriangleCount: 0,
  renderTargetMaxPx: 768,
  initialScale: 1,
);

class _Client extends http.BaseClient {
  _Client(this.respond);
  final http.StreamedResponse Function(http.BaseRequest) respond;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      respond(request);
}
