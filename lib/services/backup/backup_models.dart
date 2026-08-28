import 'dart:typed_data';

enum BackupDataType {
  collectibles('collectibles', '收藏', 'collectibles.hive'),
  histories('histories', '观看历史', 'histories.hive'),
  settings('settings', '设置', 'setting.hive'),
  plugins('plugins', '规则列表', 'plugins.json');

  const BackupDataType(this.id, this.label, this.fileName);

  final String id;
  final String label;
  final String fileName;

  static BackupDataType? fromId(String value) {
    for (final type in values) {
      if (type.id == value) return type;
    }
    return null;
  }
}

class BackupManifest {
  const BackupManifest({
    required this.version,
    required this.createdAt,
    required this.files,
    required this.counts,
  });

  static const currentVersion = 1;

  final int version;
  final DateTime createdAt;
  final Map<BackupDataType, String> files;
  final Map<BackupDataType, int?> counts;

  Map<String, dynamic> toJson() => {
        'version': version,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'files': {
          for (final entry in files.entries) entry.key.id: entry.value,
        },
        'counts': {
          for (final entry in counts.entries)
            if (entry.value != null) entry.key.id: entry.value,
        },
      };

  static BackupManifest fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final createdAt = json['createdAt'];
    final rawFiles = json['files'];
    final rawCounts = json['counts'];
    if (version is! int || createdAt is! String || rawFiles is! Map) {
      throw const FormatException('Invalid backup manifest');
    }

    final parsedFiles = <BackupDataType, String>{};
    final parsedCounts = <BackupDataType, int?>{};
    for (final entry in rawFiles.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid backup manifest file entry');
      }
      final type = BackupDataType.fromId(entry.key as String);
      if (type == null || entry.value != type.fileName) {
        throw const FormatException('Unsupported backup file entry');
      }
      if (parsedFiles.containsKey(type)) {
        throw const FormatException('Duplicate backup file entry');
      }
      parsedFiles[type] = entry.value as String;
    }

    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        if (entry.key is! String || entry.value is! int || entry.value < 0) {
          throw const FormatException('Invalid backup manifest count');
        }
        final type = BackupDataType.fromId(entry.key as String);
        if (type == null || !parsedFiles.containsKey(type)) {
          throw const FormatException('Unsupported backup manifest count');
        }
        parsedCounts[type] = entry.value as int;
      }
    }

    final parsedTime = DateTime.tryParse(createdAt);
    if (parsedTime == null || parsedTime.isAfter(DateTime.now().toUtc())) {
      throw const FormatException('Invalid backup timestamp');
    }
    if (version != currentVersion) {
      throw FormatException('Unsupported backup version: $version');
    }
    return BackupManifest(
      version: version,
      createdAt: parsedTime.toUtc(),
      files: Map.unmodifiable(parsedFiles),
      counts: Map.unmodifiable({
        for (final type in parsedFiles.keys) type: parsedCounts[type],
      }),
    );
  }
}

class BackupFile {
  const BackupFile({required this.type, required this.bytes});

  final BackupDataType type;
  final Uint8List bytes;
}

class BackupPreview {
  const BackupPreview({required this.manifest});

  final BackupManifest manifest;
}
