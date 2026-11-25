import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

part 'foundation_catalog.dart';

enum FoundationAssessmentIcon { lockbox, taskForce, crv }

class FoundationExam {
  const FoundationExam(
    this.id,
    this.code,
    this.title,
    this.subtitle,
    this.stamp,
    this.rank,
    this.icon,
    this.passScore,
    this.xp,
    this.passNote,
    this.failNote,
    this.questions,
  );

  final String id, code, title, subtitle, stamp, rank, passNote, failNote;
  final FoundationAssessmentIcon icon;
  final int passScore, xp;
  final List<FoundationQuestion> questions;
}

class FoundationQuestion {
  const FoundationQuestion(
    this.id,
    this.code,
    this.heading,
    this.brief,
    this.prompt,
    this.options,
    this.answer,
    this.explanation,
    this.reference,
    this.referenceLabel, [
    this.hiddenClue,
    this.clueHint,
  ]);

  final String id, code, heading, brief, prompt, explanation, referenceLabel;
  final List<String> options;
  final int answer;
  final ContentRef reference;
  final String? hiddenClue, clueHint;
}

class FoundationRecord {
  const FoundationRecord(
    this.attempts,
    this.bestScore,
    this.lastScore,
    this.lastAttemptAt,
    this.firstPassedAt,
  );

  factory FoundationRecord.fromJson(Map<String, dynamic> json) =>
      FoundationRecord(
        json['attempts'] as int,
        json['bestScore'] as int,
        json['lastScore'] as int,
        json['lastAttemptAt'] as int,
        json['firstPassedAt'] as int?,
      );

  final int attempts, bestScore, lastScore, lastAttemptAt;
  final int? firstPassedAt;
  bool get passed => firstPassedAt != null;

  Map<String, Object?> toJson() => {
    'attempts': attempts,
    'bestScore': bestScore,
    'lastScore': lastScore,
    'lastAttemptAt': lastAttemptAt,
    'firstPassedAt': firstPassedAt,
  };
}

class FoundationReceipt {
  const FoundationReceipt(this.record, this.passed, this.awardedXp);
  final FoundationRecord record;
  final bool passed;
  final int awardedXp;
}

class FoundationSaveException implements Exception {
  const FoundationSaveException();
}

class FoundationStore extends ChangeNotifier {
  FoundationStore(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final saved = _prefs.getString(_key);
    _records = saved == null
        ? {}
        : (jsonDecode(saved) as Map<String, dynamic>).map(
            (id, value) => MapEntry(
              id,
              FoundationRecord.fromJson(value as Map<String, dynamic>),
            ),
          );
  }

  static const _key = 'foundation.assessments';
  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  late Map<String, FoundationRecord> _records;
  Future<void> _pending = Future.value();

  FoundationRecord? recordFor(FoundationExam exam) => _records[exam.id];
  Iterable<FoundationExam> get stamps =>
      foundationExams.where((exam) => recordFor(exam)?.passed ?? false);
  int get bonusXp => stamps.fold(0, (sum, exam) => sum + exam.xp);

  Future<FoundationReceipt> submit(FoundationExam exam, List<int> answers) {
    final score = List.generate(
      exam.questions.length,
      (index) => index,
    ).where((index) => exam.questions[index].answer == answers[index]).length;
    final saved = _pending.then((_) => _save(exam, score));
    _pending = saved.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return saved;
  }

  Future<FoundationReceipt> _save(FoundationExam exam, int score) async {
    final previous = recordFor(exam);
    final passed = score >= exam.passScore;
    final firstPass = passed && previous?.firstPassedAt == null;
    final now = _clock().millisecondsSinceEpoch;
    final record = FoundationRecord(
      (previous?.attempts ?? 0) + 1,
      math.max(score, previous?.bestScore ?? 0),
      score,
      now,
      firstPass ? now : previous?.firstPassedAt,
    );
    final updated = {..._records, exam.id: record};
    try {
      if (!await _prefs.setString(_key, jsonEncode(updated))) {
        throw const FoundationSaveException();
      }
    } on PlatformException {
      throw const FoundationSaveException();
    }
    _records = updated;
    notifyListeners();
    return FoundationReceipt(record, passed, firstPass ? exam.xp : 0);
  }
}
