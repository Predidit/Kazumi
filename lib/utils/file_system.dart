import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<String> getDefaultDownloadDirectory() async {
  final appSupport = await getApplicationSupportDirectory();
  return path.join(appSupport.path, 'downloads');
}

final _illegalFileNameChars = RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]');

String safeFileName(String name,
    {required String fallback, int maxLength = 80}) {
  var result = name
      .replaceAll(_illegalFileNameChars, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (result.runes.length > maxLength) {
    result = String.fromCharCodes(result.runes.take(maxLength));
  }
  result = result.replaceFirst(RegExp(r'[. ]+$'), '');
  return result.isEmpty ? fallback : result;
}

String episodeDanmakuPath(String downloadDirectory) =>
    Directory(downloadDirectory).existsSync()
        ? path.join(downloadDirectory, 'danmaku.json')
        : '$downloadDirectory.danmaku.json';

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
