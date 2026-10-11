import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/services/update/update_download_source.dart';
import 'package:kazumi/utils/crypto.dart';

String getUpdateDownloadUrlFromAsset(
  Map<String, dynamic>? asset, {
  UpdateDownloadSource source = UpdateDownloadSource.mirror,
}) {
  final key = source == UpdateDownloadSource.mirror
      ? 'mirror_download_url'
      : 'browser_download_url';
  final url = asset?[key];
  return url is String ? url.trim() : '';
}

typedef UpdateDownloadRequest =
    Future<void> Function(
      String url,
      String savePath, {
      required CancelToken cancelToken,
      required ProgressCallback onReceiveProgress,
    });

class UpdateIntegrityException implements Exception {
  const UpdateIntegrityException(this.expected, this.actual);

  final String expected;
  final String actual;

  @override
  String toString() => '文件完整性验证失败: 期望 $expected，实际 $actual';
}

Object? _underlyingError(Object error) => switch (error) {
  NetworkException() => error.rawError,
  DioException() => error.error,
  _ => null,
};

Iterable<Object> _errorChain(Object error) sync* {
  final seen = Set<Object>.identity();
  Object? current = error;
  while (current != null && seen.add(current)) {
    yield current;
    current = _underlyingError(current);
  }
}

String describeUpdateDownloadError(Object error, StackTrace stackTrace) {
  final causes = _errorChain(error)
      .map((cause) {
        if (cause is DioException) {
          return 'DioException(type=${cause.type.name}, '
              'status=${cause.response?.statusCode}, message=${cause.message})';
        }
        return '${cause.runtimeType}: $cause';
      })
      .join(' -> ');
  final originalStack = error is NetworkException
      ? error.stackTrace ?? stackTrace
      : error is DioException
      ? error.stackTrace
      : stackTrace;
  return '$causes | stack=$originalStack';
}

String getUpdateDownloadErrorMessage(Object error, {bool? isWindows}) {
  final causes = _errorChain(error).toList();
  final fileError = causes.whereType<FileSystemException>().firstOrNull;
  if (fileError != null) {
    final code = fileError.osError?.errorCode;
    final detail = fileError.toString().toLowerCase();
    final windows = isWindows ?? Platform.isWindows;
    if ((windows ? code == 5 : code == 1 || code == 13) ||
        detail.contains('permission denied') ||
        detail.contains('access is denied') ||
        detail.contains('operation not permitted')) {
      return '无法写入更新文件，请检查临时目录权限';
    }
    if ((windows ? code == 112 || code == 39 : code == 28) ||
        detail.contains('no space left') ||
        detail.contains('disk full')) {
      return '磁盘空间不足';
    }
    return '更新文件读写失败，请查看错误详情';
  }
  if (error is UpdateIntegrityException) {
    return '文件完整性验证失败，可能是网络传输错误';
  }
  if (causes.any(
    (cause) =>
        cause is NetworkException &&
            const [
              NetworkExceptionType.connectionTimeout,
              NetworkExceptionType.receiveTimeout,
              NetworkExceptionType.sendTimeout,
            ].contains(cause.type) ||
        cause is DioException &&
            const [
              DioExceptionType.connectionTimeout,
              DioExceptionType.receiveTimeout,
              DioExceptionType.sendTimeout,
            ].contains(cause.type),
  )) {
    return '下载超时，请稍后重试';
  }
  if (causes.any(
    (cause) =>
        cause is SocketException ||
        cause is HttpException ||
        cause is HandshakeException ||
        cause is NetworkException &&
            const [
              NetworkExceptionType.connectionError,
              NetworkExceptionType.badResponse,
              NetworkExceptionType.badCertificate,
            ].contains(cause.type),
  )) {
    return '网络连接错误';
  }
  return '下载失败，请查看错误详情';
}

class UpdateDownloader {
  UpdateDownloader({
    required UpdateDownloadRequest download,
    required this.logFailure,
    Future<String> Function(File)? hashFile,
  }) : _download = download,
       _hashFile = hashFile ?? calculateFileHash;

  final UpdateDownloadRequest _download;
  final Future<String> Function(File) _hashFile;
  final void Function(String message, Object error, StackTrace stackTrace)
  logFailure;

  Future<String> download({
    required String url,
    required String filePath,
    required String expectedHash,
    required CancelToken cancelToken,
    required ProgressCallback onReceiveProgress,
  }) async {
    void checkCancelled() {
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    }

    final file = File(filePath);
    final hash = expectedHash.toLowerCase();
    final elapsed = Stopwatch()..start();
    Directory? downloadDir;
    var stage = 'prepare';
    void log(Object error, StackTrace stackTrace) => logFailure(
      'Update: stage=$stage source=$url '
      'elapsed=${elapsed.elapsedMilliseconds}ms path=$filePath | '
      '${describeUpdateDownloadError(error, stackTrace)}',
      error,
      stackTrace,
    );

    try {
      checkCancelled();
      if (url.trim().isEmpty) throw ArgumentError('没有可用的更新下载链接');
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
        throw ArgumentError('更新缺少有效的 SHA256 校验值');
      }
      if (await file.exists()) {
        stage = 'cache-verify';
        String? localHash;
        try {
          localHash = await _hashFile(file);
        } catch (error, stackTrace) {
          checkCancelled();
          log(error, stackTrace);
        }
        checkCancelled();
        if (localHash == hash) {
          onReceiveProgress(1, 1);
          return filePath;
        }
        stage = 'cache-delete';
        await file.delete();
      }
      checkCancelled();
      stage = 'prepare';
      downloadDir = await file.parent.createTemp('kazumi-update-');
      checkCancelled();
      final partial = File('${downloadDir.path}/download.part');
      onReceiveProgress(0, 0);
      stage = 'download';
      await _download(
        url,
        partial.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (!cancelToken.isCancelled) onReceiveProgress(received, total);
        },
      );
      checkCancelled();
      stage = 'verify';
      final downloadedHash = await _hashFile(partial);
      checkCancelled();
      if (downloadedHash != hash) {
        throw UpdateIntegrityException(hash, downloadedHash);
      }
      stage = 'publish';
      await partial.rename(filePath);
      checkCancelled();
      onReceiveProgress(1, 1);
      return filePath;
    } catch (error, stackTrace) {
      if (!cancelToken.isCancelled) log(error, stackTrace);
      checkCancelled();
      rethrow;
    } finally {
      if (downloadDir != null) {
        try {
          await downloadDir.delete(recursive: true);
        } catch (error, stackTrace) {
          stage = 'cleanup';
          log(error, stackTrace);
        }
      }
    }
  }
}
