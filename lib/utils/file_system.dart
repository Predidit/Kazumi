import 'dart:io';

import 'package:path/path.dart' as path;

Future<void> ensureDirectoryWritable(String directoryPath) async {
  final directory = Directory(directoryPath);
  await directory.create(recursive: true);

  final probe = File(
    path.join(
      directoryPath,
      '.kazumi_write_test_${DateTime.now().microsecondsSinceEpoch}.tmp',
    ),
  );

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
