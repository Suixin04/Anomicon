part of 'anomicon_app.dart';

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
