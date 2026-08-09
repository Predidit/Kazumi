import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/backup_service.dart';

class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  final IBackupService _backupService = inject<IBackupService>();
  bool _busy = false;

  String _timestamp(DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(now.year % 100)}${two(now.month)}${two(now.day)}'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<Set<BackupDataType>> _pickTypes({
    required String title,
    required String Function(BackupDataType type) labelFor,
    Set<BackupDataType> disabled = const {},
  }) async {
    final selected = <BackupDataType>{};
    final result = await KazumiDialog.show<Set<BackupDataType>>(
      clickMaskDismiss: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final type in BackupDataType.values)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selected.contains(type),
                  onChanged: disabled.contains(type)
                      ? null
                      : (checked) => setState(() {
                            if (checked == true) {
                              selected.add(type);
                            } else {
                              selected.remove(type);
                            }
                          }),
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
                  : () => Navigator.of(context).pop(Set.of(selected)),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
    return result ?? <BackupDataType>{};
  }

  Future<void> _startBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      late final Map<BackupDataType, int> counts;
      try {
        counts = await _backupService.getCurrentCounts();
      } catch (error, stackTrace) {
        KazumiLogger().e(
          'BackupSettings: read backup counts failed',
          error: error,
          stackTrace: stackTrace,
        );
        KazumiDialog.showToast(message: '读取备份数据失败: $error');
        return;
      }
      final types = await _pickTypes(
        title: '选择要备份的数据',
        labelFor: (type) => '${type.label}（${counts[type]} 条）',
      );
      if (!mounted || types.isEmpty) return;

      KazumiDialog.showLoading(msg: '正在备份');
      final bytes = await _backupService.createBackup(types);
      KazumiDialog.dismiss();
      if (bytes == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            KazumiDialog.showToast(message: '没有可备份的数据');
          }
        });
        return;
      }
      final String backupName = 'KazumiData-${_timestamp(DateTime.now())}.zip';
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存备份',
        fileName: backupName,
        bytes: bytes,
      );
      if (savedPath == null) {
        KazumiLogger().i('BackupSettings: backup cancelled by user');
        return;
      }
      KazumiLogger().i('BackupSettings: created a backup');
      KazumiDialog.showToast(message: '备份完成: $backupName');
    } catch (error, stackTrace) {
      KazumiDialog.dismiss();
      KazumiLogger().e(
        'BackupSettings: backup failed',
        error: error,
        stackTrace: stackTrace,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          KazumiDialog.showToast(message: '备份失败: $error');
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startRestore() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final FilePickerResult? picked;
      try {
        picked = await FilePicker.platform.pickFiles(
          dialogTitle: '选择备份文件',
          type: FileType.custom,
          allowedExtensions: ['zip'],
          withData: true,
        );
      } catch (error) {
        KazumiLogger().w('BackupSettings: pick backup file failed', error: error);
        KazumiDialog.showToast(message: '选择备份文件失败');
        return;
      }
      final bytes = picked?.files.single.bytes;
      if (bytes == null) {
        if (picked != null) KazumiDialog.showToast(message: '读取备份文件失败');
        return;
      }

      final BackupInspection inspection;
      try {
        inspection = await _backupService.inspect(bytes);
      } catch (error) {
        KazumiLogger().w('BackupSettings: invalid backup file', error: error);
        KazumiDialog.showToast(message: '该文件不是有效的备份');
        return;
      }
      if (inspection.unavailable.length == BackupDataType.values.length) {
        KazumiDialog.showToast(message: '该备份无效或没有可恢复的数据');
        return;
      }

      final types = await _pickTypes(
        title: '选择要还原的数据（${picked!.files.single.name}）',
        labelFor: (type) => inspection.counts[type] == null
            ? '${type.label}（无备份数据）'
            : '${type.label}（${inspection.counts[type]} 条）',
        disabled: inspection.unavailable,
      );
      if (types.isEmpty) return;
      final confirmed = await KazumiDialog.show<bool>(
        clickMaskDismiss: false,
        builder: (context) => AlertDialog(
          title: const Text('警告'),
          content: const Text(
            '已选项将被替换为备份文件中的内容。\n未选项不会被修改。是否继续？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认恢复'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      KazumiDialog.showLoading(msg: '正在恢复');
      await _backupService.restore(bytes, types);
      KazumiDialog.dismiss();
      KazumiLogger().i('BackupSettings: restore from a backup');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          KazumiDialog.showToast(message: '恢复完成，部分数据需要重启生效');
        }
      });
    } catch (error, stackTrace) {
      KazumiDialog.dismiss();
      KazumiLogger().e(
        'BackupSettings: restore failed',
        error: error,
        stackTrace: stackTrace,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          KazumiDialog.showToast(message: '恢复失败: $error');
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _trailing() => _busy
      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
      : const Icon(Icons.chevron_right_rounded);

  @override
  Widget build(BuildContext context) => SettingsDetailScaffold(
        title: const Text('备份与还原'),
        body: SettingsList(sections: [
          SettingsSection(title: const Text('备份数据'), tiles: [
            SettingsTile(
              leading: Icons.cloud_upload_rounded,
              title: const Text('开始备份'),
              description: const Text('选择备份项目并导出'),
              trailing: _trailing(),
              enabled: !_busy,
              onPressed: (_) => _startBackup(),
            ),
          ]),
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
        ]),
      );
}
