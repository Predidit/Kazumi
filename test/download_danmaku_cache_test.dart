import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' hide ProgressCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/player/controller/player_danmaku_controller.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/repositories/download_repository.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/download/download_manager.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const _key = 'cache-test_123';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform previousPaths;
  late HttpOverrides? previousHttp;
  late DownloadRepository repository;
  late DownloadController controller;
  late _ProgressManager manager;
  late _Comments comments;
  var caseNumber = 0;

  setUpAll(() async {
    Logger.level = Level.off;
    previousPaths = PathProviderPlatform.instance;
    previousHttp = HttpOverrides.current;
    HttpOverrides.global = null;
    root = await Directory.systemTemp.createTemp('kazumi_danmaku_test_');
    PathProviderPlatform.instance = _Paths(root.path);
    Hive.init(root.path);
    await GStorage.init();
  });

  setUp(() async {
    await GStorage.downloads.clear();
    await GStorage.putSetting(SettingsKeys.downloadDanmaku, true);
    await GStorage.putSetting(SettingsKeys.downloadParallelEpisodes, 1);
    await GStorage.putSetting(SettingsKeys.downloadDirectory, '');
    repository = DownloadRepository();
    manager = _ProgressManager();
    comments = _Comments();
    DioFactory.apiDio.interceptors.add(comments.interceptor);
    controller = DownloadController(repository, manager, _plugins());
    await controller.init();
    caseNumber++;
  });

  tearDown(() async {
    comments.release();
    await controller.deleteRecord(123, 'cache-test');
    DioFactory.reset();
  });

  tearDownAll(() async {
    await Hive.close();
    PathProviderPlatform.instance = previousPaths;
    HttpOverrides.global = previousHttp;
    await root.delete(recursive: true);
  });

  Future<DownloadEpisode> add(int number, {bool directoryReady = true}) async {
    final directory = '${root.path}/case-$caseNumber/$number';
    if (directoryReady) await Directory(directory).create(recursive: true);
    final episode = DownloadEpisode(
      number,
      'episode $number',
      0,
      DownloadStatus.paused,
      0,
      0,
      0,
      '',
      directoryReady ? directory : '',
      'http://127.0.0.1/$number.m3u8',
      null,
      '',
      0,
      '/$number',
    );
    final record =
        repository.getRecord(_key) ??
        DownloadRecord(123, 'test', '', 'cache-test', {}, DateTime.now());
    record.episodes[number] = episode;
    await repository.putRecord(record);
    return episode;
  }

  Future<void> downloaded(DownloadEpisode episode) async {
    manager.report(episode, DownloadStatus.downloading);
    manager.report(episode, DownloadStatus.completed);
    await _until(
      () => File('${episode.downloadDirectory}/danmaku.json').existsSync(),
    );
    // Reading through the controller also verifies the complete JSON wrapper.
    await _untilAsync(
      () async =>
          (await controller.getCachedDanmakus(
            123,
            'cache-test',
            episode.episodeNumber,
          ))?.isNotEmpty ??
          false,
    );
  }

  test(
    'directory-ready progress caches once and local playback stays offline',
    () async {
      final episode = await add(1);
      await downloaded(episode);
      for (var i = 0; i < 20; i++) {
        manager.report(episode, DownloadStatus.downloading);
      }
      expect(comments.requests, {1: 1});
      comments.offline = true;
      final player = PlayerDanmakuController(
        isLocalPlayback: () => true,
        downloadController: controller,
      );
      final result = await player.fetchDanmaku(123, 'cache-test', 1);
      expect(result.status, DanmakuLoadStatus.success);
      expect(comments.offlineRequests, 0);
      expect(
        (await controller.getCachedDanmakus(
          123,
          'cache-test',
          1,
        ))!.single.message,
        'episode 1 comment',
      );
    },
  );

  for (final pauseAll in [false, true]) {
    test(
      'pause ${pauseAll ? 'all' : 'one'} and resume retain one in-flight cache request',
      () async {
        comments.gate = Completer<void>();
        final episode = await add(1);
        manager.report(episode, DownloadStatus.downloading);
        await _until(() => comments.requests[1] == 1);
        controller.refreshRecords();
        if (pauseAll) {
          await controller.pauseAllDownloads();
        } else {
          await controller.pauseDownload(123, 'cache-test', 1);
        }
        expect(repository.getRecord(_key)!.episodes[1], same(episode));
        await controller.retryDownload(
          bangumiId: 123,
          pluginName: 'cache-test',
          episodeNumber: 1,
        );
        comments.release();
        await downloaded(episode);
        expect(comments.requests, {1: 1});
      },
    );
  }

  for (final failure in ['empty', 'error']) {
    test(
      '$failure is best effort and a new video attempt retries the cache',
      () async {
        comments.mode = failure;
        final episode = await add(1);
        manager.report(episode, DownloadStatus.downloading);
        await _until(() => comments.responses == 1);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        for (var i = 0; i < 5; i++) {
          manager.report(episode, DownloadStatus.downloading);
        }
        expect(comments.requests, {1: 1});
        expect(
          File('${episode.downloadDirectory}/danmaku.json').existsSync(),
          isFalse,
        );
        manager.report(episode, DownloadStatus.failed);
        comments.mode = 'success';
        await controller.retryDownload(
          bangumiId: 123,
          pluginName: 'cache-test',
          episodeNumber: 1,
        );
        await downloaded(episode);
        expect(comments.requests, {1: 2});
      },
    );
  }

  test('disabled caching makes no API requests', () async {
    await GStorage.putSetting(SettingsKeys.downloadDanmaku, false);
    final episode = await add(1);
    manager.report(episode, DownloadStatus.downloading);
    manager.report(episode, DownloadStatus.completed);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(comments.totalRequests, 0);
    expect(
      File('${episode.downloadDirectory}/danmaku.json').existsSync(),
      isFalse,
    );
  });

  test(
    'existing cache is reused after retry, priority and controller restart',
    () async {
      final episode = await add(1);
      await downloaded(episode);
      await controller.retryDownload(
        bangumiId: 123,
        pluginName: 'cache-test',
        episodeNumber: 1,
      );
      await controller.priorityDownload(
        bangumiId: 123,
        pluginName: 'cache-test',
        episodeNumber: 1,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller = DownloadController(repository, manager, _plugins());
      await controller.init();
      manager.report(episode, DownloadStatus.downloading);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(comments.requests, {1: 1});
      expect(comments.totalRequests, 2);
    },
  );

  for (final deleteWholeRecord in [false, true]) {
    test(
      'late response cannot overwrite a recreated ${deleteWholeRecord ? 'record' : 'episode'}',
      () async {
        comments.gate = Completer<void>();
        final oldEpisode = await add(1);
        manager.report(oldEpisode, DownloadStatus.downloading);
        await _until(() => comments.requests[1] == 1);
        if (deleteWholeRecord) {
          await controller.deleteRecord(123, 'cache-test');
        } else {
          await controller.deleteEpisode(123, 'cache-test', 1);
        }
        expect(Directory(oldEpisode.downloadDirectory).existsSync(), isFalse);
        final replacement = await add(1);
        final cache = File('${replacement.downloadDirectory}/danmaku.json');
        await cache.writeAsString('replacement sentinel');
        comments.release();
        await _until(() => comments.responses == 1);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(await cache.readAsString(), 'replacement sentinel');
      },
    );
  }

  test(
    'real downloads queued beyond 30 seconds both retain offline comments',
    () async {
      // Keep the deliberate queue wait independent of the transport timeout.
      DioFactory.downloadDio.options.receiveTimeout = const Duration(
        minutes: 1,
      );
      final realManager = DownloadManager();
      controller = DownloadController(repository, realManager, _plugins());
      await controller.init();
      final first = await add(1, directoryReady: false);
      final second = await add(2, directoryReady: false);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final release = Completer<void>();
      final started = Completer<void>();
      final payload = List<int>.generate(188 * 10, (i) => i % 256);
      final serving = <Future<void>>[];
      server.listen((request) {
        serving.add(() async {
          request.response.bufferOutput = false;
          if (request.uri.path.endsWith('.m3u8')) {
            final segment = request.uri.path.startsWith('/1')
                ? 'first.ts'
                : 'second.ts';
            request.response.write(
              '#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXTINF:2,\n$segment\n#EXT-X-ENDLIST\n',
            );
          } else {
            request.response.contentLength = payload.length;
            var sent = 0;
            if (request.uri.path == '/first.ts') {
              if (!started.isCompleted) started.complete();
              while (!release.isCompleted) {
                request.response.add(payload.sublist(sent, sent + 16));
                sent += 16;
                await request.response.flush();
                await Future.any([
                  release.future,
                  Future<void>.delayed(const Duration(seconds: 2)),
                ]);
              }
            }
            request.response.add(payload.sublist(sent));
          }
          await request.response.close();
        }());
      });
      try {
        first.networkM3u8Url = 'http://127.0.0.1:${server.port}/1.m3u8';
        second.networkM3u8Url = 'http://127.0.0.1:${server.port}/2.m3u8';
        await controller.retryDownload(
          bangumiId: 123,
          pluginName: 'cache-test',
          episodeNumber: 1,
        );
        await started.future.timeout(const Duration(seconds: 10));
        await controller.retryDownload(
          bangumiId: 123,
          pluginName: 'cache-test',
          episodeNumber: 2,
        );
        expect(second.status, DownloadStatus.pending);
        await Future<void>.delayed(const Duration(seconds: 33));
        expect(second.status, DownloadStatus.pending);
        expect(second.downloadDirectory, isEmpty);
        expect(comments.requests[2], isNull);
        release.complete();
        await _until(() => second.status == DownloadStatus.completed);
        for (final episode in [first, second]) {
          expect(episode.status, DownloadStatus.completed);
          expect(
            await File(
              '${episode.downloadDirectory}/seg_00000.ts',
            ).readAsBytes(),
            payload,
          );
          await _untilAsync(
            () async =>
                (await controller.getCachedDanmakus(
                  123,
                  'cache-test',
                  episode.episodeNumber,
                ))?.isNotEmpty ??
                false,
          );
        }
        comments.offline = true;
        final player = PlayerDanmakuController(
          isLocalPlayback: () => true,
          downloadController: controller,
        );
        for (final number in [1, 2]) {
          expect(
            (await player.fetchDanmaku(123, 'cache-test', number)).status,
            DanmakuLoadStatus.success,
          );
        }
        expect(comments.requests, {1: 1, 2: 1});
        expect(comments.offlineRequests, 0);
      } finally {
        if (!release.isCompleted) release.complete();
        await controller.deleteRecord(123, 'cache-test');
        await server.close(force: true);
        await Future.wait(serving);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

PluginsController _plugins() => PluginsController()
  ..pluginList.add(
    Plugin.fromJson({'name': 'cache-test', 'baseURL': 'http://127.0.0.1'}),
  );

Future<void> _until(bool Function() condition) =>
    _untilAsync(() async => condition());

Future<void> _untilAsync(Future<bool> Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline))
      throw StateError('Condition timed out');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _Paths extends PathProviderPlatform {
  _Paths(this.directory);
  final String directory;
  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

class _Comments {
  final requests = <int, int>{};
  var totalRequests = 0;
  var responses = 0;
  var offlineRequests = 0;
  var offline = false;
  var mode = 'success';
  Completer<void>? gate;

  void release() {
    if (gate != null && !gate!.isCompleted) gate!.complete();
  }

  late final interceptor = InterceptorsWrapper(
    onRequest: (options, handler) async {
      totalRequests++;
      if (offline) {
        offlineRequests++;
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        );
        return;
      }
      if (options.uri.path.contains('/bgmtv/')) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'bangumi': {'animeId': 456, 'episodes': []},
              'errorCode': 0,
              'success': true,
              'errorMessage': '',
            },
          ),
        );
        return;
      }
      final number = int.parse(options.uri.path.split('/').last) % 10000;
      requests.update(number, (count) => count + 1, ifAbsent: () => 1);
      await gate?.future;
      responses++;
      if (mode == 'error') {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        );
      } else {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'comments': mode == 'empty'
                  ? []
                  : [
                      {
                        'm': 'episode $number comment',
                        'p': '1,1,16777215,test',
                      },
                    ],
            },
          ),
        );
      }
    },
  );
}

class _ProgressManager implements IDownloadManager {
  @override
  ProgressCallback? onProgress;

  void report(DownloadEpisode episode, int status) {
    episode.status = status;
    onProgress?.call(_key, episode.episodeNumber, episode, 0);
  }

  @override
  Future<void> enqueue(DownloadRequest request) async =>
      report(request.episode, DownloadStatus.downloading);
  @override
  Future<void> enqueuePriority(DownloadRequest request) => enqueue(request);
  @override
  void pause(String recordKey, int episodeNumber) {}
  @override
  void cancel(String recordKey, int episodeNumber) {}
  @override
  Future<void> deleteEpisodeFiles(
    int bangumiId,
    String pluginName,
    int episodeNumber, {
    DownloadEpisode? episode,
  }) async {
    if (episode == null || episode.downloadDirectory.isEmpty) return;
    final directory = Directory(episode.downloadDirectory);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  @override
  Future<void> deleteRecordFiles(
    int bangumiId,
    String pluginName, {
    DownloadRecord? record,
  }) async {
    for (final episode in record?.episodes.values ?? <DownloadEpisode>[]) {
      await deleteEpisodeFiles(
        bangumiId,
        pluginName,
        episode.episodeNumber,
        episode: episode,
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
