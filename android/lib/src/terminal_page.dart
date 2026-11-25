part of 'anomicon_app.dart';

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
