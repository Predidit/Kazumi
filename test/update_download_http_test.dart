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
  late String filePath;
  late List<String> requests;
  late List<Object> errors;
  final payload = utf8.encode('local HTTP verified update');
  final expectedHash = sha256.convert(payload).toString();

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    directory = await Directory.systemTemp.createTemp('kazumi_update_http_');
    filePath = '${directory.path}/Kazumi_windows.zip';
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
    await directory.delete(recursive: true);
  });

  void serve(Future<void> Function(HttpRequest) handler) {
    server.listen((request) {
      requests.add(request.uri.path);
      unawaited(handler(request).catchError((Object _) {}));
    });
  }

  Future<String> download({
    CancelToken? token,
    Duration timeout = const Duration(seconds: 2),
    ProgressCallback? onProgress,
  }) {
    final base = 'http://127.0.0.1:${server.port}';
    return UpdateDownloader(
      download:
          (
            url,
            path, {
            required cancelToken,
            required onReceiveProgress,
          }) async {
            try {
              await dio.download(
                url,
                path,
                cancelToken: cancelToken,
                onReceiveProgress: onReceiveProgress,
              );
            } on DioException catch (error) {
              throw await NetworkErrorMapper.mapException(error);
            }
          },
      logFailure: (message, error, stackTrace) => errors.add(error),
      attemptTimeout: timeout,
    ).download(
      urls: ['$base/mirror', '$base/official'],
      filePath: filePath,
      expectedHash: expectedHash,
      cancelToken: token ?? CancelToken(),
      onReceiveProgress: onProgress ?? (_, _) {},
    );
  }

  test(
    'real Dio mirror HTTP failure falls back to verified official',
    () async {
      serve((request) async {
        if (request.uri.path == '/mirror') {
          request.response.statusCode = HttpStatus.serviceUnavailable;
        } else {
          request.response.contentLength = payload.length;
          request.response.add(payload);
        }
        await request.response.close();
      });

      expect(await download(), filePath);
      expect(requests, ['/mirror', '/official']);
      expect(
        errors.single,
        isA<NetworkException>().having((e) => e.statusCode, 'status', 503),
      );
      expect(await File(filePath).readAsBytes(), payload);
      expect(await directory.list().length, 1);
    },
  );

  test(
    'real Dio stalled body is cancelled and official uses a clean file',
    () async {
      serve((request) async {
        if (request.uri.path == '/mirror') {
          request.response.contentLength = payload.length * 100;
          request.response.add([1]);
          await request.response.flush();
          return;
        }
        request.response.contentLength = payload.length;
        request.response.add(payload);
        await request.response.close();
      });
      final token = CancelToken();

      expect(
        await download(
          token: token,
          timeout: const Duration(milliseconds: 500),
        ),
        filePath,
      );
      expect(token.isCancelled, isFalse);
      expect(requests, ['/mirror', '/official']);
      expect(
        errors.single,
        isA<NetworkException>().having(
          (e) => e.type,
          'type',
          NetworkExceptionType.receiveTimeout,
        ),
      );
      expect(await File(filePath).readAsBytes(), payload);
    },
  );

  test(
    'real Dio user cancellation during body never starts official',
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
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await bodyFlushed.future;
      token.cancel('user cancelled during response body');
      await assertion;
      expect(requests, ['/mirror']);
      expect(await File(filePath).exists(), isFalse);
    },
  );

  test('real Dio failure from both sources stops after two requests', () async {
    serve((request) async {
      request.response.statusCode = HttpStatus.badGateway;
      await request.response.close();
    });

    await expectLater(
      download(),
      throwsA(
        isA<NetworkException>().having((e) => e.statusCode, 'status', 502),
      ),
    );
    expect(requests, ['/mirror', '/official']);
    expect(errors, hasLength(2));
    expect(await File(filePath).exists(), isFalse);
  });
}
