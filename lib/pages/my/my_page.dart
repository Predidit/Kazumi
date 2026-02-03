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
        appBar: const SysAppBar(title: Text('我的'), needTopOffset: false),
        body: SettingsList(
          maxWidth: 1000,
          sections: [
            SettingsSection(
              title: Text('播放历史与视频源', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/history/');
                  },
                  leading: const Icon(Icons.history_rounded),
                  title: Text('历史记录', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('查看播放历史记录', style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/plugin/');
                  },
                  leading: const Icon(Icons.extension),
                  title: Text('规则管理', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('管理番剧资源规则', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              title: Text('播放器设置', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/player');
                  },
                  leading: const Icon(Icons.display_settings_rounded),
                  title: Text('播放设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('设置播放器相关参数', style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/danmaku/');
                  },
                  leading: const Icon(Icons.subtitles_rounded),
                  title: Text('弹幕设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('设置弹幕相关参数', style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/keyboard');
                  },
                  leading: const Icon(Icons.keyboard_rounded),
                  title: Text('操作设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('设置播放器按键映射', style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/proxy');
                  },
                  leading: const Icon(Icons.vpn_key_rounded),
                  title: Text('代理设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('配置HTTP代理', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              title: Text('应用与外观', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/theme');
                  },
                  leading: const Icon(Icons.palette_rounded),
                  title: Text('外观设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('设置应用主题和刷新率', style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/webdav/');
                  },
                  leading: const Icon(Icons.cloud),
                  title: Text('同步设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('设置同步参数', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              title: Text('其他', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/about/');
                  },
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text('关于', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
