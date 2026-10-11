import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/services/update/update_download_source.dart';
import 'package:kazumi/utils/crypto.dart';

List<String> getUpdateDownloadUrlsFromAsset(
  Map<String, dynamic>? asset, {
  UpdateDownloadSource source = UpdateDownloadSource.mirror,
}) {
  if (asset == null) return [];
  return [
        if (source == UpdateDownloadSource.mirror) asset['mirror_download_url'],
        asset['browser_download_url'],
      ]
      .whereType<String>()
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toSet()
      .toList();
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

String getUpdateDownloadErrorMessage(Object error) {
  final causes = _errorChain(error).toList();
  final fileError = causes.whereType<FileSystemException>().firstOrNull;
  if (fileError != null) {
    final code = fileError.osError?.errorCode;
    final detail = fileError.toString().toLowerCase();
    if (code == 5 ||
        code == 13 ||
        detail.contains('permission denied') ||
        detail.contains('access is denied') ||
        detail.contains('operation not permitted')) {
      return '无法写入更新文件，请检查临时目录权限';
    }
    if (code == 112 ||
        code == 28 ||
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
        cause is TimeoutException,
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
    this.attemptTimeout = const Duration(seconds: 120),
    Future<String> Function(File)? hashFile,
  }) : _download = download,
       _hashFile = hashFile ?? calculateFileHash;

  final UpdateDownloadRequest _download;
  final void Function(String message, Object error, StackTrace stackTrace)
  logFailure;
  final Duration attemptTimeout;
  final Future<String> Function(File) _hashFile;

  Future<String> download({
    required List<String> urls,
    required String filePath,
    required String expectedHash,
    required CancelToken cancelToken,
    required ProgressCallback onReceiveProgress,
  }) async {
    void checkCancelled() {
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    }

    checkCancelled();
    final sources = urls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .take(2)
        .toList();
    final file = File(filePath);
    final hash = expectedHash.toLowerCase();
    var stage = 'prepare';
    try {
      if (sources.isEmpty) throw ArgumentError('没有可用的更新下载链接');
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
        throw ArgumentError('更新缺少有效的 SHA256 校验值');
      }
      if (await file.exists()) {
        stage = 'cache-verify';
        final localHash = await _hashFile(file);
        checkCancelled();
        if (localHash == hash) {
          onReceiveProgress(1, 1);
          return filePath;
        }
        stage = 'cache-delete';
        await file.delete();
      }
    } catch (error, stackTrace) {
      if (!cancelToken.isCancelled) {
        logFailure(
          'Update: stage=$stage path=$filePath | '
          '${describeUpdateDownloadError(error, stackTrace)}',
          error,
          stackTrace,
        );
      }
      rethrow;
    }

    for (var index = 0; index < sources.length; index++) {
      checkCancelled();
      final url = sources[index];
      final elapsed = Stopwatch()..start();
      Directory? attemptDir;
      stage = 'prepare';
      try {
        attemptDir = await file.parent.createTemp('kazumi-update-');
        checkCancelled();
        final partial = File('${attemptDir.path}/download.part');
        onReceiveProgress(0, 0);
        stage = 'download';
        await _downloadAttempt(url, partial.path, cancelToken, (
          received,
          total,
        ) {
          if (!cancelToken.isCancelled) {
            onReceiveProgress(received, total);
          }
        });
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
        logFailure(
          'Update: stage=$stage source=$url '
          'attempt=${index + 1}/${sources.length} '
          'elapsed=${elapsed.elapsedMilliseconds}ms path=$filePath | '
          '${describeUpdateDownloadError(error, stackTrace)}',
          error,
          stackTrace,
        );
        checkCancelled();
        if (index == sources.length - 1 ||
            (stage != 'download' && error is! UpdateIntegrityException) ||
            !_canFallback(error)) {
          rethrow;
        }
      } finally {
        if (attemptDir != null) {
          try {
            await attemptDir.delete(recursive: true);
          } catch (error, stackTrace) {
            logFailure(
              'Update: stage=cleanup source=$url path=${attemptDir.path} | '
              '${describeUpdateDownloadError(error, stackTrace)}',
              error,
              stackTrace,
            );
          }
        }
      }
    }
    throw StateError('没有可用的更新下载链接');
  }

  bool _canFallback(Object error) {
    final causes = _errorChain(error).toList();
    if (causes.any((cause) => cause is FileSystemException)) return false;
    if (error is NetworkException &&
            error.type == NetworkExceptionType.cancel ||
        error is DioException && error.type == DioExceptionType.cancel) {
      return false;
    }
    return error is UpdateIntegrityException ||
        error is NetworkException ||
        error is DioException ||
        error is TimeoutException ||
        error is SocketException ||
        error is HttpException ||
        error is HandshakeException;
  }

  Future<void> _downloadAttempt(
    String url,
    String path,
    CancelToken userToken,
    ProgressCallback onReceiveProgress,
  ) async {
    final attemptToken = CancelToken();
    var active = true;
    var timedOut = false;
    unawaited(
      userToken.whenCancel.then((error) {
        if (active) attemptToken.cancel(error);
      }),
    );
    if (userToken.isCancelled) throw userToken.cancelError!;
    final timer = Timer(attemptTimeout, () {
      timedOut = true;
      attemptToken.cancel(
        TimeoutException(
          '更新下载超过总时限 ${attemptTimeout.inSeconds}s',
          attemptTimeout,
        ),
      );
    });
    try {
      await _download(
        url,
        path,
        cancelToken: attemptToken,
        onReceiveProgress: (received, total) {
          if (active && !attemptToken.isCancelled && !userToken.isCancelled) {
            onReceiveProgress(received, total);
          }
        },
      );
      if (timedOut) throw attemptToken.cancelError!;
    } catch (error, stackTrace) {
      if (timedOut && !userToken.isCancelled) {
        Error.throwWithStackTrace(
          NetworkException(
            type: NetworkExceptionType.receiveTimeout,
            message: '更新下载超过总时限 ${attemptTimeout.inSeconds}s',
            rawError: error,
            stackTrace: stackTrace,
          ),
          stackTrace,
        );
      }
      rethrow;
    } finally {
      active = false;
      timer.cancel();
    }
  }
}
