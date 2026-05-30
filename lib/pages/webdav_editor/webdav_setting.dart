import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/services/sync/bangumi_sync_service.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/webdav.dart';
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
  late bool enableBangumiProxy;
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
    enableBangumiProxy =
        setting.get(SettingBoxKey.enableBangumiProxy, defaultValue: false);
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
      KazumiDialog.showToast(message: 'Syncing watch history');
      var webDav = WebDav();
      try {
        await webDav.ping();
        try {
          await webDav.syncHistory();
          KazumiLogger().i('WebDav: manual history sync completed');
          KazumiDialog.showToast(message: 'Watch history sync complete');
        } catch (e) {
          KazumiLogger().w('WebDav: manual history sync failed', error: e);
          KazumiDialog.showToast(message: 'Watch history sync failed ${e.toString()}');
        }
      } catch (e) {
        KazumiLogger().w('WebDav: manual history sync ping failed', error: e);
        KazumiDialog.showToast(message: 'WebDav connection failed');
      }
    } else {
      KazumiDialog.showToast(message: 'WebDav sync is not enabled or the configuration is invalid');
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
        appBar: const SysAppBar(title: Text('Sync settings')),
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
                  title: Text('Github mirror',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Use a mirror to access the rule hosting repository',
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
                    enableBangumiProxy = value ?? !enableBangumiProxy;
                    await setting.put(
                        SettingBoxKey.enableBangumiProxy, enableBangumiProxy);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  title: Text('Bangumi mirror',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Use the local Bangumi cache backend to load trending and category rankings',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: enableBangumiProxy,
                ),
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
                            message: 'Please configure your Bangumi Access Token first');
                        return;
                      } else {
                        if (!bangumi.initialized) {
                          try {
                            await bangumi.init();
                          } catch (e) {
                            KazumiDialog.showToast(
                                message: "Bangumi initialization failed, please try again later");
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
                  title: Text('Bangumi sync',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Allow automatic syncing of collection and tracking status with Bangumi',
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
                  title: Text('Bangumi configuration',
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
                        KazumiDialog.showToast(message: 'WebDAV initialization failed $e');
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
                  title: Text('WebDAV sync',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: webDavEnable,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    if (!webDavEnable) {
                      KazumiDialog.showToast(message: 'Please enable WebDAV sync first');
                      return;
                    }
                    webDavEnableHistory = value ?? !webDavEnableHistory;
                    await setting.put(
                        SettingBoxKey.webDavEnableHistory, webDavEnableHistory);
                    setState(() {});
                  },
                  title:
                      Text('Watch history sync', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Allow automatic syncing of watch history',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: webDavEnableHistory,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    if (!webDavEnable) {
                      KazumiDialog.showToast(message: 'Please enable WebDAV sync first');
                      return;
                    }
                    webDavEnableCollect = value ?? !webDavEnableCollect;
                    await setting.put(
                        SettingBoxKey.webDavEnableCollect, webDavEnableCollect);
                    setState(() {});
                  },
                  title: Text('Collection sync', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Allow WebDAV to participate in tracking status sync',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: webDavEnableCollect,
                ),
                SettingsTile.navigation(
                  onPressed: (_) async {
                    Modular.to.pushNamed('/settings/webdav/editor');
                  },
                  title: Text('WebDAV configuration',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile(
                  trailing: const Icon(Icons.sync_rounded),
                  onPressed: (_) {
                    syncHistoryWithWebDav();
                  },
                  title: Text('Sync watch history now',
                      style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Two-way merge watch history with WebDAV',
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
