import 'package:flutter/material.dart';

import 'foundation.dart';
import 'models.dart';

class FoundationScreen extends StatelessWidget {
  const FoundationScreen({
    super.key,
    required this.store,
    required this.onOpenContent,
    required this.onOpenRaisa,
    required this.onOpenAssessment,
  });

  final FoundationStore store;
  final ValueChanged<ContentRef> onOpenContent;
  final VoidCallback onOpenRaisa;
  final ValueChanged<FoundationExam> onOpenAssessment;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Text('基金会', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 16),
          Text('档案员考核', style: Theme.of(context).textTheme.titleLarge),
          for (final exam in foundationExams) _examTile(exam),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('RAISA 工单'),
              subtitle: const Text('上报异常，查看签发回执'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenRaisa,
            ),
          ),
          const SizedBox(height: 16),
          Text('手册导读', style: Theme.of(context).textTheme.titleLarge),
          for (final reference in foundationHandbook)
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(reference.title),
              onTap: () => onOpenContent(reference),
            ),
        ],
      ),
    ),
  );

  Widget _examTile(FoundationExam exam) {
    final record = store.recordFor(exam);
    return Card(
      child: ListTile(
        leading: Icon(switch (exam.icon) {
          FoundationAssessmentIcon.lockbox => Icons.lock_outline,
          FoundationAssessmentIcon.taskForce => Icons.groups_outlined,
          FoundationAssessmentIcon.crv => Icons.visibility_outlined,
        }),
        title: Text('${exam.code} · ${exam.title}'),
        subtitle: Text(
          '${exam.subtitle}\n${record == null ? '首次通过 +${exam.xp} XP' : '最佳 ${record.bestScore}/${exam.questions.length} · ${record.attempts} 次${record.passed ? ' · ${exam.stamp}印章' : ''}'}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => onOpenAssessment(exam),
      ),
    );
  }
}

class FoundationAssessmentPage extends StatefulWidget {
  const FoundationAssessmentPage({
    super.key,
    required this.store,
    required this.exam,
    required this.onOpenContent,
  });

  final FoundationStore store;
  final FoundationExam exam;
  final ValueChanged<ContentRef> onOpenContent;

  @override
  State<FoundationAssessmentPage> createState() =>
      _FoundationAssessmentPageState();
}

class _FoundationAssessmentPageState extends State<FoundationAssessmentPage> {
  final _scroll = ScrollController();
  final _answers = <int>[];
  int? _choice;
  bool _reveal = false;
  bool _saving = false;
  FoundationReceipt? _receipt;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    final exam = widget.exam;
    if (_answers.length < exam.questions.length - 1) {
      setState(() {
        _answers.add(_choice!);
        _choice = null;
        _reveal = false;
      });
      _scroll.jumpTo(0);
      return;
    }
    setState(() => _saving = true);
    try {
      final receipt = await widget.store.submit(exam, [..._answers, _choice!]);
      if (!mounted) return;
      setState(() {
        _answers.add(_choice!);
        _receipt = receipt;
      });
      _scroll.jumpTo(0);
    } on FoundationSaveException {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('未能保存答卷，请重试。')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final receipt = _receipt;
    return Scaffold(
      appBar: AppBar(title: Text(exam.title)),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          children: receipt == null
              ? _question(context, exam)
              : _result(context, exam, receipt),
        ),
      ),
      bottomNavigationBar: receipt == null
          ? SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _choice == null || _saving ? null : _advance,
                child: Text(
                  _saving
                      ? '保存中…'
                      : _answers.length + 1 == exam.questions.length
                      ? '签发核验回执'
                      : '下一题',
                ),
              ),
            )
          : null,
    );
  }

  List<Widget> _question(BuildContext context, FoundationExam exam) {
    final question = exam.questions[_answers.length];
    return [
      Text('${exam.code} · ${_answers.length + 1}/${exam.questions.length}'),
      const SizedBox(height: 8),
      Text(question.heading, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Text(question.brief),
      if (question.hiddenClue case final clue?) ...[
        const SizedBox(height: 8),
        Text(question.clueHint!),
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: const Text('反白透视'),
            selected: _reveal,
            onSelected: (value) => setState(() => _reveal = value),
          ),
        ),
        if (_reveal)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(clue),
            ),
          ),
      ],
      const SizedBox(height: 12),
      Text(question.prompt, style: Theme.of(context).textTheme.titleMedium),
      RadioGroup<int>(
        groupValue: _choice,
        onChanged: (choice) => setState(() => _choice = choice),
        child: Column(
          children: [
            for (final (index, option) in question.options.indexed)
              RadioListTile<int>(
                value: index,
                title: Text(option),
                enabled: !_saving,
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _result(
    BuildContext context,
    FoundationExam exam,
    FoundationReceipt receipt,
  ) => [
    Text(
      '核验回执 · ${receipt.passed ? '通过' : '未通过'}',
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    Text(
      '本次 ${receipt.record.lastScore}/${exam.questions.length} · 最佳 ${receipt.record.bestScore} · 共 ${receipt.record.attempts} 次',
    ),
    if (receipt.record.passed)
      Chip(label: Text('${exam.stamp}印章 · ${exam.rank}')),
    if (receipt.awardedXp > 0) Text('首次通过奖励 +${receipt.awardedXp} XP'),
    Text(receipt.passed ? exam.passNote : exam.failNote),
    const SizedBox(height: 16),
    for (final (index, question) in exam.questions.indexed)
      Card(
        child: ExpansionTile(
          title: Text('${index + 1}. ${question.heading}'),
          subtitle: Text(_answers[index] == question.answer ? '正确' : '待复习'),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('正确答案 · ${question.options[question.answer]}'),
                  const SizedBox(height: 8),
                  Text(question.explanation),
                  TextButton(
                    onPressed: () => widget.onOpenContent(question.reference),
                    child: Text(question.referenceLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    OutlinedButton(
      onPressed: () {
        setState(() {
          _answers.clear();
          _choice = null;
          _reveal = false;
          _receipt = null;
        });
        _scroll.jumpTo(0);
      },
      child: const Text('重新考核'),
    ),
  ];
}
