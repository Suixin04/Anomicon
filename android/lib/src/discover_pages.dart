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
              SliverToBoxAdapter(
                child: _StarterGuide(onOpen: widget.onOpenContent),
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
                  height: 410,
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
                  title: '最近新增',
                  items: data.recent,
                  onOpenContent: widget.onOpenContent,
                ),
              ),
              SliverToBoxAdapter(
                child: ExploreStrip(
                  title: '每日轮换',
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
                      sliver: SliverGrid.builder(
                        itemCount: entries.length,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 285,
                              mainAxisExtent: 292,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                        itemBuilder: (context, index) => CatalogTile(
                          entry: entries[index],
                          onTap: () =>
                              widget.onOpenContent(entries[index].contentRef),
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
          color: Theme.of(context).colorScheme.surfaceContainer,
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
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
    required this.entry,
    required this.onTap,
    this.isRead = false,
    super.key,
  });

  final CatalogEntry entry;
  final VoidCallback onTap;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
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
                        isRead ? '${entry.itemId} · 已读' : entry.itemId,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
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
