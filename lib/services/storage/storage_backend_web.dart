import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_flutter.dart';

class StorageBackend {
  StorageBackend._();

  static Future<String?> initializeHive() async {
    await Hive.initFlutter();
    return null;
  }

  static Future<void> deleteBoxFiles(String hivePath, String boxName) async {
    // Hive Web uses IndexedDB and has no box files to delete. Hive.deleteBox
    // is intentionally left to the shared recovery path.
  }

  static Future<void> backupBox(
    String boxName,
    String backupFilePath,
  ) {
    throw UnsupportedError('File-based Hive backup is unavailable on Web');
  }

  static Future<Uint8List> readFileBytes(String path) {
    throw UnsupportedError(
        'Reading arbitrary local files is unavailable on Web');
  }
}
