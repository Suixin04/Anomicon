import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anomicon/src/models.dart';
import 'package:anomicon/src/seed_data.dart';

void main() {
  final content = ContentRef.create(ContentKind.scp, 'scp-173', '雕像');

  test('derives experience and research count from credited reading', () {
    final now = DateTime(2026, 9, 3, 20).millisecondsSinceEpoch;
    final progress = deriveResearchProgress(
      <ResearchActivitySegment>[
        ResearchActivitySegment(
          segmentId: 'segment-1',
          content: content,
          startedAt: now - 2 * researchMinuteMs,
          endedAt: now,
          activeMs: 2 * researchMinuteMs,
        ),
      ],
      now: now,
    );

    expect(progress.creditedActiveMs, 2 * researchMinuteMs);
    expect(progress.researchedContentCount, 1);
    expect(progress.experience, 10);
    expect(progress.level, 2);
    expect(progress.rankTitle, ResearchRankTitle.visitor);
    expect(progress.levelProgressPercent, greaterThan(0));
  });

  test('applies daily cap before calculating experience', () {
    final now = DateTime(2026, 9, 3, 20).millisecondsSinceEpoch;
    final progress = deriveResearchProgress(
      <ResearchActivitySegment>[
        ResearchActivitySegment(
          segmentId: 'segment-1',
          content: content,
          startedAt: now - 240 * researchMinuteMs,
          endedAt: now,
          activeMs: 240 * researchMinuteMs,
        ),
      ],
      now: now,
    );

    expect(progress.creditedActiveMs, researchDailyCapMs);
    expect(progress.experience, 3 * 60 + researchedContentReward);
  });

  test('splits cross-day reading without losing active milliseconds', () {
    final start = DateTime(2026, 9, 3, 23, 59).millisecondsSinceEpoch;
    final end = DateTime(2026, 9, 4, 0, 1).millisecondsSinceEpoch;
    final progress = deriveResearchProgress(
      <ResearchActivitySegment>[
        ResearchActivitySegment(
          segmentId: 'segment-1',
          content: content,
          startedAt: start,
          endedAt: end,
          activeMs: 2 * researchMinuteMs,
        ),
      ],
      now: end,
    );

    expect(progress.daily, hasLength(2));
    expect(
      progress.daily.fold<int>(0, (sum, item) => sum + item.activeMs),
      2 * researchMinuteMs,
    );
  });

  test('bundled GLB assets match the Flutter manifest', () async {
    for (final asset in SeedData.archiveAssets.where((item) => item.isReadyByDefault)) {
      final file = File(asset.resourcePath);
      expect(await file.exists(), isTrue, reason: '${asset.resourcePath} is missing');
      expect(await file.length(), asset.byteLength, reason: '${asset.resourcePath} size mismatch');
      final digest = sha256.convert(await file.readAsBytes()).toString();
      expect(digest, asset.sha256, reason: '${asset.resourcePath} sha256 mismatch');
    }
  });
}
