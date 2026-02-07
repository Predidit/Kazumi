import 'package:card_settings_ui/list/settings_list.dart';
import 'package:card_settings_ui/section/settings_section.dart';
import 'package:card_settings_ui/tile/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/storage.dart';

class InterfaceSettingsPage extends StatefulWidget {
  const InterfaceSettingsPage({super.key});

  @override
  State<InterfaceSettingsPage> createState() => _InterfaceSettingsPageState();
}

class _InterfaceSettingsPageState extends State<InterfaceSettingsPage> {
  Box setting = GStorage.setting;
  late bool showRating;
  late String defaultPage;

  static const List<DropdownMenuItem> defaultPageSettingList = [
    DropdownMenuItem(
      value: "/tab/popular/",
      child: Text('推荐'),
    ),
    DropdownMenuItem(
      value: "/tab/timeline/",
      child: Text('时间表'),
    ),
    DropdownMenuItem(
      value: "/tab/collect/",
      child: Text('追番'),
    ),
    DropdownMenuItem(
      value: "/tab/my/",
      child: Text('我的'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    showRating = setting.get(SettingBoxKey.showRating, defaultValue: true);
    defaultPage = setting.get(SettingBoxKey.defaultStartupPage,
        defaultValue: '/tab/popular/');
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    return Scaffold(
      appBar: SysAppBar(
        title: Text('界面设置'),
      ),
      body: SettingsList(
        sections: [
          SettingsSection(tiles: [
            SettingsTile.navigation(
              title: Text('启动界面设置', style: TextStyle(fontFamily: fontFamily)),
              description: Text('设置应用开启时的默认页面',
                  style: TextStyle(fontFamily: fontFamily)),
              trailing: DropdownButton(
                value: defaultPage,
                items: defaultPageSettingList,
                onChanged: (value) async {
                  await setting.put(SettingBoxKey.defaultStartupPage, value);
                  setState(() {
                    defaultPage = value;
                  });
                },
              ),
            ),
          ]),
          SettingsSection(tiles: [
            SettingsTile.switchTile(
              onToggle: (value) async {
                showRating = value ?? !showRating;
                await setting.put(SettingBoxKey.showRating, showRating);
                setState(() {});
              },
              title: Text('显示评分', style: TextStyle(fontFamily: fontFamily)),
              description: Text('关闭后将在概览中隐藏评分信息',
                  style: TextStyle(fontFamily: fontFamily)),
              initialValue: showRating,
            ),
          ]),
        ],
      ),
    );
  }
}
