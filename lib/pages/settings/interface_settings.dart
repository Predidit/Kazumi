import 'package:kazumi/design_system/kazumi_settings.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/storage/storage.dart';

class InterfaceSettingsPage extends StatefulWidget {
  const InterfaceSettingsPage({super.key});

  @override
  State<InterfaceSettingsPage> createState() => _InterfaceSettingsPageState();
}

class _InterfaceSettingsPageState extends State<InterfaceSettingsPage> {
  late bool showRating;
  late bool showAnimeCounter;
  late String defaultPage;
  final MenuController defaultPageMenuController = MenuController();

  static const Map<String, String> defaultPageMap = {
    '/tab/popular/': '推荐',
    '/tab/timeline/': '时间表',
    '/tab/collect/': '追番',
    '/tab/my/': '我的',
  };

  @override
  void initState() {
    super.initState();
    showRating = GStorage.getSetting(SettingsKeys.showRating);
    showAnimeCounter = GStorage.getSetting(SettingsKeys.showAnimeCounter);
    defaultPage = GStorage.getSetting(SettingsKeys.defaultStartupPage);
  }

  void updateDefaultPage(String page) {
    GStorage.putSetting(SettingsKeys.defaultStartupPage, page);
    setState(() {
      defaultPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SysAppBar(
        title: Text('界面设置'),
      ),
      body: SettingsList(
        sections: [
          SettingsSection(tiles: [
            SettingsTile.navigation(
              onPressed: (_) async {
                if (defaultPageMenuController.isOpen) {
                  defaultPageMenuController.close();
                } else {
                  defaultPageMenuController.open();
                }
              },
              title: Text('启动界面设置', style: TextStyle(fontFamily: fontFamily)),
              description: Text('设置应用开启时的默认页面',
                  style: TextStyle(fontFamily: fontFamily)),
              value: MenuAnchor(
                consumeOutsideTap: true,
                controller: defaultPageMenuController,
                builder: (_, __, ___) {
                  return Text(
                    defaultPageMap[defaultPage] ?? '推荐',
                    style: TextStyle(fontFamily: fontFamily),
                  );
                },
                menuChildren: [
                  for (final entry in defaultPageMap.entries)
                    MenuItemButton(
                      requestFocusOnHover: false,
                      onPressed: () => updateDefaultPage(entry.key),
                      child: Container(
                        height: 48,
                        constraints: BoxConstraints(minWidth: 112),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              color: entry.key == defaultPage
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ]),
          SettingsSection(tiles: [
            SettingsTile.switchTile(
              onToggle: (value) async {
                showRating = value ?? !showRating;
                await GStorage.putSetting(SettingsKeys.showRating, showRating);
                setState(() {});
              },
              title: Text('显示评分', style: TextStyle(fontFamily: fontFamily)),
              description: Text('关闭后将在概览中隐藏评分信息',
                  style: TextStyle(fontFamily: fontFamily)),
              initialValue: showRating,
            ),
          ]),
          SettingsSection(tiles: [
            SettingsTile.switchTile(
              onToggle: (value) async {
                showAnimeCounter = value ?? !showAnimeCounter;
                await GStorage.putSetting(
                    SettingsKeys.showAnimeCounter, showAnimeCounter);
                setState(() {});
              },
              title: Text('显示追番统计', style: TextStyle(fontFamily: fontFamily)),
              description: Text('启用后将在追番页面下方显示追番统计',
                  style: TextStyle(fontFamily: fontFamily)),
              initialValue: showAnimeCounter,
            ),
          ]),
        ],
      ),
    );
  }
}
