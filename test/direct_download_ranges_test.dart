import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/download/download_manager.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final v1 = List.generate(3500, (i) => i % 251);
  final v2 = v1.reversed.toList();
  const block = 1024;
  late Directory root;
  late Directory directory;
  late HttpServer server;
  late PathProviderPlatform originalPaths;
  late HttpOverrides? originalOverrides;
  late Level originalLogLevel;
  late DownloadEpisode episode;
  late void Function(HttpRequest request) serve;
  final ranges = <String?>[];
  final validators = <String?>[];

  File file(String name) => File('${directory.path}/$name');

  int startOf(HttpRequest request) {
    final range = request.headers.value(HttpHeaders.rangeHeader);
    return range == null ? 0 : int.parse(range.substring(6, range.length - 1));
  }

  void partial(HttpRequest request, List<int> body, int start, int end,
      {String? etag, String? total}) {
    final response = request.response..statusCode = HttpStatus.partialContent;
    if (etag != null) response.headers.set(HttpHeaders.etagHeader, etag);
    response.headers.set(HttpHeaders.contentRangeHeader,
        'bytes $start-${end - 1}/${total ?? body.length}');
    response.add(body.sublist(start, end));
  }

  void capped(HttpRequest request, List<int> body, {String? etag}) {
    final start = startOf(request);
    partial(request, body, start, min(start + block, body.length), etag: etag);
  }

  setUpAll(() async {
    originalLogLevel = Logger.level;
    Logger.level = Level.off;
    DioFactory.reset();
    originalOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    originalPaths = PathProviderPlatform.instance;
    root = await Directory.systemTemp.createTemp('kazumi-direct-ranges-');
    PathProviderPlatform.instance = _Paths(root.path);
    Hive.init(root.path);
    await GStorage.init();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (ranges.isEmpty) {
        // The manager first probes the URL for an M3U8 playlist.
        request.response.add(v1.sublist(0, block));
      } else {
        serve(request);
      }
      ranges.add(request.headers.value(HttpHeaders.rangeHeader));
      validators.add(request.headers.value(HttpHeaders.ifRangeHeader));
      try {
        await request.response.close();
      } on IOException {
        // The downloader may abort a rejected response.
      }
    });
  });

  setUp(() async {
    directory = await root.createTemp('episode-');
    episode = DownloadEpisode(1, 'episode', 0, DownloadStatus.pending, 0, 0, 0,
        '', directory.path, '', null, '', 0, '');
  });

  tearDownAll(() async {
    DioFactory.reset();
    await server.close(force: true);
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    HttpOverrides.global = originalOverrides;
    await root.delete(recursive: true);
    Logger.level = originalLogLevel;
  });

  Future<void> download({int? pauseAt}) async {
    ranges.clear();
    validators.clear();
    final manager = DownloadManager();
    final done = Completer<void>();
    manager.onProgress = (_, _, current, _) {
      if (current.status == DownloadStatus.downloading &&
          current.totalBytes == pauseAt) {
        manager.pause('record', 1);
      }
      if (!done.isCompleted &&
          current.status != DownloadStatus.downloading &&
          current.status != DownloadStatus.pending) {
        done.complete();
      }
    };
    await manager.resume(DownloadRequest(
      recordKey: 'record',
      bangumiId: 1,
      pluginName: 'test',
      episodeNumber: 1,
      m3u8Url: 'http://127.0.0.1:${server.port}/video.mp4',
      httpHeaders: {},
      adBlockerEnabled: false,
      episode: episode,
    ));
    await done.future.timeout(const Duration(seconds: 15));
  }

  Future<void> expectComplete(List<int> body) async {
    expect(episode.status, DownloadStatus.completed,
        reason: episode.errorMessage);
    expect(await file('video.mp4').readAsBytes(), orderedEquals(body));
    expect(await file('video.mp4.tmp').exists(), isFalse);
    expect(await file('video.mp4.tmp.info').exists(), isFalse);
  }

  test('continues capped responses until the file is complete', () async {
    // Only the first response carries the ETag.
    serve = (request) =>
        capped(request, v1, etag: startOf(request) == 0 ? '"v1"' : null);
    await download();
    await expectComplete(v1);
    expect(ranges, [null, null, 'bytes=1024-', 'bytes=2048-', 'bytes=3072-']);
    expect(validators, [null, null, '"v1"', '"v1"', '"v1"']);
  });

  test('resumes the partial file after a pause', () async {
    serve = (request) => capped(request, v1, etag: '"v1"');
    await download(pauseAt: block);
    expect(episode.status, DownloadStatus.paused);

    serve = (request) =>
        partial(request, v1, startOf(request), v1.length, etag: '"v1"');
    await download();
    await expectComplete(v1);
    expect(ranges, [null, 'bytes=1024-']);
    expect(validators, [null, '"v1"']);
  });

  for (final cappedRestart in [false, true]) {
    test(
        'restarts when the file changed during a pause '
        '(capped: $cappedRestart)', () async {
      serve = (request) => capped(request, v1, etag: '"v1"');
      await download(pauseAt: block);

      // A stale If-Range makes the server ignore Range.
      serve = (request) {
        if (request.headers.value(HttpHeaders.ifRangeHeader) == '"v2"') {
          capped(request, v2, etag: '"v2"');
        } else if (cappedRestart) {
          partial(request, v2, 0, block, etag: '"v2"');
        } else {
          request.response.headers.set(HttpHeaders.etagHeader, '"v2"');
          request.response.add(v2);
        }
      };
      await download();
      await expectComplete(v2);
      expect(validators[1], '"v1"');
    });
  }

  test('completes a fully written partial file on 416', () async {
    serve = (request) => partial(request, v1, 0, v1.length, etag: '"v1"');
    await download(pauseAt: v1.length);
    expect(episode.status, DownloadStatus.paused);

    serve = (request) => request.response
      ..statusCode = HttpStatus.requestedRangeNotSatisfiable
      ..headers.set(HttpHeaders.etagHeader, '"v1"')
      ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */${v1.length}');
    await download();
    await expectComplete(v1);
    expect(ranges, [null, 'bytes=3500-']);
  });

  test('accepts an unknown complete length', () async {
    serve = (request) => partial(request, v1, 0, v1.length, total: '*');
    await download();
    await expectComplete(v1);
  });

  test('discards the partial file when its length changes', () async {
    serve = (request) => capped(request, v1);
    await download(pauseAt: block);

    serve = (request) =>
        partial(request, v1, startOf(request), v1.length, total: '3600');
    await download();
    expect(episode.status, DownloadStatus.failed);
    expect(episode.errorMessage, '服务器上的视频已变更，请重新下载');
    expect(await file('video.mp4.tmp').exists(), isFalse);
    expect(await file('video.mp4.tmp.info').exists(), isFalse);
  });
}
