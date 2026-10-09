import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/services/download/download_manager.dart';
import 'package:kazumi/services/download/download_path_migration.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory temporaryDirectory;
  late PathProviderPlatform originalPaths;

  setUpAll(() async {
    Logger.level = Level.off;
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'kazumi_download_paths_',
    );
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(temporaryDirectory.path);
    Hive.init(path.join(temporaryDirectory.path, 'hive'));
    await GStorage.init();
  });

  setUp(() async {
    PathProviderPlatform.instance = _TestPaths(temporaryDirectory.path);
    await GStorage.downloads.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    expect(
      path.isWithin(Directory.systemTemp.path, temporaryDirectory.path),
      isTrue,
    );
    expect(
      path.basename(temporaryDirectory.path),
      startsWith('kazumi_download_paths_'),
    );
    await temporaryDirectory.delete(recursive: true);
  });

  for (final filename in ['playlist.m3u8', 'video.mp4']) {
    test(
      'relocated $filename can be played and deleted after reopening Hive',
      () async {
        final oldContainer = Directory(
          path.join(temporaryDirectory.path, filename, 'old-container'),
        );
        final newContainer = Directory(
          path.join(temporaryDirectory.path, filename, 'new-container'),
        );
        String base(Directory container) => path.join(
          container.path,
          'Library',
          'Application Support',
          'downloads',
        );
        final oldEpisodeDirectory = path.join(
          base(oldContainer),
          '123_source',
          '1',
        );
        await Directory(oldEpisodeDirectory).create(recursive: true);
        final oldVideo = File(path.join(oldEpisodeDirectory, filename));
        await oldVideo.writeAsString('downloaded video');
        await File(
          path.join(oldEpisodeDirectory, 'seg_00000.ts'),
        ).writeAsString('segment');
        await File(
          path.join(oldEpisodeDirectory, 'danmaku.json'),
        ).writeAsString('[]');
        final episode = _episode(
          directory: oldEpisodeDirectory,
          videoPath: oldVideo.path,
        );
        final record = _record({1: episode});
        await GStorage.downloads.put(record.key, record);
        final manager = DownloadManager();
        expect(manager.getLocalVideoPath(episode), oldVideo.path);

        expect(
          path.isWithin(temporaryDirectory.path, oldContainer.path),
          isTrue,
        );
        expect(
          path.isWithin(temporaryDirectory.path, newContainer.path),
          isTrue,
        );
        await oldContainer.rename(newContainer.path);
        expect(manager.getLocalVideoPath(episode), isNull);

        PathProviderPlatform.instance = _TestPaths(
          path.join(newContainer.path, 'Library', 'Application Support'),
        );
        await rebaseIosDownloadPaths(GStorage.downloads);
        await GStorage.downloads.close();
        GStorage.downloads = await Hive.openBox<DownloadRecord>('downloads');
        final restoredRecord = GStorage.downloads.get(record.key)!;
        final restoredEpisode = restoredRecord.episodes[1]!;
        final newEpisodeDirectory = path.join(
          base(newContainer),
          '123_source',
          '1',
        );
        expect(restoredEpisode.downloadDirectory, newEpisodeDirectory);
        expect(
          manager.getLocalVideoPath(restoredEpisode),
          path.join(newEpisodeDirectory, filename),
        );
        expect(
          File(path.join(newEpisodeDirectory, 'danmaku.json')).existsSync(),
          isTrue,
        );
        expect(restoredEpisode.status, DownloadStatus.completed);
        expect(restoredEpisode.totalBytes, 42);

        // A second startup must leave already restored paths unchanged.
        await rebaseIosDownloadPaths(GStorage.downloads);
        expect(
          GStorage.downloads.get(record.key)!.episodes[1]!.localM3u8Path,
          path.join(newEpisodeDirectory, filename),
        );

        if (filename == 'playlist.m3u8') {
          await manager.deleteEpisodeFiles(
            123,
            'source',
            1,
            episode: restoredEpisode,
          );
        } else {
          await manager.deleteRecordFiles(
            123,
            'source',
            record: restoredRecord,
          );
        }
        expect(Directory(newEpisodeDirectory).existsSync(), isFalse);
      },
    );
  }

  test(
    'partial downloads keep their files and unstarted episodes stay empty',
    () async {
      final oldDirectory = path.join(
        temporaryDirectory.path,
        'stale',
        '123_source',
        '2',
      );
      final currentBase = path.join(
        temporaryDirectory.path,
        'current',
        'downloads',
      );
      final currentDirectory = path.join(currentBase, '123_source', '2');
      await Directory(currentDirectory).create(recursive: true);
      final segment = File(path.join(currentDirectory, 'seg_00000.ts'));
      await segment.writeAsString('partial download');
      final partial = _episode(directory: oldDirectory, videoPath: '')
        ..episodeNumber = 2
        ..status = DownloadStatus.paused;
      final unstarted = _episode(directory: '', videoPath: '')
        ..episodeNumber = 3
        ..status = DownloadStatus.pending;
      // Older records can contain a local file path without a recorded directory.
      final legacy = _episode(
        directory: '',
        videoPath: path.join(oldDirectory, 'video.mp4'),
      )..episodeNumber = 4;
      await GStorage.downloads.put(
        'source_123',
        _record({2: partial, 3: unstarted, 4: legacy}),
      );

      await rebaseIosDownloadPaths(
        GStorage.downloads,
        downloadDirectory: () async => currentBase,
      );

      final restored = GStorage.downloads.get('source_123')!;
      expect(restored.episodes[2]!.downloadDirectory, currentDirectory);
      expect(restored.episodes[2]!.localM3u8Path, isEmpty);
      expect(restored.episodes[2]!.status, DownloadStatus.paused);
      expect(await segment.readAsString(), 'partial download');
      expect(restored.episodes[3]!.downloadDirectory, isEmpty);
      expect(restored.episodes[3]!.localM3u8Path, isEmpty);
      expect(
        restored.episodes[4]!.localM3u8Path,
        path.join(currentBase, '123_source', '4', 'video.mp4'),
      );
      expect(DownloadManager().getLocalVideoPath(restored.episodes[4]), isNull);
    },
  );

  test('resuming a relocated download reuses its existing segments', () async {
    final currentBase = path.join(
      temporaryDirectory.path,
      'resume',
      'downloads',
    );
    final currentDirectory = path.join(currentBase, '123_source', '1');
    await Directory(currentDirectory).create(recursive: true);
    final existingSegment = File(path.join(currentDirectory, 'seg_00000.ts'));
    await existingSegment.writeAsString('already downloaded');
    final partial = _episode(
      directory: '/old-container/downloads/123_source/1',
      videoPath: '',
    )..status = DownloadStatus.paused;
    await GStorage.downloads.put('source_123', _record({1: partial}));
    await rebaseIosDownloadPaths(
      GStorage.downloads,
      downloadDirectory: () async => currentBase,
    );
    final restored = GStorage.downloads.get('source_123')!.episodes[1]!;

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    server.listen((request) async {
      requests.add(request.uri.path);
      switch (request.uri.path) {
        case '/playlist.m3u8':
          request.response.write(
            '#EXTM3U\n#EXT-X-TARGETDURATION:10\n'
            '#EXTINF:10,\nfirst.ts\n#EXTINF:10,\nsecond.ts\n#EXT-X-ENDLIST\n',
          );
        case '/second.ts':
          request.response.write('new segment');
        default:
          request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
    final finished = Completer<void>();
    final manager = DownloadManager()
      ..onProgress = (_, _, episode, _) {
        if (finished.isCompleted) return;
        if (episode.status == DownloadStatus.completed) finished.complete();
        if (episode.status == DownloadStatus.failed) {
          finished.completeError(StateError(episode.errorMessage));
        }
      };
    try {
      await manager.resume(
        DownloadRequest(
          recordKey: 'source_123',
          bangumiId: 123,
          pluginName: 'source',
          episodeNumber: 1,
          m3u8Url: 'http://127.0.0.1:${server.port}/playlist.m3u8',
          httpHeaders: const {},
          adBlockerEnabled: false,
          episode: restored,
        ),
      );
      await finished.future.timeout(const Duration(seconds: 15));
      expect(await existingSegment.readAsString(), 'already downloaded');
      expect(
        await File(path.join(currentDirectory, 'seg_00001.ts')).readAsString(),
        'new segment',
      );
      expect(requests, ['/playlist.m3u8', '/second.ts']);
      expect(
        manager.getLocalVideoPath(restored),
        path.join(currentDirectory, 'playlist.m3u8'),
      );
    } finally {
      manager.cancel('source_123', 1);
      await server.close(force: true);
    }
  });

  test('directory lookup failure leaves existing downloads usable', () async {
    final original = _record({
      1: _episode(directory: '/old/downloads/123_source/1', videoPath: ''),
    });
    await GStorage.downloads.put(original.key, original);
    await expectLater(
      rebaseIosDownloadPaths(
        GStorage.downloads,
        downloadDirectory: () async => throw FileSystemException('unavailable'),
      ),
      completes,
    );
    expect(
      GStorage.downloads.get(original.key)!.episodes[1]!.downloadDirectory,
      '/old/downloads/123_source/1',
    );
  });

  for (final failOnFlush in [false, true]) {
    test(
      'migration tolerates ${failOnFlush ? 'flush' : 'write'} failure and retries',
      () async {
        final original = _record({
          1: _episode(directory: '/old/downloads/123_source/1', videoPath: ''),
        });
        await GStorage.downloads.put(original.key, original);
        final currentBase = path.join(
          temporaryDirectory.path,
          'retry',
          'downloads',
        );
        await expectLater(
          rebaseIosDownloadPaths(
            _FailingDownloads(GStorage.downloads, failOnFlush: failOnFlush),
            downloadDirectory: () async => currentBase,
          ),
          completes,
        );
        await GStorage.downloads.close();
        GStorage.downloads = await Hive.openBox<DownloadRecord>('downloads');
        if (!failOnFlush) {
          expect(
            GStorage.downloads
                .get(original.key)!
                .episodes[1]!
                .downloadDirectory,
            '/old/downloads/123_source/1',
          );
        }

        await rebaseIosDownloadPaths(
          GStorage.downloads,
          downloadDirectory: () async => currentBase,
        );
        await GStorage.downloads.close();
        GStorage.downloads = await Hive.openBox<DownloadRecord>('downloads');
        expect(
          GStorage.downloads.get(original.key)!.episodes[1]!.downloadDirectory,
          path.join(currentBase, '123_source', '1'),
        );
      },
    );
  }
}

DownloadRecord _record(Map<int, DownloadEpisode> episodes) =>
    DownloadRecord(123, 'anime', '', 'source', episodes, DateTime(2026));

DownloadEpisode _episode({
  required String directory,
  required String videoPath,
}) => DownloadEpisode(
  1,
  'episode',
  0,
  DownloadStatus.completed,
  1,
  1,
  1,
  videoPath,
  directory,
  '',
  DateTime(2026),
  '',
  42,
  '',
);

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.directory);

  final String directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

class _FailingDownloads implements Box<DownloadRecord> {
  _FailingDownloads(this.delegate, {required this.failOnFlush});

  final Box<DownloadRecord> delegate;
  final bool failOnFlush;

  @override
  Iterable<dynamic> get keys => delegate.keys;

  @override
  DownloadRecord? get(dynamic key, {DownloadRecord? defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);

  @override
  Future<void> put(dynamic key, DownloadRecord value) async {
    if (!failOnFlush) throw FileSystemException('No space left on device');
    await delegate.put(key, value);
  }

  @override
  Future<void> flush() async => throw FileSystemException('flush failed');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
