import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

enum _BackupDataType {
  collect(
    label: '我的追番',
    fileNames: ['collectibles.hive', 'collectchanges.hive'],
  ),
  history(label: '历史记录', fileNames: ['histories.hive']),
  rules(label: '规则列表', fileNames: ['plugins.json']),
  settings(label: '设置项目', fileNames: ['setting.hive']);

  const _BackupDataType({required this.label, required this.fileNames});

  final String label;
  final List<String> fileNames;

  bool get isRules => this == rules;

  String get primaryFileName => fileNames.first;
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  bool _busy = false;

  String _timestamp(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.year % 100)}${two(now.month)}${two(now.day)}'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<void> _toast(String message, {bool dismissFirst = false}) async {
    if (dismissFirst) KazumiDialog.dismiss();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    KazumiDialog.showToast(message: message);
  }

  Future<Set<_BackupDataType>> _pickTypes({
    required String title,
    required String Function(_BackupDataType type) labelFor,
    Set<_BackupDataType> disabled = const {},
  }) async {
    final selected = <_BackupDataType>{};
    final result = await KazumiDialog.show<Set<_BackupDataType>>(
      clickMaskDismiss: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final type in _BackupDataType.values)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: selected.contains(type),
                      onChanged: disabled.contains(type)
                          ? null
                          : (checked) {
                              setState(() {
                                if (checked == true) {
                                  selected.add(type);
                                } else {
                                  selected.remove(type);
                                }
                              });
                            },
                      title: Text(labelFor(type)),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.of(context)
                          .pop(Set<_BackupDataType>.of(selected)),
                  child: const Text('确认'),
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? <_BackupDataType>{};
  }

  Future<void> _startBackup() async {
    if (_busy) return;
    final types = await _pickTypes(
      title: '选择要备份的数据',
      labelFor: (type) {
        final count = switch (type) {
          _BackupDataType.collect => GStorage.collectibles.length,
          _BackupDataType.history => GStorage.histories.length,
          _BackupDataType.rules =>
            inject<PluginsController>().pluginList.length,
          _BackupDataType.settings => GStorage.settingsCount,
        };
        return '${type.label}（$count 条）';
      },
    );
    if (types.isEmpty) return;

    setState(() => _busy = true);
    KazumiDialog.showLoading(msg: '正在备份');
    try {
      await GStorage.flushAll();
      final supportDir = await getApplicationSupportDirectory();
      final backupArchive = Archive();
      for (final type in types) {
        final sourceDir = type.isRules
            ? Directory(p.join(supportDir.path, 'plugins', 'v2'))
            : Directory(p.join(supportDir.path, 'hive'));
        for (final fileName in type.fileNames) {
          final source = File(p.join(sourceDir.path, fileName));
          if (await source.exists()) {
            backupArchive.addFile(
              ArchiveFile.bytes(fileName, await source.readAsBytes()),
            );
          }
        }
      }
      if (backupArchive.isEmpty) {
        await _toast('没有可备份的数据', dismissFirst: true);
        return;
      }
      final zipBytes = ZipEncoder().encodeBytes(backupArchive);
      final fileName = 'KazumiData-${_timestamp(DateTime.now())}.zip';
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存备份',
        fileName: fileName,
        bytes: zipBytes,
      );
      if (savedPath == null) {
        KazumiLogger().i('BackupSettings: backup cancelled by user');
        KazumiDialog.dismiss();
        return;
      }
      KazumiLogger().i('BackupSettings: created a backup');
      await _toast('备份完成', dismissFirst: true);
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'BackupSettings: backup failed',
        error: e,
        stackTrace: stackTrace,
      );
      await _toast('备份失败: $e', dismissFirst: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startRestore() async {
    if (_busy) return;
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        dialogTitle: '选择备份文件',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );
    } catch (e) {
      KazumiLogger().w('BackupSettings: pick backup file failed', error: e);
      await _toast('选择备份文件失败');
      return;
    }
    if (picked == null || picked.files.isEmpty) return;

    final pickedFile = picked.files.single;
    final pickedBytes = pickedFile.bytes;
    if (pickedBytes == null) {
      await _toast('读取备份文件失败');
      return;
    }
    final Archive backupArchive;
    try {
      backupArchive = ZipDecoder().decodeBytes(pickedBytes);
    } catch (e) {
      KazumiLogger().w('BackupSettings: invalid backup file', error: e);
      await _toast('该文件不是有效的备份');
      return;
    }

    Future<int?> countOf(_BackupDataType type) async {
      final entry = backupArchive.findFile(type.primaryFileName);
      final bytes = (entry == null || !entry.isFile) ? null : entry.readBytes();
      if (bytes == null) return null;
      try {
        if (type.isRules) {
          final data = jsonDecode(utf8.decode(bytes));
          return data is List ? data.length : null;
        }
        final box = await Hive.openBox('backupCountBox', bytes: bytes);
        try {
          return box.length;
        } finally {
          await box.close();
        }
      } catch (e) {
        KazumiLogger().w('BackupSettings: read backup count failed', error: e);
        return null;
      }
    }

    final counts = <_BackupDataType, int?>{
      for (final type in _BackupDataType.values) type: await countOf(type),
    };
    final disabled = <_BackupDataType>{
      for (final entry in counts.entries)
        if (entry.value == null) entry.key,
    };
    if (disabled.length == _BackupDataType.values.length) {
      KazumiLogger().w(
          'BackupSettings: cannot use the backup because no valid data in it');
      await _toast('该备份无效或没有可恢复的数据');
      return;
    }

    final fileName = pickedFile.name;
    final stamp = fileName
        .replaceFirst(RegExp('^KazumiData-'), '')
        .replaceFirst(RegExp(r'\.zip$'), '');
    final timeLabel = stamp.length == 12
        ? '${stamp.substring(0, 2)}-${stamp.substring(2, 4)}-'
            '${stamp.substring(4, 6)} '
            '${stamp.substring(6, 8)}:${stamp.substring(8, 10)}:'
            '${stamp.substring(10, 12)}'
        : fileName;

    final types = await _pickTypes(
      title: '选择要还原的数据（$timeLabel）',
      labelFor: (type) {
        final count = counts[type];
        return count == null
            ? '${type.label}（无备份数据）'
            : '${type.label}（$count 条）';
      },
      disabled: disabled,
    );
    if (types.isEmpty) return;

    final confirmed = await KazumiDialog.show<bool>(
      clickMaskDismiss: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('警告'),
          content: const Text(
            '已选项将被替换为备份文件中的内容。\n'
            '未选项不会被修改。是否继续？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认还原'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    KazumiDialog.showLoading(msg: '正在还原');
    try {
      final supportDir = await getApplicationSupportDirectory();
      for (final type in types) {
        if (type.isRules) {
          final bytes = backupArchive.findFile('plugins.json')?.readBytes();
          if (bytes != null) {
            final targetDir =
                Directory(p.join(supportDir.path, 'plugins', 'v2'));
            await targetDir.create(recursive: true);
            await File(p.join(targetDir.path, 'plugins.json'))
                .writeAsBytes(bytes);
            await inject<PluginsController>().init();
          }
          continue;
        }
        switch (type) {
          case _BackupDataType.collect:
            {
              final collectBytes =
                  backupArchive.findFile('collectibles.hive')?.readBytes();
              if (collectBytes != null) {
                await GStorage.restoreBoxFromBytes(
                  'collectibles',
                  GStorage.collectibles,
                  collectBytes,
                );
              }
              final changesBytes =
                  backupArchive.findFile('collectchanges.hive')?.readBytes();
              if (changesBytes != null) {
                await GStorage.restoreCollectChangesFromBytes(changesBytes);
              }
            }
          case _BackupDataType.history:
            {
              final bytes =
                  backupArchive.findFile('histories.hive')?.readBytes();
              if (bytes != null) {
                await GStorage.restoreBoxFromBytes(
                  'histories',
                  GStorage.histories,
                  bytes,
                );
              }
            }
          case _BackupDataType.settings:
            {
              final bytes = backupArchive.findFile('setting.hive')?.readBytes();
              if (bytes != null) {
                await GStorage.restoreSettingsFromBytes(bytes);
              }
            }
          case _BackupDataType.rules:
            break;
        }
      }
      KazumiLogger().i('BackupSettings: restore from a backup');
      await _toast('恢复完成，部分数据需要重启生效', dismissFirst: true);
    } catch (e, stackTrace) {
      KazumiLogger().e(
        'BackupSettings: restore failed',
        error: e,
        stackTrace: stackTrace,
      );
      await _toast('恢复失败: $e', dismissFirst: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _trailing() {
    if (_busy) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return const Icon(Icons.chevron_right_rounded);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: const Text('备份与还原'),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('备份数据'),
            tiles: [
              SettingsTile(
                leading: Icons.cloud_upload_rounded,
                title: const Text('开始备份'),
                description: const Text('选择备份项目并导出'),
                trailing: _trailing(),
                enabled: !_busy,
                onPressed: (_) => _startBackup(),
              ),
            ],
          ),
          SettingsSection(
            title: const Text('还原数据'),
            tiles: [
              SettingsTile(
                leading: Icons.cloud_download_rounded,
                title: const Text('从备份还原'),
                description: const Text('从备份文件导入数据'),
                trailing: _trailing(),
                enabled: !_busy,
                onPressed: (_) => _startRestore(),
              ),
            ],
            bottomInfo: const Text('警告：还原将覆盖当前数据，建议先进行一次备份。'),
          ),
        ],
      ),
    );
  }
}
