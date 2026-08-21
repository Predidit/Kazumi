import 'dart:typed_data';

import 'package:kazumi/services/backup/backup_models.dart';
import 'package:kazumi/services/backup/backup_ports.dart';
import 'package:kazumi/services/storage/storage.dart';

class HiveBackupDataRepository implements BackupDataPort {
  HiveBackupDataRepository({required this.type, required this.boxName});

  @override
  final BackupDataType type;
  final String boxName;

  @override
  Future<int> count() async => GStorage.backupBoxLength(boxName);

  @override
  Future<Uint8List> exportData() => GStorage.readBackupBoxBytes(boxName);

  @override
  Future<void> validateData(Uint8List data) async {
    await GStorage.validateBackupBoxBytes(
      boxName: boxName,
      bytes: data,
    );
  }

  @override
  Future<void> replaceData(Uint8List data) {
    return GStorage.replaceBackupBoxBytes(boxName, data);
  }
}

class CollectiblesBackupRepository extends HiveBackupDataRepository
  implements CollectiblesBackupPort {
  CollectiblesBackupRepository()
      : super(type: BackupDataType.collectibles, boxName: 'collectibles');
}

class HistoriesBackupRepository extends HiveBackupDataRepository
  implements HistoriesBackupPort {
  HistoriesBackupRepository()
      : super(type: BackupDataType.histories, boxName: 'histories');
}

class SettingsBackupRepository extends HiveBackupDataRepository
  implements SettingsBackupPort {
  SettingsBackupRepository()
      : super(type: BackupDataType.settings, boxName: 'setting');
}
