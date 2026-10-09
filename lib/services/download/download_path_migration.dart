import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/services/download/directory/download_directory_service.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:path/path.dart' as path;

/// iOS can move an app's data container on update. Download files move with it,
/// but the absolute paths stored in Hive still point to the old container.
/// iOS has no custom download directory, so restore all started episodes under
/// the current default directory before any playback, resume or deletion.
Future<void> rebaseIosDownloadPaths(
  Box<DownloadRecord> downloads, {
  Future<String> Function()? downloadDirectory,
}) async {
  try {
    // Container relocation always targets app-owned storage, regardless of any
    // custom-directory setting. Keep lookup failures inside the migration guard.
    final resolveDirectory =
        downloadDirectory ??
        DownloadDirectoryService.instance.getDefaultDirectory;
    await _rebaseDownloadPaths(downloads, await resolveDirectory());
  } catch (error, stackTrace) {
    // Existing boxes remain usable even if migration cannot be persisted (for
    // example on a full disk). Retry from the saved records on the next launch.
    KazumiLogger().e(
      'DownloadStorage: iOS download path migration failed',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

Future<void> _rebaseDownloadPaths(
  Box<DownloadRecord> downloads,
  String downloadBase,
) async {
  var changed = false;
  for (final key in downloads.keys.toList()) {
    final record = downloads.get(key);
    if (record == null) continue;

    var recordChanged = false;
    for (final entry in record.episodes.entries) {
      final episode = entry.value;
      if (episode.downloadDirectory.isEmpty && episode.localM3u8Path.isEmpty) {
        continue;
      }

      final directory = path.join(
        downloadBase,
        '${record.bangumiId}_${record.pluginName}',
        '${entry.key}',
      );
      final videoPath = episode.localM3u8Path.isEmpty
          ? ''
          : path.join(directory, path.basename(episode.localM3u8Path));
      if (episode.downloadDirectory == directory &&
          episode.localM3u8Path == videoPath) {
        continue;
      }

      episode.downloadDirectory = directory;
      episode.localM3u8Path = videoPath;
      recordChanged = true;
    }

    if (recordChanged) {
      await downloads.put(key, record);
      changed = true;
    }
  }
  if (changed) await downloads.flush();
}
