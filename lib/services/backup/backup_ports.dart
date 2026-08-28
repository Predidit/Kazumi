import 'dart:typed_data';

import 'package:kazumi/services/backup/backup_models.dart';

/// Boundary for one application's user-data category.
///
/// The backup coordinator knows only bytes and transaction operations. The
/// concrete adapter owns Hive, rule persistence, synchronization state, and
/// any compatibility handling for its category.
abstract interface class BackupDataPort {
  BackupDataType get type;

  Future<int> count();

  Future<Uint8List> exportData();

  Future<void> validateData(Uint8List data);

  Future<void> replaceData(Uint8List data);
}

abstract interface class CollectiblesBackupPort implements BackupDataPort {}

abstract interface class HistoriesBackupPort implements BackupDataPort {}

abstract interface class SettingsBackupPort implements BackupDataPort {}

abstract interface class PluginsBackupPort implements BackupDataPort {}
