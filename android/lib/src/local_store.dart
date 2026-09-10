import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class LocalStore {
  LocalStore._(this._prefs);

  static Future<LocalStore> create() async => LocalStore._(await SharedPreferences.getInstance());

  static const _settingsKey = 'settings';
  static const _favoritesKey = 'favorites';
  static const _historyKey = 'history';
  static const _activitySegmentsKey = 'activitySegments';
  static const _maxHistoryEntries = 500;
  static const _maxResearchSegments = 2000;
  static const _activeReadIdleCapMs = 90000;

  final SharedPreferences _prefs;

  AppSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const AppSettings();
    }
    return _decodeObject(raw, AppSettings.fromJson) ?? const AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(_settingsKey, jsonEncode(settings.normalized().toJson()));
  }

  LibrarySnapshot loadLibrary() => LibrarySnapshot(
    favorites: _decodeArray(_prefs.getString(_favoritesKey), ContentRef.fromJson),
    history: _decodeArray(_prefs.getString(_historyKey), ReadingHistoryEntry.fromJson),
    activitySegments: _decodeArray(
      _prefs.getString(_activitySegmentsKey),
      ResearchActivitySegment.fromJson,
    ),
  );

  Future<LibrarySnapshot> toggleFavorite(ContentRef content) async {
    final current = loadLibrary();
    final exists = current.favorites.any((item) => item.key == content.key);
    final favorites = exists
        ? current.favorites.where((item) => item.key != content.key).toList()
        : <ContentRef>[content, ...current.favorites];
    await _saveLibrary(current.copyWith(favorites: favorites));
    return loadLibrary();
  }

  Future<LibrarySnapshot> recordRead(
    ContentRef content, {
    int? scrollOffset,
    int? blockCount,
    bool creditActiveTime = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = loadLibrary();
    final existing = current.history.where((item) => item.content.key == content.key).firstOrNull;
    final openedAt = existing?.openedAt ?? now;
    final resolvedOffset = normalizeReadingOffset(scrollOffset ?? existing?.scrollOffset ?? 0);
    final resolvedBlockCount = math.max(
      normalizeReadingBlockCount(blockCount ?? existing?.blockCount ?? 0),
      resolvedOffset > 0 ? resolvedOffset + 1 : 0,
    );
    final creditedMs = _activeDelta(existing, now, creditActiveTime);
    final updated = ReadingHistoryEntry(
      content: content,
      openedAt: openedAt,
      lastReadAt: now,
      scrollOffset: resolvedOffset,
      blockCount: resolvedBlockCount,
      activeMs: normalizeResearchDuration((existing?.activeMs ?? 0) + creditedMs),
    );
    final history = <ReadingHistoryEntry>[
      updated,
      ...current.history.where((item) => item.content.key != content.key),
    ].take(_maxHistoryEntries).toList();
    final activitySegments = _appendActivitySegment(
      current.activitySegments,
      content,
      existing,
      now,
      creditedMs,
      resolvedOffset,
    );
    await _saveLibrary(
      current.copyWith(history: history, activitySegments: activitySegments),
    );
    return loadLibrary();
  }

  Future<void> _saveLibrary(LibrarySnapshot snapshot) async {
    await Future.wait(<Future<bool>>[
      _prefs.setString(
        _favoritesKey,
        jsonEncode(snapshot.favorites.map((item) => item.toJson()).toList()),
      ),
      _prefs.setString(
        _historyKey,
        jsonEncode(snapshot.history.map((item) => item.toJson()).toList()),
      ),
      _prefs.setString(
        _activitySegmentsKey,
        jsonEncode(snapshot.activitySegments.map((item) => item.toJson()).toList()),
      ),
    ]);
  }

  int _activeDelta(ReadingHistoryEntry? existing, int now, bool creditActiveTime) {
    if (!creditActiveTime || existing == null || existing.lastReadAt <= 0) {
      return 0;
    }
    final delta = now - existing.lastReadAt;
    if (delta <= 0) {
      return 0;
    }
    return math.min(delta, _activeReadIdleCapMs);
  }

  List<ResearchActivitySegment> _appendActivitySegment(
    List<ResearchActivitySegment> current,
    ContentRef content,
    ReadingHistoryEntry? existing,
    int now,
    int activeMs,
    int lastOffset,
  ) {
    if (activeMs <= 0) {
      return current;
    }
    final startedAt = math.max(0, now - activeMs);
    final segment = ResearchActivitySegment(
      segmentId: '${content.key}:$now:${current.length}',
      content: content,
      startedAt: startedAt,
      endedAt: now,
      activeMs: activeMs,
      lastOffset: lastOffset,
    );
    final last = current.isEmpty ? null : current.last;
    final merged = existing != null &&
            last != null &&
            last.content.key == content.key &&
            startedAt <= last.endedAt + 1000
        ? <ResearchActivitySegment>[
            ...current.take(current.length - 1),
            last.copyWith(
              endedAt: now,
              activeMs: normalizeResearchDuration(last.activeMs + activeMs),
              lastOffset: lastOffset,
            ),
          ]
        : <ResearchActivitySegment>[...current, segment];
    return merged.length > _maxResearchSegments
        ? merged.sublist(merged.length - _maxResearchSegments)
        : merged;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

T? _decodeObject<T>(String raw, T Function(Map<String, Object?> json) decode) {
  try {
    final parsed = jsonDecode(raw);
    if (parsed is Map<String, Object?>) {
      return decode(parsed);
    }
    if (parsed is Map) {
      return decode(parsed.cast<String, Object?>());
    }
  } on FormatException {
    return null;
  }
  return null;
}

List<T> _decodeArray<T>(String? raw, T Function(Map<String, Object?> json) decode) {
  if (raw == null || raw.trim().isEmpty) {
    return <T>[];
  }
  try {
    final parsed = jsonDecode(raw);
    if (parsed is! List) {
      return <T>[];
    }
    return parsed
        .whereType<Map>()
        .map((item) => decode(item.cast<String, Object?>()))
        .toList();
  } on FormatException {
    return <T>[];
  }
}
