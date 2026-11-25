import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

enum RaisaCategory {
  archiveRender('archive_render', '档案解析异常'),
  terminalBug('terminal_bug', '终端运行故障'),
  archive3d('archive_3d', '三维收容异常'),
  systemProposal('system_proposal', '系统演进提案');

  const RaisaCategory(this.code, this.label);
  final String code, label;
}

class RaisaOrigin {
  const RaisaOrigin.foundation()
    : content = null,
      renderMode = '',
      revealHiddenText = false;
  const RaisaOrigin.article({
    required ContentRef this.content,
    required this.renderMode,
    this.revealHiddenText = false,
  });

  final ContentRef? content;
  final String renderMode;
  final bool revealHiddenText;
  String get source => content == null ? 'foundation' : 'article';
  RaisaCategory get category =>
      content == null ? RaisaCategory.terminalBug : RaisaCategory.archiveRender;
}

class RaisaAttachment {
  const RaisaAttachment(this.name, this.mimeType, this.bytes);
  final String name, mimeType;
  final Uint8List bytes;

  Map<String, Object> toWire() => {
    'fileName': name,
    'mimeType': mimeType,
    'base64Data': base64Encode(bytes),
  };
}

const raisaMaxAttachments = 3;
const raisaMaxAttachmentBytes = 2 * 1024 * 1024;
const raisaMaxTotalBytes = 5 * 1024 * 1024;

String? raisaAttachmentError(List<RaisaAttachment> attachments) {
  if (attachments.length > raisaMaxAttachments) return '最多添加 3 个附件';
  var total = 0;
  for (final attachment in attachments) {
    final length = attachment.bytes.length;
    if (attachment.name.trim().isEmpty || length == 0) return '附件为空或没有文件名';
    if (length > raisaMaxAttachmentBytes) return '单个附件不能超过 2 MiB';
    if (!_supportsAttachment(attachment)) {
      return '不支持或格式不匹配的附件：${attachment.name}。'
          '请选择 JPEG、PNG、GIF、WebP、PDF、TXT、LOG、JSON 或 Markdown。';
    }
    total += length;
  }
  return total > raisaMaxTotalBytes ? '附件合计不能超过 5 MiB' : null;
}

// Match the RAISA relay's magic bytes and text-file rules at the picker boundary.
bool _supportsAttachment(RaisaAttachment attachment) {
  final bytes = attachment.bytes;
  bool matches(List<int> signature, [int offset = 0]) {
    if (bytes.length < offset + signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[offset + index] != signature[index]) return false;
    }
    return true;
  }

  if (matches(const [0xff, 0xd8, 0xff]) ||
      matches(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]) ||
      matches('GIF87a'.codeUnits) ||
      matches('GIF89a'.codeUnits) ||
      (matches('RIFF'.codeUnits) && matches('WEBP'.codeUnits, 8)) ||
      matches('%PDF-'.codeUnits)) {
    return true;
  }

  final mime = attachment.mimeType.trim().toLowerCase();
  if (mime.startsWith('image/') || bytes.contains(0)) return false;
  final name = attachment.name.trim().toLowerCase();
  return const ['.txt', '.log', '.json', '.md'].any(name.endsWith) ||
      const {'text/plain', 'application/json', 'text/markdown'}.contains(mime);
}

String raisaSingleLine(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

class RaisaDraft {
  RaisaDraft({
    required this.category,
    required String summary,
    required String details,
    required String contact,
    required this.appVersion,
    this.diagnostics,
    this.attachments = const [],
  }) : summary = raisaSingleLine(summary),
       details = details.trim().replaceAll(RegExp(r'\r\n?'), '\n'),
       contact = raisaSingleLine(contact);

  final RaisaCategory category;
  final String summary, details, contact, appVersion;
  final Map<String, Object>? diagnostics;
  final List<RaisaAttachment> attachments;

  String? get error {
    if (summary.length < 4 || summary.length > 80) {
      return '简述须为 4–80 个字符';
    }
    if (details.length < 8 || details.length > 2000) {
      return '详细说明须为 8–2000 个字符';
    }
    if (contact.length > 64) return '联络代号不能超过 64 个字符';
    return raisaAttachmentError(attachments);
  }

  Map<String, Object> toWire() => {
    'category': category.code,
    'summary': summary,
    'details': details,
    'contact': contact,
    'includeDiagnostics': diagnostics != null,
    'appVersionLabel': appVersion,
    'diagnostics': ?diagnostics,
    if (attachments.isNotEmpty)
      'attachments': attachments.map((file) => file.toWire()).toList(),
  };

  String copyReport(Map<String, String> diagnosticLabels) => [
    '[RAISA 工单报文 // ${category.label}]',
    '简述：$summary',
    '说明：\n$details',
    if (contact.isNotEmpty) '联络代号：$contact',
    '提交版本：$appVersion',
    if (diagnostics != null) ...[
      '--- 终端诊断快照 ---',
      for (final entry in diagnostics!.entries)
        '${diagnosticLabels[entry.key] ?? entry.key}：${entry.value}',
    ],
    if (attachments.isNotEmpty)
      '附件（需手动添加）：${attachments.map((file) => file.name).join('、')}',
  ].join('\n');
}

class RaisaReceipt {
  RaisaReceipt(
    this.issueNumber,
    this.code,
    this.issueUrl,
    this.createdAt,
    this.summary,
    this.idempotencyKey,
  );

  factory RaisaReceipt.fromJson(Map<String, dynamic> json) => RaisaReceipt(
    json['issueNumber'] as int,
    json['ticketCode'] as String,
    Uri.parse(json['issueUrl'] as String),
    DateTime.parse(json['createdAt'] as String),
    json['summary'] as String,
    json['idempotencyKey'] as String,
  );

  final int issueNumber;
  final String code, summary, idempotencyKey;
  final Uri issueUrl;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'issueNumber': issueNumber,
    'ticketCode': code,
    'issueUrl': issueUrl.toString(),
    'createdAt': createdAt.toIso8601String(),
    'summary': summary,
    'idempotencyKey': idempotencyKey,
  };
}

class RaisaException implements Exception {
  const RaisaException(this.message);
  final String message;
}

class RaisaResult {
  const RaisaResult(
    this.receipt, {
    required this.deduplicated,
    this.savedLocally = false,
  });
  final RaisaReceipt receipt;
  final bool deduplicated, savedLocally;
}

class RaisaRelay {
  const RaisaRelay({
    this.client,
    this.endpoint = 'https://raisa.xiaotau.com/v1/raisa/tickets',
  });
  final http.Client? client;
  final String endpoint;

  Future<RaisaResult> send(RaisaDraft draft, String body, String key) async {
    final transport = client ?? http.Client();
    try {
      final request = http.Request('POST', Uri.parse(endpoint))
        ..followRedirects = false
        ..headers.addAll({
          'content-type': 'application/json; charset=utf-8',
          'accept': 'application/json',
          'x-anomicon-client': 'android',
          'x-anomicon-version': draft.appVersion,
          'x-idempotency-key': key,
        })
        ..body = body;
      final response = await transport
          .send(request)
          .then(http.Response.fromStream)
          .timeout(Duration(seconds: draft.attachments.isEmpty ? 15 : 45));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RaisaException(switch (response.statusCode) {
          413 => '附件超过中转限制，请移除一部分附件后重试。',
          429 => '工单提交过于频繁，请稍后重试。',
          400 || 422 => '工单内容未通过中转校验，请检查后重试。',
          final status => 'RAISA 中转暂不可用（HTTP $status）。',
        });
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json case {
        'issueNumber': final int number,
        'issueUrl': final String url,
        'ticketCode': final String code,
        'createdAt': final String timestamp,
      }) {
        final issue = Uri.tryParse(url);
        final createdAt = DateTime.tryParse(timestamp);
        if (number > 0 &&
            code.isNotEmpty &&
            issue != null &&
            issue.scheme == 'https' &&
            issue.host == 'github.com' &&
            issue.userInfo.isEmpty &&
            !issue.hasPort &&
            issue.path == '/Suixin04/Anomicon/issues/$number' &&
            createdAt != null) {
          return RaisaResult(
            RaisaReceipt(number, code, issue, createdAt, draft.summary, key),
            deduplicated: json['deduplicated'] == true,
          );
        }
      }
      throw const RaisaException('中转返回的签发回执无效。');
    } on http.ClientException {
      throw const RaisaException('无法连接 RAISA，请检查网络后重试。');
    } on TimeoutException {
      throw const RaisaException('等待 RAISA 响应超时，请重试。');
    } on FormatException {
      throw const RaisaException('中转返回的签发回执无效。');
    } finally {
      if (client == null) transport.close();
    }
  }
}

class RaisaStore {
  RaisaStore(this._prefs, {this.relay = const RaisaRelay()});
  final SharedPreferences _prefs;
  final RaisaRelay relay;
  static const _historyKey = 'raisa.receipts';
  static const _clientIdKey = 'raisa.clientId';
  final _requests = <String, Future<RaisaResult>>{};
  Future<String>? _clientId;

  List<RaisaReceipt> get history => List.unmodifiable(_history);
  late List<RaisaReceipt> _history = _loadHistory();
  Future<void> _saving = Future.value();

  List<RaisaReceipt> _loadHistory() {
    final saved = _prefs.getString(_historyKey);
    if (saved == null) return [];
    return (jsonDecode(saved) as List)
        .cast<Map<String, dynamic>>()
        .map(RaisaReceipt.fromJson)
        .toList();
  }

  Future<String> _loadClientId() async {
    final existing = _prefs.getString(_clientIdKey);
    if (existing != null) return existing;
    final random = Random.secure();
    final id = base64UrlEncode(List.generate(18, (_) => random.nextInt(256)));
    try {
      if (await _prefs.setString(_clientIdKey, id)) return id;
    } on PlatformException catch (error) {
      throw RaisaException('无法保存提交标识（${error.code}），请稍后重试。');
    }
    throw const RaisaException('无法保存提交标识，请稍后重试。');
  }

  Future<RaisaResult> submit(RaisaDraft draft) async {
    if (draft.error case final error?) throw RaisaException(error);
    final body = jsonEncode(draft.toWire());
    final request = _clientId ??= _loadClientId();
    final String clientId;
    try {
      clientId = await request;
    } on RaisaException {
      if (identical(request, _clientId)) _clientId = null;
      rethrow;
    }
    final key = sha256.convert(utf8.encode('$clientId:$body')).toString();
    final receipt = _history
        .where((item) => item.idempotencyKey == key)
        .firstOrNull;
    if (receipt != null) {
      return RaisaResult(receipt, deduplicated: true, savedLocally: true);
    }
    return _requests.putIfAbsent(key, () => _dispatch(draft, body, key));
  }

  Future<RaisaResult> _dispatch(
    RaisaDraft draft,
    String body,
    String key,
  ) async {
    try {
      final result = await relay.send(draft, body, key);
      final saved = await saveReceipt(result.receipt);
      return RaisaResult(
        result.receipt,
        deduplicated: result.deduplicated,
        savedLocally: saved,
      );
    } finally {
      _requests.remove(key);
    }
  }

  Future<bool> saveReceipt(RaisaReceipt receipt) {
    final saving = _saving.then((_) => _saveReceipt(receipt));
    _saving = saving.then<void>((_) {});
    return saving;
  }

  Future<bool> _saveReceipt(RaisaReceipt receipt) async {
    final updated = [
      receipt,
      ..._history.where((item) => item.issueNumber != receipt.issueNumber),
    ];
    try {
      final saved = await _prefs.setString(_historyKey, jsonEncode(updated));
      if (saved) _history = updated;
      return saved;
    } on PlatformException {
      return false;
    }
  }
}
