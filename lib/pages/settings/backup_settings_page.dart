import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/services/backup/backup_controller.dart';
import 'package:kazumi/services/backup/backup_models.dart';

class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  late final BackupController _controller = inject<BackupController>();
  bool _isOpeningFilePicker = false;

  Future<void> _export() async {
    final counts = await _controller.currentCounts();
    final types = await _selectTypes('选择要备份的数据', counts: counts);
    if (types == null || types.isEmpty) return;
    try {
      _setFilePickerLoading(true);
      final saved = await _controller.export(types);
      if (saved) {
        KazumiDialog.showToast(message: '备份已保存');
      }
    } catch (error) {
      KazumiDialog.showToast(message: '备份失败：$error');
    } finally {
      _setFilePickerLoading(false);
    }
  }

  Future<void> _restore() async {
    try {
      _setFilePickerLoading(true);
      if (!await _controller.selectBackup()) return;
      _setFilePickerLoading(false);
      final preview = _controller.preview;
      if (preview == null || !mounted) return;
      final types = await _selectTypes(
        '恢复数据\n${_formatDateTime(preview.manifest.createdAt.toLocal())}',
        available: preview.manifest.files.keys.toSet(),
        counts: preview.manifest.counts,
      );
      if (types == null || types.isEmpty || !mounted) return;
      final confirmed = await KazumiDialog.show<bool>(
        context: context,
        clickMaskDismiss: false,
        builder: (context) => AlertDialog(
          title: const Text('确认恢复数据？'),
          content: const Text('选中的数据将替换当前数据，此操作无法撤销。'),
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
      await _controller.restore(types);
      KazumiDialog.showToast(message: '恢复完成，部分数据需要重启生效');
    } catch (error) {
      KazumiDialog.showToast(message: '恢复失败：$error');
    } finally {
      _setFilePickerLoading(false);
    }
  }

  void _setFilePickerLoading(bool value) {
    if (!mounted || _isOpeningFilePicker == value) return;
    setState(() => _isOpeningFilePicker = value);
  }

  Future<Set<BackupDataType>?> _selectTypes(
    String title, {
    Set<BackupDataType>? available,
    Map<BackupDataType, int?>? counts,
  }) async {
    final selectable = {
      for (final type in (available ?? BackupDataType.values.toSet()))
        if ((counts?[type] ?? 0) > 0) type,
    };
    final selected = <BackupDataType>{
      ...selectable,
    };
    return KazumiDialog.show<Set<BackupDataType>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final type in BackupDataType.values)
                CheckboxListTile(
                  value: selectable.contains(type) && selected.contains(type),
                  title: Text('${type.label}（${counts?[type] ?? 0} 条）'),
                  enabled: selectable.contains(type),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        selected.add(type);
                      } else {
                        selected.remove(type);
                      }
                    });
                  },
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
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}:${twoDigits(value.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: const Text('备份与恢复'),
      body: Stack(
        children: [
          SettingsList(
            sections: [
              SettingsSection(
                title: const Text('应用数据'),
                tiles: [
                  SettingsTile(
                    leading: Icons.upload_file_rounded,
                    title: const Text('导出备份'),
                    description: const Text('选择应用数据并导出'),
                    onPressed: (_) => _export(),
                  ),
                  SettingsTile(
                    leading: Icons.file_download_rounded,
                    title: const Text('导入备份'),
                    description: const Text('从备份文件中恢复数据'),
                    onPressed: (_) => _restore(),
                  ),
                ],
              ),
            ],
          ),
          if (_isOpeningFilePicker)
            const ModalBarrier(
              dismissible: false,
              color: Colors.transparent,
            ),
          if (_isOpeningFilePicker)
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 16),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('正在打开文件选择器…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
