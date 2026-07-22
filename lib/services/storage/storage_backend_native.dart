import 'dart:io';
import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class StorageBackend {
  StorageBackend._();

  static Future<String?> initializeHive() async {
    final hivePath = '${(await getApplicationSupportDirectory()).path}/hive';
    await Hive.initFlutter(hivePath);
    return hivePath;
  }

  static Future<void> deleteBoxFiles(String hivePath, String boxName) async {
    final boxFile = File('$hivePath/$boxName.hive');
    final lockFile = File('$hivePath/$boxName.lock');
    if (await boxFile.exists()) await boxFile.delete();
    if (await lockFile.exists()) await lockFile.delete();
  }

  static Future<void> backupBox(
    String boxName,
    String backupFilePath,
  ) async {
    final appDocumentDir = await getApplicationSupportDirectory();
    final source = File('${appDocumentDir.path}/hive/$boxName.hive');
    if (!await source.exists()) {
      throw FileSystemException('Hive box does not exist', source.path);
    }
    await source.copy(backupFilePath);
  }

  static Future<Uint8List> readFileBytes(String path) {
    return File(path).readAsBytes();
  }
}
