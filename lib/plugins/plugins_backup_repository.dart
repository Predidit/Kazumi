import 'dart:convert';
import 'dart:typed_data';

import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/backup/backup_models.dart';
import 'package:kazumi/services/backup/backup_ports.dart';

/// Adapter between the backup service boundary and the rule domain.
class PluginsBackupRepository implements PluginsBackupPort {
  PluginsBackupRepository(this._controller);

  final PluginsController _controller;

  @override
  BackupDataType get type => BackupDataType.plugins;

  @override
  Future<int> count() async => _controller.pluginList.length;

  @override
  Future<Uint8List> exportData() async {
    return Uint8List.fromList(utf8.encode(_controller.pluginsJsonForBackup()));
  }

  @override
  Future<void> validateData(Uint8List data) async {
    _decode(data);
  }

  @override
  Future<void> replaceData(Uint8List data) {
    return _controller.replacePluginsFromBackup(_decode(data));
  }

  List<Plugin> _decode(Uint8List data) {
    final decoded = jsonDecode(utf8.decode(data));
    if (decoded is! List) {
      throw const FormatException('Plugin backup must be a JSON list');
    }
    return [
      for (final item in decoded)
        if (item is Map)
          Plugin.fromJson(Map<String, dynamic>.from(item))
        else
          throw const FormatException('Invalid plugin backup item'),
    ];
  }
}
