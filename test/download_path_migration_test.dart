import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/services/download/download_path_migration.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

void main() {
  setUpAll(() => Logger.level = Level.off);

  test('rebases recorded paths under the current download root', () async {
    String oldDirectory(int episode) =>
        path.join('old', 'downloads', '123_source', '$episode');
    String newDirectory(int episode) =>
        path.join('new', 'downloads', '123_source', '$episode');
    final record = _record({
      1: _episode(oldDirectory(1), path.join(oldDirectory(1), 'playlist.m3u8')),
      2: _episode(oldDirectory(2), ''),
      3: _episode('', ''),
      // Older records can hold a video path without a recorded directory.
      4: _episode('', path.join(oldDirectory(4), 'video.mp4')),
    });
    final downloads = _MemoryDownloads({record.key: record});

    await rebaseIosDownloadPaths(
      downloads,
      downloadDirectory: () async => path.join('new', 'downloads'),
    );

    final episodes = downloads.get(record.key)!.episodes;
    expect(episodes[1]!.downloadDirectory, newDirectory(1));
    expect(
      episodes[1]!.localM3u8Path,
      path.join(newDirectory(1), 'playlist.m3u8'),
    );
    expect(episodes[2]!.downloadDirectory, newDirectory(2));
    expect(episodes[2]!.localM3u8Path, isEmpty);
    expect(episodes[3]!.downloadDirectory, isEmpty);
    expect(episodes[3]!.localM3u8Path, isEmpty);
    expect(episodes[4]!.localM3u8Path, path.join(newDirectory(4), 'video.mp4'));
    expect(downloads.saved, {record.key});
  });

  test('a failed directory lookup leaves records untouched', () async {
    final directory = path.join('old', 'downloads', '123_source', '1');
    final record = _record({1: _episode(directory, '')});
    final downloads = _MemoryDownloads({record.key: record});

    await expectLater(
      rebaseIosDownloadPaths(
        downloads,
        downloadDirectory: () async => throw StateError('unavailable'),
      ),
      completes,
    );
    expect(
      downloads.get(record.key)!.episodes[1]!.downloadDirectory,
      directory,
    );
  });
}

DownloadRecord _record(Map<int, DownloadEpisode> episodes) =>
    DownloadRecord(123, 'anime', '', 'source', episodes, DateTime(2026));

DownloadEpisode _episode(String directory, String videoPath) => DownloadEpisode(
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

class _MemoryDownloads implements Box<DownloadRecord> {
  _MemoryDownloads(this._records);

  final Map<String, DownloadRecord> _records;
  final saved = <dynamic>{};

  @override
  Iterable<dynamic> get keys => _records.keys;

  @override
  DownloadRecord? get(dynamic key, {DownloadRecord? defaultValue}) =>
      _records[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, DownloadRecord value) async {
    _records[key as String] = value;
    saved.add(key);
  }

  @override
  Future<void> flush() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
