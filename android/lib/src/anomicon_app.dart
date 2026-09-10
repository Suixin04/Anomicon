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

const _black = Color(0xFF000000);
const _surface = Color(0xFF202528);
const _surfaceHigh = Color(0xFF34393C);
const _surfaceLow = Color(0xFF171A1C);
const _accent = Color(0xFF2F80FF);
const _muted = Color(0xFF92979C);
const _archiveBlue = Color(0xFF242C42);

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

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    required this.repository,
    required this.onOpenContent,
    super.key,
  });

  final AnomiconRepository repository;
  final ValueChanged<ContentRef> onOpenContent;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late Future<ExploreHomeData> _future;
  int _recommendationIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadExplore();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExploreHomeData>(
      future: _future,
      builder: (context, snapshot) {
        final data =
            snapshot.data ??
            ExploreHomeData(
              topRated: SeedData.fallbackExplore,
              recommendations: SeedData.fallbackRecommendations,
            );
        return PageCanvas(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: PageHeading(
                  title: '探索',
                  trailing: GlassIconButton(
                    icon: Icons.refresh_rounded,
                    label: '刷新',
                    onPressed: () {
                      setState(() {
                        _recommendationIndex = 0;
                        _future = widget.repository.loadExplore();
                      });
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SectionTitle(
                  title: '今日推荐',
                  subtitle: '每天随机解析一组主站档案',
                  trailing:
                      '${math.min(_recommendationIndex + 1, data.recommendations.length)} / ${data.recommendations.length}',
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 410,
                  child: PageView.builder(
                    itemCount: data.recommendations.length,
                    onPageChanged: (index) =>
                        setState(() => _recommendationIndex = index),
                    itemBuilder: (context, index) {
                      final entry = data.recommendations[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: RecommendationHeroCard(
                          entry: entry,
                          onTap: () => widget.onOpenContent(
                            ContentRef.create(
                              ContentKind.scp,
                              entry.normalizedId,
                              entry.title,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: HintRow(
                  icon: Icons.swipe_rounded,
                  text: '左右划走顶牌，点击卡牌阅读',
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
                  child: SectionTitle(
                    title: '热门原创',
                    subtitle: 'SCP 中文主站高分内容',
                    compact: true,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: RankedListCard(
                  entries: data.topRated.take(8).toList(),
                  onOpenContent: (entry) => widget.onOpenContent(
                    ContentRef.create(
                      ContentKind.wiki,
                      entry.normalizedId,
                      entry.title,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: ExploreStrip(
                  title: '最近更新',
                  items: data.recent,
                  onOpenContent: widget.onOpenContent,
                ),
              ),
              SliverToBoxAdapter(
                child: ExploreStrip(
                  title: '轻松内容',
                  items: data.jokes,
                  onOpenContent: widget.onOpenContent,
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          ),
        );
      },
    );
  }
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    required this.repository,
    required this.onOpenContent,
    required this.onOpenArchiveGallery,
    required this.onHaptic,
    super.key,
  });

  final AnomiconRepository repository;
  final ValueChanged<ContentRef> onOpenContent;
  final VoidCallback onOpenArchiveGallery;
  final VoidCallback onHaptic;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  var _selectedSeriesId = scpSeriesDescriptors.first.id;
  var _query = '';
  var _showSearch = false;
  late Future<List<CatalogEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadCatalog(_selectedSeriesId);
  }

  @override
  Widget build(BuildContext context) {
    return PageCanvas(
      child: FutureBuilder<List<CatalogEntry>>(
        future: _future,
        builder: (context, snapshot) {
          final entries = snapshot.data ?? SeedData.fallbackCatalog;
          final normalizedQuery = _query.trim().toLowerCase();
          final filtered = entries.where((entry) {
            return normalizedQuery.isEmpty ||
                entry.itemId.toLowerCase().contains(normalizedQuery) ||
                entry.title.toLowerCase().contains(normalizedQuery);
          }).toList();
          return CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: PageHeading(
                  title: '图鉴',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      GlassIconButton(
                        icon: Icons.search_rounded,
                        label: '搜索',
                        onPressed: () {
                          widget.onHaptic();
                          setState(() => _showSearch = !_showSearch);
                        },
                      ),
                      const SizedBox(width: 10),
                      GlassIconButton(
                        icon: Icons.grid_view_rounded,
                        label: '三维档案馆',
                        onPressed: widget.onOpenArchiveGallery,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showSearch)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: SearchPill(
                      hint: '搜索编号或名称',
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: HorizontalPills(
                  labels: <String, String>{
                    for (final series in scpSeriesDescriptors)
                      series.id: series.label,
                  },
                  selected: _selectedSeriesId,
                  onSelected: (value) {
                    if (value == _selectedSeriesId) return;
                    widget.onHaptic();
                    setState(() {
                      _selectedSeriesId = value;
                      _future = widget.repository.loadCatalog(value);
                    });
                  },
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 124),
                sliver: SliverGrid.builder(
                  itemCount: filtered.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 292,
                  ),
                  itemBuilder: (context, index) => CatalogTile(
                    entry: filtered[index],
                    onTap: () =>
                        widget.onOpenContent(filtered[index].contentRef),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({
    required this.repository,
    required this.onOpenContent,
    required this.onHaptic,
    super.key,
  });

  final AnomiconRepository repository;
  final ValueChanged<ContentRef> onOpenContent;
  final VoidCallback onHaptic;

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  static final _letters = List<String>.generate(
    26,
    (index) => String.fromCharCode(65 + index),
  );

  var _query = '';
  var _selectedLetter = '';
  late Future<List<TaleEntry>> _future;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadTales();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageCanvas(
      child: FutureBuilder<List<TaleEntry>>(
        future: _future,
        builder: (context, snapshot) {
          final tales = snapshot.data ?? SeedData.fallbackTales;
          final normalizedQuery = _query.trim().toLowerCase();
          final filtered = tales.where((tale) {
            final matchesLetter =
                _selectedLetter.isEmpty ||
                (tale.id.isNotEmpty &&
                    tale.id[0].toUpperCase() == _selectedLetter);
            return matchesLetter &&
                (normalizedQuery.isEmpty ||
                    tale.id.toLowerCase().contains(normalizedQuery) ||
                    tale.title.toLowerCase().contains(normalizedQuery));
          }).toList();
          return CustomScrollView(
            controller: _controller,
            slivers: <Widget>[
              const SliverToBoxAdapter(child: PageHeading(title: '故事')),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: SearchPill(
                    hint: '搜索故事标题或路径',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: HorizontalPills(
                  labels: <String, String>{
                    '': '全部',
                    for (final letter in _letters) letter: letter,
                  },
                  selected: _selectedLetter,
                  onSelected: (value) {
                    if (value == _selectedLetter) return;
                    widget.onHaptic();
                    setState(() => _selectedLetter = value);
                    _controller.animateTo(
                      0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: EmptyCard(
                      title: '无匹配故事',
                      actionLabel:
                          _query.isNotEmpty || _selectedLetter.isNotEmpty
                          ? '清除筛选'
                          : null,
                      onAction: () {
                        widget.onHaptic();
                        setState(() {
                          _query = '';
                          _selectedLetter = '';
                        });
                      },
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 124),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => StoryRow(
                      tale: filtered[index],
                      onTap: () =>
                          widget.onOpenContent(filtered[index].contentRef),
                    ),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class TerminalScreen extends StatelessWidget {
  const TerminalScreen({
    required this.library,
    required this.onOpenContent,
    required this.onToggleFavorite,
    required this.onOpenSettings,
    super.key,
  });

  final LibrarySnapshot library;
  final ValueChanged<ContentRef> onOpenContent;
  final ValueChanged<ContentRef> onToggleFavorite;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final progress = deriveResearchProgress(library.activitySegments);
    final resumeEntry = library.history
        .where((item) => item.scrollOffset > 0)
        .firstOrNull;
    final resumeKey = resumeEntry?.content.key;
    final recentEntries = library.history
        .where((item) => item.content.key != resumeKey)
        .take(30)
        .toList();
    return PageCanvas(
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: PageHeading(
              title: '终端',
              trailing: GlassIconButton(
                icon: Icons.settings_rounded,
                label: '设置',
                onPressed: onOpenSettings,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: ResearchProfileCard(
                progress: progress,
                favoriteCount: library.favorites.length,
                historyCount: library.history.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SectionTitle(
                title: '个人资料库',
                subtitle: '收藏、阅读进度与近期访问都保存在本地',
                compact: true,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: LibraryGroup(
              title: '继续阅读',
              icon: Icons.play_arrow_rounded,
              count: resumeEntry == null ? 0 : 1,
              child: resumeEntry == null
                  ? const EmptyCard(title: '暂无可继续的条目。')
                  : ReadingHistoryRow(
                      entry: resumeEntry,
                      onTap: () => onOpenContent(resumeEntry.content),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: LibraryGroup(
              title: '收藏',
              icon: Icons.star_rounded,
              count: library.favorites.length,
              child: library.favorites.isEmpty
                  ? const EmptyCard(title: '还没有收藏。')
                  : Column(
                      children: library.favorites
                          .map(
                            (content) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ContentRow(
                                content: content,
                                subtitle: content.id,
                                trailing: IconButton(
                                  onPressed: () => onToggleFavorite(content),
                                  icon: const Icon(
                                    Icons.star_rounded,
                                    color: _accent,
                                  ),
                                ),
                                onTap: () => onOpenContent(content),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: LibraryGroup(
              title: '最近阅读',
              icon: Icons.history_rounded,
              count: recentEntries.length,
              child: recentEntries.isEmpty
                  ? const EmptyCard(title: '暂无阅读记录。')
                  : Column(
                      children: recentEntries
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ReadingHistoryRow(
                                entry: entry,
                                onTap: () => onOpenContent(entry.content),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }
}

class ArticleScreen extends StatefulWidget {
  const ArticleScreen({
    required this.content,
    required this.settings,
    required this.repository,
    required this.localStore,
    required this.favorite,
    required this.onBack,
    required this.onToggleFavorite,
    required this.onLibraryChanged,
    required this.onOpenArchive,
    super.key,
  });

  final ContentRef content;
  final AppSettings settings;
  final AnomiconRepository repository;
  final LocalStore localStore;
  final bool favorite;
  final VoidCallback onBack;
  final VoidCallback onToggleFavorite;
  final ValueChanged<LibrarySnapshot> onLibraryChanged;
  final ValueChanged<ArchiveAsset> onOpenArchive;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  late Future<ArticleDocument> _future;
  late final ScrollController _controller;
  int _lastCreditAt = 0;
  ArticleDocument? _document;
  File? _previewFile;

  @override
  void initState() {
    super.initState();
    final existing = widget.localStore
        .loadLibrary()
        .history
        .where((entry) => entry.content.key == widget.content.key)
        .firstOrNull;
    _controller = ScrollController(
      initialScrollOffset: (existing?.scrollOffset ?? 0) * 220.0,
    );
    _controller.addListener(_recordScrollCheckpoint);
    _future = _load();
  }

  Future<ArticleDocument> _load() async {
    final document = await widget.repository.loadArticle(widget.content);
    _document = document;
    widget.onLibraryChanged(
      await widget.localStore.recordRead(
        widget.content,
        scrollOffset: _blockIndex,
        blockCount: document.blocks.length,
      ),
    );
    return document;
  }

  int get _blockIndex {
    final count = _document?.blocks.length ?? 0;
    if (count == 0 || !_controller.hasClients) return 0;
    return (_controller.offset / 220).floor().clamp(0, math.max(0, count - 1));
  }

  Future<void> _recordScrollCheckpoint() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastCreditAt < 1200 || _document == null) return;
    _lastCreditAt = now;
    widget.onLibraryChanged(
      await widget.localStore.recordRead(
        widget.content,
        scrollOffset: _blockIndex,
        blockCount: _document!.blocks.length,
        creditActiveTime: true,
      ),
    );
  }

  @override
  void dispose() {
    _recordScrollCheckpoint();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final archiveAsset = SeedData.archiveAssetFor(widget.content.id);
    return DetailCanvas(
      onBack: widget.onBack,
      title: widget.content.title,
      subtitle: widget.content.id,
      actions: <Widget>[
        if (archiveAsset != null)
          GlassIconButton(
            icon: Icons.view_in_ar_rounded,
            label: '三维档案',
            onPressed: () => widget.onOpenArchive(archiveAsset),
          ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: widget.favorite
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          label: widget.favorite ? '取消收藏' : '收藏',
          onPressed: widget.onToggleFavorite,
        ),
      ],
      child: FutureBuilder<ArticleDocument>(
        future: _future,
        builder: (context, snapshot) {
          final document = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting &&
              document == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || document == null) {
            return ArticleError(
              message: snapshot.error?.toString() ?? '文章暂时不可用',
              onRetry: () => setState(() => _future = _load()),
              onOpenOriginal: () =>
                  _openExternal(articleUrlOf(widget.content.id)),
            );
          }
          final progress = document.blocks.length <= 1
              ? 1.0
              : (_blockIndex / math.max(1, document.blocks.length - 1)).clamp(
                  0.0,
                  1.0,
                );
          return Stack(
            children: <Widget>[
              ListView.separated(
                controller: _controller,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 44),
                itemCount: document.blocks.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '原生阅读 · ${document.blocks.length} 个内容块',
                          style: const TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  }
                  if (index == document.blocks.length + 1) {
                    return const Text(
                      '内容来自 SCP Wiki 缓存；图片按需缓存到本机。',
                      style: TextStyle(color: _muted, fontSize: 12),
                    );
                  }
                  return ArticleBlockView(
                    block: document.blocks[index - 1],
                    settings: widget.settings,
                    repository: widget.repository,
                    onImageLoaded: (file) =>
                        setState(() => _previewFile = file),
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_previewFile != null)
                ImagePreviewDialog(
                  file: _previewFile!,
                  onDismiss: () => setState(() => _previewFile = null),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ArchiveGalleryScreen extends StatefulWidget {
  const ArchiveGalleryScreen({
    required this.repository,
    required this.onBack,
    required this.onOpenAsset,
    required this.onOpenArticle,
    required this.onHaptic,
    super.key,
  });

  final AnomiconRepository repository;
  final VoidCallback onBack;
  final ValueChanged<ArchiveAsset> onOpenAsset;
  final ValueChanged<ContentRef> onOpenArticle;
  final VoidCallback onHaptic;

  @override
  State<ArchiveGalleryScreen> createState() => _ArchiveGalleryScreenState();
}

class _ArchiveGalleryScreenState extends State<ArchiveGalleryScreen> {
  var _filter = 'all';
  var _installed = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _refreshInstalled();
  }

  Future<void> _refreshInstalled() async {
    final next = <String, bool>{};
    for (final asset in SeedData.archiveAssets) {
      next[asset.assetId] =
          asset.isReadyByDefault ||
          await widget.repository.installedArchiveAsset(asset) != null;
    }
    if (!mounted) return;
    setState(() => _installed = next);
  }

  @override
  Widget build(BuildContext context) {
    final installedCount = SeedData.archiveAssets
        .where((asset) => _installed[asset.assetId] ?? asset.isReadyByDefault)
        .length;
    final visible = SeedData.archiveAssets.where((asset) {
      final isInstalled = _installed[asset.assetId] ?? asset.isReadyByDefault;
      return _filter == 'all' ||
          (_filter == 'installed' && isInstalled) ||
          (_filter == 'pending' && !isInstalled);
    }).toList();
    return DetailCanvas(
      onBack: widget.onBack,
      title: '三维档案馆',
      subtitle: '${SeedData.archiveAssets.length} 个档案',
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: HorizontalPills(
              labels: <String, String>{
                'all': '全部 ${SeedData.archiveAssets.length}',
                'installed': '已下载 $installedCount',
                'pending':
                    '待下载 ${SeedData.archiveAssets.length - installedCount}',
              },
              selected: _filter,
              onSelected: (value) {
                widget.onHaptic();
                setState(() => _filter = value);
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            sliver: SliverList.separated(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final asset = visible[index];
                return ArchiveGalleryCard(
                  asset: asset,
                  installed:
                      _installed[asset.assetId] ?? asset.isReadyByDefault,
                  onOpenAsset: () => widget.onOpenAsset(asset),
                  onOpenArticle: () => widget.onOpenArticle(asset.contentRef),
                  onDelete: asset.delivery == ArchiveAssetDelivery.onDemand
                      ? () async {
                          await widget.repository.deleteArchiveAsset(asset);
                          await _refreshInstalled();
                        }
                      : null,
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class ArchiveDetailScreen extends StatefulWidget {
  const ArchiveDetailScreen({
    required this.asset,
    required this.repository,
    required this.onBack,
    required this.onOpenArticle,
    super.key,
  });

  final ArchiveAsset asset;
  final AnomiconRepository repository;
  final VoidCallback onBack;
  final VoidCallback onOpenArticle;

  @override
  State<ArchiveDetailScreen> createState() => _ArchiveDetailScreenState();
}

class _ArchiveDetailScreenState extends State<ArchiveDetailScreen> {
  File? _installedFile;
  ArchiveDownloadProgress? _progress;
  String? _error;
  var _downloading = false;
  var _autoRotate = true;

  @override
  void initState() {
    super.initState();
    _loadInstalled();
  }

  Future<void> _loadInstalled() async {
    final file = await widget.repository.installedArchiveAsset(widget.asset);
    if (!mounted) return;
    setState(() => _installedFile = file);
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _error = null;
      _progress = null;
    });
    try {
      final file = await widget.repository.downloadArchiveAsset(
        widget.asset,
        onProgress: (progress) => setState(() => _progress = progress),
      );
      if (!mounted) return;
      setState(() => _installedFile = file);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final installed = asset.isReadyByDefault || _installedFile != null;
    final modelSrc = asset.isReadyByDefault
        ? asset.resourcePath
        : _installedFile?.uri.toString() ?? asset.downloadUrl;
    return DetailCanvas(
      onBack: widget.onBack,
      title: '三维档案',
      subtitle: asset.title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: 430,
              child: installed
                  ? ModelViewer(
                      backgroundColor: _archiveBlue,
                      src: modelSrc,
                      alt: '${asset.title} GLB',
                      autoRotate: _autoRotate,
                      cameraControls: true,
                      disableZoom: false,
                    )
                  : RemoteArchivePlaceholder(
                      asset: asset,
                      progress: _progress,
                      downloading: _downloading,
                      error: _error,
                      onDownload: _download,
                    ),
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                FilledButton(
                  onPressed: installed
                      ? () => setState(() => _autoRotate = !_autoRotate)
                      : null,
                  child: Text(_autoRotate ? '停止旋转' : '自动旋转'),
                ),
                FilledButton(
                  onPressed: installed
                      ? () => setState(() => _autoRotate = true)
                      : null,
                  child: const Text('复位'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            '档案说明',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '对象等级 · ${asset.objectClass}',
                            style: const TextStyle(color: _muted, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _openExternal(asset.sourceUrl),
                      child: const Text('来源'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  asset.description,
                  style: const TextStyle(
                    color: Color(0xFFB9BEC3),
                    fontSize: 17,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 22),
                const Divider(color: Color(0xFF3F4448)),
                MetadataRow(label: '格式', value: 'GLB'),
                MetadataRow(label: '大小', value: formatBytes(asset.byteLength)),
                MetadataRow(label: '档案版本', value: asset.version),
                MetadataRow(
                  label: '交付方式',
                  value: asset.delivery == ArchiveAssetDelivery.bundled
                      ? '随应用内置'
                      : '按需下载',
                ),
                MetadataRow(label: '许可证', value: asset.license),
                MetadataRow(label: '归因', value: asset.attribution),
                const SizedBox(height: 12),
                Text(
                  asset.modificationNote,
                  style: const TextStyle(color: _muted, height: 1.45),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onOpenArticle,
                        child: const Text('打开条目'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openExternal(asset.contentSourceUrl),
                        child: const Text('英文来源'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.settings,
    required this.onBack,
    required this.onSettingsChange,
    required this.onHaptic,
    super.key,
  });

  final AppSettings settings;
  final VoidCallback onBack;
  final ValueChanged<AppSettings> onSettingsChange;
  final VoidCallback onHaptic;

  @override
  Widget build(BuildContext context) {
    return DetailCanvas(
      onBack: onBack,
      title: '设置',
      subtitle: '阅读与平台反馈',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 44),
        children: <Widget>[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '主题',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                HorizontalPills(
                  labels: const <String, String>{
                    'system': '跟随系统',
                    'light': '浅色',
                    'dark': '深色',
                  },
                  selected: settings.themeMode.name,
                  onSelected: (value) {
                    onHaptic();
                    onSettingsChange(
                      settings.copyWith(
                        themeMode: ThemeModePreference.values.firstWhere(
                          (item) => item.name == value,
                        ),
                      ),
                    );
                  },
                  horizontalPadding: 0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              children: <Widget>[
                SettingSwitchRow(
                  title: '触感反馈',
                  subtitle: '保留 HarmonyOS 版本中的触感开关语义。',
                  value: settings.hapticEnabled,
                  onChanged: (value) {
                    onHaptic();
                    onSettingsChange(settings.copyWith(hapticEnabled: value));
                  },
                ),
                const Divider(color: Color(0xFF3F4448)),
                SettingSwitchRow(
                  title: '沉浸材质',
                  subtitle: '保持黑底、半透明底栏和系统栏沉浸效果。',
                  value: settings.immersiveMaterialEnabled,
                  onChanged: (value) {
                    onHaptic();
                    onSettingsChange(
                      settings.copyWith(immersiveMaterialEnabled: value),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              children: <Widget>[
                SettingSliderRow(
                  title: '阅读字号',
                  valueLabel: '${settings.fontSize.round()}sp',
                  value: settings.fontSize,
                  min: ReadingSettingsRange.minFontSize,
                  max: ReadingSettingsRange.maxFontSize,
                  onChanged: (value) =>
                      onSettingsChange(settings.copyWith(fontSize: value)),
                ),
                const SizedBox(height: 18),
                SettingSliderRow(
                  title: '阅读行距',
                  valueLabel:
                      '${settings.lineHeightMultiple.toStringAsFixed(1)}x',
                  value: settings.lineHeightMultiple,
                  min: ReadingSettingsRange.minLineHeight,
                  max: ReadingSettingsRange.maxLineHeight,
                  onChanged: (value) => onSettingsChange(
                    settings.copyWith(lineHeightMultiple: value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PageCanvas extends StatelessWidget {
  const PageCanvas({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _black,
      child: SafeArea(bottom: false, child: child),
    );
  }
}

class DetailCanvas extends StatelessWidget {
  const DetailCanvas({
    required this.onBack,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const <Widget>[],
    super.key,
  });

  final VoidCallback onBack;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: <Widget>[
                  GlassIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    label: '返回',
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(color: _muted, fontSize: 18),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    this.subtitle,
    this.trailing,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: compact
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 30 : 28,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(color: _muted, fontSize: 17),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                color: _muted,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class GlassBottomBar extends StatelessWidget {
  const GlassBottomBar({
    required this.selectedTab,
    required this.onSelectTab,
    super.key,
  });

  final HomeTab selectedTab;
  final ValueChanged<HomeTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(44),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: math.min(MediaQuery.sizeOf(context).width - 72, 580),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: _surfaceHigh.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(44),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: HomeTab.values.map((tab) {
              final selected = tab == selectedTab;
              return InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => onSelectTab(tab),
                child: SizedBox(
                  width: 62,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        tab.icon,
                        size: 28,
                        color: selected ? _accent : _muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.title,
                        style: TextStyle(
                          color: selected ? _accent : _muted,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: _surfaceLow.withValues(alpha: 0.86),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 64,
            height: 64,
            child: Icon(icon, size: 34, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color = _surface,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }
}

class SearchPill extends StatelessWidget {
  const SearchPill({required this.hint, required this.onChanged, super.key});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF26282A),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 20),
        decoration: InputDecoration(
          icon: const Icon(Icons.search_rounded, color: _muted, size: 30),
          hintText: hint,
          hintStyle: const TextStyle(color: _muted),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class HorizontalPills extends StatelessWidget {
  const HorizontalPills({
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.horizontalPadding = 20,
    super.key,
  });

  final Map<String, String> labels;
  final String selected;
  final ValueChanged<String> onSelected;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        itemBuilder: (context, index) {
          final entry = labels.entries.elementAt(index);
          final active = entry.key == selected;
          return ChoiceChip(
            selected: active,
            showCheckmark: false,
            label: Text(entry.value),
            labelStyle: TextStyle(
              color: active ? Colors.white : const Color(0xFFC1C4C7),
              fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              fontSize: 18,
            ),
            selectedColor: _accent,
            backgroundColor: _surfaceLow,
            side: BorderSide(
              color: Colors.white.withValues(alpha: active ? 0 : 0.12),
            ),
            shape: const StadiumBorder(),
            onSelected: (_) => onSelected(entry.key),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 10),
      ),
    );
  }
}

class RecommendationHeroCard extends StatelessWidget {
  const RecommendationHeroCard({
    required this.entry,
    required this.onTap,
    super.key,
  });

  final ExploreEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          color: _surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: VisualPanel(
                  label: entry.normalizedId.toUpperCase(),
                  seed: entry.normalizedId,
                  icon: Icons.visibility_rounded,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.normalizedId.toUpperCase(),
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      entry.summary.isEmpty
                          ? '点击进入原生阅读，离线时优先显示本机缓存。'
                          : entry.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFB7BCC0),
                        fontSize: 20,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VisualPanel extends StatelessWidget {
  const VisualPanel({
    required this.label,
    required this.seed,
    this.icon = Icons.auto_awesome_rounded,
    super.key,
  });

  final String label;
  final String seed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForSeed(seed);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(painter: _SignalPainter(seed.hashCode)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 62,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RankedListCard extends StatelessWidget {
  const RankedListCard({
    required this.entries,
    required this.onOpenContent,
    super.key,
  });

  final List<ExploreEntry> entries;
  final ValueChanged<ExploreEntry> onOpenContent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: entries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Column(
              children: <Widget>[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 7,
                  ),
                  leading: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: _accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    item.normalizedId,
                    style: const TextStyle(color: _muted, fontSize: 15),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (item.score >= 0)
                        Text(
                          '+${_formatNumber(item.score)}',
                          style: const TextStyle(color: _muted, fontSize: 18),
                        ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: _muted,
                        size: 28,
                      ),
                    ],
                  ),
                  onTap: () => onOpenContent(item),
                ),
                if (index != entries.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 92, right: 24),
                    child: Divider(color: Color(0xFF3C4144), height: 1),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class ExploreStrip extends StatelessWidget {
  const ExploreStrip({
    required this.title,
    required this.items,
    required this.onOpenContent,
    super.key,
  });

  final String title;
  final List<ExploreContentItem> items;
  final ValueChanged<ContentRef> onOpenContent;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionTitle(title: title, compact: true),
          ),
          SizedBox(
            height: 178,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: items.take(12).length,
              itemBuilder: (context, index) {
                final item = items[index];
                return SizedBox(
                  width: 230,
                  child: GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: InkWell(
                      onTap: () => onOpenContent(item.contentRef),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.sourceLabel,
                            style: const TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            item.entry.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.entry.normalizedId,
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(width: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class CatalogTile extends StatelessWidget {
  const CatalogTile({required this.entry, required this.onTap, super.key});

  final CatalogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: _surface,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 5,
                child: VisualPanel(
                  label: entry.itemId,
                  seed: entry.itemId,
                  icon: entry.hasArchive3D
                      ? Icons.view_in_ar_rounded
                      : Icons.blur_on_rounded,
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.itemId,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          entry.description.isEmpty
                              ? '${entry.itemId} 档案条目，点击进入阅读。'
                              : entry.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 15,
                            height: 1.22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoryRow extends StatelessWidget {
  const StoryRow({required this.tale, required this.onTap, super.key});

  final TaleEntry tale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tale.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tale.id,
                      style: const TextStyle(color: _muted, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class ResearchProfileCard extends StatelessWidget {
  const ResearchProfileCard({
    required this.progress,
    required this.favoriteCount,
    required this.historyCount,
    super.key,
  });

  final ResearchProgress progress;
  final int favoriteCount;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _surfaceHigh,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text(
                      'LV',
                      style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${progress.level}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '档案阅历',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      progress.rankTitle.label,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '累计 ${progress.experience} XP',
                      style: const TextStyle(color: _muted, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                progress.levelExperienceTarget <= 0
                    ? '已达最高等级'
                    : '距 Lv.${progress.level + 1}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                progress.levelExperienceTarget <= 0
                    ? '等级上限'
                    : '${progress.levelExperience} / ${progress.levelExperienceTarget} XP',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress.levelProgressPercent,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: _surfaceHigh,
          ),
          const SizedBox(height: 26),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 126,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              ResearchStatTile(
                icon: Icons.schedule_rounded,
                value: formatDuration(progress.creditedActiveMs),
                label: '计分阅读',
              ),
              ResearchStatTile(
                icon: Icons.article_rounded,
                value: '${progress.researchedContentCount}',
                label: '已研读',
              ),
              ResearchStatTile(
                icon: Icons.star_rounded,
                value: '$favoriteCount',
                label: '收藏',
              ),
              ResearchStatTile(
                icon: Icons.inventory_2_rounded,
                value: '$historyCount',
                label: '记录',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF3F4448)),
          const SizedBox(height: 12),
          const HintRow(
            icon: Icons.access_time_filled_rounded,
            text: '有效阅读每分钟 1 XP；单篇累计满 1 分钟另计 8 XP，每日最多计分 180 分钟',
          ),
          const SizedBox(height: 10),
          const HintRow(icon: Icons.lock_rounded, text: '应用内阅读称号，不等同于基金会安保许可'),
        ],
      ),
    );
  }
}

class ResearchStatTile extends StatelessWidget {
  const ResearchStatTile({
    required this.icon,
    required this.value,
    required this.label,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: Colors.white70, size: 26),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class LibraryGroup extends StatelessWidget {
  const LibraryGroup({
    required this.title,
    required this.icon,
    required this.count,
    required this.child,
    super.key,
  });

  final String title;
  final IconData icon;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _surfaceLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: _accent, size: 30),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _surfaceLow,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class ReadingHistoryRow extends StatelessWidget {
  const ReadingHistoryRow({
    required this.entry,
    required this.onTap,
    super.key,
  });

  final ReadingHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = readingProgressPercent(entry);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      entry.content.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    progress > 0 ? '${(progress * 100).round()}%' : '开始阅读',
                    style: const TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: _surfaceHigh,
              ),
              const SizedBox(height: 8),
              Text(
                '${formatDuration(entry.activeMs)} · ${formatLastReadAt(entry.lastReadAt)}',
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContentRow extends StatelessWidget {
  const ContentRow({
    required this.content,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final ContentRef content;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: const Icon(Icons.info_outline_rounded, color: _muted),
        title: Text(
          content.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: _muted)),
        trailing:
            trailing ?? const Icon(Icons.chevron_right_rounded, color: _muted),
        onTap: onTap,
      ),
    );
  }
}

class ArticleBlockView extends StatelessWidget {
  const ArticleBlockView({
    required this.block,
    required this.settings,
    required this.repository,
    required this.onImageLoaded,
    super.key,
  });

  final ArticleBlock block;
  final AppSettings settings;
  final AnomiconRepository repository;
  final ValueChanged<File> onImageLoaded;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = TextStyle(
      fontSize: settings.fontSize,
      height: settings.lineHeightMultiple,
      color: const Color(0xFFE7E8EA),
      fontWeight: FontWeight.w500,
    );
    return switch (block) {
      ArticleHeading(:final text, :final level) => Padding(
        padding: EdgeInsets.only(top: level <= 2 ? 10 : 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: level == 1
                ? 30
                : level == 2
                ? 25
                : 21,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      ArticleParagraph(:final text) => Text(text, style: bodyStyle),
      ArticleQuote(:final text) => GlassCard(
        color: _surfaceLow,
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: bodyStyle.copyWith(color: const Color(0xFFC9CED2)),
        ),
      ),
      ArticleListBlock(:final items, :final ordered) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.indexed.map((entry) {
          final marker = ordered ? '${entry.$1 + 1}.' : '•';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('$marker ${entry.$2}', style: bodyStyle),
          );
        }).toList(),
      ),
      ArticleImage() => CachedArticleImage(
        image: block as ArticleImage,
        repository: repository,
        onImageLoaded: onImageLoaded,
      ),
      ArticleDivider() => const Divider(color: Color(0xFF3F4448)),
    };
  }
}

class CachedArticleImage extends StatefulWidget {
  const CachedArticleImage({
    required this.image,
    required this.repository,
    required this.onImageLoaded,
    super.key,
  });

  final ArticleImage image;
  final AnomiconRepository repository;
  final ValueChanged<File> onImageLoaded;

  @override
  State<CachedArticleImage> createState() => _CachedArticleImageState();
}

class _CachedArticleImageState extends State<CachedArticleImage> {
  late Future<File> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadImageFile(widget.image.url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final file = snapshot.data!;
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: GestureDetector(
              onTap: () => widget.onImageLoaded(file),
              child: Image.file(file, fit: BoxFit.cover),
            ),
          );
        }
        if (snapshot.hasError) {
          return Text(
            widget.image.alt.isEmpty ? '图片暂时不可用' : widget.image.alt,
            style: const TextStyle(color: _muted),
          );
        }
        return Container(
          height: 160,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const CircularProgressIndicator(),
        );
      },
    );
  }
}

class ImagePreviewDialog extends StatelessWidget {
  const ImagePreviewDialog({
    required this.file,
    required this.onDismiss,
    super.key,
  });

  final File file;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.82),
        child: Center(
          child: GestureDetector(
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ArticleError extends StatelessWidget {
  const ArticleError({
    required this.message,
    required this.onRetry,
    required this.onOpenOriginal,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.cloud_off_rounded, color: _muted, size: 48),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: _muted),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  FilledButton(onPressed: onRetry, child: const Text('重试')),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onOpenOriginal,
                    child: const Text('原文'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArchiveGalleryCard extends StatelessWidget {
  const ArchiveGalleryCard({
    required this.asset,
    required this.installed,
    required this.onOpenAsset,
    required this.onOpenArticle,
    this.onDelete,
    super.key,
  });

  final ArchiveAsset asset;
  final bool installed;
  final VoidCallback onOpenAsset;
  final VoidCallback onOpenArticle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpenAsset,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      asset.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  StatusPill(
                    text: asset.delivery == ArchiveAssetDelivery.bundled
                        ? '随应用内置'
                        : installed
                        ? '已下载'
                        : '待下载',
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _muted,
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                asset.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB6BAC0),
                  fontSize: 18,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Text(
                    asset.objectClass,
                    style: const TextStyle(color: _muted, fontSize: 18),
                  ),
                  const Spacer(),
                  Text(
                    'GLB  ${formatBytes(asset.byteLength)}',
                    style: const TextStyle(color: _muted, fontSize: 18),
                  ),
                ],
              ),
              if (onDelete != null && installed) ...<Widget>[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: onDelete,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFE1E1),
                      foregroundColor: const Color(0xFF9B2D2D),
                    ),
                    child: const Text('删除'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF315B9F),
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class RemoteArchivePlaceholder extends StatelessWidget {
  const RemoteArchivePlaceholder({
    required this.asset,
    required this.progress,
    required this.downloading,
    required this.error,
    required this.onDownload,
    super.key,
  });

  final ArchiveAsset asset;
  final ArchiveDownloadProgress? progress;
  final bool downloading;
  final String? error;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final fraction = progress?.fraction;
    return Container(
      color: _archiveBlue,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.cloud_download_rounded,
            size: 64,
            color: Colors.white70,
          ),
          const SizedBox(height: 16),
          Text(
            asset.title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            downloading
                ? progress == null
                      ? '正在准备下载...'
                      : '正在下载 ${formatDownloadProgress(progress!)}'
                : '按需下载后保存到应用私有缓存，并校验大小与 SHA-256。',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFC3C9D1),
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          if (downloading)
            LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              borderRadius: BorderRadius.circular(99),
            )
          else
            FilledButton.icon(
              onPressed: asset.downloadUrl.isEmpty ? null : onDownload,
              icon: const Icon(Icons.cloud_download_rounded),
              label: const Text('下载并查看'),
            ),
          if (error != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFA5A5)),
            ),
          ],
        ],
      ),
    );
  }
}

class MetadataRow extends StatelessWidget {
  const MetadataRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 17),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingSwitchRow extends StatelessWidget {
  const SettingSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, height: 1.35),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class SettingSliderRow extends StatelessWidget {
  const SettingSliderRow({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              valueLabel,
              style: const TextStyle(
                color: _accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: _surfaceLow,
      child: Column(
        children: <Widget>[
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 17),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class HintRow extends StatelessWidget {
  const HintRow({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, color: _muted, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _muted, fontSize: 16, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalPainter extends CustomPainter {
  const _SignalPainter(this.seed);

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.11);
    for (var i = 0; i < 12; i++) {
      final rect = Rect.fromCenter(
        center: Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        width: size.shortestSide * (0.28 + random.nextDouble() * 0.5),
        height: size.shortestSide * (0.18 + random.nextDouble() * 0.42),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(18 + random.nextDouble() * 28),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SignalPainter oldDelegate) =>
      oldDelegate.seed != seed;
}

List<Color> _colorsForSeed(String seed) {
  final hash = seed.codeUnits.fold<int>(0, (value, item) => value + item);
  final palettes = <List<Color>>[
    const <Color>[Color(0xFF24324B), Color(0xFF1F2529)],
    const <Color>[Color(0xFF3A2F26), Color(0xFF1D2224)],
    const <Color>[Color(0xFF1C3B35), Color(0xFF1B2023)],
    const <Color>[Color(0xFF39293E), Color(0xFF202328)],
    const <Color>[Color(0xFF40242C), Color(0xFF1C2227)],
  ];
  return palettes[hash % palettes.length];
}

String formatDuration(int activeMs) {
  final minutes = activeMs ~/ researchMinuteMs;
  if (minutes <= 0 && activeMs > 0) return '不足 1 分钟';
  if (minutes < 60) return '$minutes 分钟';
  return '${minutes ~/ 60} 小时 ${minutes % 60} 分钟';
}

String formatLastReadAt(int timestamp) {
  if (timestamp <= 0) return '尚无时间记录';
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.year}-$month-$day $hour:$minute';
}

String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatDownloadProgress(ArchiveDownloadProgress progress) {
  final fraction = progress.fraction;
  if (fraction == null) {
    return formatBytes(progress.downloadedBytes);
  }
  return '${(fraction * 100).round()}% · ${formatBytes(progress.downloadedBytes)} / ${formatBytes(progress.totalBytes)}';
}

String _formatNumber(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final remaining = raw.length - i;
    buffer.write(raw[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

Future<void> _openExternal(String url) async {
  if (url.trim().isEmpty) return;
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
