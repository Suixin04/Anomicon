part of 'anomicon_app.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    required this.repository,
    required this.onOpenContent,
    this.onOpenSearch,
    super.key,
  });

  final AnomiconRepository repository;
  final ValueChanged<ContentRef> onOpenContent;
  final VoidCallback? onOpenSearch;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late Future<DiscoveryExplore> _future;
  int _round = 0;
  int _recommendationIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = DiscoveryRepository.of(widget.repository).explore();
  }

  void _refresh() {
    setState(() {
      _round++;
      _recommendationIndex = 0;
      _future = DiscoveryRepository.of(widget.repository)
          .explore(force: true, round: _round);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DiscoveryExplore>(
      future: _future,
      builder: (context, snapshot) {
        final data =
            snapshot.data?.data ??
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GlassIconButton(
                        icon: Icons.search_rounded,
                        label: '搜索',
                        onPressed: () {
                          final launch = widget.onOpenSearch;
                          if (launch == null) {
                            _openDiscoverySearch(
                              context,
                              widget.repository,
                              widget.onOpenContent,
                            );
                          } else {
                            launch();
                          }
                        },
                      ),
                      GlassIconButton(
                        icon: Icons.refresh_rounded,
                        label: '刷新',
                        onPressed: _refresh,
                      ),
                    ],
                  ),
                ),
              ),
              if (snapshot.hasError || snapshot.data?.hasSourceFailure == true)
                SliverToBoxAdapter(
                  child: _DiscoveryNotice(
                    text: '部分来源未更新，已保留可用内容',
                    action: _refresh,
                  ),
                ),
              SliverToBoxAdapter(
                child: SectionTitle(
                  title: '今日推荐',
                  subtitle: '主站译文与中文原创',
                  trailing:
                      '${math.min(_recommendationIndex + 1, data.recommendations.length)} / ${data.recommendations.length}',
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 330,
                  child: PageView.builder(
                    key: ValueKey(_round),
                    itemCount: data.recommendations.length,
                    onPageChanged: (index) =>
                        setState(() => _recommendationIndex = index),
                    itemBuilder: (context, index) {
                      final entry = data.recommendations[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: RecommendationHeroCard(
                          repository: widget.repository,
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
                child: _StarterGuide(onOpen: widget.onOpenContent),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: SectionTitle(
                          title: '热门原创',
                          subtitle: 'SCP 中文主站高分内容',
                          compact: true,
                        ),
                      ),
                      if (data.topRated.isNotEmpty)
                        TextButton(
                          onPressed: () => _openExploreCollection(
                            context,
                            '热门原创',
                            data.topRated
                                .map(
                                  (entry) => ExploreContentItem(
                                    entry,
                                    ContentKind.wiki,
                                    '热门原创',
                                  ),
                                )
                                .toList(),
                            widget.onOpenContent,
                          ),
                          child: const Text('查看全部'),
                        ),
                    ],
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
                  title: '轻松一下',
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
    this.onOpenSearch,
    this.isRead,
    super.key,
  });
  final AnomiconRepository repository;
  final ValueChanged<ContentRef> onOpenContent;
  final VoidCallback onOpenArchiveGallery;
  final VoidCallback onHaptic;
  final bool Function(String)? isRead;
  final ValueChanged<String>? onOpenSearch;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  var _series = scpSeriesDescriptors.first;
  late var _future = _repository.catalog(_series);
  int _revision = 0;
  DiscoveryRepository get _repository =>
      DiscoveryRepository.of(widget.repository);
  bool get _original => originalSeries.contains(_series);

  void _select(CatalogSeriesDescriptor series, {bool force = false}) {
    widget.onHaptic();
    setState(() {
      _series = series;
      _future = _repository.catalog(series, force: force);
      _revision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final series = _original ? originalSeries : scpSeriesDescriptors;
    return PageCanvas(
      child: Column(
        children: [
          PageHeading(
            title: '图鉴',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassIconButton(
                  icon: Icons.search_rounded,
                  label: '搜索',
                  onPressed: () {
                    final launch = widget.onOpenSearch;
                    if (launch != null) {
                      launch(_series.id);
                    } else {
                      _openDiscoverySearch(
                        context,
                        widget.repository,
                        widget.onOpenContent,
                        _series.id,
                      );
                    }
                  },
                ),
                GlassIconButton(
                  icon: Icons.view_in_ar_outlined,
                  label: '三维档案馆',
                  onPressed: widget.onOpenArchiveGallery,
                ),
              ],
            ),
          ),
          HorizontalPills(
            labels: const {'main': '主站译文', 'cn': '中文原创'},
            selected: _original ? 'cn' : 'main',
            onSelected: (branch) {
              if ((branch == 'cn') != _original) {
                _select(
                  branch == 'cn'
                      ? originalSeries.first
                      : scpSeriesDescriptors.first,
                );
              }
            },
          ),
          HorizontalPills(
            labels: {for (final item in series) item.id: item.label},
            selected: _series.id,
            onSelected: (id) {
              if (id != _series.id) {
                _select(series.firstWhere((item) => item.id == id));
              }
            },
          ),
          Expanded(
            child: FutureBuilder<DiscoverySnapshot<CatalogEntry>>(
              key: ValueKey(_revision),
              future: _future,
              builder: (context, snapshot) {
                final data = snapshot.data;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = data?.entries ?? [];
                return CustomScrollView(
                  slivers: [
                    if (snapshot.hasError || data?.failed == true)
                      SliverToBoxAdapter(
                        child: _DiscoveryNotice(
                          text: entries.isEmpty
                              ? '目录暂时无法加载'
                              : '网络更新失败，正在显示已缓存的目录',
                          action: () => _select(_series, force: true),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 124),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) =>
                            SliverMasonryGrid.count(
                              crossAxisCount:
                                  switch (constraints.crossAxisExtent + 40) {
                                    >= 1440 => 5,
                                    >= 840 => 4,
                                    >= 600 => 3,
                                    _ => 2,
                                  },
                              childCount: entries.length,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                return CatalogTile(
                                  key: ValueKey(entry.itemId),
                                  repository: widget.repository,
                                  entry: entry,
                                  isRead:
                                      widget.isRead?.call(
                                        entry.contentRef.id,
                                      ) ??
                                      false,
                                  onTap: () =>
                                      widget.onOpenContent(entry.contentRef),
                                );
                              },
                            ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openDiscoverySearch(
  BuildContext context,
  AnomiconRepository repository,
  ValueChanged<ContentRef> open, [
  String? series,
]) async {
  final result = await Navigator.of(context).push<ContentRef>(
    MaterialPageRoute(
      builder: (context) => DiscoverySearchScreen(
        repository: repository,
        initialSeriesId: series,
        onOpenContent: (content) => Navigator.of(context).pop(content),
      ),
    ),
  );
  if (result != null && context.mounted) open(result);
}

class DiscoverySearchScreen extends StatefulWidget {
  const DiscoverySearchScreen({
    required this.repository,
    required this.onOpenContent,
    this.initialSeriesId,
    this.onBack,
    super.key,
  });
  final AnomiconRepository repository;
  final ValueChanged<ContentRef> onOpenContent;
  final String? initialSeriesId;
  final VoidCallback? onBack;

  @override
  State<DiscoverySearchScreen> createState() => _DiscoverySearchScreenState();
}

class _DiscoverySearchScreenState extends State<DiscoverySearchScreen> {
  late String? _scope = widget.initialSeriesId;
  final _input = TextEditingController();
  final _catalogs = <String, DiscoverySnapshot<CatalogEntry>>{};
  List<DiscoverySnapshot<TaleEntry>> _taleSources = [];
  List<String> _history = [];
  int _epoch = 0;
  bool _loading = false;
  bool _error = false;
  var _randomSalt = 0;
  DiscoveryRepository get _repository =>
      DiscoveryRepository.of(widget.repository);
  List<CatalogSeriesDescriptor> get _series => _scope == null
      ? discoverySeries
      : discoverySeries.where((series) => series.id == _scope).toList();

  @override
  void initState() {
    super.initState();
    DiscoveryHistory.revision.addListener(_readHistory);
    _readHistory();
    _load();
  }

  @override
  void dispose() {
    DiscoveryHistory.revision.removeListener(_readHistory);
    _input.dispose();
    super.dispose();
  }

  Future<void> _readHistory() async {
    final items = await DiscoveryHistory.load();
    if (mounted) setState(() => _history = items);
  }

  Future<void> _load({bool retry = false}) async {
    final epoch = ++_epoch;
    final series = _series;
    final all = _scope == null;
    setState(() {
      _loading = true;
      _error = false;
    });
    bool active() => mounted && _epoch == epoch;
    try {
      final cached = await Future.wait(series.map(_repository.cachedCatalog));
      if (!active()) return;
      setState(() {
        for (var index = 0; index < series.length; index++) {
          if (cached[index].entries.isNotEmpty) {
            _catalogs[series[index].id] ??= cached[index];
          }
        }
      });
      final queue = series
          .where((item) => !retry || _catalogs[item.id]?.failed != false)
          .toList();
      int next = 0;
      Future<void> worker() async {
        while (active() && next < queue.length) {
          final item = queue[next++];
          final data = await _repository.catalog(item, force: retry);
          if (active()) setState(() => _catalogs[item.id] = data);
        }
      }

      await Future.wait([
        for (var i = 0; i < math.min(3, queue.length); i++) worker(),
        if (all)
          _repository.taleSources(force: retry).then((sources) {
            if (active()) setState(() => _taleSources = sources);
          }),
      ]);
    } on Exception {
      if (active()) setState(() => _error = true);
    } finally {
      if (active()) setState(() => _loading = false);
    }
  }

  Future<void> _remember(String query) async {
    try {
      await DiscoveryHistory.remember(query);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('搜索历史保存失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _input.text.trim();
    final entries = [
      for (final item in _series)
        for (final entry
            in _catalogs[item.id]?.entries ?? const <CatalogEntry>[])
          entry.contentRef,
      if (_scope == null)
        for (final tale in _repository.mergeTales(_taleSources))
          tale.contentRef,
    ];
    final covered = _series
        .where((item) => _catalogs[item.id]?.entries.isNotEmpty == true)
        .length;
    final partial =
        _error ||
        covered < _series.length ||
        _series.any((item) => _catalogs[item.id]?.failed == true) ||
        _scope == null &&
            (_taleSources.length < 2 ||
                _taleSources.any((source) => source.failed));
    final matches = query.isEmpty
        ? dailyDiscoveryOrder(
            entries.isEmpty
                ? SeedData.fallbackCatalog.map((item) => item.contentRef)
                : entries,
            'search:$_randomSalt',
          ).take(6).toList()
        : discoveryMatches(entries, query);
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        leading: BackButton(onPressed: widget.onBack),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _input,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: _remember,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜索编号、标题或路径',
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除查询',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_input.clear),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String?>(
              value: _scope,
              hint: const Text('全部系列（含故事）'),
              isExpanded: true,
              onChanged: (value) {
                setState(() => _scope = value);
                _load();
              },
              items: [
                const DropdownMenuItem(value: null, child: Text('全部系列（含故事）')),
                for (final item in discoverySeries)
                  DropdownMenuItem(value: item.id, child: Text(item.label)),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (partial)
            _DiscoveryNotice(
              text:
                  '已覆盖 $covered / ${_series.length} 个系列${_scope == null ? '，另查故事' : ''}',
              action: _loading ? null : () => _load(retry: true),
              actionLabel: '补查',
            ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (query.isEmpty && _history.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('历史搜索'),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final term in _history)
                                ActionChip(
                                  label: Text(term),
                                  onPressed: () =>
                                      setState(() => _input.text = term),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (query.isEmpty)
                  SliverToBoxAdapter(
                    child: ListTile(
                      title: const Text('随机发现'),
                      trailing: IconButton(
                        tooltip: '换一批',
                        icon: const Icon(Icons.shuffle),
                        onPressed: () => setState(() => _randomSalt++),
                      ),
                    ),
                  ),
                if (query.isNotEmpty && matches.isEmpty)
                  SliverToBoxAdapter(
                    child: _DiscoveryNotice(
                      text: _loading ? '正在检索目录' : '当前范围内无匹配条目',
                    ),
                  ),
                SliverList.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final item = matches[index];
                    return ListTile(
                      title: Text(item.title),
                      subtitle: Text(item.id),
                      leading: Icon(
                        item.kind == ContentKind.tale
                            ? Icons.description_outlined
                            : Icons.article_outlined,
                      ),
                      onTap: () {
                        if (query.isNotEmpty) _remember(query);
                        widget.onOpenContent(item);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryNotice extends StatelessWidget {
  const _DiscoveryNotice({
    required this.text,
    this.action,
    this.actionLabel = '重试',
  });
  final String text;
  final VoidCallback? action;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(text),
    trailing: action == null
        ? null
        : TextButton(onPressed: action, child: Text(actionLabel)),
  );
}

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({
    required this.repository,
    required this.onOpenContent,
    required this.onHaptic,
    this.isRead,
    super.key,
  });

  final AnomiconRepository repository;
  final ValueChanged<ContentRef> onOpenContent;
  final VoidCallback onHaptic;
  final bool Function(String)? isRead;

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
  late Future<List<DiscoverySnapshot<TaleEntry>>> _future;
  final _search = TextEditingController();
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _future = DiscoveryRepository.of(widget.repository).taleSources();
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageCanvas(
      child: FutureBuilder<List<DiscoverySnapshot<TaleEntry>>>(
        future: _future,
        builder: (context, snapshot) {
          final repository = DiscoveryRepository.of(widget.repository);
          final tales = repository.mergeTales(snapshot.data ?? []);
          final unavailable =
              snapshot.data?.any((source) => source.failed) ?? false;
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
                    controller: _search,
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
              if (snapshot.hasError || unavailable)
                SliverToBoxAdapter(
                  child: _DiscoveryNotice(
                    text: tales.isEmpty ? '故事目录暂时无法加载' : '部分故事来源未更新，保留已缓存的目录',
                    action: () => setState(
                      () => _future = repository.taleSources(force: true),
                    ),
                  ),
                ),
              if (_query.trim().isEmpty && _selectedLetter.isEmpty)
                SliverToBoxAdapter(
                  child: _StorySeriesCard(
                    onOpen: widget.onOpenContent,
                    isRead: widget.isRead ?? (_) => false,
                  ),
                ),
              if (filtered.isEmpty &&
                  !unavailable &&
                  snapshot.connectionState == ConnectionState.done)
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
                          _search.clear();
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
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) => SliverMasonryGrid.count(
                      crossAxisCount: constraints.crossAxisExtent >= 560
                          ? 2
                          : 1,
                      childCount: filtered.length,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 12,
                      itemBuilder: (context, index) => StoryRow(
                        tale: filtered[index],
                        onTap: () =>
                            widget.onOpenContent(filtered[index].contentRef),
                      ),
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

class _StarterGuide extends StatefulWidget {
  const _StarterGuide({required this.onOpen});
  final ValueChanged<ContentRef> onOpen;

  @override
  State<_StarterGuide> createState() => _StarterGuideState();
}

class _StarterGuideState extends State<_StarterGuide> {
  late final _dismissed = DiscoveryHistory.starterDismissed();
  bool _hidden = false;

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _dismissed,
    builder: (context, snapshot) {
      if (_hidden || snapshot.data != false) return const SizedBox.shrink();
      return Card(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: ListTile(
          title: const Text('入门指引'),
          subtitle: Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => widget.onOpen(
                  ContentRef.create(
                    ContentKind.wiki,
                    'about-the-scp-foundation',
                    '关于 SCP 基金会',
                  ),
                ),
                child: const Text('基金会手册'),
              ),
              TextButton(
                onPressed: () => widget.onOpen(_antimemeticsHub),
                child: const Text('精选系列'),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: '关闭入门指引',
            onPressed: () async {
              await DiscoveryHistory.dismissStarter();
              if (mounted) setState(() => _hidden = true);
            },
          ),
        ),
      );
    },
  );
}

final _antimemeticsHub = ContentRef.create(
  ContentKind.tale,
  'antimemetics-division-hub',
  '逆模因部',
);

class _StorySeriesCard extends StatelessWidget {
  const _StorySeriesCard({required this.onOpen, required this.isRead});
  final ValueChanged<ContentRef> onOpen;
  final bool Function(String) isRead;

  @override
  Widget build(BuildContext context) {
    final next = nextAntimemeticsChapter(isRead);
    final completed = antimemeticsGroups
        .where((group) => group.$2)
        .expand((group) => group.$3)
        .where((chapter) => isRead(chapter.$1))
        .length;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ListTile(
        title: const Text('逆模因部'),
        subtitle: Text('主线已读 $completed / 19'),
        onTap: () async {
          final selection = await Navigator.of(context).push<ContentRef>(
            MaterialPageRoute(
              builder: (context) => DiscoverySeriesScreen(
                isRead: isRead,
                onOpenContent: (chapter) => Navigator.of(context).pop(chapter),
              ),
            ),
          );
          if (selection != null && context.mounted) onOpen(selection);
        },
        trailing: next == null
            ? null
            : TextButton(
                onPressed: () => onOpen(next),
                child: Text(completed == 0 ? '开始阅读' : '继续阅读'),
              ),
      ),
    );
  }
}

class DiscoverySeriesScreen extends StatelessWidget {
  const DiscoverySeriesScreen({
    required this.onOpenContent,
    required this.isRead,
    super.key,
  });
  final ValueChanged<ContentRef> onOpenContent;
  final bool Function(String) isRead;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('逆模因部')),
    body: ListView(
      children: [
        ListTile(
          title: const Text('浏览原站导读'),
          onTap: () => onOpenContent(_antimemeticsHub),
        ),
        for (final (title, _, chapters) in antimemeticsGroups)
          ExpansionTile(
            title: Text(title),
            children: [
              for (final (id, name) in chapters)
                ListTile(
                  title: Text(name),
                  leading: Icon(
                    isRead(id) ? Icons.check_circle : Icons.article_outlined,
                  ),
                  onTap: () => onOpenContent(discoveryContent(id, name)),
                ),
            ],
          ),
      ],
    ),
  );
}

class SearchPill extends StatelessWidget {
  const SearchPill({
    required this.hint,
    required this.onChanged,
    this.controller,
    super.key,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 20,
        ),
        decoration: InputDecoration(
          icon: Icon(
            Icons.search_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 30,
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class RecommendationHeroCard extends StatelessWidget {
  const RecommendationHeroCard({
    required this.repository,
    required this.entry,
    required this.onTap,
    super.key,
  });
  final AnomiconRepository repository;
  final ExploreEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = entry.normalizedId.toUpperCase();
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _WikiPreviewImage(
                repository: repository,
                content: ContentRef.create(
                  ContentKind.scp,
                  entry.normalizedId,
                  entry.title,
                ),
                cover: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (entry.title.toUpperCase() != id)
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                  if (entry.summary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      entry.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (item.score >= 0)
                        Text(
                          '+${_formatNumber(item.score)}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 18,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                    ],
                  ),
                  onTap: () => onOpenContent(item),
                ),
                if (index != entries.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 92, right: 24),
                    child: Divider(height: 1),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

Future<void> _openExploreCollection(
  BuildContext context,
  String title,
  List<ExploreContentItem> items,
  ValueChanged<ContentRef> onOpen,
) async {
  final selected = await Navigator.of(context).push<ContentRef>(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final entry = item.entry;
            return ListTile(
              title: Text(entry.title),
              subtitle: Text(entry.normalizedId),
              onTap: () => Navigator.of(context).pop(item.contentRef),
            );
          },
        ),
      ),
    ),
  );
  if (selected != null && context.mounted) onOpen(selected);
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
            child: Row(
              children: [
                Expanded(child: SectionTitle(title: title, compact: true)),
                TextButton(
                  onPressed: () => _openExploreCollection(
                    context,
                    title,
                    items,
                    onOpenContent,
                  ),
                  child: const Text('查看全部'),
                ),
              ],
            ),
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
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
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
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
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
  const CatalogTile({
    required this.repository,
    required this.entry,
    required this.onTap,
    required this.isRead,
    super.key,
  });

  final AnomiconRepository repository;
  final CatalogEntry entry;
  final VoidCallback onTap;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WikiPreviewImage(
              repository: repository,
              content: entry.contentRef,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isRead ? '${entry.itemId} · 已读' : entry.itemId,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (entry.hasArchive3D)
                        const Icon(Icons.view_in_ar_rounded, size: 16),
                    ],
                  ),
                  if (entry.displayTitle != entry.itemId) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.displayTitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                  if (entry.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WikiPreviewImage extends StatelessWidget {
  const _WikiPreviewImage({
    required this.repository,
    required this.content,
    this.cover = false,
  });
  final AnomiconRepository repository;
  final ContentRef content;
  final bool cover;

  @override
  Widget build(BuildContext context) => FutureBuilder<File?>(
    future: repository.loadPreviewImage(content),
    builder: (context, snapshot) {
      final image = snapshot.data;
      final fallback = cover
          ? Center(
              child: Text(
                snapshot.connectionState == ConnectionState.waiting
                    ? '正在加载预览图'
                    : '暂无预览图',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          : const SizedBox.shrink();
      if (image == null) return fallback;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: Image.file(
          image,
          width: double.infinity,
          cacheWidth: cover ? 960 : 640,
          fit: cover ? BoxFit.cover : BoxFit.contain,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
      );
    },
  );
}

class StoryRow extends StatelessWidget {
  const StoryRow({required this.tale, required this.onTap, super.key});

  final TaleEntry tale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
