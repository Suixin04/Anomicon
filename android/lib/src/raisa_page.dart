import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'raisa.dart';

class RaisaFeedbackPage extends StatefulWidget {
  const RaisaFeedbackPage({
    super.key,
    required this.store,
    required this.origin,
    required this.appVersion,
  });
  final RaisaStore store;
  final RaisaOrigin origin;
  final String appVersion;

  @override
  State<RaisaFeedbackPage> createState() => _RaisaFeedbackPageState();
}

class _RaisaFeedbackPageState extends State<RaisaFeedbackPage> {
  static const _picker = MethodChannel('anomicon/raisa_attachments');
  static const _diagnosticLabels = {
    'appVersionLabel': '应用版本',
    'osLabel': '系统环境',
    'windowWidthVp': '窗口宽度',
    'themeMode': '界面主题',
    'entrySource': '工单入口',
    'articleId': '档案标识',
    'articleTitle': '档案标题',
    'articleUrl': '档案地址',
    'renderMode': '阅读模式',
    'revealHiddenText': '反白透视',
  };
  final _summary = TextEditingController();
  final _details = TextEditingController();
  final _contact = TextEditingController();
  final _attachments = <RaisaAttachment>[];
  late RaisaCategory _category = widget.origin.category;
  Map<String, Object>? _snapshot;
  bool _diagnostics = true;
  bool _sending = false;
  bool _picking = false;
  String? _error;
  RaisaResult? _result;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final origin = widget.origin;
    _snapshot ??= {
      'appVersionLabel': widget.appVersion,
      'osLabel': Platform.isAndroid
          ? 'Android ${Platform.operatingSystemVersion}'
          : Platform.operatingSystem,
      'windowWidthVp': MediaQuery.sizeOf(context).width.round(),
      'themeMode': Theme.of(context).brightness.name,
      'entrySource': origin.source,
      if (origin.content case final content?) ...{
        'articleId': content.id,
        'articleTitle': content.title,
        'articleUrl': articleUrlOf(content.id),
        'renderMode': origin.renderMode,
        'revealHiddenText': origin.revealHiddenText,
      },
    };
  }

  RaisaDraft _draft() => RaisaDraft(
    category: _category,
    summary: _summary.text,
    details: _details.text,
    contact: _contact.text,
    appVersion: widget.appVersion,
    diagnostics: _diagnostics ? _snapshot : null,
    attachments: List.of(_attachments),
  );

  @override
  void dispose() {
    _summary.dispose();
    _details.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _pick(bool imagesOnly) async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final selected = await _picker.invokeMapMethod<String, dynamic>('pick', {
        'imagesOnly': imagesOnly,
      });
      if (!mounted || selected == null) return;
      final attachment = RaisaAttachment(
        selected['name'] as String,
        selected['mimeType'] as String,
        selected['bytes'] as Uint8List,
      );
      final error = raisaAttachmentError([..._attachments, attachment]);
      setState(() {
        _error = error;
        if (error == null) _attachments.add(attachment);
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = switch (error.code) {
          'too_large' => '单个附件不能超过 2 MiB',
          'unavailable' => '系统附件选择器不可用',
          _ => '未能读取附件，请重新选择',
        },
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _preview() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('诊断预览'),
        content: SingleChildScrollView(
          child: SelectableText(
            _snapshot!.entries
                .map((item) => '${_diagnosticLabels[item.key]}：${item.value}')
                .join('\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final draft = _draft();
    if (draft.error case final error?) {
      setState(() => _error = error);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('签发公开工单？'),
        content: const Text(
          '中转服务会将文字、附件及已勾选的诊断发到公开 GitHub Issue。请确认其中没有个人信息或敏感内容。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('检查草稿'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认签发'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await widget.store.submit(draft);
      if (mounted) setState(() => _result = result);
    } on RaisaException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: _draft().copyReport(_diagnosticLabels)),
    );
    if (mounted) _message('已复制工单报文');
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _openIssue(Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (mounted && !opened) _message('无法打开 Issue 链接');
  }

  void _history() {
    final history = widget.store.history;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('已签发工单'),
        content: SizedBox(
          width: 480,
          child: history.isEmpty
              ? const Text('暂无本地回执')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final receipt in history) _receiptTile(receipt),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  ListTile _receiptTile(RaisaReceipt receipt) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text('${receipt.code} · #${receipt.issueNumber}'),
    subtitle: Text('${receipt.summary}\n${receipt.issueUrl}'),
    trailing: const Icon(Icons.open_in_new),
    onTap: () => _openIssue(receipt.issueUrl),
  );

  void _newTicket() {
    setState(() {
      _result = null;
      _error = null;
      _summary.clear();
      _details.clear();
      _contact.clear();
      _attachments.clear();
      _category = widget.origin.category;
      _diagnostics = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final busy = _sending || _picking;
    final canPick = !busy && _attachments.length < raisaMaxAttachments;
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('RAISA 工单'),
          actions: [
            IconButton(
              onPressed: busy ? null : _history,
              icon: const Icon(Icons.history),
              tooltip: '已签发工单',
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: result != null
                ? [
                    Text(
                      result.deduplicated ? '已找到同一份工单的回执' : '工单已签发',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    _receiptTile(result.receipt),
                    if (!result.savedLocally) ...[
                      const Text('工单已公开签发，本地回执保存失败。'),
                      TextButton(
                        onPressed: () async {
                          final saved = await widget.store.saveReceipt(
                            result.receipt,
                          );
                          if (!mounted) return;
                          if (saved) {
                            setState(
                              () => _result = RaisaResult(
                                result.receipt,
                                deduplicated: result.deduplicated,
                                savedLocally: true,
                              ),
                            );
                          } else {
                            _message('未能保存本地回执');
                          }
                        },
                        child: const Text('重存本地回执'),
                      ),
                    ],
                    OutlinedButton(
                      onPressed: _newTicket,
                      child: const Text('新建工单'),
                    ),
                  ]
                : [
                    const Text('签发后会创建公开 GitHub Issue。请在提交前检查文字、联络代号与附件。'),
                    if (widget.origin.content case final content?)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('关联档案 · ${content.title}'),
                        subtitle: Text(content.id),
                      ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<RaisaCategory>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: '工单类型'),
                      items: [
                        for (final category in RaisaCategory.values)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category.label),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => _category = value!),
                    ),
                    TextField(
                      controller: _summary,
                      enabled: !busy,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: '工单简述（至少 4 字）',
                      ),
                    ),
                    TextField(
                      controller: _details,
                      enabled: !busy,
                      maxLength: 2000,
                      minLines: 3,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: '详细说明（至少 8 字）',
                      ),
                    ),
                    TextField(
                      controller: _contact,
                      enabled: !busy,
                      maxLength: 64,
                      decoration: const InputDecoration(labelText: '联络代号（选填）'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('附带诊断'),
                      value: _diagnostics,
                      onChanged: busy
                          ? null
                          : (value) => setState(() => _diagnostics = value),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: busy ? null : _preview,
                        child: const Text('预览诊断'),
                      ),
                    ),
                    Text('附件 ${_attachments.length}/3 · 单件 2 MiB · 合计 5 MiB'),
                    for (final (index, attachment) in _attachments.indexed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(attachment.name),
                        subtitle: Text('${attachment.bytes.length} 字节'),
                        trailing: IconButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  _attachments.removeAt(index);
                                  _error = null;
                                }),
                          icon: const Icon(Icons.close),
                          tooltip: '移除 ${attachment.name}',
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: canPick ? () => _pick(true) : null,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('添加图片'),
                        ),
                        OutlinedButton.icon(
                          onPressed: canPick ? () => _pick(false) : null,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('添加文件'),
                        ),
                      ],
                    ),
                    if (_error case final error?)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      child: Text(_sending ? '签发中…' : '签发工单'),
                    ),
                    TextButton(
                      onPressed: busy ? null : _copy,
                      child: const Text('复制工单报文'),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}
