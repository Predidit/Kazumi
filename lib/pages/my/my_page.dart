import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  late NavigationBarState navigationBarState;

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    navigationBarState.updateSelectedIndex(0);
    Modular.to.navigate('/tab/popular/');
  }

  @override
  void initState() {
    super.initState();
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('Me'), needTopOffset: false),
        body: SettingsList(
          maxWidth: 1000,
          sections: [
            SettingsSection(
              title: Text('Watch history and video sources', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/history/');
                  },
                  leading: const Icon(Icons.history_rounded),
                  title: Text('History', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('View watch history',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/download/');
                  },
                  leading: const Icon(Icons.download_rounded),
                  title: Text('Download manager', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('View and manage offline downloads',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/download-settings');
                  },
                  leading: const Icon(Icons.settings_rounded),
                  title: Text('Download settings', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Configure download concurrency and other parameters',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/plugin/');
                  },
                  leading: const Icon(Icons.extension),
                  title: Text('Rule management', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Manage anime source rules',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              title: Text('Player settings', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/player');
                  },
                  leading: const Icon(Icons.display_settings_rounded),
                  title: Text('Playback settings', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Configure player-related parameters',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/danmaku/');
                  },
                  leading: const Icon(Icons.subtitles_rounded),
                  title: Text('Danmaku settings', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Configure danmaku-related parameters',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/keyboard');
                  },
                  leading: const Icon(Icons.keyboard_rounded),
                  title: Text('Control settings', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Configure player key bindings',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/proxy');
                  },
                  leading: const Icon(Icons.vpn_key_rounded),
                  title: Text('Proxy settings', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Configure HTTP proxy',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              title: Text('App and appearance', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/theme');
                  },
                  leading: const Icon(Icons.palette_rounded),
                  title: Text('Appearance settings', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Configure app theme and refresh rate',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/interface');
                  },
                  leading: const Icon(Icons.pages_rounded),
                  title: Text('Interface settings', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Configure app interface style',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/webdav/');
                  },
                  leading: const Icon(Icons.cloud),
                  title: Text('Sync settings', style: TextStyle(fontFamily: fontFamily)),
                  description:
                      Text('Configure sync parameters', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              title: Text('Other', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/about/');
                  },
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text('About', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
