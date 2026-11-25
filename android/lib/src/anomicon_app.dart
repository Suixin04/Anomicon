import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'discovery.dart';
import 'foundation.dart';
import 'foundation_page.dart';
import 'local_store.dart';
import 'models.dart';
import 'offline_article_store.dart';
import 'raisa.dart';
import 'raisa_page.dart';
import 'repository.dart';
import 'seed_data.dart';

part 'discover_pages.dart';
part 'article_page.dart';
part 'terminal_page.dart';
part 'archive_pages.dart';
part 'settings_page.dart';
part 'shared_widgets.dart';

const _accent = Color(0xFF2F80FF);

enum HomeTab { explore, catalog, foundation, stories, terminal }

extension HomeTabMeta on HomeTab {
  String get title => switch (this) {
    HomeTab.explore => '探索',
    HomeTab.catalog => '图鉴',
    HomeTab.foundation => '基金会',
    HomeTab.stories => '故事',
    HomeTab.terminal => '终端',
  };

  IconData get icon => switch (this) {
    HomeTab.explore => Icons.travel_explore_rounded,
    HomeTab.catalog => Icons.article_outlined,
    HomeTab.foundation => Icons.shield_outlined,
    HomeTab.stories => Icons.description_outlined,
    HomeTab.terminal => Icons.desktop_windows_outlined,
  };
}

class AnomiconApp extends StatefulWidget {
  const AnomiconApp({
    required this.repository,
    required this.localStore,
    required this.appVersion,
    super.key,
  });

  final AnomiconRepository repository;
  final LocalStore localStore;
  final String appVersion;

  @override
  State<AnomiconApp> createState() => _AnomiconAppState();
}

class _AnomiconAppState extends State<AnomiconApp> {
  final _details = GlobalKey<NavigatorState>();
  late final _DetailObserver _detailObserver = _DetailObserver((hasDetail) {
    if (mounted) setState(() => _hasDetail = hasDetail);
  });
  late AppSettings _settings;
  late LibrarySnapshot _library;
  HomeTab _selectedTab = HomeTab.explore;
  bool _hasDetail = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.localStore.loadSettings();
    _library = widget.localStore.loadLibrary();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anomicon',
      debugShowCheckedModeBanner: false,
      themeMode: switch (_settings.themeMode) {
        ThemeModePreference.light => ThemeMode.light,
        ThemeModePreference.dark => ThemeMode.dark,
        ThemeModePreference.system => ThemeMode.system,
      },
      theme: _appTheme(Brightness.light),
      darkTheme: _appTheme(Brightness.dark),
      highContrastTheme: _appTheme(Brightness.light, contrast: 1),
      highContrastDarkTheme: _appTheme(Brightness.dark, contrast: 1),
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final iconBrightness = dark ? Brightness.light : Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
            statusBarIconBrightness: iconBrightness,
            systemNavigationBarIconBrightness: iconBrightness,
          ),
          child: _AppData(
            settings: _settings,
            library: _library,
            child: child!,
          ),
        );
      },
      home: HomeShell(
        repository: widget.repository,
        selectedTab: _selectedTab,
        library: _library,
        onSelectTab: _selectTab,
        onOpenSettings: _openSettings,
        onOpenSearch: _openSearch,
        onOpenArchiveGallery: _openArchiveGallery,
        onOpenContent: _openContent,
        foundationStore: widget.localStore.foundationStore,
        onOpenAssessment: _openAssessment,
        onOpenRaisa: () => _openRaisa(const RaisaOrigin.foundation()),
        onOpenOffline: _openOffline,
        onToggleFavorite: _toggleFavorite,
        onHaptic: _playSelection,
        hasDetail: _hasDetail,
        detail: NavigatorPopHandler<void>(
          onPopWithResult: (_) => _details.currentState!.maybePop(),
          child: Navigator(
            key: _details,
            observers: <NavigatorObserver>[_detailObserver],
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => const Center(child: Text('选择一条内容以查看详情')),
            ),
          ),
        ),
      ),
    );
  }

  void _selectTab(HomeTab tab) {
    if (_selectedTab == tab) return;
    unawaited(_playSelection());
    _details.currentState!.popUntil((route) => route.isFirst);
    setState(() => _selectedTab = tab);
  }

  Future<void> _playSelection() async {
    if (_settings.hapticEnabled) {
      await HapticFeedback.selectionClick();
    }
  }

  Future<void> _popDetail() async {
    unawaited(_playSelection());
    if (!mounted) return;
    await _details.currentState!.maybePop();
  }

  Future<void> _openDetail(WidgetBuilder builder) async {
    unawaited(_playSelection());
    await _details.currentState!.push<void>(
      MaterialPageRoute(builder: builder),
    );
  }

  Future<void> _openSearch([String? initialSeriesId]) => _openDetail(
    (context) => DiscoverySearchScreen(
      repository: widget.repository,
      onOpenContent: _openContent,
      initialSeriesId: initialSeriesId,
      onBack: _popDetail,
    ),
  );

  Future<void> _openSettings() => _openDetail(
    (context) => SettingsScreen(
      settings: _AppData.of(context).settings,
      onBack: _popDetail,
      onSettingsChange: _saveSettings,
      onHaptic: _playSelection,
      onOpenArchiveGallery: _openArchiveGallery,
      onOpenOffline: _openOffline,
    ),
  );

  Future<void> _openArchiveGallery() => _openDetail(
    (context) => ArchiveGalleryScreen(
      repository: widget.repository,
      onBack: _popDetail,
      onOpenAsset: _openArchive,
      onOpenArticle: _openContent,
      onHaptic: _playSelection,
    ),
  );

  Future<void> _openArchive(ArchiveAsset asset) => _openDetail(
    (context) => ArchiveDetailScreen(
      asset: asset,
      repository: widget.repository,
      onBack: _popDetail,
      onOpenArticle: () => _openContent(asset.contentRef),
    ),
  );

  Future<void> _openOffline() => _openDetail(
    (context) => OfflineShelfScreen(
      repository: widget.repository,
      onBack: _popDetail,
      onOpenContent: (content) => _openContent(content, offline: true),
    ),
  );

  Future<void> _openAssessment(FoundationExam exam) => _openDetail(
    (context) => FoundationAssessmentPage(
      store: widget.localStore.foundationStore,
      exam: exam,
      onOpenContent: _openContent,
    ),
  );

  Future<void> _openRaisa(RaisaOrigin origin) => _openDetail(
    (context) => RaisaFeedbackPage(
      store: widget.localStore.raisaStore,
      origin: origin,
      appVersion: widget.appVersion,
    ),
  );

  Future<void> _openContent(ContentRef content, {bool offline = false}) async {
    final library = await widget.localStore.recordRead(content);
    if (!mounted) return;
    setState(() => _library = library);
    await _openDetail((context) {
      final data = _AppData.of(context);
      return ArticleScreen(
        content: content,
        settings: data.settings,
        repository: widget.repository,
        localStore: widget.localStore,
        favorite: data.library.favorites.any((item) => item.key == content.key),
        onBack: _popDetail,
        onToggleFavorite: () => _toggleFavorite(content),
        onLibraryChanged: (library) => setState(() => _library = library),
        onOpenArchive: _openArchive,
        offline: offline,
        onOpenContent: _openContent,
        onOpenSettings: _openSettings,
        onReport: (mode) =>
            _openRaisa(RaisaOrigin.article(content: content, renderMode: mode)),
      );
    });
  }

  Future<void> _toggleFavorite(ContentRef content) async {
    unawaited(_playSelection());
    final library = await widget.localStore.toggleFavorite(content);
    if (!mounted) return;
    setState(() => _library = library);
  }

  Future<void> _saveSettings(AppSettings settings) async {
    final normalized = settings.normalized();
    setState(() => _settings = normalized);
    await widget.localStore.saveSettings(normalized);
  }
}

class _DetailObserver extends NavigatorObserver {
  _DetailObserver(this.onChanged);

  final ValueChanged<bool> onChanged;
  bool _hasDetail = false;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    final hasDetail = !topRoute.isFirst;
    if (hasDetail == _hasDetail) return;
    _hasDetail = hasDetail;
    // The Navigator may update while laying out its routes.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(_hasDetail));
  }
}

class _AppData extends InheritedWidget {
  const _AppData({
    required this.settings,
    required this.library,
    required super.child,
  });

  final AppSettings settings;
  final LibrarySnapshot library;

  static _AppData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppData>()!;

  @override
  bool updateShouldNotify(_AppData oldWidget) =>
      settings != oldWidget.settings || library != oldWidget.library;
}

bool _immersiveMaterialOf(BuildContext context) =>
    context
        .dependOnInheritedWidgetOfExactType<_AppData>()
        ?.settings
        .immersiveMaterialEnabled ??
    true;

ThemeData _appTheme(Brightness brightness, {double contrast = 0}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _accent,
    brightness: brightness,
    contrastLevel: contrast,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamilyFallback: const <String>['Noto Sans CJK SC', 'sans-serif'],
    ),
  );
}

class HomeShell extends StatelessWidget {
  const HomeShell({
    required this.repository,
    required this.selectedTab,
    required this.library,
    required this.onSelectTab,
    required this.onOpenSettings,
    required this.onOpenSearch,
    required this.onOpenArchiveGallery,
    required this.onOpenContent,
    required this.onToggleFavorite,
    required this.onHaptic,
    required this.foundationStore,
    required this.onOpenAssessment,
    required this.onOpenRaisa,
    required this.onOpenOffline,
    this.detail,
    this.hasDetail = false,
    super.key,
  });

  final AnomiconRepository repository;
  final HomeTab selectedTab;
  final LibrarySnapshot library;
  final ValueChanged<HomeTab> onSelectTab;
  final VoidCallback onOpenSettings;
  final void Function([String?]) onOpenSearch;
  final VoidCallback onOpenArchiveGallery;
  final ValueChanged<ContentRef> onOpenContent;
  final ValueChanged<ContentRef> onToggleFavorite;
  final VoidCallback onHaptic;
  final FoundationStore foundationStore;
  final ValueChanged<FoundationExam> onOpenAssessment;
  final VoidCallback onOpenRaisa;
  final VoidCallback onOpenOffline;
  final Widget? detail;
  final bool hasDetail;

  @override
  Widget build(BuildContext context) {
    final child = switch (selectedTab) {
      HomeTab.explore => ExploreScreen(
        repository: repository,
        onOpenSearch: onOpenSearch,
        onOpenContent: onOpenContent,
      ),
      HomeTab.catalog => CatalogScreen(
        repository: repository,
        onOpenSearch: onOpenSearch,
        onOpenContent: onOpenContent,
        onOpenArchiveGallery: onOpenArchiveGallery,
        onHaptic: onHaptic,
      ),
      HomeTab.foundation => FoundationScreen(
        store: foundationStore,
        onOpenContent: onOpenContent,
        onOpenRaisa: onOpenRaisa,
        onOpenAssessment: onOpenAssessment,
      ),
      HomeTab.stories => StoriesScreen(
        repository: repository,
        onOpenContent: onOpenContent,
        onHaptic: onHaptic,
      ),
      HomeTab.terminal => TerminalScreen(
        library: library,
        onOpenContent: onOpenContent,
        onToggleFavorite: onToggleFavorite,
        onOpenSettings: onOpenSettings,
        foundationStore: foundationStore,
        onOpenOffline: onOpenOffline,
        onOpenArchiveGallery: onOpenArchiveGallery,
      ),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final split = wide && detail != null;
        final hideHome = !wide && hasDetail;
        final primaryWidth = split
            ? math.min(560.0, (constraints.maxWidth - 81) * 0.46)
            : constraints.maxWidth - (wide ? 81 : 0);
        return Scaffold(
          bottomNavigationBar: wide || hideHome
              ? null
              : GlassBottomBar(
                  selectedTab: selectedTab,
                  onSelectTab: onSelectTab,
                ),
          body: Row(
            children: <Widget>[
              if (wide) ...<Widget>[
                SizedBox(
                  width: 80,
                  child: SafeArea(
                    child: NavigationRail(
                      labelType: NavigationRailLabelType.all,
                      scrollable: true,
                      backgroundColor: _immersiveMaterialOf(context)
                          ? Theme.of(context).colorScheme.surfaceContainerHigh
                          : Theme.of(context).colorScheme.surface,
                      selectedIndex: selectedTab.index,
                      onDestinationSelected: (index) =>
                          onSelectTab(HomeTab.values[index]),
                      destinations: [
                        for (final tab in HomeTab.values)
                          NavigationRailDestination(
                            icon: Icon(tab.icon),
                            label: Text(tab.title),
                          ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      key: const ValueKey('home-pane'),
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: primaryWidth,
                      child: Offstage(
                        offstage: hideHome,
                        child: ExcludeFocus(excluding: hideHome, child: child),
                      ),
                    ),
                    if (split)
                      Positioned(
                        left: primaryWidth,
                        top: 0,
                        bottom: 0,
                        child: const VerticalDivider(width: 1),
                      ),
                    if (detail != null)
                      Positioned.fill(
                        key: const ValueKey('detail-pane'),
                        left: split ? primaryWidth + 1 : 0,
                        child: Offstage(
                          offstage: !split && !hasDetail,
                          child: detail!,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
