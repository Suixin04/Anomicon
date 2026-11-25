import 'dart:convert';
import 'dart:typed_data';

import 'package:anomicon/src/foundation.dart';
import 'package:anomicon/src/foundation_page.dart';
import 'package:anomicon/src/models.dart';
import 'package:anomicon/src/raisa.dart';
import 'package:anomicon/src/raisa_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('保留首次通过时间，重考提高最佳成绩、累计次数而不重复计分', () async {
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 1, 1);
    final store = FoundationStore(prefs, clock: () => now);
    final exam = foundationExams.first;
    final correct = exam.questions.map((question) => question.answer).toList();
    final wrong = correct.map((answer) => (answer + 1) % 4).toList();
    expect((await store.submit(exam, wrong)).passed, false);
    final firstPass = await store.submit(exam, [
      ...correct.take(4),
      wrong.last,
    ]);
    expect(firstPass.awardedXp, 15);
    expect(firstPass.record.firstPassedAt, now.millisecondsSinceEpoch);
    now = now.add(const Duration(days: 1));
    expect((await store.submit(exam, correct)).awardedXp, 0);
    final restored = FoundationStore(prefs);
    expect(restored.recordFor(exam)?.bestScore, 5);
    expect(restored.recordFor(exam)?.attempts, 3);
    expect(
      restored.recordFor(exam)?.firstPassedAt,
      firstPass.record.firstPassedAt,
    );
    expect(restored.stamps.single.id, exam.id);
    expect(
      deriveResearchProgress([], assessmentXp: restored.bonusXp).experience,
      15,
    );
  });

  testWidgets('CRV 逐题作答并从反白透视进入核验回执', (tester) async {
    final exam = foundationExams.last;
    final store = FoundationStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(
        home: FoundationAssessmentPage(
          store: store,
          exam: exam,
          onOpenContent: (_) {},
        ),
      ),
    );
    for (final (index, question) in exam.questions.indexed) {
      if (question.hiddenClue case final clue?) {
        expect(find.text(clue), findsNothing);
        await tester.tap(find.text('反白透视'));
        await tester.pumpAndSettle();
        expect(find.text(clue), findsOneWidget);
      }
      final choice = find.text(question.options[question.answer]);
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
      await tester.tap(find.text(index == 4 ? '签发核验回执' : '下一题'));
      await tester.pumpAndSettle();
    }
    expect(find.text('核验回执 · 通过'), findsOneWidget);
    expect(find.text('首次通过奖励 +25 XP'), findsOneWidget);
  });

  const endpoint = 'https://relay.test/v1/raisa/tickets';
  const response =
      '{"ticketCode":"RAISA-123","issueNumber":123,"issueUrl":"https://github.com/Suixin04/Anomicon/issues/123","createdAt":"2026-01-02T00:00:00Z"}';
  RaisaDraft draft({
    Map<String, Object>? diagnostics,
    List<RaisaAttachment> attachments = const [],
  }) => RaisaDraft(
    category: RaisaCategory.archiveRender,
    summary: '   文内图片  无法显示 ',
    details: '原生档案打开后图片区域留白。',
    contact: '',
    appVersion: '1.0.0+1',
    diagnostics: diagnostics,
    attachments: attachments,
  );

  test('模拟断网重试使用同一幂等键，保存同一个本地回执', () async {
    final prefs = await SharedPreferences.getInstance();
    final keys = <String>[];
    final mocked = MockClient((request) async {
      expect(request.url.toString(), endpoint);
      keys.add(request.headers['x-idempotency-key']!);
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['summary'], '文内图片 无法显示');
      expect(payload['appVersionLabel'], '1.0.0+1');
      expect(payload['includeDiagnostics'], false);
      expect(payload.containsKey('diagnostics'), false);
      expect(payload['attachments'], [
        {'fileName': 'log.txt', 'mimeType': 'text/plain', 'base64Data': 'AQID'},
      ]);
      if (keys.length == 1) throw http.ClientException('offline');
      final body = jsonDecode(response) as Map<String, dynamic>;
      body['deduplicated'] = true;
      return http.Response(jsonEncode(body), 201);
    });
    final relay = RaisaRelay(client: mocked, endpoint: endpoint);
    final report = draft(
      attachments: [
        RaisaAttachment('log.txt', 'text/plain', Uint8List.fromList([1, 2, 3])),
      ],
    );
    final store = RaisaStore(prefs, relay: relay);
    await expectLater(store.submit(report), throwsA(isA<RaisaException>()));
    expect((await store.submit(report)).savedLocally, true);
    expect(
      (await RaisaStore(prefs, relay: relay).submit(report)).deduplicated,
      true,
    );
    expect(keys, hasLength(2));
    expect(keys.toSet(), hasLength(1));
    final restored = RaisaStore(prefs).history.single;
    expect(restored.issueNumber, 123);
    expect(
      restored.issueUrl.toString(),
      'https://github.com/Suixin04/Anomicon/issues/123',
    );
  });

  test('附件限制、可选诊断与中转 413／429', () async {
    final max = RaisaAttachment(
      'log.txt',
      'text/plain',
      Uint8List(raisaMaxAttachmentBytes),
    );
    final small = RaisaAttachment('note.txt', 'text/plain', Uint8List(1));
    expect(raisaAttachmentError([max, max, small]), isNull);
    expect(raisaAttachmentError([max, max, max]), contains('5 MiB'));
    expect(raisaAttachmentError([small, small, small, small]), contains('3 个'));
    final prefs = await SharedPreferences.getInstance();
    for (final (code, message) in [(413, '附件超过'), (429, '过于频繁')]) {
      final relay = RaisaRelay(
        endpoint: endpoint,
        client: MockClient((request) async {
          expect(jsonDecode(request.body)['diagnostics'], {
            'articleId': 'scp-173',
          });
          return http.Response('', code);
        }),
      );
      final store = RaisaStore(prefs, relay: relay);
      await expectLater(
        store.submit(draft(diagnostics: {'articleId': 'scp-173'})),
        throwsA(
          isA<RaisaException>().having(
            (error) => error.message,
            'message',
            contains(message),
          ),
        ),
      );
      expect(store.history, isEmpty);
    }
  });

  testWidgets('正文工单公开确认与签发回执', (tester) async {
    final store = RaisaStore(
      await SharedPreferences.getInstance(),
      relay: RaisaRelay(
        endpoint: endpoint,
        client: MockClient((request) async {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['diagnostics']['articleId'], 'scp-173');
          expect(payload['diagnostics']['renderMode'], 'native');
          return http.Response(response, 201);
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RaisaFeedbackPage(
          store: store,
          origin: RaisaOrigin.article(
            content: ContentRef.create(ContentKind.scp, 'scp-173', 'SCP-173'),
            renderMode: 'native',
          ),
          appVersion: '1.0.0+1',
        ),
      ),
    );
    expect(find.text('关联档案 · SCP-173'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '文内图片无法显示');
    await tester.enterText(find.byType(TextField).at(1), '原生档案打开后图片区域留白。');
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('签发工单'));
    await tester.pumpAndSettle();
    expect(store.history, isEmpty);
    await tester.tap(find.text('确认签发'));
    await tester.pumpAndSettle();
    expect(find.text('工单已签发'), findsOneWidget);
    expect(find.text('RAISA-123 · #123'), findsOneWidget);
  });
}
