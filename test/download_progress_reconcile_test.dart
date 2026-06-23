import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/services/download/download_manager.dart';

void main() {
  late Directory tempDir;
  late DownloadManager manager;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('kazumi_download_reconcile_');
    manager = DownloadManager(
      downloadBaseDirProvider: () async => tempDir.path,
      loadSettings: false,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DownloadManager.reconcileEpisodeWithLocalFiles', () {
    test('restores partial m3u8 segment progress from disk', () async {
      final episodeDir = await _episodeDir(tempDir, 1, 'plugin', 3);
      await File('${episodeDir.path}/seg_00000.ts')
          .writeAsBytes(List.filled(4, 1));
      await File('${episodeDir.path}/seg_00001.ts')
          .writeAsBytes(List.filled(6, 1));
      await File('${episodeDir.path}/seg_00002.ts.tmp')
          .writeAsBytes(List.filled(8, 1));

      final episode = _episode(
        episodeNumber: 3,
        status: DownloadStatus.paused,
        progressPercent: 0.9,
        totalSegments: 4,
        downloadedSegments: 0,
        totalBytes: 0,
      );

      final reconciled = await manager.reconcileEpisodeWithLocalFiles(
        bangumiId: 1,
        pluginName: 'plugin',
        episodeNumber: 3,
        episode: episode,
      );

      expect(reconciled.status, DownloadStatus.paused);
      expect(reconciled.downloadDirectory, episodeDir.path);
      expect(reconciled.downloadedSegments, 2);
      expect(reconciled.progressPercent, 0.5);
      expect(reconciled.totalBytes, 10);
    });

    test('marks m3u8 download completed when local playlist exists', () async {
      final episodeDir = await _episodeDir(tempDir, 1, 'plugin', 3);
      await File('${episodeDir.path}/seg_00000.ts')
          .writeAsBytes(List.filled(4, 1));
      await File('${episodeDir.path}/seg_00001.ts')
          .writeAsBytes(List.filled(6, 1));
      await File('${episodeDir.path}/playlist.m3u8').writeAsString('#EXTM3U');

      final episode = _episode(
        episodeNumber: 3,
        status: DownloadStatus.paused,
        progressPercent: 0.5,
        totalSegments: 2,
        downloadedSegments: 1,
        totalBytes: 4,
      );

      final reconciled = await manager.reconcileEpisodeWithLocalFiles(
        bangumiId: 1,
        pluginName: 'plugin',
        episodeNumber: 3,
        episode: episode,
      );

      expect(reconciled.status, DownloadStatus.completed);
      expect(reconciled.localM3u8Path, '${episodeDir.path}/playlist.m3u8');
      expect(reconciled.downloadedSegments, 2);
      expect(reconciled.progressPercent, 1.0);
      expect(reconciled.totalBytes, 10);
      expect(reconciled.completedAt, isNotNull);
    });

    test('restores direct download temporary file bytes', () async {
      final episodeDir = await _episodeDir(tempDir, 1, 'plugin', 3);
      await File('${episodeDir.path}/video.mp4.tmp')
          .writeAsBytes(List.filled(12, 1));

      final episode = _episode(
        episodeNumber: 3,
        status: DownloadStatus.failed,
        progressPercent: 0.25,
        totalSegments: 0,
        downloadedSegments: 0,
        totalBytes: 0,
      );

      final reconciled = await manager.reconcileEpisodeWithLocalFiles(
        bangumiId: 1,
        pluginName: 'plugin',
        episodeNumber: 3,
        episode: episode,
      );

      expect(reconciled.status, DownloadStatus.paused);
      expect(reconciled.totalSegments, 1);
      expect(reconciled.downloadedSegments, 0);
      expect(reconciled.totalBytes, 12);
      expect(reconciled.progressPercent, 0.25);
    });

    test('marks direct download completed when video file exists', () async {
      final episodeDir = await _episodeDir(tempDir, 1, 'plugin', 3);
      await File('${episodeDir.path}/video.mp4')
          .writeAsBytes(List.filled(12, 1));

      final episode = _episode(
        episodeNumber: 3,
        status: DownloadStatus.paused,
        progressPercent: 0.25,
        totalSegments: 1,
        downloadedSegments: 0,
        totalBytes: 3,
      );

      final reconciled = await manager.reconcileEpisodeWithLocalFiles(
        bangumiId: 1,
        pluginName: 'plugin',
        episodeNumber: 3,
        episode: episode,
      );

      expect(reconciled.status, DownloadStatus.completed);
      expect(reconciled.localM3u8Path, '${episodeDir.path}/video.mp4');
      expect(reconciled.downloadedSegments, 1);
      expect(reconciled.progressPercent, 1.0);
      expect(reconciled.totalBytes, 12);
    });

    test('does not mark missing or empty directories completed', () async {
      final missing = _episode(
        episodeNumber: 3,
        status: DownloadStatus.paused,
        progressPercent: 0.75,
        totalSegments: 4,
        downloadedSegments: 3,
        totalBytes: 30,
      );

      final missingReconciled = await manager.reconcileEpisodeWithLocalFiles(
        bangumiId: 1,
        pluginName: 'plugin',
        episodeNumber: 3,
        episode: missing,
      );

      expect(missingReconciled.status, DownloadStatus.paused);
      expect(missingReconciled.downloadedSegments, 0);
      expect(missingReconciled.progressPercent, 0.0);
      expect(missingReconciled.totalBytes, 0);

      await _episodeDir(tempDir, 1, 'plugin', 4);
      final empty = _episode(
        episodeNumber: 4,
        status: DownloadStatus.paused,
        progressPercent: 0.75,
        totalSegments: 4,
        downloadedSegments: 3,
        totalBytes: 30,
      );

      final emptyReconciled = await manager.reconcileEpisodeWithLocalFiles(
        bangumiId: 1,
        pluginName: 'plugin',
        episodeNumber: 4,
        episode: empty,
      );

      expect(emptyReconciled.status, DownloadStatus.paused);
      expect(emptyReconciled.downloadedSegments, 0);
      expect(emptyReconciled.progressPercent, 0.0);
      expect(emptyReconciled.totalBytes, 0);
    });
  });
}

Future<Directory> _episodeDir(
  Directory base,
  int bangumiId,
  String pluginName,
  int episodeNumber,
) async {
  final dir = Directory('${base.path}/${bangumiId}_$pluginName/$episodeNumber');
  await dir.create(recursive: true);
  return dir;
}

DownloadEpisode _episode({
  required int episodeNumber,
  required int status,
  required double progressPercent,
  required int totalSegments,
  required int downloadedSegments,
  required int totalBytes,
}) {
  return DownloadEpisode(
    episodeNumber,
    '第$episodeNumber话',
    0,
    status,
    progressPercent,
    totalSegments,
    downloadedSegments,
    '',
    '',
    '',
    null,
    '',
    totalBytes,
    '/episode/$episodeNumber',
  );
}
