import 'package:flutter/material.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/bean/settings/settings.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/menu/side_menu.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class PlayerSettingsPage extends StatefulWidget {
  const PlayerSettingsPage({super.key});

  @override
  State<PlayerSettingsPage> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends State<PlayerSettingsPage> {
  dynamic navigationBarState;

  @override
  void initState() {
    super.initState();
    if (Utils.isCompact()) {
      navigationBarState =
          Provider.of<NavigationBarState>(context, listen: false);
    } else {
      navigationBarState =
          Provider.of<SideNavigationBarState>(context, listen: false);
    }
  }

  void onBackPressed(BuildContext context) {
    navigationBarState.showNavigate();
    // Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigationBarState.hideNavigate();
    });
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: const Scaffold(
        appBar: SysAppBar(title: Text('播放设置')),
        body: Column(
          children: [
            InkWell(
              child: SetSwitchItem(
                title: '硬件解码',
                setKey: SettingBoxKey.hAenable,
                needReboot: true,
                defaultVal: true,
              ),
            ),
            InkWell(
              child: SetSwitchItem(
                title: '低内存模式',
                subTitle: '禁用高级缓存以减少内存占用',
                setKey: SettingBoxKey.lowMemoryMode,
                needReboot: true,
                defaultVal: false,
              ),
            ),
            InkWell(
              child: SetSwitchItem(
                title: '自动跳转',
                subTitle: '跳转到上次播放位置',
                setKey: SettingBoxKey.playResume,
                defaultVal: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
