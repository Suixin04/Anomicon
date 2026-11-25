import 'dart:convert';
import 'dart:io';

import 'package:anomicon/src/anomicon_app.dart';
import 'package:anomicon/src/foundation_page.dart';
import 'package:anomicon/src/discovery.dart';
import 'package:anomicon/src/local_store.dart';
import 'package:anomicon/src/models.dart';
import 'package:anomicon/src/offline_article_store.dart';
import 'package:anomicon/src/raisa_page.dart';
import 'package:anomicon/src/repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<LocalStore> openApp(WidgetTester tester, Size surface) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.create();
    await store.saveSettings(const AppSettings(hapticEnabled: false));
    await tester.pumpWidget(
      AnomiconApp(
        repository: _FixtureRepository(),
        localStore: store,
        appVersion: '1.2.7',
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  Finder terminalDestination(Type navigation) =>
      find.descendant(of: find.byType(navigation), matching: find.text('终端'));

  Future<void> openSettings(WidgetTester tester, Type navigation) async {
    await tester.tap(terminalDestination(navigation));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
  }

  ColorScheme settingsColors(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SettingsScreen))).colorScheme;

  double contrast(Color foreground, Color background) {
    final a = foreground.computeLuminance();
    final b = background.computeLuminance();
    return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
  }

  testWidgets('settings apply and persist light, dark and system themes', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final store = await openApp(tester, const Size(400, 800));
    await openSettings(tester, NavigationBar);
    expect(settingsColors(tester).brightness, Brightness.dark);

    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    final light = settingsColors(tester);
    expect(light.brightness, Brightness.light);
    expect(store.loadSettings().themeMode, ThemeModePreference.light);
    expect(
      contrast(light.onSurfaceVariant, light.surfaceContainer),
      greaterThanOrEqualTo(4.5),
    );

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    final dark = settingsColors(tester);
    expect(dark.brightness, Brightness.dark);
    expect(dark.surface, isNot(light.surface));
    expect(
      contrast(dark.onSurfaceVariant, dark.surfaceContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(store.loadSettings().themeMode, ThemeModePreference.dark);

    await tester.tap(find.text('跟随系统'));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(settingsColors(tester).brightness, Brightness.light);
    expect(store.loadSettings().themeMode, ThemeModePreference.system);
  });

  testWidgets('system high contrast strengthens settings colors', (
    tester,
  ) async {
    await openApp(tester, const Size(400, 800));
    await openSettings(tester, NavigationBar);
    final regular = settingsColors(tester);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(highContrast: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpAndSettle();
    final high = settingsColors(tester);
    expect(high.brightness, regular.brightness);
    expect(
      contrast(high.primary, high.surface),
      greaterThan(contrast(regular.primary, regular.surface)),
    );
    expect(
      contrast(high.onSurfaceVariant, high.surfaceContainer),
      greaterThanOrEqualTo(7),
    );
  });

  testWidgets('foundation opens RAISA with the injected app version', (
    tester,
  ) async {
    await openApp(tester, const Size(440, 800));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('基金会'),
      ),
    );
    await tester.pumpAndSettle();
    final raisa = find.text('RAISA 工单');
    await tester.ensureVisible(raisa);
    await tester.tap(raisa);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RaisaFeedbackPage>(find.byType(RaisaFeedbackPage))
          .appVersion,
      '1.2.7',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(FoundationScreen), findsOneWidget);
  });

  testWidgets('terminal opens the offline shelf', (tester) async {
    await openApp(tester, const Size(440, 800));
    await tester.tap(terminalDestination(NavigationBar));
    await tester.pumpAndSettle();
    final shelf = find.text('离线书架');
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -550),
    );
    await tester.pumpAndSettle();
    await tester.tap(shelf);
    await tester.pumpAndSettle();
    expect(find.byType(OfflineShelfScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TerminalScreen), findsOneWidget);
  });

  testWidgets(
    'clearing history from reader settings updates the retained search',
    (tester) async {
      await openApp(tester, const Size(440, 900));
      await DiscoveryHistory.remember('SCP-173');
      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();
      expect(find.byType(DiscoverySearchScreen), findsOneWidget);
      expect(find.text('SCP-173'), findsWidgets);
      await tester.tap(find.widgetWithText(ActionChip, 'SCP-173'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'scp-173'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('阅读菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('阅读设置'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('清空搜索历史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清空搜索历史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();
      expect(await DiscoveryHistory.load(), isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DiscoverySearchScreen), findsOneWidget);
      await tester.tap(find.byTooltip('清除查询'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ActionChip, 'SCP-173'), findsNothing);
    },
  );

  testWidgets('model detail opens article and system back restores model', (
    tester,
  ) async {
    await openApp(tester, const Size(440, 900));
    await openSettings(tester, NavigationBar);
    await tester.drag(find.byType(ListView).first, const Offset(0, -480));
    await tester.pumpAndSettle();
    await tester.tap(find.text('三维档案馆'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('待下载 6'));
    await tester.pumpAndSettle();
    final card = find.byType(ArchiveGalleryCard).first;
    final asset = tester.widget<ArchiveGalleryCard>(card).asset;
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveDetailScreen), findsOneWidget);
    final openArticle = find.text('打开条目');
    await tester.drag(
      find.descendant(
        of: find.byType(ArchiveDetailScreen),
        matching: find.byType(ListView),
      ),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    await tester.tap(openArticle);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ArticleScreen>(find.byType(ArticleScreen)).content.id,
      asset.contentId,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ArchiveDetailScreen>(find.byType(ArchiveDetailScreen))
          .asset,
      asset,
    );
  });

  testWidgets('finished articles update catalog and story navigation', (
    tester,
  ) async {
    final store = await openApp(tester, const Size(440, 900));

    Future<void> selectTab(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> finishCurrentArticle() async {
      await tester.drag(
        find.descendant(
          of: find.byType(ArticleScreen),
          matching: find.byType(SingleChildScrollView),
        ),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      expect(find.text('已读 · 上拉取消已读'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    await selectTab('图鉴');
    expect(find.text('SCP-173 · 已读'), findsNothing);
    await tester.tap(find.widgetWithText(CatalogTile, 'SCP-173').first);
    await tester.pumpAndSettle();
    await finishCurrentArticle();
    expect(find.text('SCP-173 · 已读'), findsWidgets);
    expect(store.loadLibrary().history.single.completed, isTrue);

    await selectTab('故事');
    expect(find.text('主线已读 0 / 19'), findsOneWidget);
    await tester.tap(find.text('开始阅读'));
    await tester.pumpAndSettle();
    await finishCurrentArticle();
    expect(find.text('主线已读 1 / 19'), findsOneWidget);
  });

  testWidgets('wide detail and compact back share the same route stack', (
    tester,
  ) async {
    await openApp(tester, const Size(1000, 800));
    await openSettings(tester, NavigationRail);
    expect(find.byType(TerminalScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsOneWidget);
    final primary = tester.getRect(find.byType(TerminalScreen));
    final details = tester.getRect(find.byType(SettingsScreen));
    expect(primary.right, lessThanOrEqualTo(details.left));

    await tester.drag(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ListView && widget.scrollDirection == Axis.vertical,
        ),
      ),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('三维档案馆'));
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveGalleryScreen), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(440, 800));
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveGalleryScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(TerminalScreen), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(TerminalScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      HomeTab.terminal.index,
    );
  });
}

class _FixtureRepository extends Fake implements AnomiconRepository {
  @override
  final ContentCache contentCache = _FixtureCache();

  @override
  final WikiGateway wikiGateway = _FixtureWiki();

  @override
  final ArchiveAssetStore archiveAssetStore = _FixtureArchiveStore();

  @override
  Future<ArticleDocument> loadArticle(ContentRef content) async =>
      ArticleDocument(
        content: content,
        sourceUrl: 'https://scp-wiki-cn.wikidot.com/${content.id}',
        fetchedAt: 0,
        blocks: const [ArticleParagraph('测试正文')],
      );

  @override
  Future<File?> installedArchiveAsset(ArchiveAsset asset) async => null;

  @override
  Future<OfflineArticleStore> get offlineArticles async => _EmptyOfflineStore();
}

class _EmptyOfflineStore extends Fake implements OfflineArticleStore {
  @override
  Future<List<OfflineArticleInfo>> list() async => [];

  @override
  Future<bool> contains(ContentRef content) async => false;
}

class _FixtureCache extends Fake implements ContentCache {
  @override
  Future<CachedContent?> read(String key, String extension) async =>
      CachedContent(
        jsonEncode({
          'html': '<div id="page-content"><ul><li><a href="/scp-173">SCP-173</a> - 雕像</li><li><a href="/scp-cn-2000">SCP-CN-2000</a> - 辉光</li><li><a href="/ghost-story">白日之梦</a></li></ul></div>',
        }),
        DateTime.now().millisecondsSinceEpoch,
      );
}

class _FixtureWiki extends Fake implements WikiGateway {
  @override
  List<ExploreEntry> parseExplore(ExploreSource source, String html) => [
    const ExploreEntry(id: 'scp-173', title: '雕像'),
  ];
}

class _FixtureArchiveStore extends Fake implements ArchiveAssetStore {
  @override
  final installedRevision = ValueNotifier<int>(0);

  final _state = ValueNotifier(const ArchiveDownloadState());

  @override
  ValueNotifier<ArchiveDownloadState> stateOf(ArchiveAsset asset) => _state;

  @override
  Future<void> restoreProgress(ArchiveAsset asset) async {}

  @override
  Future<File?> installedFile(ArchiveAsset asset) async => null;
}
