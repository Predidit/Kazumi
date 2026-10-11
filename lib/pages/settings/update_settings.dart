import 'package:flutter/material.dart';

import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_dropdown_tile.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/update/update_download_source.dart';

class UpdateSettingsPage extends StatefulWidget {
  const UpdateSettingsPage({super.key});

  @override
  State<UpdateSettingsPage> createState() => _UpdateSettingsPageState();
}

class _UpdateSettingsPageState extends State<UpdateSettingsPage> {
  bool _autoUpdate = GStorage.getSetting(SettingsKeys.autoUpdate);
  bool _pluginUpdate =
      GStorage.getSetting(SettingsKeys.checkPluginUpdateOnStartup);
  UpdateDownloadSource _downloadSource = UpdateDownloadSource.fromSetting(
      GStorage.getSetting(SettingsKeys.updateDownloadSource));

  Future<void> _setDownloadSource(UpdateDownloadSource source) async {
    try {
      await GStorage.putSetting(SettingsKeys.updateDownloadSource, source.name);
      if (mounted) setState(() => _downloadSource = source);
    } catch (_) {
      if (mounted) {
        KazumiDialog.showToast(context: context, message: '下载源保存失败，请重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) => SettingsDetailScaffold(
        title: const Text('更新设置'),
        body: SettingsList(
          sections: [
            SettingsSection(
              title: const Text('应用更新下载'),
              tiles: [
                SettingsDropdownTile<UpdateDownloadSource>(
                  leading: Icons.download_rounded,
                  title: const Text('更新下载源'),
                  description: Text(_downloadSource.description),
                  value: _downloadSource,
                  options: {
                    for (final source in UpdateDownloadSource.values)
                      source: source.label,
                  },
                  onChanged: _setDownloadSource,
                ),
              ],
            ),
            SettingsSection(
              title: const Text('启动时检查更新'),
              tiles: [
                SettingsTile.switchTile(
                  leading: Icons.update_rounded,
                  title: const Text('应用更新'),
                  initialValue: _autoUpdate,
                  onToggle: (value) {
                    setState(() => _autoUpdate = value ?? !_autoUpdate);
                    GStorage.putSetting(SettingsKeys.autoUpdate, _autoUpdate);
                  },
                ),
                SettingsTile.switchTile(
                  leading: Icons.extension_rounded,
                  title: const Text('规则更新'),
                  initialValue: _pluginUpdate,
                  onToggle: (value) {
                    setState(() => _pluginUpdate = value ?? !_pluginUpdate);
                    GStorage.putSetting(
                      SettingsKeys.checkPluginUpdateOnStartup,
                      _pluginUpdate,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      );
}
