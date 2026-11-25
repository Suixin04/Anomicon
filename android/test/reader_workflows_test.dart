import 'dart:convert';
import 'dart:io';

import 'package:anomicon/src/anomicon_app.dart';
import 'package:anomicon/src/article_parser.dart';
import 'package:anomicon/src/local_store.dart';
import 'package:anomicon/src/models.dart';
import 'package:anomicon/src/offline_article_store.dart';
import 'package:anomicon/src/repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final content = ContentRef.create(ContentKind.scp, 'scp-173', '读者测试');

  test('原生正文提取目录、脚注、折叠和相对链接', () {
    final article = parseNativeArticle(content, '''
<div id="page-content">
  <div id="toc"><a href="#first">第一节</a></div>
  <h2 id="first">第一节</h2>
  <p>这是正文编号 1，继续<span id="footnote:1"><sup><a href="#footnote-1">1</a></sup></span>。
    <a href="/scp-131">下一档案</a></p>
  <div class="collapsible-block">
    <div class="collapsible-block-folded"><a class="collapsible-block-link">展开隐藏记录</a></div>
    <div class="collapsible-block-content"><p>隐藏记录</p></div>
  </div>
  <div class="footnotes-footer"><div class="footnote-footer" id="footnote-1"><a href="#footnote:1">1</a>. 脚注内容</div></div>
</div>''', 1000);
    expect(article.blocks[article.anchors['first']!], isA<ArticleHeading>());
    final source = article.anchors['footnote:1']!;
    final reference = article.links[source]!.first;
    final text = (article.blocks[source] as ArticleParagraph).text;
    expect(reference.offset, '这是正文编号 1，继续'.length);
    expect(text.substring(reference.offset, reference.offset + 1), '1');
    expect(article.footnotes[reference.target.fragment]!.text, '脚注内容');
    expect(
      article.links[source]!.last.target.toString(),
      articleUrlOf('scp-131'),
    );
    expect(article.folds.single.label, '展开隐藏记录');
    expect(
      (article.blocks[article.folds.single.start] as ArticleParagraph).text,
      '隐藏记录',
    );
  });

  test('同源 HTML 帧保留相对于帧的资源地址', () async {
    final base = Uri.parse(articleUrlOf(content.id));
    final expanded = await expandArticleFrames(
      '''
<div id="page-content"><iframe class="html-block-iframe" src="/html/frame/index.html"></iframe>
<iframe class="html-block-iframe" src="https://example.com/html/frame"></iframe></div>''',
      base,
      (uri) async {
        expect(uri, base.resolve('/html/frame/index.html'));
        return '<p>帧内容</p><img src="image.png">';
      },
    );
    final article = parseNativeArticle(content, expanded, 1000);
    expect(article.blocks.whereType<ArticleParagraph>().single.text, '帧内容');
    expect(
      article.blocks.whereType<ArticleImage>().single.url,
      base.resolve('/html/frame/image.png').toString(),
    );
  });

  test('离线版本跨实例保留；取图失败保留旧版本；更新原址配图', () async {
    final root = await Directory.systemTemp.createTemp('anomicon-reader-test-');
    addTearDown(() => root.delete(recursive: true));
    final store = OfflineArticleStore(root);
    final version1 = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
    );
    final version2 = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNg+M8AAAICAQB7CYF4AAAAAElFTkSuQmCC',
    );
    String html(String version) =>
        '<div id="page-content"><p>$version</p><img src="/same.png"></div>';
    await store.save(
      content,
      fetchArticle: (_) async => html('v1'),
      fetchImage: (_) async => version1,
    );
    final reopened = OfflineArticleStore(root);
    expect((await reopened.list()).single.content.key, content.key);
    await expectLater(
      store.save(
        content,
        fetchArticle: (_) async => html('v2'),
        fetchImage: (_) async => throw const HttpException('no image'),
      ),
      throwsA(isA<HttpException>()),
    );
    final old = await reopened.read(content);
    expect((old.document.blocks.first as ArticleParagraph).text, 'v1');
    expect(old.images.values.single, version1);
    await store.save(
      content,
      fetchArticle: (_) async => html('v2'),
      fetchImage: (_) async => version2,
    );
    final updated = await reopened.read(content);
    expect((updated.document.blocks.first as ArticleParagraph).text, 'v2');
    expect(updated.images.values.single, version2);
    await reopened.remove(content);
    expect(await store.list(), isEmpty);
  });

  testWidgets('脚注可定位原引用，短拉无效，长拉切换已读', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(430, 800);
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final local = await LocalStore.create();
    final article = parseNativeArticle(
      content,
      """
<div id="page-content"><h2>原生标题</h2><p>正文<sup id="footnote:1"><a href="#footnote-1">1</a></sup>。</p>
<div class="footnotes-footer"><div class="footnote-footer" id="footnote-1"><a href="#footnote:1">1</a>. 脚注测试</div></div></div>""",
      1000,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ArticleScreen(
          content: content,
          settings: const AppSettings(hapticEnabled: false),
          repository: _ReaderRepository(article),
          localStore: local,
          favorite: false,
          onBack: () {},
          onToggleFavorite: () {},
          onLibraryChanged: (_) {},
          onOpenArchive: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('脚注测试'), findsOneWidget);
    await tester.tap(find.text('返回正文位置'));
    await tester.pumpAndSettle();
    expect(find.text('脚注测试'), findsNothing);
    final reader = find.byType(SingleChildScrollView);
    await tester.drag(reader, const Offset(0, -28));
    await tester.pumpAndSettle();
    expect(local.loadLibrary().history.single.completed, isFalse);
    await tester.drag(reader, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(local.loadLibrary().history.single.completed, isTrue);
    await tester.drag(reader, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(local.loadLibrary().history.single.completed, isFalse);
  });

  test('分别持久化原生、网页、离线位置和已读状态', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.create();
    await store.recordRead(
      content,
      pixelOffset: 345.25,
      completed: true,
      activeDeltaMs: 2500,
    );
    await store.recordRead(
      content,
      webPixelOffset: 900,
      offlinePixelOffset: 79,
    );
    final reopened = await LocalStore.create();
    final library = reopened.loadLibrary();
    final entry = library.history.single;
    expect(entry.pixelOffset, 345.25);
    expect(entry.webPixelOffset, 900);
    expect(entry.offlinePixelOffset, 79);
    expect(entry.completed, isTrue);
    expect(library.activitySegments.single.activeMs, 2500);
    await reopened.recordRead(content, completed: false);
    expect(store.loadLibrary().history.single.completed, isFalse);
  });
}

class _ReaderRepository extends Fake implements AnomiconRepository {
  _ReaderRepository(this.article);

  final ArticleDocument article;

  @override
  Future<OfflineArticleStore> get offlineArticles async =>
      _ReaderOfflineStore();

  @override
  Future<ArticleDocument> loadArticle(ContentRef content) async => article;
}

class _ReaderOfflineStore extends Fake implements OfflineArticleStore {
  @override
  Future<bool> contains(ContentRef content) async => false;
}
