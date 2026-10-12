import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/dialog/update_download_source_selector.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/services/update/update_download_source.dart';
import 'package:kazumi/services/update/update_downloader.dart';

void main() {
  late HttpServer server;
  late Directory directory;
  late Dio dio;
  late String filePath;
  late Map<String, dynamic> asset;
  late List<String> requests;
  late List<Object> errors;
  late int status;
  late List<int> responseBytes;
  final payload = utf8.encode('verified update');
  final expectedHash = sha256.convert(payload).toString();

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    directory = await Directory.systemTemp.createTemp('kazumi_update_test_');
    filePath = '${directory.path}/Kazumi_windows.zip';
    final base = 'http://127.0.0.1:${server.port}';
    asset = {
      'mirror_download_url': '$base/mirror',
      'browser_download_url': '$base/official',
    };
    requests = [];
    errors = [];
    status = HttpStatus.ok;
    responseBytes = payload;
    dio =
        Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 2),
              receiveTimeout: const Duration(seconds: 2),
            ),
          )
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () =>
                _LocalHttpOverrides().createHttpClient(null),
          );
    server.listen((request) {
      requests.add(request.uri.path);
      request.response.statusCode = status;
      request.response.contentLength = responseBytes.length;
      request.response.add(responseBytes);
      unawaited(request.response.close());
    });
  });

  tearDown(() async {
    dio.close(force: true);
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  Future<String> download(UpdateDownloadSource source) =>
      UpdateDownloader(
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
                Error.throwWithStackTrace(
                  await NetworkErrorMapper.mapException(error),
                  error.stackTrace,
                );
              }
            },
        logFailure: (_, error, _) => errors.add(error),
      ).download(
        url: getUpdateDownloadUrlFromAsset(asset, source: source),
        filePath: filePath,
        expectedHash: expectedHash,
        cancelToken: CancelToken(),
        onReceiveProgress: (_, _) {},
      );

  testWidgets('choosing GitHub in the dialog downloads only from official', (
    tester,
  ) async {
    var source = UpdateDownloadSource.mirror;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlertDialog(
            title: const Text('发现新版本'),
            content: UpdateDownloadSourceSelector(
              value: source,
              onChanged: (value) => source = value,
            ),
          ),
        ),
      ),
    );
    await tester.tap(
      find.byType(DropdownButtonFormField<UpdateDownloadSource>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('GitHub 官方源').last);
    await tester.pumpAndSettle();

    expect(source, UpdateDownloadSource.github);
    expect(await tester.runAsync(() => download(source)), filePath);
    expect(requests, ['/official']);
    expect(await tester.runAsync(() => File(filePath).readAsBytes()), payload);
    expect(errors, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  test(
    'selected source HTTP 503 fails once and retains the original error',
    () async {
      status = HttpStatus.serviceUnavailable;
      Object? caught;
      try {
        await download(UpdateDownloadSource.mirror);
        fail('HTTP 503 must fail');
      } on NetworkException catch (error) {
        caught = error;
        expect(error.statusCode, 503);
        expect(error.rawError, isA<DioException>());
        final original = error.rawError as DioException;
        expect(original.type, DioExceptionType.badResponse);
        expect(original.response?.statusCode, 503);
        expect(error.stackTrace, same(original.stackTrace));
      }
      expect(requests, ['/mirror']);
      expect(errors.single, same(caught));
      expect(await directory.list().length, 0);
    },
  );

  test(
    'SHA256 mismatch rejects the update and cleans temporary files',
    () async {
      responseBytes = utf8.encode('corrupt update');
      await expectLater(
        download(UpdateDownloadSource.mirror),
        throwsA(isA<UpdateIntegrityException>()),
      );
      expect(requests, ['/mirror']);
      expect(errors.single, isA<UpdateIntegrityException>());
      expect(await File(filePath).exists(), isFalse);
      expect(await directory.list().length, 0);
    },
  );
}

class _LocalHttpOverrides extends HttpOverrides {}
