import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/services/update/update_downloader.dart';

void main() {
  late HttpServer server;
  late Directory directory;
  late Dio dio;
  late String path;
  late List<String> requests;
  late List<Object> errors;
  final payload = utf8.encode('local HTTP verified update');
  final hash = sha256.convert(payload).toString();

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    directory = await Directory.systemTemp.createTemp('kazumi_update_http_');
    path = '${directory.path}/Kazumi_windows.zip';
    requests = [];
    errors = [];
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
      ),
    );
  });

  tearDown(() async {
    dio.close(force: true);
    await server.close(force: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  void serve(Future<void> Function(HttpRequest) handler) {
    server.listen((request) {
      requests.add(request.uri.path);
      unawaited(handler(request).catchError((Object _) {}));
    });
  }

  Future<String> download({
    String source = '/mirror',
    CancelToken? token,
    ProgressCallback? onProgress,
  }) =>
      UpdateDownloader(
        download:
            (
              url,
              partial, {
              required cancelToken,
              required onReceiveProgress,
            }) async {
              try {
                await dio.download(
                  url,
                  partial,
                  cancelToken: cancelToken,
                  onReceiveProgress: onReceiveProgress,
                );
              } on DioException catch (error) {
                throw await NetworkErrorMapper.mapException(error);
              }
            },
        logFailure: (message, error, stack) => errors.add(error),
      ).download(
        url: 'http://127.0.0.1:${server.port}$source',
        filePath: path,
        expectedHash: hash,
        cancelToken: token ?? CancelToken(),
        onReceiveProgress: onProgress ?? (_, _) {},
      );

  for (final source in ['/mirror', '/official']) {
    test('real Dio downloads only selected source $source', () async {
      serve((request) async {
        request.response.contentLength = payload.length;
        request.response.add(payload);
        await request.response.close();
      });
      expect(await download(source: source), path);
      expect(requests, [source]);
      expect(await File(path).readAsBytes(), payload);
      expect(errors, isEmpty);
      expect(await directory.list().length, 1);
    });

    test('real Dio selected source $source fails without switching', () async {
      serve((request) async {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
      });
      await expectLater(
        download(source: source),
        throwsA(
          isA<NetworkException>().having((e) => e.statusCode, 'status', 503),
        ),
      );
      expect(requests, [source]);
      expect(errors, hasLength(1));
      expect(await File(path).exists(), isFalse);
    });
  }

  test('real Dio receive idle timeout fails without another request', () async {
    dio.options.receiveTimeout = const Duration(milliseconds: 200);
    serve((request) async {
      request.response.contentLength = payload.length * 100;
      request.response.add([1]);
      await request.response.flush();
    });
    final token = CancelToken();
    await expectLater(
      download(token: token),
      throwsA(
        isA<NetworkException>().having(
          (e) => e.type,
          'type',
          NetworkExceptionType.receiveTimeout,
        ),
      ),
    );
    expect(token.isCancelled, isFalse);
    expect(requests, ['/mirror']);
    expect(await File(path).exists(), isFalse);
  });

  test(
    'real Dio continues while chunks arrive within receive idle timeout',
    () async {
      dio.options.receiveTimeout = const Duration(seconds: 1);
      serve((request) async {
        request.response.bufferOutput = false;
        request.response.contentLength = payload.length;
        for (var start = 0; start < payload.length; start += 5) {
          request.response.add(
            payload.sublist(
              start,
              start + 5 > payload.length ? payload.length : start + 5,
            ),
          );
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        await request.response.close();
      });
      final progress = <int>[];
      final elapsed = Stopwatch()..start();
      expect(
        await download(onProgress: (received, _) => progress.add(received)),
        path,
      );
      expect(elapsed.elapsed, greaterThan(const Duration(seconds: 1)));
      expect(
        progress.where((count) => count > 0).toSet().length,
        greaterThan(2),
      );
      expect(requests, ['/mirror']);
      expect(await File(path).readAsBytes(), payload);
    },
  );

  test(
    'real Dio user cancellation during body never starts another request',
    () async {
      final bodyFlushed = Completer<void>();
      serve((request) async {
        request.response.contentLength = payload.length * 100;
        request.response.add([1]);
        await request.response.flush();
        bodyFlushed.complete();
      });
      final token = CancelToken();
      final assertion = expectLater(
        download(token: token),
        throwsA(
          predicate(
            (error) =>
                error is DioException &&
                    error.type == DioExceptionType.cancel ||
                error is NetworkException &&
                    error.type == NetworkExceptionType.cancel,
          ),
        ),
      );
      await bodyFlushed.future;
      token.cancel('user cancelled during response body');
      await assertion;
      expect(requests, ['/mirror']);
      expect(await File(path).exists(), isFalse);
    },
  );
}
