import 'dart:math' as math;

const wikiBaseUrl = 'https://scp-wiki-cn.wikidot.com';

enum ContentKind { scp, tale, wiki, knowledge }

extension ContentKindLabel on ContentKind {
  String get label => switch (this) {
    ContentKind.scp => 'SCP',
    ContentKind.tale => '故事',
    ContentKind.wiki => '页面',
    ContentKind.knowledge => '知识',
  };
}

enum ThemeModePreference { system, light, dark }

enum ArchiveAssetSource { bundled, remote }

enum ArchiveAssetDelivery { bundled, onDemand }

enum ExploreSource {
  topRated('$wikiBaseUrl/top-rated-pages', '高评分'),
  recentTranslated('$wikiBaseUrl/most-recently-created-translated', '近期翻译'),
  recentOriginal('$wikiBaseUrl/most-recently-created-cn', '近期原创'),
  jokeScps('$wikiBaseUrl/joke-scps', '搞笑 SCP'),
  jokeTales('$wikiBaseUrl/joke-scps-tales-edition', '搞笑故事');

  const ExploreSource(this.url, this.label);

  final String url;
  final String label;
}

class ReadingSettingsRange {
  static const minFontSize = 14.0;
  static const defaultFontSize = 18.0;
  static const maxFontSize = 22.0;
  static const minLineHeight = 1.2;
  static const defaultLineHeight = 1.6;
  static const maxLineHeight = 2.0;
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeModePreference.system,
    this.hapticEnabled = true,
    this.immersiveMaterialEnabled = true,
    this.fontSize = ReadingSettingsRange.defaultFontSize,
    this.lineHeightMultiple = ReadingSettingsRange.defaultLineHeight,
  });

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    themeMode: _themeModeFromName(json['themeMode'] as String?),
    hapticEnabled: json['hapticEnabled'] as bool? ?? true,
    immersiveMaterialEnabled: json['immersiveMaterialEnabled'] as bool? ?? true,
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? ReadingSettingsRange.defaultFontSize,
    lineHeightMultiple:
        (json['lineHeightMultiple'] as num?)?.toDouble() ?? ReadingSettingsRange.defaultLineHeight,
  ).normalized();

  final ThemeModePreference themeMode;
  final bool hapticEnabled;
  final bool immersiveMaterialEnabled;
  final double fontSize;
  final double lineHeightMultiple;

  AppSettings copyWith({
    ThemeModePreference? themeMode,
    bool? hapticEnabled,
    bool? immersiveMaterialEnabled,
    double? fontSize,
    double? lineHeightMultiple,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    hapticEnabled: hapticEnabled ?? this.hapticEnabled,
    immersiveMaterialEnabled: immersiveMaterialEnabled ?? this.immersiveMaterialEnabled,
    fontSize: fontSize ?? this.fontSize,
    lineHeightMultiple: lineHeightMultiple ?? this.lineHeightMultiple,
  );

  AppSettings normalized() => copyWith(
    fontSize: normalizeFontSize(fontSize),
    lineHeightMultiple: normalizeLineHeight(lineHeightMultiple),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'themeMode': themeMode.name,
    'hapticEnabled': hapticEnabled,
    'immersiveMaterialEnabled': immersiveMaterialEnabled,
    'fontSize': fontSize,
    'lineHeightMultiple': lineHeightMultiple,
  };
}

class ContentRef {
  ContentRef._({
    required this.kind,
    required this.id,
    required this.title,
  }) : key = 'main:${normalizeContentId(id)}';

  factory ContentRef.create(ContentKind kind, String id, String title) {
    final normalizedId = normalizeContentId(id);
    final resolvedTitle = title.trim().isEmpty ? normalizedId.toUpperCase() : title.trim();
    return ContentRef._(kind: kind, id: normalizedId, title: resolvedTitle);
  }

  factory ContentRef.fromJson(Map<String, Object?> json) => ContentRef.create(
    _contentKindFromName(json['kind'] as String?),
    json['id'] as String? ?? 'scp-173',
    json['title'] as String? ?? json['id'] as String? ?? '',
  );

  final ContentKind kind;
  final String id;
  final String title;
  final String key;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    'id': id,
    'title': title,
  };
}

class CatalogSeriesDescriptor {
  const CatalogSeriesDescriptor(this.id, this.label, this.url);

  final String id;
  final String label;
  final String url;
}

const scpSeriesDescriptors = <CatalogSeriesDescriptor>[
  CatalogSeriesDescriptor('scp-series', 'I', '$wikiBaseUrl/scp-series'),
  CatalogSeriesDescriptor('scp-series-2', 'II', '$wikiBaseUrl/scp-series-2'),
  CatalogSeriesDescriptor('scp-series-3', 'III', '$wikiBaseUrl/scp-series-3'),
  CatalogSeriesDescriptor('scp-series-4', 'IV', '$wikiBaseUrl/scp-series-4'),
  CatalogSeriesDescriptor('scp-series-5', 'V', '$wikiBaseUrl/scp-series-5'),
  CatalogSeriesDescriptor('scp-series-6', 'VI', '$wikiBaseUrl/scp-series-6'),
  CatalogSeriesDescriptor('scp-series-7', 'VII', '$wikiBaseUrl/scp-series-7'),
  CatalogSeriesDescriptor('scp-series-8', 'VIII', '$wikiBaseUrl/scp-series-8'),
  CatalogSeriesDescriptor('scp-series-9', 'IX', '$wikiBaseUrl/scp-series-9'),
  CatalogSeriesDescriptor('scp-series-10', 'X', '$wikiBaseUrl/scp-series-10'),
];

class CatalogEntry {
  const CatalogEntry({
    required this.itemId,
    required this.title,
    this.description = '',
    this.hasArchive3D = false,
    this.imageUrl = '',
  });

  final String itemId;
  final String title;
  final String description;
  final bool hasArchive3D;
  final String imageUrl;

  String get displayTitle => title.trim().isEmpty ? itemId.toUpperCase() : title;

  ContentRef get contentRef => ContentRef.create(ContentKind.scp, itemId, displayTitle);

  Map<String, Object?> toJson() => <String, Object?>{
    'itemId': itemId,
    'title': title,
    'description': description,
    'hasArchive3D': hasArchive3D,
    'imageUrl': imageUrl,
  };

  factory CatalogEntry.fromJson(Map<String, Object?> json) => CatalogEntry(
    itemId: json['itemId'] as String? ?? 'SCP-173',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    hasArchive3D: json['hasArchive3D'] as bool? ?? false,
    imageUrl: json['imageUrl'] as String? ?? '',
  );
}

class TaleEntry {
  const TaleEntry({required this.id, required this.title});

  final String id;
  final String title;

  ContentRef get contentRef => ContentRef.create(ContentKind.tale, id, title);

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'title': title};

  factory TaleEntry.fromJson(Map<String, Object?> json) => TaleEntry(
    id: json['id'] as String? ?? 'about-the-foundation',
    title: json['title'] as String? ?? '',
  );
}

class ExploreEntry {
  const ExploreEntry({
    required this.id,
    required this.title,
    this.score = -1,
    this.date = '',
    this.comments = '',
    this.summary = '',
    this.imageUrl = '',
  });

  final String id;
  final String title;
  final int score;
  final String date;
  final String comments;
  final String summary;
  final String imageUrl;

  String get normalizedId => normalizeContentId(id);

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'score': score,
    'date': date,
    'comments': comments,
    'summary': summary,
    'imageUrl': imageUrl,
  };

  factory ExploreEntry.fromJson(Map<String, Object?> json) => ExploreEntry(
    id: json['id'] as String? ?? 'scp-173',
    title: json['title'] as String? ?? '',
    score: json['score'] as int? ?? -1,
    date: json['date'] as String? ?? '',
    comments: json['comments'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    imageUrl: json['imageUrl'] as String? ?? '',
  );
}

class ExploreContentItem {
  const ExploreContentItem(this.entry, this.kind, this.sourceLabel, {this.timestamp = 0});

  final ExploreEntry entry;
  final ContentKind kind;
  final String sourceLabel;
  final int timestamp;

  String get key => '${kind.name}:${entry.normalizedId}';
  ContentRef get contentRef => ContentRef.create(kind, entry.normalizedId, entry.title);
}

class ExploreHomeData {
  const ExploreHomeData({
    this.topRated = const <ExploreEntry>[],
    this.recent = const <ExploreContentItem>[],
    this.jokes = const <ExploreContentItem>[],
    this.recommendations = const <ExploreEntry>[],
    this.error,
  });

  final List<ExploreEntry> topRated;
  final List<ExploreContentItem> recent;
  final List<ExploreContentItem> jokes;
  final List<ExploreEntry> recommendations;
  final String? error;
}

sealed class ArticleBlock {
  const ArticleBlock();
}

class ArticleHeading extends ArticleBlock {
  const ArticleHeading(this.text, this.level);

  final String text;
  final int level;
}

class ArticleParagraph extends ArticleBlock {
  const ArticleParagraph(this.text);

  final String text;
}

class ArticleImage extends ArticleBlock {
  const ArticleImage(this.url, this.alt);

  final String url;
  final String alt;
}

class ArticleQuote extends ArticleBlock {
  const ArticleQuote(this.text);

  final String text;
}

class ArticleListBlock extends ArticleBlock {
  const ArticleListBlock(this.items, this.ordered);

  final List<String> items;
  final bool ordered;
}

class ArticleDivider extends ArticleBlock {
  const ArticleDivider();
}

class ArticleDocument {
  const ArticleDocument({
    required this.content,
    required this.sourceUrl,
    required this.fetchedAt,
    required this.blocks,
  });

  final ContentRef content;
  final String sourceUrl;
  final int fetchedAt;
  final List<ArticleBlock> blocks;
}

class ArchiveAsset {
  const ArchiveAsset({
    required this.assetId,
    required this.contentId,
    required this.resourcePath,
    required this.source,
    required this.delivery,
    required this.version,
    required this.byteLength,
    required this.sha256,
    required this.license,
    required this.attribution,
    required this.contentAttribution,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.downloadUrl,
    required this.contentSourceUrl,
    required this.description,
    required this.objectClass,
    required this.notice,
    required this.modificationNote,
    required this.estimatedTriangleCount,
    required this.renderTargetMaxPx,
    required this.initialScale,
  });

  final String assetId;
  final String contentId;
  final String resourcePath;
  final ArchiveAssetSource source;
  final ArchiveAssetDelivery delivery;
  final String version;
  final int byteLength;
  final String sha256;
  final String license;
  final String attribution;
  final String contentAttribution;
  final String sourceLabel;
  final String sourceUrl;
  final String downloadUrl;
  final String contentSourceUrl;
  final String description;
  final String objectClass;
  final String notice;
  final String modificationNote;
  final int estimatedTriangleCount;
  final int renderTargetMaxPx;
  final double initialScale;

  String get title => contentId.toUpperCase();
  bool get isReadyByDefault => delivery == ArchiveAssetDelivery.bundled;
  ContentRef get contentRef => ContentRef.create(ContentKind.scp, contentId, title);
}

class ReadingHistoryEntry {
  const ReadingHistoryEntry({
    required this.content,
    required this.openedAt,
    required this.lastReadAt,
    this.scrollOffset = 0,
    this.blockCount = 0,
    this.activeMs = 0,
  });

  factory ReadingHistoryEntry.fromJson(Map<String, Object?> json) => ReadingHistoryEntry(
    content: ContentRef.fromJson(json),
    openedAt: json['openedAt'] as int? ?? 0,
    lastReadAt: json['lastReadAt'] as int? ?? 0,
    scrollOffset: json['scrollOffset'] as int? ?? 0,
    blockCount: json['blockCount'] as int? ?? 0,
    activeMs: json['activeMs'] as int? ?? 0,
  );

  final ContentRef content;
  final int openedAt;
  final int lastReadAt;
  final int scrollOffset;
  final int blockCount;
  final int activeMs;

  ReadingHistoryEntry copyWith({
    ContentRef? content,
    int? openedAt,
    int? lastReadAt,
    int? scrollOffset,
    int? blockCount,
    int? activeMs,
  }) => ReadingHistoryEntry(
    content: content ?? this.content,
    openedAt: openedAt ?? this.openedAt,
    lastReadAt: lastReadAt ?? this.lastReadAt,
    scrollOffset: scrollOffset ?? this.scrollOffset,
    blockCount: blockCount ?? this.blockCount,
    activeMs: activeMs ?? this.activeMs,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    ...content.toJson(),
    'openedAt': openedAt,
    'lastReadAt': lastReadAt,
    'scrollOffset': scrollOffset,
    'blockCount': blockCount,
    'activeMs': activeMs,
  };
}

class LibrarySnapshot {
  const LibrarySnapshot({
    this.favorites = const <ContentRef>[],
    this.history = const <ReadingHistoryEntry>[],
    this.activitySegments = const <ResearchActivitySegment>[],
  });

  final List<ContentRef> favorites;
  final List<ReadingHistoryEntry> history;
  final List<ResearchActivitySegment> activitySegments;

  LibrarySnapshot copyWith({
    List<ContentRef>? favorites,
    List<ReadingHistoryEntry>? history,
    List<ResearchActivitySegment>? activitySegments,
  }) => LibrarySnapshot(
    favorites: favorites ?? this.favorites,
    history: history ?? this.history,
    activitySegments: activitySegments ?? this.activitySegments,
  );
}

class ResearchActivitySegment {
  const ResearchActivitySegment({
    required this.segmentId,
    required this.content,
    required this.startedAt,
    required this.endedAt,
    required this.activeMs,
    this.lastOffset = 0,
  });

  factory ResearchActivitySegment.fromJson(Map<String, Object?> json) => ResearchActivitySegment(
    segmentId: json['segmentId'] as String? ?? 'legacy',
    content: ContentRef.fromJson(json),
    startedAt: json['startedAt'] as int? ?? 0,
    endedAt: json['endedAt'] as int? ?? 0,
    activeMs: json['activeMs'] as int? ?? 0,
    lastOffset: json['lastOffset'] as int? ?? 0,
  );

  final String segmentId;
  final ContentRef content;
  final int startedAt;
  final int endedAt;
  final int activeMs;
  final int lastOffset;

  ResearchActivitySegment copyWith({
    String? segmentId,
    ContentRef? content,
    int? startedAt,
    int? endedAt,
    int? activeMs,
    int? lastOffset,
  }) => ResearchActivitySegment(
    segmentId: segmentId ?? this.segmentId,
    content: content ?? this.content,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    activeMs: activeMs ?? this.activeMs,
    lastOffset: lastOffset ?? this.lastOffset,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'segmentId': segmentId,
    ...content.toJson(),
    'startedAt': startedAt,
    'endedAt': endedAt,
    'activeMs': activeMs,
    'lastOffset': lastOffset,
  };
}

enum ResearchRankTitle {
  visitor('初访者'),
  retriever('检索者'),
  reader('研读者'),
  cataloger('编目者'),
  researcher('考据者'),
  archivist('典藏者');

  const ResearchRankTitle(this.label);

  final String label;
}

class ResearchDailyProgress {
  const ResearchDailyProgress(this.day, this.activeMs);

  final DateTime day;
  final int activeMs;
}

class ResearchContentProgress {
  const ResearchContentProgress({
    required this.content,
    required this.activeMs,
    required this.researched,
  });

  final ContentRef content;
  final int activeMs;
  final bool researched;
}

class ResearchProgress {
  const ResearchProgress({
    required this.rawActiveMs,
    required this.creditedActiveMs,
    required this.todayActiveMs,
    required this.researchedContentCount,
    required this.experience,
    required this.level,
    required this.rankTitle,
    required this.levelThreshold,
    required this.nextLevelThreshold,
    required this.levelExperience,
    required this.levelExperienceTarget,
    required this.daily,
    required this.contents,
  });

  final int rawActiveMs;
  final int creditedActiveMs;
  final int todayActiveMs;
  final int researchedContentCount;
  final int experience;
  final int level;
  final ResearchRankTitle rankTitle;
  final int levelThreshold;
  final int nextLevelThreshold;
  final int levelExperience;
  final int levelExperienceTarget;
  final List<ResearchDailyProgress> daily;
  final List<ResearchContentProgress> contents;

  double get levelProgressPercent =>
      levelExperienceTarget <= 0 ? 1 : (levelExperience / levelExperienceTarget).clamp(0.0, 1.0);
}

class _ResearchDaySlice {
  const _ResearchDaySlice(this.content, this.day, this.startedAt, this.endedAt, this.activeMs);

  final ContentRef content;
  final DateTime day;
  final int startedAt;
  final int endedAt;
  final int activeMs;
}

class _CreditedResearchSlice {
  const _CreditedResearchSlice(this.content, this.day, this.startedAt, this.activeMs);

  final ContentRef content;
  final DateTime day;
  final int startedAt;
  final int activeMs;
}

const researchMinuteMs = 60000;
const researchDailyCapMinutes = 180;
const researchDailyCapMs = researchDailyCapMinutes * researchMinuteMs;
const researchedContentMinMs = researchMinuteMs;
const researchedContentReward = 8;
const researchMaxLevel = 50;

String normalizeContentId(String value) {
  var normalized = value.trim().toLowerCase();
  while (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  if (normalized.isEmpty) {
    throw ArgumentError('内容标识不能为空');
  }
  return normalized;
}

String articleUrlOf(String id) => '$wikiBaseUrl/${normalizeContentId(id)}';

String dayKey([DateTime? date]) {
  final value = date ?? DateTime.now();
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

double normalizeFontSize(double value) {
  if (!value.isFinite) return ReadingSettingsRange.defaultFontSize;
  final clamped = value.clamp(ReadingSettingsRange.minFontSize, ReadingSettingsRange.maxFontSize);
  return (clamped * 100).round() / 100;
}

double normalizeLineHeight(double value) {
  if (!value.isFinite) return ReadingSettingsRange.defaultLineHeight;
  final clamped = value.clamp(ReadingSettingsRange.minLineHeight, ReadingSettingsRange.maxLineHeight);
  return (clamped * 1000).round() / 1000;
}

int normalizeResearchDuration(int value) => value <= 0 ? 0 : value;

int normalizeReadingOffset(int value) => math.max(0, value);

int normalizeReadingBlockCount(int value) => math.max(0, value);

double readingProgressPercent(ReadingHistoryEntry entry) {
  if (entry.blockCount <= 1) return 0;
  return (entry.scrollOffset / math.max(1, entry.blockCount - 1)).clamp(0.0, 1.0);
}

ResearchProgress deriveResearchProgress(
  List<ResearchActivitySegment> segments, {
  int? now,
}) {
  final currentMs = normalizeResearchDuration(now ?? DateTime.now().millisecondsSinceEpoch);
  final normalizedSegments = segments
      .where((segment) => segment.activeMs > 0)
      .map(
        (segment) => segment.copyWith(
          startedAt: normalizeResearchDuration(segment.startedAt),
          endedAt: math.max(
            normalizeResearchDuration(segment.startedAt),
            normalizeResearchDuration(segment.endedAt),
          ),
          activeMs: normalizeResearchDuration(segment.activeMs),
          lastOffset: normalizeReadingOffset(segment.lastOffset),
        ),
      )
      .toList();
  final rawActiveMs = normalizedSegments.fold<int>(0, (sum, item) => sum + item.activeMs);
  final credited = _creditResearchSegments(normalizedSegments);
  final creditedActiveMs = credited.fold<int>(0, (sum, item) => sum + item.activeMs);
  final byDay = <String, List<_CreditedResearchSlice>>{};
  for (final slice in credited) {
    byDay.putIfAbsent(dayKey(slice.day), () => <_CreditedResearchSlice>[]).add(slice);
  }
  final daily = byDay.values
      .map((slices) => ResearchDailyProgress(_startOfDay(slices.first.day), slices.fold(0, (sum, item) => sum + item.activeMs)))
      .toList()
    ..sort((left, right) => right.day.compareTo(left.day));
  final today = _startOfDay(DateTime.fromMillisecondsSinceEpoch(currentMs));
  final todayActiveMs = daily.where((item) => _sameDay(item.day, today)).fold<int>(0, (sum, item) => sum + item.activeMs);
  final byContent = <String, List<_CreditedResearchSlice>>{};
  for (final slice in credited) {
    byContent.putIfAbsent(slice.content.key, () => <_CreditedResearchSlice>[]).add(slice);
  }
  final contents = byContent.values.map((slices) {
    final activeMs = slices.fold<int>(0, (sum, item) => sum + item.activeMs);
    return ResearchContentProgress(
      content: slices.first.content,
      activeMs: activeMs,
      researched: activeMs >= researchedContentMinMs,
    );
  }).toList()
    ..sort((left, right) {
      final active = right.activeMs.compareTo(left.activeMs);
      if (active != 0) return active;
      return left.content.key.compareTo(right.content.key);
    });
  final researchedContentCount = contents.where((item) => item.researched).length;
  final experience = math.min(
    creditedActiveMs ~/ researchMinuteMs + researchedContentCount * researchedContentReward,
    0x7fffffff,
  );
  final level = researchLevelForExperience(experience);
  final levelThreshold = researchExperienceThreshold(level);
  final nextLevelThreshold = level >= researchMaxLevel ? levelThreshold : researchExperienceThreshold(level + 1);
  return ResearchProgress(
    rawActiveMs: rawActiveMs,
    creditedActiveMs: creditedActiveMs,
    todayActiveMs: todayActiveMs,
    researchedContentCount: researchedContentCount,
    experience: experience,
    level: level,
    rankTitle: researchRankTitleForLevel(level),
    levelThreshold: levelThreshold,
    nextLevelThreshold: nextLevelThreshold,
    levelExperience: experience - levelThreshold,
    levelExperienceTarget: level >= researchMaxLevel ? 0 : nextLevelThreshold - levelThreshold,
    daily: daily,
    contents: contents,
  );
}

int researchExperienceThreshold(int level) {
  final normalizedLevel = level.clamp(1, researchMaxLevel);
  return 8 * (normalizedLevel - 1) * (normalizedLevel - 1);
}

int researchLevelForExperience(int experience) {
  final normalizedExperience = math.max(0, experience);
  var level = 1;
  for (var candidate = 2; candidate <= researchMaxLevel; candidate++) {
    if (normalizedExperience < researchExperienceThreshold(candidate)) {
      break;
    }
    level = candidate;
  }
  return level;
}

ResearchRankTitle researchRankTitleForLevel(int level) {
  final normalizedLevel = level.clamp(1, researchMaxLevel);
  if (normalizedLevel >= 50) return ResearchRankTitle.archivist;
  if (normalizedLevel >= 35) return ResearchRankTitle.researcher;
  if (normalizedLevel >= 20) return ResearchRankTitle.cataloger;
  if (normalizedLevel >= 10) return ResearchRankTitle.reader;
  if (normalizedLevel >= 5) return ResearchRankTitle.retriever;
  return ResearchRankTitle.visitor;
}

List<_CreditedResearchSlice> _creditResearchSegments(List<ResearchActivitySegment> segments) {
  final usedByDay = <String, int>{};
  final slices = segments.expand(_splitResearchSegmentByDay).toList()
    ..sort((left, right) {
      final dayComparison = left.day.compareTo(right.day);
      if (dayComparison != 0) return dayComparison;
      return left.startedAt.compareTo(right.startedAt);
    });
  final credited = <_CreditedResearchSlice>[];
  for (final slice in slices) {
    final key = dayKey(slice.day);
    final used = usedByDay[key] ?? 0;
    final remaining = math.max(0, researchDailyCapMs - used);
    final creditedMs = math.min(slice.activeMs, remaining);
    if (creditedMs > 0) {
      usedByDay[key] = used + creditedMs;
      credited.add(_CreditedResearchSlice(slice.content, slice.day, slice.startedAt, creditedMs));
    }
  }
  return credited;
}

List<_ResearchDaySlice> _splitResearchSegmentByDay(ResearchActivitySegment segment) {
  final activeMs = normalizeResearchDuration(segment.activeMs);
  if (activeMs == 0) return const <_ResearchDaySlice>[];
  final startedAt = normalizeResearchDuration(segment.startedAt);
  final endedAt = math.max(startedAt, normalizeResearchDuration(segment.endedAt));
  final startDay = _startOfDay(DateTime.fromMillisecondsSinceEpoch(startedAt));
  if (endedAt <= startedAt) {
    return <_ResearchDaySlice>[_ResearchDaySlice(segment.content, startDay, startedAt, endedAt, activeMs)];
  }

  final wallSpan = endedAt - startedAt;
  final slices = <_ResearchDaySlice>[];
  var cursor = startedAt;
  var allocated = 0;
  while (cursor < endedAt) {
    final cursorDateTime = DateTime.fromMillisecondsSinceEpoch(cursor);
    final day = _startOfDay(cursorDateTime);
    final sliceEndAt = math.min(endedAt, day.add(const Duration(days: 1)).millisecondsSinceEpoch);
    final isLast = sliceEndAt >= endedAt;
    final sliceActiveMs = isLast ? activeMs - allocated : (activeMs * ((sliceEndAt - cursor) / wallSpan)).floor();
    if (sliceActiveMs > 0) {
      slices.add(_ResearchDaySlice(segment.content, day, cursor, sliceEndAt, sliceActiveMs));
      allocated += sliceActiveMs;
    }
    cursor = sliceEndAt;
  }
  return slices;
}

DateTime _startOfDay(DateTime value) => DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year && left.month == right.month && left.day == right.day;

ThemeModePreference _themeModeFromName(String? value) {
  final normalized = value?.trim().toLowerCase();
  return ThemeModePreference.values.firstWhere(
    (item) => item.name.toLowerCase() == normalized,
    orElse: () => ThemeModePreference.system,
  );
}

ContentKind _contentKindFromName(String? value) {
  final normalized = value?.trim().toLowerCase();
  return ContentKind.values.firstWhere(
    (item) => item.name.toLowerCase() == normalized,
    orElse: () => ContentKind.scp,
  );
}
