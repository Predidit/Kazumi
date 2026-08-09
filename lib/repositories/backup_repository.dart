import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class IBackupRepository {
  Future<Map<String, int>> getCurrentCounts();
  Future<Uint8List?> createArchive(Set<String> fileNames);
  Future<Map<String, int?>> inspectArchive(Uint8List bytes);
  Future<Set<String>> restoreArchive(Uint8List bytes, Set<String> fileNames);
}

class BackupRepository implements IBackupRepository {
  static const _collectibles = 'collectibles.hive';
  static const _collectChanges = 'collectchanges.hive';
  static const _histories = 'histories.hive';
  static const _settings = 'setting.hive';
  static const _plugins = 'plugins.json';

  @override
  Future<Map<String, int>> getCurrentCounts() async {
    final supportDir = await getApplicationSupportDirectory();
    var rules = 0;
    final rulesFile = File(p.join(supportDir.path, 'plugins', 'v2', _plugins));
    if (await rulesFile.exists()) {
      try {
        final data = jsonDecode(await rulesFile.readAsString());
        rules = data is List ? data.length : 0;
      } catch (error, stackTrace) {
        KazumiLogger().w('BackupRepository: read rules count failed', error: error, stackTrace: stackTrace);
      }
    }
    return {
      'collect': GStorage.collectibles.length,
      'history': GStorage.histories.length,
      'rules': rules,
      'settings': GStorage.settingsCount,
    };
  }

  @override
  Future<Uint8List?> createArchive(Set<String> fileNames) async {
    await GStorage.flushAll();
    final supportDir = await getApplicationSupportDirectory();
    final archive = Archive();
    for (final fileName in fileNames) {
      final sourceDir = fileName == _plugins
          ? p.join(supportDir.path, 'plugins', 'v2')
          : p.join(supportDir.path, 'hive');
      final source = File(p.join(sourceDir, fileName));
      if (await source.exists()) {
        archive.addFile(ArchiveFile.bytes(fileName, await source.readAsBytes()));
      }
    }
    final collectRequested =
        fileNames.contains(_collectibles) || fileNames.contains(_collectChanges);
    final collectComplete =
        archive.findFile(_collectibles) != null &&
        archive.findFile(_collectChanges) != null;
    if (collectRequested && !collectComplete) return null;
    return archive.isEmpty ? null : ZipEncoder().encodeBytes(archive);
  }

  @override
  Future<Map<String, int?>> inspectArchive(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final counts = <String, int?>{};
    for (final fileName in const [
      _collectibles,
      _collectChanges,
      _histories,
      _plugins,
      _settings,
    ]) {
      final entry = archive.findFile(fileName);
      final content = entry == null || !entry.isFile ? null : entry.readBytes();
      if (content == null) {
        counts[fileName] = null;
        continue;
      }
      try {
        if (fileName == _plugins) {
          final data = jsonDecode(utf8.decode(content));
          counts[fileName] = data is List ? data.length : null;
        } else {
          final box = await Hive.openBox('backupCountBox', bytes: content);
          counts[fileName] = box.length;
          await box.close();
        }
      } catch (error, stackTrace) {
        KazumiLogger().w('BackupRepository: inspect archive failed', error: error, stackTrace: stackTrace);
        counts[fileName] = null;
      }
    }
    final collectiblesAvailable =
        counts[_collectibles] != null && counts[_collectChanges] != null;
    counts[_collectibles] = collectiblesAvailable ? counts[_collectibles] : null;
    return counts;
  }

  @override
  Future<Set<String>> restoreArchive(
    Uint8List bytes,
    Set<String> fileNames,
  ) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final restoredFiles = <String>{};
    for (final fileName in fileNames) {
      final content = archive.findFile(fileName)?.readBytes();
      if (content == null) continue;
      switch (fileName) {
        case _plugins:
          final supportDir = await getApplicationSupportDirectory();
          final targetDir = Directory(p.join(supportDir.path, 'plugins', 'v2'));
          await targetDir.create(recursive: true);
          await File(p.join(targetDir.path, fileName)).writeAsBytes(content);
        case _collectibles:
          await GStorage.restoreCollectiblesFromBytes(content);
        case _collectChanges:
          await GStorage.restoreCollectChangesFromBytes(content);
        case _histories:
          await GStorage.restoreBoxFromBytes(_histories, GStorage.histories, content);
        case _settings:
          await GStorage.restoreSettingsFromBytes(content);
      }
      restoredFiles.add(fileName);
    }
    return restoredFiles;
  }
}
