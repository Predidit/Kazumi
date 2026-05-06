import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/bangumi_sync_service.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:hive_ce/hive.dart';
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
  late bool webDavEnableCollect;
  late bool enableGitProxy;
  late bool bangumiSyncEnable;

  @override
  void initState() {
    super.initState();
    webDavEnable = setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    webDavEnableHistory =
        setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);
    webDavEnableCollect =
        setting.get(SettingBoxKey.webDavEnableCollect, defaultValue: false);
    enableGitProxy =
        setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);
    bangumiSyncEnable =
        setting.get(SettingBoxKey.bangumiSyncEnable, defaultValue: false);
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  Future<void> syncHistoryWithWebDav() async {
    var webDavEnable =
        await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    if (webDavEnable) {
      KazumiLogger().i('WebDav: manual history sync started');
      KazumiDialog.showToast(message: '正在同步观看记录');
      var webDav = WebDav();
      try {
        await webDav.ping();
        try {
          await webDav.syncHistory();
          KazumiLogger().i('WebDav: manual history sync completed');
          KazumiDialog.showToast(message: '观看记录同步完成');
        } catch (e) {
          KazumiLogger().w('WebDav: manual history sync failed', error: e);
          KazumiDialog.showToast(message: '观看记录同步失败 ${e.toString()}');
        }
      } catch (e) {
        KazumiLogger().w('WebDav: manual history sync ping failed', error: e);
        KazumiDialog.showToast(message: 'WebDav连接失败');
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
                  title: Text('Github镜像',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text('使用镜像访问规则托管仓库',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: enableGitProxy,
                ),
              ],
            ),
            SettingsSection(
              title: Text('Bangumi', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    final tBangumiEnableSync = value ?? !bangumiSyncEnable;
                    final bangumi = BangumiSyncService();
                    if (tBangumiEnableSync == true) {
                      final token = setting
                          .get(SettingBoxKey.bangumiAccessToken,
                              defaultValue: '')
                          .toString()
                          .trim();
                      if (token.isEmpty) {
                        KazumiDialog.showToast(
                            message: '请先配置 Bangumi 的 Access Token');
                        return;
                      } else {
                        if (!bangumi.initialized) {
                          try {
                            await bangumi.init();
                          } catch (e) {
                            KazumiDialog.showToast(
                                message: "Bangumi 初始化失败，请稍后再试");
                            return;
                          }
                        }
                      }
                    }
                    bangumiSyncEnable = tBangumiEnableSync;
                    await setting.put(
                        SettingBoxKey.bangumiSyncEnable, bangumiSyncEnable);
                    if (!mounted) {
                      return;
                    }
                    setState(() {});
                  },
                  title: Text('Bangumi 同步',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text('允许与Bangumi自动同步收藏/追番状态',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: bangumiSyncEnable,
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    await Modular.to.pushNamed('/settings/bangumi/');
                    bangumiSyncEnable = setting.get(
                        SettingBoxKey.bangumiSyncEnable,
                        defaultValue: false);
                    setState(() {});
                  },
                  title: Text('Bangumi 配置',
                      style: TextStyle(fontFamily: fontFamily)),
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
                      webDavEnableCollect = false;
                      await setting.put(
                          SettingBoxKey.webDavEnableHistory, false);
                      await setting.put(
                          SettingBoxKey.webDavEnableCollect, false);
                    }
                    await setting.put(SettingBoxKey.webDavEnable, webDavEnable);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  title: Text('WEBDAV同步',
                      style: TextStyle(fontFamily: fontFamily)),
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
                  title:
                      Text('观看记录同步', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('允许自动同步观看记录',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: webDavEnableHistory,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    if (!webDavEnable) {
                      KazumiDialog.showToast(message: '请先开启WEBDAV同步');
                      return;
                    }
                    webDavEnableCollect = value ?? !webDavEnableCollect;
                    await setting.put(
                        SettingBoxKey.webDavEnableCollect, webDavEnableCollect);
                    setState(() {});
                  },
                  title: Text('收藏同步', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('允许 WebDAV 参与追番状态同步',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: webDavEnableCollect,
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    Modular.to.pushNamed('/settings/webdav/editor');
                  },
                  title: Text('WEBDAV配置',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile(
                  trailing: const Icon(Icons.sync_rounded),
                  onPressed: (_) {
                    syncHistoryWithWebDav();
                  },
                  title: Text('立即同步观看记录',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text('与WEBDAV双向合并观看记录',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
