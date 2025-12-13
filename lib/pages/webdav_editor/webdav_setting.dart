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
  late bool webDavEnableHistory;
  late bool enableGitProxy;

  @override
  void initState() {
    super.initState();
    webDavEnable = setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    webDavEnableHistory =
        setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);
    enableGitProxy =
        setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

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
      await webDav.downloadAndPatchHistory();
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
      KazumiDialog.showToast(message: '尝试上传到WebDav');
      var webDav = WebDav();
      try {
        await webDav.ping();
        try {
          await webDav.updateHistory();
          KazumiDialog.showToast(message: '同步成功');
        } catch (e) {
          KazumiDialog.showToast(message: '同步失败 ${e.toString()}');
        }
      } catch (e) {
        KazumiDialog.showToast(message: 'WebDAV连接失败');
      }
    } else {
      KazumiDialog.showToast(message: '未开启WebDav同步或配置无效');
    }
  }

  Future<void> downloadWebdav() async {
    var webDavEnable =
        await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    if (webDavEnable) {
      KazumiDialog.showToast(message: '尝试从WebDav同步');
      var webDav = WebDav();
      try {
        await webDav.ping();
        try {
          await webDav.downloadAndPatchHistory();
          KazumiDialog.showToast(message: '同步成功');
        } catch (e) {
          KazumiDialog.showToast(message: '同步失败 ${e.toString()}');
        }
      } catch (e) {
        KazumiDialog.showToast(message: 'WebDAV连接失败');
      }
    } else {
      KazumiDialog.showToast(message: '未开启WebDav同步或配置无效');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('同步设置')),
        body: SettingsList(
          maxWidth: 1000,
          sections: [
            SettingsSection(
              title: Text('Github', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    enableGitProxy = value ?? !enableGitProxy;
                    await setting.put(
                        SettingBoxKey.enableGitProxy, enableGitProxy);
                    setState(() {});
                  },
                  title: Text('Github镜像', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('使用镜像访问规则托管仓库', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: enableGitProxy,
                ),
              ],
            ),
            SettingsSection(
              title: Text('WEBDAV', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    webDavEnable = value ?? !webDavEnable;
                    if (!WebDav().initialized && webDavEnable) {
                      try {
                        await WebDav().init();
                      } catch (e) {
                        webDavEnable = false;
                        KazumiDialog.showToast(message: 'WEBDAV初始化失败 $e');
                      }
                    }
                    if (!webDavEnable) {
                      webDavEnableHistory = false;
                      await setting.put(
                          SettingBoxKey.webDavEnableHistory, false);
                    }
                    await setting.put(SettingBoxKey.webDavEnable, webDavEnable);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  title: Text('WEBDAV同步', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: webDavEnable,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    if (!webDavEnable) {
                      KazumiDialog.showToast(message: '请先开启WEBDAV同步');
                      return;
                    }
                    webDavEnableHistory = value ?? !webDavEnableHistory;
                    await setting.put(
                        SettingBoxKey.webDavEnableHistory, webDavEnableHistory);
                    setState(() {});
                  },
                  title: Text('观看记录同步', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('允许自动同步观看记录', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: webDavEnableHistory,
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    Modular.to.pushNamed('/settings/webdav/editor');
                  },
                  title: Text('WEBDAV配置', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              bottomInfo: Text('立即上传观看记录到WEBDAV', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile(
                  trailing: const Icon(Icons.cloud_upload_rounded),
                  onPressed: (_) {
                    updateWebdav();
                  },
                  title: Text('手动上传', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              bottomInfo: Text('立即下载观看记录到本地', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile(
                  trailing: const Icon(Icons.cloud_download_rounded),
                  onPressed: (_) {
                    downloadWebdav();
                  },
                  title: Text('手动下载', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
