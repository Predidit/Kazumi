import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:hive/hive.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class WebDavSettingsPage extends StatefulWidget {
  const WebDavSettingsPage({super.key});

  @override
  State<WebDavSettingsPage> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends State<WebDavSettingsPage> {
  Box setting = GStorage.setting;
  late bool webDavEnable;
  late bool enableGitProxy;

  @override
  void initState() {
    super.initState();
    webDavEnable = setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    enableGitProxy = setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);
  }

  void onBackPressed(BuildContext context) {}

  Future<void> checkWebDav() async {
    var webDavURL =
        await setting.get(SettingBoxKey.webDavURL, defaultValue: '');
    if (webDavURL == '') {
      await setting.put(SettingBoxKey.webDavEnable, false);
      KazumiDialog.showToast(message: '未找到有效的webdav配置');
      return;
    }
    try {
      KazumiDialog.showToast(message: '尝试从WebDav同步');
      var webDav = WebDav();
      await webDav.downloadHistory();
      KazumiDialog.showToast(message: '同步成功');
    } catch (e) {
      if (e.toString().contains('Error: Not Found')) {
        KazumiDialog.showToast(message: '配置成功, 这是一个不存在已有同步文件的全新WebDav');
      } else {
        KazumiDialog.showToast(message: '同步失败 ${e.toString()}');
      }
    }
  }

  Future<void> updateWebdav() async {
    var webDavEnable =
        await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    if (webDavEnable) {
      try {
        KazumiDialog.showToast(message: '尝试上传到WebDav');
        var webDav = WebDav();
        await webDav.updateHistory();
        KazumiDialog.showToast(message: '同步成功');
      } catch (e) {
        KazumiDialog.showToast(message: '同步失败 ${e.toString()}');
      }
    } else {
      KazumiDialog.showToast(message: '未开启WebDav同步或配置无效');
    }
  }

  Future<void> downloadWebdav() async {
    var webDavEnable =
        await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    if (webDavEnable) {
      try {
        KazumiDialog.showToast(message: '尝试从WebDav同步');
        var webDav = WebDav();
        await webDav.downloadHistory();
        KazumiDialog.showToast(message: '同步成功');
      } catch (e) {
        KazumiDialog.showToast(message: '同步失败 ${e.toString()}');
      }
    } else {
      KazumiDialog.showToast(message: '未开启WebDav同步或配置无效');
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {});
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('同步设置')),
        body: Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
            child: SettingsList(
              sections: [
                SettingsSection(
                  title: const Text('Github'),
                  tiles: [
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        enableGitProxy = value ?? !enableGitProxy;
                        await setting.put(SettingBoxKey.enableGitProxy, enableGitProxy);
                        setState(() {});
                      },
                      title: const Text('Github镜像'),
                      description: const Text('使用镜像访问规则托管仓库'),
                      initialValue: enableGitProxy,
                    ),
                  ],
                ),
                SettingsSection(
                  title: const Text('WEBDAV'),
                  tiles: [
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        webDavEnable = value ?? !webDavEnable;
                        await setting.put(SettingBoxKey.webDavEnable, webDavEnable);
                        setState(() {});
                      },
                      title: const Text('WEBDAV同步'),
                      description: const Text('使用WEBDAV自动同步观看记录'),
                      initialValue: webDavEnable,
                    ),
                    SettingsTile.navigation(
                      onPressed: (_) async {
                        Modular.to.pushNamed('/settings/webdav/editor');
                      },
                      title: Text(
                        'WEBDAV配置',
                        style: Theme.of(context).textTheme.titleMedium!,
                      ),
                    ),
                  ],
                ),
                SettingsSection(
                  bottomInfo: const Text('立即上传观看记录到WEBDAV'),
                  tiles: [
                    SettingsTile(
                      trailing: const Icon(Icons.cloud_upload_rounded),
                      onPressed: (_) {
                        updateWebdav();
                      },
                      title: const Text('手动上传'),
                    ),
                  ],
                ),
                SettingsSection(
                  bottomInfo: const Text('立即下载观看记录到本地'),
                  tiles: [
                    SettingsTile(
                      trailing: const Icon(Icons.cloud_download_rounded),
                      onPressed: (_) {
                        downloadWebdav();
                      },
                      title: const Text('手动下载'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
