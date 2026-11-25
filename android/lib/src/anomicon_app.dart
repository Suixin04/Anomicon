import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'local_store.dart';
import 'models.dart';
import 'repository.dart';
import 'seed_data.dart';

part 'discover_pages.dart';
part 'article_page.dart';
part 'terminal_page.dart';
part 'archive_pages.dart';
part 'settings_page.dart';
part 'shared_widgets.dart';

const _black = Color(0xFF000000);
const _surface = Color(0xFF202528);
const _surfaceHigh = Color(0xFF34393C);
const _surfaceLow = Color(0xFF171A1C);
const _accent = Color(0xFF2F80FF);
const _muted = Color(0xFF92979C);

enum HomeTab { explore, catalog, stories, terminal }

extension HomeTabMeta on HomeTab {
  String get title => switch (this) {
    HomeTab.explore => '探索',
    HomeTab.catalog => '图鉴',
    HomeTab.stories => '故事',
    HomeTab.terminal => '终端',
  };

  IconData get icon => switch (this) {
    HomeTab.explore => Icons.travel_explore_rounded,
    HomeTab.catalog => Icons.article_outlined,
    HomeTab.stories => Icons.description_outlined,
    HomeTab.terminal => Icons.desktop_windows_outlined,
  };
}

class AnomiconApp extends StatefulWidget {
  const AnomiconApp({
    required this.repository,
    required this.localStore,
    super.key,
  });

  final AnomiconRepository repository;
  final LocalStore localStore;

  @override
  State<AnomiconApp> createState() => _AnomiconAppState();
}

class _AnomiconAppState extends State<AnomiconApp> {
  late AppSettings _settings;
  late LibrarySnapshot _library;
  HomeTab _selectedTab = HomeTab.explore;
  ContentRef? _activeContent;
  ArchiveAsset? _activeArchive;
  bool _showSettings = false;
  bool _showArchiveGallery = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.localStore.loadSettings();
    _library = widget.localStore.loadLibrary();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    return MaterialApp(
      title: 'Anomicon',
      debugShowCheckedModeBanner: false,
      themeMode: switch (_settings.themeMode) {
        ThemeModePreference.light => ThemeMode.light,
        ThemeModePreference.dark => ThemeMode.dark,
        ThemeModePreference.system => ThemeMode.system,
      },
      theme: _appTheme(Brightness.dark),
      darkTheme: _appTheme(Brightness.dark),
      home: _buildSurface(),
    );
  }

  Widget _buildSurface() {
    if (_activeArchive != null) {
      return ArchiveDetailScreen(
        asset: _activeArchive!,
        repository: widget.repository,
        onBack: () async {
          await _playSelection();
          setState(() => _activeArchive = null);
        },
        onOpenArticle: () => _openContent(_activeArchive!.contentRef),
      );
    }
    if (_activeContent != null) {
      return ArticleScreen(
        content: _activeContent!,
        settings: _settings,
        repository: widget.repository,
        localStore: widget.localStore,
        favorite: _library.favorites.any(
          (item) => item.key == _activeContent!.key,
        ),
        onBack: () async {
          await _playSelection();
          setState(() => _activeContent = null);
        },
        onToggleFavorite: () => _toggleFavorite(_activeContent!),
        onLibraryChanged: (library) => setState(() => _library = library),
        onOpenArchive: (asset) async {
          await _playSelection();
          setState(() => _activeArchive = asset);
        },
      );
    }
    if (_showSettings) {
      return SettingsScreen(
        settings: _settings,
        onBack: () async {
          await _playSelection();
          setState(() => _showSettings = false);
        },
        onSettingsChange: _saveSettings,
        onHaptic: _playSelection,
      );
    }
    if (_showArchiveGallery) {
      return ArchiveGalleryScreen(
        repository: widget.repository,
        onBack: () async {
          await _playSelection();
          setState(() => _showArchiveGallery = false);
        },
        onOpenAsset: (asset) async {
          await _playSelection();
          setState(() => _activeArchive = asset);
        },
        onOpenArticle: _openContent,
        onHaptic: _playSelection,
      );
    }
    return HomeShell(
      repository: widget.repository,
      selectedTab: _selectedTab,
      library: _library,
      onSelectTab: (tab) async {
        if (_selectedTab == tab) return;
        await _playSelection();
        setState(() => _selectedTab = tab);
      },
      onOpenSettings: () async {
        await _playSelection();
        setState(() => _showSettings = true);
      },
      onOpenArchiveGallery: () async {
        await _playSelection();
        setState(() => _showArchiveGallery = true);
      },
      onOpenContent: _openContent,
      onToggleFavorite: _toggleFavorite,
      onHaptic: _playSelection,
    );
  }

  Future<void> _playSelection() async {
    if (_settings.hapticEnabled) {
      await HapticFeedback.selectionClick();
    }
  }

  Future<void> _openContent(ContentRef content) async {
    await _playSelection();
    final library = await widget.localStore.recordRead(content);
    if (!mounted) return;
    setState(() {
      _library = library;
      _activeContent = content;
    });
  }

  Future<void> _toggleFavorite(ContentRef content) async {
    await _playSelection();
    final library = await widget.localStore.toggleFavorite(content);
    if (!mounted) return;
    setState(() => _library = library);
  }

  Future<void> _saveSettings(AppSettings settings) async {
    final normalized = settings.normalized();
    await widget.localStore.saveSettings(normalized);
    if (!mounted) return;
    setState(() => _settings = normalized);
  }
}

ThemeData _appTheme(Brightness brightness) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: const ColorScheme.dark(
      primary: _accent,
      secondary: Color(0xFF8AB4FF),
      surface: _surface,
      surfaceContainerHighest: _surfaceHigh,
      error: Color(0xFFFF8A8A),
      onPrimary: Colors.white,
      onSurface: Colors.white,
      onSurfaceVariant: _muted,
    ),
    scaffoldBackgroundColor: _black,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
      fontFamilyFallback: const <String>['Noto Sans CJK SC', 'sans-serif'],
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}

class HomeShell extends StatelessWidget {
  const HomeShell({
    required this.repository,
    required this.selectedTab,
    required this.library,
    required this.onSelectTab,
    required this.onOpenSettings,
    required this.onOpenArchiveGallery,
    required this.onOpenContent,
    required this.onToggleFavorite,
    required this.onHaptic,
    super.key,
  });

  final AnomiconRepository repository;
  final HomeTab selectedTab;
  final LibrarySnapshot library;
  final ValueChanged<HomeTab> onSelectTab;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenArchiveGallery;
  final ValueChanged<ContentRef> onOpenContent;
  final ValueChanged<ContentRef> onToggleFavorite;
  final VoidCallback onHaptic;

  @override
  Widget build(BuildContext context) {
    final child = switch (selectedTab) {
      HomeTab.explore => ExploreScreen(
        repository: repository,
        onOpenContent: onOpenContent,
      ),
      HomeTab.catalog => CatalogScreen(
        repository: repository,
        onOpenContent: onOpenContent,
        onOpenArchiveGallery: onOpenArchiveGallery,
        onHaptic: onHaptic,
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
      ),
    };
    return Scaffold(
      backgroundColor: _black,
      body: Stack(
        children: <Widget>[
          child,
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 20),
              child: GlassBottomBar(
                selectedTab: selectedTab,
                onSelectTab: onSelectTab,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
