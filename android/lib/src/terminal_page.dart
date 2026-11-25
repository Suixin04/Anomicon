part of 'anomicon_app.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({
    required this.library,
    required this.onOpenContent,
    required this.onToggleFavorite,
    required this.onOpenSettings,
    this.foundationStore,
    this.onOpenOffline,
    this.onOpenArchiveGallery,
    super.key,
  });

  final LibrarySnapshot library;
  final ValueChanged<ContentRef> onOpenContent;
  final ValueChanged<ContentRef> onToggleFavorite;
  final VoidCallback onOpenSettings;
  final FoundationStore? foundationStore;
  final VoidCallback? onOpenOffline;
  final VoidCallback? onOpenArchiveGallery;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  Timer? _midnight;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _scheduleMidnight();
    _lifecycle = AppLifecycleListener(onResume: _refreshDay);
  }

  void _scheduleMidnight() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight?.cancel();
    _midnight = Timer(next.difference(now), _refreshDay);
  }

  void _refreshDay() {
    _scheduleMidnight();
    setState(() {});
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.foundationStore;
    return store == null
        ? _body(context)
        : ListenableBuilder(
            listenable: store,
            builder: (context, _) => _body(context),
          );
  }

  Widget _body(BuildContext context) {
    final now = DateTime.now();
    final colors = Theme.of(context).colorScheme;
    final progress = deriveResearchProgress(
      widget.library.activitySegments,
      now: now.millisecondsSinceEpoch,
      assessmentXp: widget.foundationStore?.bonusXp ?? 0,
    );
    final seen = <String>{};
    final history = widget.library.history
        .where((entry) => seen.add(entry.content.key))
        .toList();
    final resumable = history
        .where(
          (item) => item.scrollOffset > 0 && readingProgressPercent(item) < 1,
        )
        .toList();
    final resumeEntry = resumable.firstOrNull;
    final recentEntries = history
        .where((item) => item.content.key != resumeEntry?.content.key)
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
                onPressed: widget.onOpenSettings,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: ResearchProfileCard(
                progress: progress,
                favoriteCount: widget.library.favorites.length,
                historyCount: history.length,
                stamps: widget.foundationStore?.stamps.toList() ?? const [],
                now: now,
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
          if (widget.onOpenOffline != null ||
              widget.onOpenArchiveGallery != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  children: [
                    if (widget.onOpenOffline != null)
                      ListTile(
                        leading: const Icon(Icons.offline_pin_outlined),
                        title: const Text('离线书架'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: widget.onOpenOffline,
                      ),
                    if (widget.onOpenArchiveGallery != null)
                      ListTile(
                        leading: const Icon(Icons.view_in_ar_outlined),
                        title: const Text('三维档案馆'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: widget.onOpenArchiveGallery,
                      ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: LibraryGroup(
              title: '继续阅读',
              icon: Icons.play_arrow_rounded,
              count: resumable.length,
              child: resumeEntry == null
                  ? const EmptyCard(title: '暂无可继续的条目。')
                  : Column(
                      children: [
                        ReadingHistoryRow(
                          entry: resumeEntry,
                          onTap: () =>
                              widget.onOpenContent(resumeEntry.content),
                        ),
                        if (resumable.length > 1)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  _openResumable(context, resumable),
                              child: const Text('全部续读'),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: LibraryGroup(
              title: '收藏',
              icon: Icons.star_rounded,
              count: widget.library.favorites.length,
              child: widget.library.favorites.isEmpty
                  ? const EmptyCard(title: '还没有收藏。')
                  : Column(
                      children: widget.library.favorites
                          .map(
                            (content) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ContentRow(
                                content: content,
                                subtitle: content.id,
                                trailing: IconButton(
                                  onPressed: () =>
                                      widget.onToggleFavorite(content),
                                  icon: Icon(
                                    Icons.star_rounded,
                                    color: colors.primary,
                                  ),
                                ),
                                onTap: () => widget.onOpenContent(content),
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
                                onTap: () =>
                                    widget.onOpenContent(entry.content),
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

  void _openResumable(BuildContext context, List<ReadingHistoryEntry> entries) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('全部续读', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ReadingHistoryRow(
                  entry: entry,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onOpenContent(entry.content);
                  },
                ),
              ),
          ],
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
    required this.stamps,
    required this.now,
    super.key,
  });

  final ResearchProgress progress;
  final int favoriteCount;
  final int historyCount;
  final List<FoundationExam> stamps;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dayTotals = {
      for (final day in progress.daily) dayKey(day.day): day.activeMs,
    };
    final days = List.generate(
      7,
      (index) => DateTime(now.year, now.month, now.day - 6 + index),
    );
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
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'LV',
                      style: TextStyle(
                        color: colors.primary,
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
                    Text(
                      '档案阅历',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
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
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 18,
                      ),
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
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                progress.levelExperienceTarget <= 0
                    ? '等级上限'
                    : '${progress.levelExperience} / ${progress.levelExperienceTarget} XP',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
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
            backgroundColor: colors.surfaceContainerHighest,
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
          Text('今日计分阅读 ${formatDuration(progress.todayActiveMs)} / 180 分钟'),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value:
                              (dayTotals[dayKey(day)] ?? 0) /
                              researchDailyCapMs,
                          semanticsLabel:
                              '${day.month}/${day.day} ${formatDuration(dayTotals[dayKey(day)] ?? 0)}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.month}/${day.day}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (stamps.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('基金会印章'),
            Wrap(
              spacing: 6,
              children: [
                for (final exam in stamps) Chip(label: Text(exam.stamp)),
              ],
            ),
          ],
          const Divider(),
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: colors.onSurfaceVariant, size: 26),
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
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
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
    final colors = Theme.of(context).colorScheme;
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
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: colors.primary, size: 30),
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
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
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
    final colors = Theme.of(context).colorScheme;
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
                    style: TextStyle(
                      color: colors.primary,
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
                backgroundColor: colors.surfaceContainerHighest,
              ),
              const SizedBox(height: 8),
              Text(
                '${formatDuration(entry.activeMs)} · ${formatLastReadAt(entry.lastReadAt)}',
                style: TextStyle(color: colors.onSurfaceVariant),
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
    final colors = Theme.of(context).colorScheme;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(
          Icons.info_outline_rounded,
          color: colors.onSurfaceVariant,
        ),
        title: Text(
          content.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        trailing:
            trailing ??
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
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
