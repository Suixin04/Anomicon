import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

class ArchiveDownloadProgress {
  const ArchiveDownloadProgress(this.downloadedBytes, this.totalBytes);

  final int downloadedBytes;
  final int totalBytes;

  double get fraction => downloadedBytes / totalBytes;
}

class ArchiveAssetIntegrity {
  static Future<bool> isValid(ArchiveAsset asset, File file) async {
    if (!await file.exists() ||
        await file.length() != asset.byteLength ||
        asset.byteLength < 20) {
      return false;
    }
    final handle = await file.open();
    try {
      final header = ByteData.sublistView(await handle.read(12));
      if (header.getUint32(0, Endian.little) != 0x46546c67 ||
          header.getUint32(4, Endian.little) != 2 ||
          header.getUint32(8, Endian.little) != asset.byteLength) {
        return false;
      }
    } finally {
      await handle.close();
    }
    return await sha256File(file) == asset.sha256;
  }

  static Future<String> sha256File(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();
}

class ArchiveDownloadState {
  const ArchiveDownloadState({
    this.progress,
    this.downloading = false,
    this.error,
  });

  final ArchiveDownloadProgress? progress;
  final bool downloading;
  final String? error;
}

class ArchiveAssetStore {
  ArchiveAssetStore(this._root, this._client);

  static Future<ArchiveAssetStore> create({http.Client? client}) async {
    final documents = await getApplicationDocumentsDirectory();
    return ArchiveAssetStore(
      Directory('${documents.path}/archive3d/v1/objects'),
      client ?? http.Client(),
    );
  }

  final Directory _root;
  final http.Client _client;
  final _jobs = <String, Completer<void>>{};
  final _states = <String, ValueNotifier<ArchiveDownloadState>>{};
  final installedRevision = ValueNotifier<int>(0);
  static const _timeout = Duration(seconds: 45);

  ValueNotifier<ArchiveDownloadState> stateOf(ArchiveAsset asset) =>
      _states.putIfAbsent(
        asset.assetId,
        () => ValueNotifier(const ArchiveDownloadState()),
      );

  Future<void> restoreProgress(ArchiveAsset asset) async {
    final state = stateOf(asset);
    final downloaded = await _downloadedBytes(_partialFor(asset));
    if (!state.value.downloading &&
        state.value.error == null &&
        downloaded > 0) {
      state.value = ArchiveDownloadState(
        progress: ArchiveDownloadProgress(downloaded, asset.byteLength),
      );
    }
  }

  Future<File?> installedFile(ArchiveAsset asset) async {
    final target = _fileFor(asset);
    if (await ArchiveAssetIntegrity.isValid(asset, target)) return target;
    return null;
  }

  void pause(ArchiveAsset asset) {
    final job = _jobs[asset.assetId];
    if (job != null && !job.isCompleted) job.complete();
  }

  Future<void> download(ArchiveAsset asset) async {
    if (_jobs.containsKey(asset.assetId)) return;
    final abort = Completer<void>();
    _jobs[asset.assetId] = abort;
    final state = stateOf(asset);
    state.value = ArchiveDownloadState(
      progress: state.value.progress,
      downloading: true,
    );
    final partial = _partialFor(asset);
    String? error;
    var published = false;
    try {
      final target = _fileFor(asset);
      if (await installedFile(asset) != null) return;
      await target.parent.create(recursive: true);
      var offset = await _downloadedBytes(partial);
      if (offset > asset.byteLength) {
        await partial.delete();
        offset = 0;
      }
      if (offset < asset.byteLength) {
        await _fetch(asset, partial, offset, abort, state);
      }
      if (abort.isCompleted) return;
      if (!await ArchiveAssetIntegrity.isValid(asset, partial)) {
        await partial.delete();
        throw const FormatException('模型校验失败。请重新下载。');
      }
      await partial.rename(target.path);
      published = true;
    } on FormatException catch (failure) {
      error = failure.message;
    } on TimeoutException {
      if (!abort.isCompleted) error = '模型下载超时，可以继续下载。';
    } on http.ClientException {
      if (!abort.isCompleted) error = '连接中断，可以继续下载。';
    } on SocketException {
      if (!abort.isCompleted) error = '连接中断，可以继续下载。';
    } on FileSystemException {
      error = '无法保存模型，请检查可用存储空间后重试。';
    } finally {
      if (!abort.isCompleted) abort.complete();
      final downloaded = await _downloadedBytes(partial);
      _jobs.remove(asset.assetId);
      state.value = ArchiveDownloadState(
        progress: downloaded > 0
            ? ArchiveDownloadProgress(downloaded, asset.byteLength)
            : null,
        error: error,
      );
      if (published) installedRevision.value++;
    }
  }

  Future<void> _fetch(
    ArchiveAsset asset,
    File partial,
    int offset,
    Completer<void> abort,
    ValueNotifier<ArchiveDownloadState> state,
  ) async {
    final request = http.AbortableRequest(
      'GET',
      Uri.parse(asset.downloadUrl),
      abortTrigger: abort.future,
    );
    request.headers[HttpHeaders.acceptEncodingHeader] = 'identity';
    if (offset > 0) request.headers[HttpHeaders.rangeHeader] = 'bytes=$offset-';
    final response = await _client.send(request).timeout(_timeout);
    if (response.statusCode == HttpStatus.ok) {
      offset = 0; // The server did not honor Range. Use its full response.
    } else if (response.statusCode != HttpStatus.partialContent ||
        response.headers[HttpHeaders.contentRangeHeader] !=
            'bytes $offset-${asset.byteLength - 1}/${asset.byteLength}') {
      throw FormatException('模型服务器响应异常（HTTP ${response.statusCode}）。请重试。');
    }
    if (abort.isCompleted) return;
    if (response.contentLength case final length?
        when length != asset.byteLength - offset) {
      throw const FormatException('模型服务器返回的文件长度不符。请重试。');
    }
    final handle = await partial.open(
      mode: offset > 0 ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in response.stream.timeout(_timeout)) {
        if (abort.isCompleted) break;
        if (offset + chunk.length > asset.byteLength) {
          await handle.truncate(0);
          throw const FormatException('模型服务器返回的文件长度不符。请重试。');
        }
        await handle.writeFrom(chunk);
        offset += chunk.length;
        state.value = ArchiveDownloadState(
          progress: ArchiveDownloadProgress(offset, asset.byteLength),
          downloading: true,
        );
      }
    } finally {
      await handle.close();
    }
    if (!abort.isCompleted && offset != asset.byteLength) {
      throw const FormatException('模型传输提前结束，可以继续下载。');
    }
  }

  Future<bool> delete(ArchiveAsset asset) async {
    final target = _fileFor(asset);
    final partial = _partialFor(asset);
    for (final file in [target, partial]) {
      if (await file.exists()) await file.delete();
    }
    stateOf(asset).value = const ArchiveDownloadState();
    installedRevision.value++;
    return true;
  }

  Future<int> _downloadedBytes(File file) async =>
      await file.exists() ? file.length() : 0;

  File _partialFor(ArchiveAsset asset) =>
      File('${_fileFor(asset).path}.download');

  File _fileFor(ArchiveAsset asset) =>
      File('${_root.path}/${asset.sha256.substring(0, 2)}/${asset.sha256}.glb');
}
