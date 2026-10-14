import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kazumi/request/clients/download_http_client.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/update/update_download_source.dart';
import 'package:kazumi/utils/crypto.dart';

String getUpdateDownloadUrlFromAsset(
    Map<String, dynamic>? asset, UpdateDownloadSource source) {
  final url = asset?[switch (source) {
    UpdateDownloadSource.mirror => 'mirror_download_url',
    UpdateDownloadSource.github => 'browser_download_url',
  }];
  return url is String ? url.trim() : '';
}

class UpdateIntegrityException implements Exception {
  const UpdateIntegrityException(this.expected, this.actual);

  final String expected;
  final String actual;

  @override
  String toString() => '文件完整性验证失败: 期望 $expected，实际 $actual';
}

Iterable<Object> _errorChain(Object error) sync* {
  final seen = Set<Object>.identity();
  Object? current = error;
  while (current != null && seen.add(current)) {
    yield current;
    current = switch (current) {
      NetworkException() => current.rawError,
      DioException() => current.error,
      _ => null,
    };
  }
}

String describeUpdateDownloadError(Object error, StackTrace stackTrace) {
  final causes = _errorChain(error).map((cause) => switch (cause) {
        DioException() => 'DioException(type=${cause.type.name}, '
            'status=${cause.response?.statusCode}, message=${cause.message})',
        _ => '${cause.runtimeType}: $cause',
      });
  final stack =
      error is NetworkException ? error.stackTrace ?? stackTrace : stackTrace;
  return '${causes.join(' -> ')} | stack=$stack';
}

String getUpdateDownloadErrorMessage(Object error) {
  final causes = _errorChain(error).toList();
  final fileError = causes.whereType<FileSystemException>().firstOrNull;
  if (fileError != null) {
    final code = fileError.osError?.errorCode;
    final windows = Platform.isWindows;
    if (windows ? code == 5 : code == 1 || code == 13) {
      return '无法写入更新文件，请检查临时目录权限';
    }
    if (windows ? code == 112 || code == 39 : code == 28) {
      return '磁盘空间不足';
    }
    return '更新文件读写失败';
  }
  if (error is UpdateIntegrityException) {
    return '文件完整性验证失败，可能是网络传输错误';
  }
  final networkType =
      causes.whereType<NetworkException>().firstOrNull?.type;
  switch (networkType) {
    case NetworkExceptionType.connectionTimeout ||
          NetworkExceptionType.receiveTimeout ||
          NetworkExceptionType.sendTimeout:
      return '下载超时，请稍后重试';
    case NetworkExceptionType.connectionError ||
          NetworkExceptionType.badResponse ||
          NetworkExceptionType.badCertificate:
      return '网络连接错误';
    default:
      if (causes.any((cause) =>
          cause is SocketException ||
          cause is HttpException ||
          cause is HandshakeException)) {
        return '网络连接错误';
      }
      return '下载失败';
  }
}

/// Reuses a verified cached file; otherwise downloads into a private temp
/// directory and only moves the file to [filePath] after the hash matches.
Future<String> downloadUpdateFile({
  required String url,
  required String filePath,
  required String expectedHash,
  required CancelToken cancelToken,
  required ProgressCallback onReceiveProgress,
}) async {
  // Dio cancellation does not cover filesystem work or hashing.
  void checkCancelled() {
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
  }

  final hash = expectedHash.toLowerCase();
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
    throw ArgumentError('更新缺少有效的 SHA256 校验值');
  }

  final file = File(filePath);
  if (await file.exists()) {
    String? localHash;
    try {
      localHash = await calculateFileHash(file);
    } catch (e) {
      KazumiLogger().w('Update: cached file verification failed', error: e);
    }
    checkCancelled();
    if (localHash == hash) {
      onReceiveProgress(1, 1);
      return filePath;
    }
    await file.delete();
  }

  checkCancelled();
  final downloadDir = await file.parent.createTemp('kazumi-update-');
  try {
    final partial = File('${downloadDir.path}/download.part');
    await DownloadHttpClient.instance.download(
      url,
      partial.path,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (!cancelToken.isCancelled) onReceiveProgress(received, total);
      },
    );
    checkCancelled();
    final downloadedHash = await calculateFileHash(partial);
    checkCancelled();
    if (downloadedHash != hash) {
      throw UpdateIntegrityException(hash, downloadedHash);
    }
    await partial.rename(filePath);
    onReceiveProgress(1, 1);
    return filePath;
  } finally {
    try {
      await downloadDir.delete(recursive: true);
    } catch (e) {
      KazumiLogger().w('Update: temp download cleanup failed', error: e);
    }
  }
}
