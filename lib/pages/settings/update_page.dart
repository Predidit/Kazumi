import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/utils/auto_updater.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive/hive.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  Box setting = GStorage.setting;
  late bool autoUpdate;
  bool isChecking = false;
  UpdateInfo? latestUpdate;

  @override
  void initState() {
    super.initState();
    autoUpdate = setting.get(SettingBoxKey.autoUpdate, defaultValue: true);
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    if (isChecking) return;

    setState(() {
      isChecking = true;
    });

    try {
      final autoUpdater = AutoUpdater();
      final updateInfo = await autoUpdater.checkForUpdates();

      setState(() {
        latestUpdate = updateInfo;
        isChecking = false;
      });
    } catch (e) {
      setState(() {
        isChecking = false;
      });
      KazumiDialog.showToast(message: '检查更新失败');
    }
  }

  void _manualCheckUpdate() async {
    final autoUpdater = AutoUpdater();
    await autoUpdater.manualCheckForUpdates();
    // 检查完成后刷新状态
    _checkForUpdates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(title: Text('应用更新')),
      body: Center(
        child: SizedBox(
          width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
          child: SettingsList(
            sections: [
              SettingsSection(
                title: const Text('当前版本'),
                tiles: [
                  SettingsTile.navigation(
                    title: const Text('版本号'),
                    value: Text(Api.version),
                    leading: const Icon(Icons.info_outline),
                    onPressed: null,
                  ),
                  SettingsTile.navigation(
                    title: const Text('更新状态'),
                    value: _buildUpdateStatusWidget(),
                    leading: const Icon(Icons.update),
                    onPressed: null,
                  ),
                ],
              ),
              SettingsSection(
                title: const Text('更新设置'),
                tiles: [
                  SettingsTile.navigation(
                    onPressed: (_) => _manualCheckUpdate(),
                    title: const Text('检查更新'),
                    description: const Text('立即检查是否有新版本'),
                    leading: const Icon(Icons.refresh),
                    trailing: isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : SizedBox.shrink(),
                  ),
                ],
              ),
              if (latestUpdate != null) ...[
                SettingsSection(
                  title: const Text('可用更新'),
                  tiles: [
                    SettingsTile.navigation(
                      title: Text('新版本 ${latestUpdate!.version}'),
                      leading: const Icon(Icons.system_update),
                      onPressed: (_) {
                        _manualCheckUpdate();
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateStatusWidget() {
    if (isChecking) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('检查中...'),
        ],
      );
    }

    if (latestUpdate != null) {
      return const Text('有新版本可用');
    }

    return const Text('已是最新版本');
  }
}
