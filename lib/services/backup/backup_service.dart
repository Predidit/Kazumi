import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:kazumi/services/backup/backup_models.dart';
import 'package:kazumi/services/backup/backup_ports.dart';
import 'package:kazumi/services/logging/logger.dart';

class BackupService {
  BackupService({
    required CollectiblesBackupPort collectibles,
    required HistoriesBackupPort histories,
    required SettingsBackupPort settings,
    required PluginsBackupPort plugins,
  }) : _ports = {
          collectibles.type: collectibles,
          histories.type: histories,
          settings.type: settings,
          plugins.type: plugins,
        };

  final Map<BackupDataType, BackupDataPort> _ports;

  Future<Map<BackupDataType, int>> currentCounts() async {
    final result = <BackupDataType, int>{};
    for (final entry in _ports.entries) {
      result[entry.key] = await entry.value.count();
    }
    return result;
  }

  Future<Uint8List> exportData(Set<BackupDataType> types) async {
    _validateTypes(types);
    final createdAt = DateTime.now().toUtc();
    final archive = Archive();
    final files = <BackupDataType, String>{};
    final counts = <BackupDataType, int?>{};

    try {
      for (final type in types) {
        final data = await _ports[type]!.exportData();
        counts[type] = await _ports[type]!.count();
        archive.addFile(ArchiveFile(type.fileName, data.length, data));
        files[type] = type.fileName;
      }
      final manifest = BackupManifest(
        version: BackupManifest.currentVersion,
        createdAt: createdAt,
        files: files,
        counts: counts,
      );
      final manifestBytes = Uint8List.fromList(
        utf8.encode(jsonEncode(manifest.toJson())),
      );
      archive.addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
      );
      return Uint8List.fromList(ZipEncoder().encode(archive));
    } catch (error, stackTrace) {
      KazumiLogger().e(
        'Backup: export failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> exportToFile(
    Set<BackupDataType> types,
    String destinationPath,
  ) async {
    final bytes = await exportData(types);
    final target = File(destinationPath);
    final temporary = File('$destinationPath.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (await target.exists()) {
        await target.delete();
      }
      await temporary.rename(destinationPath);
    } catch (error, stackTrace) {
      KazumiLogger().e(
        'Backup: failed to save archive',
        error: error,
        stackTrace: stackTrace,
      );
      try {
        if (await temporary.exists()) await temporary.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<BackupPreview> preview(Uint8List archiveBytes) async {
    final files = _decodeArchive(archiveBytes);
    final manifest = _decodeManifest(files['manifest.json']);
    for (final entry in manifest.files.entries) {
      final data = files[entry.value];
      if (data == null) {
        throw FormatException('Missing backup file: ${entry.value}');
      }
      await _ports[entry.key]!.validateData(data);
    }
    return BackupPreview(manifest: manifest);
  }

  Future<BackupPreview> previewFile(String filePath) async {
    return preview(await File(filePath).readAsBytes());
  }

  Future<void> restore(
    Uint8List archiveBytes,
    Set<BackupDataType> types,
  ) async {
    final files = _decodeArchive(archiveBytes);
    final manifest = _decodeManifest(files['manifest.json']);
    final selected = <BackupDataType, Uint8List>{};
    for (final type in types) {
      final fileName = manifest.files[type];
      if (fileName == null) {
        throw FormatException('Backup does not contain ${type.label}');
      }
      final data = files[fileName];
      if (data == null) {
        throw FormatException('Missing backup file: $fileName');
      }
      await _ports[type]!.validateData(data);
      selected[type] = data;
    }

    // Each port owns its own storage transaction. The coordinator validates all
    // selected inputs before invoking any replacement operation.
    for (final entry in selected.entries) {
      await _ports[entry.key]!.replaceData(entry.value);
    }
  }

  Future<void> restoreFile(
    String filePath,
    Set<BackupDataType> types,
  ) async {
    return restore(await File(filePath).readAsBytes(), types);
  }

  Map<String, Uint8List> _decodeArchive(Uint8List archiveBytes) {
    final archive = ZipDecoder().decodeBytes(archiveBytes, verify: true);
    final files = <String, Uint8List>{};
    for (final file in archive) {
      if (!file.isFile || !_isSafeFileName(file.name)) {
        throw const FormatException('Invalid backup archive entry');
      }
      if (files.containsKey(file.name)) {
        throw const FormatException('Duplicate backup archive entry');
      }
      files[file.name] = Uint8List.fromList(file.content as List<int>);
    }
    return files;
  }

  BackupManifest _decodeManifest(Uint8List? data) {
    if (data == null) {
      throw const FormatException('Missing backup manifest');
    }
    final decoded = jsonDecode(utf8.decode(data));
    if (decoded is! Map) {
      throw const FormatException('Invalid backup manifest JSON');
    }
    return BackupManifest.fromJson(Map<String, dynamic>.from(decoded));
  }

  void _validateTypes(Set<BackupDataType> types) {
    if (types.isEmpty) {
      throw ArgumentError('At least one backup data type is required');
    }
    for (final type in types) {
      if (!_ports.containsKey(type)) {
        throw StateError('No backup port registered for ${type.id}');
      }
    }
  }

  bool _isSafeFileName(String value) {
    if (value == 'manifest.json') return true;
    return BackupDataType.values.any((type) => value == type.fileName);
  }
}
