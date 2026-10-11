import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/services/update/update_downloader.dart';

typedef _Download =
    Future<void> Function(
      String url,
      String path, {
      required CancelToken cancelToken,
      required ProgressCallback onReceiveProgress,
    });

const _mirror = 'https://mirror.example/Kazumi_windows.zip';
const _official = 'https://github.com/example/releases/Kazumi_windows.zip';
final _payload = utf8.encode('verified Kazumi Windows release');
final _hash = sha256.convert(_payload).toString();

void main() {
  late Directory directory;
  late String path;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kazumi_update_test_');
    path = '${directory.path}/Kazumi_windows.zip';
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  for (final source in [_mirror, _official]) {
    test('selected source $source succeeds in one verified download', () async {
      final harness = _Harness((
        url,
        partial, {
        required cancelToken,
        required onReceiveProgress,
      }) async {
        await File(partial).writeAsBytes(_payload);
        onReceiveProgress(_payload.length, _payload.length);
      });
      final progress = <(int, int)>[];
      expect(await harness.run(path, url: source, progress: progress), path);
      expect(harness.urls, [source]);
      expect(harness.paths.single, isNot(path));
      expect(await File(path).readAsBytes(), _payload);
      expect(progress, contains((_payload.length, _payload.length)));
      expect(await directory.list().length, 1);
      expect(harness.errors, isEmpty);
    });

    test('selected source $source failure never changes source', () async {
      final failure = _failure(NetworkExceptionType.unknown);
      final harness = _Harness((
        url,
        partial, {
        required cancelToken,
        required onReceiveProgress,
      }) async {
        await File(partial).writeAsString('partial download');
        throw failure;
      });
      await expectLater(harness.run(path, url: source), throwsA(same(failure)));
      expect(harness.urls, [source]);
      expect(harness.errors, [same(failure)]);
      expect(harness.messages.single, contains('SocketException'));
      expect(harness.messages.single, contains('original socket failure'));
      expect(await File(path).exists(), isFalse);
      expect(await directory.list().length, 0);
    });
  }

  test('receive timeout preserves original exception without retry', () async {
    final failure = _failure(NetworkExceptionType.receiveTimeout);
    final harness = _Harness((
      url,
      partial, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      throw failure;
    });
    await expectLater(harness.run(path), throwsA(same(failure)));
    expect(harness.urls, [_mirror]);
    expect(harness.errors.single, same(failure));
  });

  test('user cancellation during transfer stops the only request', () async {
    final token = CancelToken();
    final harness = _Harness((
      url,
      partial, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      token.cancel('user cancelled');
      throw await cancelToken.whenCancel;
    });
    await expectLater(harness.run(path, token: token), throwsA(_cancelled));
    expect(harness.urls, [_mirror]);
    expect(await File(path).exists(), isFalse);
  });

  test('pre-cancellation prevents a request', () async {
    final token = CancelToken()..cancel('cancelled before start');
    final harness = _Harness(_writeDownload);
    await expectLater(harness.run(path, token: token), throwsA(_cancelled));
    expect(harness.urls, isEmpty);
  });

  test('cancelling during downloaded SHA256 does not publish', () async {
    final token = CancelToken();
    final harness = _Harness(
      _writeDownload,
      hashFile: (file) async {
        token.cancel('cancelled during verification');
        return _hash;
      },
    );
    await expectLater(harness.run(path, token: token), throwsA(_cancelled));
    expect(harness.urls, [_mirror]);
    expect(await File(path).exists(), isFalse);
  });

  test('integrity mismatch is rejected without another source', () async {
    final harness = _Harness((
      url,
      partial, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      await File(partial).writeAsString('corrupt release');
    });
    await expectLater(
      harness.run(path),
      throwsA(isA<UpdateIntegrityException>()),
    );
    expect(harness.urls, [_mirror]);
    expect(await File(path).exists(), isFalse);
  });

  test('verified cache skips the network', () async {
    await File(path).writeAsBytes(_payload);
    final harness = _Harness(_writeDownload);
    expect(await harness.run(path), path);
    expect(harness.urls, isEmpty);
  });

  test(
    'unreadable cache logs original error and downloads a replacement',
    () async {
      await File(path).writeAsString('old cache');
      final failure = FileSystemException('cache read failed', path);
      final harness = _Harness(
        _writeDownload,
        hashFile: (file) async {
          if (file.path == path) throw failure;
          return sha256.convert(await file.readAsBytes()).toString();
        },
      );
      expect(await harness.run(path), path);
      expect(harness.urls, [_mirror]);
      expect(harness.errors.first, same(failure));
      expect(harness.messages.first, contains('stage=cache-verify'));
      expect(await File(path).readAsBytes(), _payload);
    },
  );

  test('cache hash mismatch downloads and verifies a replacement', () async {
    await File(path).writeAsString('outdated cached bytes');
    final harness = _Harness(_writeDownload);
    expect(await harness.run(path), path);
    expect(harness.urls, [_mirror]);
    expect(await File(path).readAsBytes(), _payload);
  });

  test('diagnostic descriptions retain original network and Dio stacks', () {
    final originalStack = StackTrace.fromString('original stack');
    final caughtStack = StackTrace.fromString('replacement caught stack');
    final dio = DioException(
      requestOptions: RequestOptions(path: _mirror),
      stackTrace: originalStack,
    );
    final network = NetworkException(
      type: NetworkExceptionType.unknown,
      message: 'unknown',
      rawError: dio,
      stackTrace: originalStack,
    );
    for (final error in [dio, network]) {
      final description = describeUpdateDownloadError(error, caughtStack);
      expect(description, contains('original stack'));
      expect(description, isNot(contains('replacement caught stack')));
    }
  });

  test(
    'cache deletion failure is logged and prevents network access',
    () async {
      await File(path).writeAsString('old cache');
      final failure = FileSystemException('cache read failed', path);
      final harness = _Harness(
        _writeDownload,
        hashFile: (file) async {
          await file.delete();
          await Directory(file.path).create();
          await File('${file.path}/retained').writeAsString('nonempty');
          throw failure;
        },
      );
      await expectLater(harness.run(path), throwsA(isA<FileSystemException>()));
      expect(harness.urls, isEmpty);
      expect(harness.errors.first, same(failure));
      expect(harness.messages.last, contains('stage=cache-delete'));
      expect(await File('$path/retained').readAsString(), 'nonempty');
    },
  );

  test(
    'cancellation during cache verification preserves cached bytes',
    () async {
      await File(path).writeAsBytes(_payload);
      final token = CancelToken();
      final harness = _Harness(
        _writeDownload,
        hashFile: (file) async {
          token.cancel('cancel cache verification');
          throw FileSystemException('interrupted hash read', file.path);
        },
      );
      await expectLater(harness.run(path, token: token), throwsA(_cancelled));
      expect(harness.urls, isEmpty);
      expect(await File(path).readAsBytes(), _payload);
    },
  );

  test('downloaded hash read error is preserved and cannot publish', () async {
    final failure = FileSystemException('download read failed', path);
    final harness = _Harness(
      _writeDownload,
      hashFile: (_) async => throw failure,
    );
    await expectLater(harness.run(path), throwsA(same(failure)));
    expect(harness.urls, [_mirror]);
    expect(harness.errors.single, same(failure));
    expect(await File(path).exists(), isFalse);
  });

  test('nested file write failure is retained in diagnostic logs', () async {
    final failure = NetworkException(
      type: NetworkExceptionType.unknown,
      message: 'unknown download failure',
      rawError: DioException(
        requestOptions: RequestOptions(path: _mirror),
        error: FileSystemException(
          'write failed',
          path,
          const OSError('Access is denied', 5),
        ),
      ),
    );
    final harness = _Harness((
      url,
      partial, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      throw failure;
    });
    await expectLater(harness.run(path), throwsA(same(failure)));
    expect(harness.urls, [_mirror]);
    expect(harness.messages.single, contains('FileSystemException'));
    expect(harness.messages.single, contains('Access is denied'));
  });

  test('empty URL and missing hash do not start network requests', () async {
    for (final inputs in [('', _hash), (_mirror, '')]) {
      final harness = _Harness(_writeDownload);
      await expectLater(
        harness.run(path, url: inputs.$1, hash: inputs.$2),
        throwsA(isA<ArgumentError>()),
      );
      expect(harness.urls, isEmpty);
    }
  });

  for (final scenario in [
    (true, 5, '无法写入更新文件，请检查临时目录权限'),
    (true, 112, '磁盘空间不足'),
    (true, 39, '磁盘空间不足'),
    (false, 1, '无法写入更新文件，请检查临时目录权限'),
    (false, 13, '无法写入更新文件，请检查临时目录权限'),
    (false, 28, '磁盘空间不足'),
    (true, 13, '更新文件读写失败，请查看错误详情'),
    (true, 28, '更新文件读写失败，请查看错误详情'),
    (false, 5, '更新文件读写失败，请查看错误详情'),
  ]) {
    test(
      'OS code ${scenario.$2} is interpreted for Windows=${scenario.$1}',
      () {
        final error = FileSystemException(
          'I/O failure',
          path,
          OSError('I/O failure', scenario.$2),
        );
        expect(
          getUpdateDownloadErrorMessage(error, isWindows: scenario.$1),
          scenario.$3,
        );
      },
    );
  }

  test('unknown, socket, integrity and timeout retain distinct messages', () {
    expect(
      getUpdateDownloadErrorMessage(
        const NetworkException(
          type: NetworkExceptionType.unknown,
          message: 'unknown',
        ),
      ),
      '下载失败，请查看错误详情',
    );
    expect(
      getUpdateDownloadErrorMessage(_failure(NetworkExceptionType.unknown)),
      '网络连接错误',
    );
    expect(
      getUpdateDownloadErrorMessage(const UpdateIntegrityException('a', 'b')),
      '文件完整性验证失败，可能是网络传输错误',
    );
    expect(
      getUpdateDownloadErrorMessage(
        _failure(NetworkExceptionType.receiveTimeout),
      ),
      '下载超时，请稍后重试',
    );
  });

  testWidgets('continuing progress can download beyond 120 seconds', (
    tester,
  ) async {
    final files = <String, List<int>>{};
    await IOOverrides.runZoned(() async {
      final token = CancelToken();
      final progress = <(int, int)>[];
      final harness = _Harness((
        url,
        partial, {
        required cancelToken,
        required onReceiveProgress,
      }) {
        final done = Completer<void>();
        Timer.periodic(const Duration(seconds: 1), (timer) {
          onReceiveProgress(timer.tick, 130);
          if (timer.tick == 130) {
            timer.cancel();
            files[partial] = _payload;
            done.complete();
          }
        });
        return done.future;
      }, hashFile: (_) async => _hash);
      String? result;
      final pending = harness
          .run(path, token: token, progress: progress)
          .then((value) => result = value);
      await tester.pump();
      await tester.pump(const Duration(seconds: 121));
      expect(result, isNull);
      expect(token.isCancelled, isFalse);
      expect(progress, contains((121, 130)));
      await tester.pump(const Duration(seconds: 9));
      await pending;
      expect(result, path);
      expect(files[path], _payload);
      expect(harness.urls, [_mirror]);
      expect(harness.errors, isEmpty);
    }, createFile: (name) => _MemoryFile(name, files));
  });
}

Future<void> _writeDownload(
  String url,
  String path, {
  required CancelToken cancelToken,
  required ProgressCallback onReceiveProgress,
}) async {
  await File(path).writeAsBytes(_payload);
}

final _cancelled = predicate<Object>(
  (error) =>
      error is DioException && error.type == DioExceptionType.cancel ||
      error is NetworkException && error.type == NetworkExceptionType.cancel,
);

NetworkException _failure(NetworkExceptionType type) => NetworkException(
  type: type,
  message: 'download failed',
  rawError: DioException(
    requestOptions: RequestOptions(path: _mirror),
    type: type == NetworkExceptionType.receiveTimeout
        ? DioExceptionType.receiveTimeout
        : DioExceptionType.unknown,
    error: const SocketException('original socket failure'),
  ),
);

class _Harness {
  _Harness(this.download, {this.hashFile});
  final _Download download;
  final Future<String> Function(File)? hashFile;
  final urls = <String>[];
  final paths = <String>[];
  final errors = <Object>[];
  final messages = <String>[];

  Future<String> run(
    String path, {
    String url = _mirror,
    String? hash,
    CancelToken? token,
    List<(int, int)>? progress,
  }) =>
      UpdateDownloader(
        download:
            (url, partial, {required cancelToken, required onReceiveProgress}) {
              urls.add(url);
              paths.add(partial);
              return download(
                url,
                partial,
                cancelToken: cancelToken,
                onReceiveProgress: onReceiveProgress,
              );
            },
        logFailure: (message, error, stack) {
          messages.add(message);
          errors.add(error);
        },
        hashFile: hashFile,
      ).download(
        url: url,
        filePath: path,
        expectedHash: hash ?? _hash,
        cancelToken: token ?? CancelToken(),
        onReceiveProgress: (received, total) =>
            progress?.add((received, total)),
      );
}

class _MemoryFile implements File {
  _MemoryFile(this.path, this.files);
  @override
  final String path;
  final Map<String, List<int>> files;
  @override
  Directory get parent => _MemoryDirectory('$path-parent', files);
  @override
  Future<bool> exists() async => files.containsKey(path);
  @override
  Future<File> rename(String newPath) async {
    files[newPath] = files.remove(path)!;
    return _MemoryFile(newPath, files);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryDirectory implements Directory {
  _MemoryDirectory(this.path, this.files);
  @override
  final String path;
  final Map<String, List<int>> files;
  @override
  Future<Directory> createTemp([String? prefix]) async =>
      _MemoryDirectory('$path/${prefix ?? ''}unique', files);
  @override
  Future<Directory> delete({bool recursive = false}) async {
    files.removeWhere((name, _) => name.startsWith('$path/'));
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
