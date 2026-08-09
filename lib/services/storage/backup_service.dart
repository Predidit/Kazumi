import 'dart:typed_data';

import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/repositories/backup_repository.dart';
import 'package:kazumi/services/plugin/plugin_reloader.dart';

enum BackupDataType {
  collect(label: '我的追番', fileNames: ['collectibles.hive', 'collectchanges.hive']),
  history(label: '历史记录', fileNames: ['histories.hive']),
  rules(label: '规则列表', fileNames: ['plugins.json']),
  settings(label: '设置项目', fileNames: ['setting.hive']);

  const BackupDataType({required this.label, required this.fileNames});

  final String label;
  final List<String> fileNames;

  String get primaryFileName => fileNames.first;
}

class BackupInspection {
  const BackupInspection(this.counts);

  final Map<BackupDataType, int?> counts;

  Set<BackupDataType> get unavailable => counts.entries
      .where((entry) => entry.value == null)
      .map((entry) => entry.key)
      .toSet();
}

abstract interface class IBackupService {
  Future<Map<BackupDataType, int>> getCurrentCounts();
  Future<Uint8List?> createBackup(Set<BackupDataType> types);
  Future<BackupInspection> inspect(Uint8List bytes);
  Future<void> restore(Uint8List bytes, Set<BackupDataType> types);
}

class BackupService implements IBackupService {
  BackupService(
    this._repository,
    this._pluginReloader,
    this._pluginsController,
  );

  final IBackupRepository _repository;
  final IPluginReloader _pluginReloader;
  final PluginsController _pluginsController;

  @override
  Future<Map<BackupDataType, int>> getCurrentCounts() async {
    final counts = await _repository.getCurrentCounts();
    return {
      BackupDataType.collect: counts['collect'] ?? 0,
      BackupDataType.history: counts['history'] ?? 0,
      BackupDataType.rules: counts['rules'] ?? 0,
      BackupDataType.settings: counts['settings'] ?? 0,
    };
  }

  @override
  Future<Uint8List?> createBackup(Set<BackupDataType> types) {
    return _repository.createArchive(
      types.expand((type) => type.fileNames).toSet(),
    );
  }

  @override
  Future<BackupInspection> inspect(Uint8List bytes) async {
    final counts = await _repository.inspectArchive(bytes);
    return BackupInspection({
      for (final type in BackupDataType.values)
        type: counts[type.primaryFileName],
    });
  }

  @override
  Future<void> restore(Uint8List bytes, Set<BackupDataType> types) {
    return _pluginsController.runSerializedPluginOperation(() async {
      final restoredFiles = await _repository.restoreArchive(
        bytes,
        types.expand((type) => type.fileNames).toSet(),
      );
      if (restoredFiles.contains(BackupDataType.rules.primaryFileName)) {
        await _pluginReloader.reload();
      }
    });
  }
}
