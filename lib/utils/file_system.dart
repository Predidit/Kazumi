import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Custom download directories are supported on desktop platforms where the
/// user can grant persistent access to an arbitrary directory. On macOS this
/// additionally requires a security-scoped bookmark (SecureBookmarkService).
bool get supportsCustomDownloadDirectory =>
    Platform.isWindows || Platform.isMacOS;

Future<String> getDefaultDownloadDirectory() async {
  final appSupport = await getApplicationSupportDirectory();
  return path.join(appSupport.path, 'downloads');
}

Future<void> ensureDirectoryWritable(String directoryPath) async {
  final directory = Directory(directoryPath);
  await directory.create(recursive: true);

  final probe = File(path.join(
    directoryPath,
    '.kazumi_write_test_${DateTime.now().microsecondsSinceEpoch}.tmp',
  ));

  try {
    await probe.writeAsString('ok', flush: true);
  } finally {
    try {
      if (await probe.exists()) {
        await probe.delete();
      }
    } on FileSystemException {
      // The write check already succeeded; a leftover probe is not fatal.
    }
  }
}
