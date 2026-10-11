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
      String savePath, {
      required CancelToken cancelToken,
      required ProgressCallback onReceiveProgress,
    });

const _mirror = 'https://mirror.example/Kazumi_windows.zip';
const _official = 'https://github.com/example/releases/Kazumi_windows.zip';
final _payload = utf8.encode('verified Kazumi Windows release');
final _expectedHash = sha256.convert(_payload).toString();

void main() {
  late Directory directory;
  late String filePath;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kazumi_update_test_');
    filePath = '${directory.path}${Platform.pathSeparator}Kazumi_windows.zip';
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('asset sources prefer mirror and trim and deduplicate URLs', () {
    expect(getUpdateDownloadUrlsFromAsset(null), isEmpty);
    expect(getUpdateDownloadUrlsFromAsset({}), isEmpty);
    expect(
      getUpdateDownloadUrlsFromAsset({
        'mirror_download_url': '  $_mirror  ',
        'browser_download_url': ' $_official ',
      }),
      [_mirror, _official],
    );
    expect(
      getUpdateDownloadUrlsFromAsset({
        'mirror_download_url': '  $_official ',
        'browser_download_url': _official,
      }),
      [_official],
    );
    expect(
      getUpdateDownloadUrlsFromAsset({
        'mirror_download_url': '  ',
        'browser_download_url': _official,
      }),
      [_official],
    );
  });

  test('successful mirror is verified without requesting official', () async {
    final harness = _Harness((
      url,
      path, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      await File(path).writeAsBytes(_payload);
      onReceiveProgress(_payload.length, _payload.length);
    });
    final progress = <(int, int)>[];

    final result = await harness.run(filePath, progress: progress);

    expect(result, filePath);
    expect(harness.urls, [_mirror]);
    expect(harness.paths.single, isNot(filePath));
    expect(await File(result).readAsBytes(), _payload);
    expect(progress, contains((_payload.length, _payload.length)));
    expect(harness.errors, isEmpty);
  });

  for (final type in [
    NetworkExceptionType.unknown,
    NetworkExceptionType.receiveTimeout,
  ]) {
    test(
      '$type mirror failure falls back to verified official asset',
      () async {
        final failure = _networkFailure(type, 'mirror disconnected');
        final harness = _Harness((
          url,
          path, {
          required cancelToken,
          required onReceiveProgress,
        }) async {
          if (url == _mirror) {
            await File(path).writeAsString('partial mirror download');
            throw failure;
          }
          await File(path).writeAsBytes(_payload);
        });

        expect(await harness.run(filePath), filePath);
        expect(harness.urls, [_mirror, _official]);
        expect(harness.paths.toSet(), hasLength(2));
        expect(harness.paths, everyElement(isNot(filePath)));
        expect(harness.errors, [same(failure)]);
        expect(await File(filePath).readAsBytes(), _payload);
      },
    );
  }

  test(
    'both sources fail once and preserve last error and original causes',
    () async {
      final mirrorFailure = _networkFailure(
        NetworkExceptionType.unknown,
        'original mirror transport error',
      );
      final officialFailure = _networkFailure(
        NetworkExceptionType.connectionError,
        'original official socket error',
      );
      final harness = _Harness((
        url,
        path, {
        required cancelToken,
        required onReceiveProgress,
      }) async {
        throw url == _mirror ? mirrorFailure : officialFailure;
      });

      await expectLater(harness.run(filePath), throwsA(same(officialFailure)));

      expect(harness.urls, [_mirror, _official]);
      expect(harness.errors, [same(mirrorFailure), same(officialFailure)]);
      expect(
        (harness.errors[0] as NetworkException).rawError,
        same(mirrorFailure.rawError),
      );
      expect(
        (harness.errors[1] as NetworkException).rawError,
        same(officialFailure.rawError),
      );
      expect(harness.messages[0], contains('original mirror transport error'));
      expect(harness.messages[1], contains('original official socket error'));
      expect(harness.messages, everyElement(contains('SocketException')));
      expect(await File(filePath).exists(), isFalse);
    },
  );

  test('cancelling an active mirror never requests official', () async {
    final userToken = CancelToken();
    final harness = _Harness((
      url,
      path, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      userToken.cancel('user cancelled download');
      throw await cancelToken.whenCancel;
    });

    await expectLater(
      harness.run(filePath, token: userToken),
      throwsA(_isCancellation),
    );
    expect(harness.urls, [_mirror]);
    expect(await File(filePath).exists(), isFalse);
  });

  test('a pre-cancelled token makes no network request', () async {
    final token = CancelToken()..cancel('cancelled before start');
    final harness = _Harness((
      url,
      path, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      fail('pre-cancelled download must not start');
    });

    await expectLater(
      harness.run(filePath, token: token),
      throwsA(_isCancellation),
    );
    expect(harness.urls, isEmpty);
  });

  test(
    'cancellation at failure boundary suppresses official fallback',
    () async {
      final token = CancelToken();
      final failure = _networkFailure(
        NetworkExceptionType.receiveTimeout,
        'mirror timed out',
      );
      final harness = _Harness((
        url,
        path, {
        required cancelToken,
        required onReceiveProgress,
      }) async {
        token.cancel('cancel as mirror fails');
        throw failure;
      });

      await expectLater(
        harness.run(filePath, token: token),
        throwsA(_isCancellation),
      );
      expect(harness.urls, [_mirror]);
      expect(await File(filePath).exists(), isFalse);
    },
  );

  test(
    'cancellation during SHA256 verification cannot publish a file',
    () async {
      final token = CancelToken();
      final harness = _Harness(
        (url, path, {required cancelToken, required onReceiveProgress}) async {
          await File(path).writeAsBytes(_payload);
        },
        hashFile: (file) async {
          final bytes = await file.readAsBytes();
          token.cancel('cancelled during integrity check');
          return sha256.convert(bytes).toString();
        },
      );

      await expectLater(
        harness.run(filePath, token: token),
        throwsA(_isCancellation),
      );
      expect(harness.urls, [_mirror]);
      expect(await File(filePath).exists(), isFalse);
    },
  );

  test('a network cancellation exception never triggers fallback', () async {
    final failure = _networkFailure(
      NetworkExceptionType.cancel,
      'transport cancellation',
    );
    final harness = _Harness((
      url,
      path, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      throw failure;
    });

    await expectLater(harness.run(filePath), throwsA(same(failure)));
    expect(harness.urls, [_mirror]);
  });

  test(
    'nested filesystem failure is not retried as an unknown network error',
    () async {
      final cause = FileSystemException(
        'write denied',
        filePath,
        const OSError('Access is denied', 5),
      );
      final failure = NetworkException(
        type: NetworkExceptionType.unknown,
        message: 'unknown download error',
        rawError: DioException(
          requestOptions: RequestOptions(path: _mirror),
          error: cause,
        ),
      );
      final harness = _Harness((
        url,
        path, {
        required cancelToken,
        required onReceiveProgress,
      }) async {
        throw failure;
      });

      await expectLater(harness.run(filePath), throwsA(same(failure)));
      expect(harness.urls, [_mirror]);
      expect(harness.errors, [same(failure)]);
      expect(harness.messages.single, contains('FileSystemException'));
      expect(harness.messages.single, contains('Access is denied'));
      expect(await File(filePath).exists(), isFalse);
    },
  );

  test('direct filesystem failure is not retried', () async {
    final failure = FileSystemException('disk full', filePath);
    final harness = _Harness((
      url,
      path, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      throw failure;
    });

    await expectLater(harness.run(filePath), throwsA(same(failure)));
    expect(harness.urls, [_mirror]);
  });

  test(
    'mirror integrity mismatch falls back to verified official bytes',
    () async {
      final harness = _Harness((
        url,
        path, {
        required cancelToken,
        required onReceiveProgress,
      }) async {
        await File(path).writeAsBytes(
          url == _mirror ? utf8.encode('corrupt mirror bytes') : _payload,
        );
      });

      expect(await harness.run(filePath), filePath);
      expect(harness.urls, [_mirror, _official]);
      expect(harness.errors, hasLength(1));
      expect(await File(filePath).readAsBytes(), _payload);
    },
  );

  test(
    'integrity mismatch from both sources never publishes the file',
    () async {
      final harness = _Harness((
        url,
        path, {
        required cancelToken,
        required onReceiveProgress,
      }) async {
        await File(path).writeAsString('corrupt download from $url');
      });

      await expectLater(harness.run(filePath), throwsA(isA<Exception>()));
      expect(harness.urls, [_mirror, _official]);
      expect(harness.errors, hasLength(2));
      expect(await File(filePath).exists(), isFalse);
    },
  );

  test('verified cached file skips both network sources', () async {
    await File(filePath).writeAsBytes(_payload);
    final harness = _Harness((
      url,
      path, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      fail('verified cached file must not be downloaded');
    });

    expect(await harness.run(filePath), filePath);
    expect(harness.urls, isEmpty);
    expect(await File(filePath).readAsBytes(), _payload);
  });

  test('total attempt timeout cancels only mirror and falls back', () async {
    CancelToken? mirrorToken;
    final token = CancelToken();
    final mirrorCancelled = Completer<void>();
    final harness = _Harness((
      url,
      path, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      if (url == _mirror) {
        mirrorToken = cancelToken;
        final cancellation = await cancelToken.whenCancel;
        mirrorCancelled.complete();
        throw cancellation;
      }
      expect(mirrorToken!.isCancelled, isTrue);
      expect(token.isCancelled, isFalse);
      await File(path).writeAsBytes(_payload);
    }, attemptTimeout: const Duration(milliseconds: 100));

    expect(await harness.run(filePath, token: token), filePath);
    await mirrorCancelled.future;
    expect(harness.urls, [_mirror, _official]);
    expect(token.isCancelled, isFalse);
    expect(harness.errors, hasLength(1));
    expect(await File(filePath).readAsBytes(), _payload);
  });

  test('fallback resets progress before reporting official progress', () async {
    final progress = <(int, int)>[];
    final harness = _Harness((
      url,
      path, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      if (url == _mirror) {
        onReceiveProgress(75, 100);
        throw _networkFailure(NetworkExceptionType.unknown, 'mirror stopped');
      }
      onReceiveProgress(10, 100);
      await File(path).writeAsBytes(_payload);
      onReceiveProgress(100, 100);
    });

    await harness.run(filePath, progress: progress);

    final mirrorProgress = progress.indexOf((75, 100));
    final officialProgress = progress.indexOf((10, 100));
    expect(mirrorProgress, greaterThanOrEqualTo(0));
    expect(officialProgress, greaterThan(mirrorProgress));
    expect(
      progress.sublist(mirrorProgress + 1, officialProgress),
      contains((0, 0)),
    );
  });

  for (final code in [5, 13, 112, 28, 999]) {
    test('filesystem OS error $code has an accurate download message', () {
      final failure = NetworkException(
        type: NetworkExceptionType.unknown,
        message: 'unknown',
        rawError: DioException(
          requestOptions: RequestOptions(path: _mirror),
          error: FileSystemException(
            'write failed',
            filePath,
            OSError('OS write error', code),
          ),
        ),
      );
      final expectedMessage = switch (code) {
        5 || 13 => '无法写入更新文件，请检查临时目录权限',
        112 || 28 => '磁盘空间不足',
        _ => '更新文件读写失败，请查看错误详情',
      };
      expect(getUpdateDownloadErrorMessage(failure), expectedMessage);
    });
  }

  test(
    'unknown without an identified cause is not called a network failure',
    () {
      const failure = NetworkException(
        type: NetworkExceptionType.unknown,
        message: 'unidentified failure',
      );
      expect(getUpdateDownloadErrorMessage(failure), '下载失败，请查看错误详情');
    },
  );

  test('unknown with a socket cause is identified as network failure', () {
    expect(
      getUpdateDownloadErrorMessage(
        _networkFailure(NetworkExceptionType.unknown, 'connection reset'),
      ),
      '网络连接错误',
    );
  });

  test('integrity and timeout messages explain their distinct failures', () {
    expect(
      getUpdateDownloadErrorMessage(
        const UpdateIntegrityException('expected hash', 'actual hash'),
      ),
      '文件完整性验证失败，可能是网络传输错误',
    );
    expect(
      getUpdateDownloadErrorMessage(
        _networkFailure(
          NetworkExceptionType.receiveTimeout,
          'receive timed out',
        ),
      ),
      '下载超时，请稍后重试',
    );
  });

  test('empty source list fails before requesting a download', () async {
    final harness = _Harness((
      url,
      path, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      fail('empty sources cannot request a download');
    });

    await expectLater(
      harness.run(filePath, sourceUrls: []),
      throwsA(isA<ArgumentError>()),
    );
    expect(harness.urls, isEmpty);
    expect(await File(filePath).exists(), isFalse);
  });

  test('an official-only asset is downloaded and verified directly', () async {
    expect(
      getUpdateDownloadUrlsFromAsset({'browser_download_url': _official}),
      [_official],
    );
    final harness = _Harness((
      url,
      path, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      await File(path).writeAsBytes(_payload);
    });

    expect(await harness.run(filePath, sourceUrls: [_official]), filePath);
    expect(harness.urls, [_official]);
    expect(await File(filePath).readAsBytes(), _payload);
  });

  test('source list is deduplicated and bounded to two attempts', () async {
    final failure = _networkFailure(
      NetworkExceptionType.connectionError,
      'all sources unavailable',
    );
    final harness = _Harness((
      url,
      path, {
      required cancelToken,
      required onReceiveProgress,
    }) async {
      throw failure;
    });

    await expectLater(
      harness.run(
        filePath,
        sourceUrls: [
          ' $_mirror ',
          _mirror,
          _official,
          'https://third.example/file.zip',
        ],
      ),
      throwsA(same(failure)),
    );
    expect(harness.urls, [_mirror, _official]);
    expect(harness.errors, hasLength(2));
  });

  for (final invalidHash in ['', 'sha256:not-a-valid-hash']) {
    test('invalid SHA256 "$invalidHash" fails without network', () async {
      final harness = _Harness((
        url,
        path, {
        required cancelToken,
        required onReceiveProgress,
      }) async {
        fail('download without valid SHA256 must not start');
      });

      await expectLater(
        harness.run(filePath, expectedHash: invalidHash),
        throwsA(isA<ArgumentError>()),
      );
      expect(harness.urls, isEmpty);
      expect(await File(filePath).exists(), isFalse);
    });
  }

  test(
    'failure reading downloaded bytes for SHA256 does not change source',
    () async {
      final failure = FileSystemException(
        'cannot read download',
        filePath,
        const OSError('Access is denied', 5),
      );
      final harness = _Harness((
        url,
        path, {
        required cancelToken,
        required onReceiveProgress,
      }) async {
        await File(path).writeAsBytes(_payload);
      }, hashFile: (_) async => throw failure);

      await expectLater(harness.run(filePath), throwsA(same(failure)));
      expect(harness.urls, [_mirror]);
      expect(harness.errors, [same(failure)]);
      expect(harness.messages.single, contains('stage=verify'));
      expect(await File(filePath).exists(), isFalse);
    },
  );

  test(
    'failure reading cached SHA256 preserves cache and makes no request',
    () async {
      await File(filePath).writeAsBytes(_payload);
      final failure = FileSystemException('cache read denied', filePath);
      final harness = _Harness((
        url,
        path, {
        required cancelToken,
        required onReceiveProgress,
      }) async {
        fail('unreadable cache must not trigger a network fallback');
      }, hashFile: (_) async => throw failure);

      await expectLater(harness.run(filePath), throwsA(same(failure)));
      expect(harness.urls, isEmpty);
      expect(harness.messages.single, contains('stage=cache-verify'));
      expect(await File(filePath).readAsBytes(), _payload);
    },
  );
}

final _isCancellation = predicate<Object>(
  (error) =>
      error is DioException && error.type == DioExceptionType.cancel ||
      error is NetworkException && error.type == NetworkExceptionType.cancel,
);

NetworkException _networkFailure(NetworkExceptionType type, String message) {
  final dioType = switch (type) {
    NetworkExceptionType.cancel => DioExceptionType.cancel,
    NetworkExceptionType.receiveTimeout => DioExceptionType.receiveTimeout,
    NetworkExceptionType.connectionError => DioExceptionType.connectionError,
    _ => DioExceptionType.unknown,
  };
  return NetworkException(
    type: type,
    message: message,
    rawError: DioException(
      requestOptions: RequestOptions(path: _mirror),
      type: dioType,
      error: SocketException(message),
      message: message,
    ),
    stackTrace: StackTrace.current,
  );
}

class _Harness {
  _Harness(
    this.download, {
    this.attemptTimeout = const Duration(seconds: 120),
    this.hashFile,
  });

  final _Download download;
  final Duration attemptTimeout;
  final Future<String> Function(File)? hashFile;
  final urls = <String>[];
  final paths = <String>[];
  final errors = <Object>[];
  final messages = <String>[];

  Future<String> run(
    String filePath, {
    CancelToken? token,
    List<(int, int)>? progress,
    List<String> sourceUrls = const [_mirror, _official],
    String? expectedHash,
  }) {
    final downloader = UpdateDownloader(
      download:
          (url, savePath, {required cancelToken, required onReceiveProgress}) {
            urls.add(url);
            paths.add(savePath);
            return download(
              url,
              savePath,
              cancelToken: cancelToken,
              onReceiveProgress: onReceiveProgress,
            );
          },
      logFailure: (message, error, stackTrace) {
        messages.add(message);
        errors.add(error);
      },
      attemptTimeout: attemptTimeout,
      hashFile: hashFile,
    );
    return downloader.download(
      urls: sourceUrls,
      filePath: filePath,
      expectedHash: expectedHash ?? _expectedHash,
      cancelToken: token ?? CancelToken(),
      onReceiveProgress: (received, total) => progress?.add((received, total)),
    );
  }
}
