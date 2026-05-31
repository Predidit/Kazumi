import 'package:card_settings_ui/list/settings_list.dart';
import 'package:card_settings_ui/section/settings_section.dart';
import 'package:card_settings_ui/tile/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/storage/storage.dart';

class InterfaceSettingsPage extends StatefulWidget {
  const InterfaceSettingsPage({super.key});

  @override
  State<InterfaceSettingsPage> createState() => _InterfaceSettingsPageState();
}

class _InterfaceSettingsPageState extends State<InterfaceSettingsPage> {
  Box setting = GStorage.setting;
  late bool showRating;
  late bool forceEnglish;
  late String defaultPage;
  final MenuController defaultPageMenuController = MenuController();

  static const Map<String, String> defaultPageMap = {
    '/tab/popular/': 'Recommended',
    '/tab/timeline/': 'Schedule',
    '/tab/collect/': 'Tracking',
    '/tab/my/': 'Me',
  };

  @override
  void initState() {
    super.initState();
    showRating = setting.get(SettingBoxKey.showRating, defaultValue: true);
    forceEnglish =
        setting.get(SettingBoxKey.forceEnglishTranslation, defaultValue: true);
    defaultPage = setting.get(SettingBoxKey.defaultStartupPage,
        defaultValue: '/tab/popular/');
  }

  void updateDefaultPage(String page) {
    setting.put(SettingBoxKey.defaultStartupPage, page);
    setState(() {
      defaultPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    return Scaffold(
      appBar: SysAppBar(
        title: Text('Interface settings'),
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
              title: Text('Startup screen settings', style: TextStyle(fontFamily: fontFamily)),
              description: Text('Set the default page when the app opens',
                  style: TextStyle(fontFamily: fontFamily)),
              value: MenuAnchor(
                consumeOutsideTap: true,
                controller: defaultPageMenuController,
                builder: (_, __, ___) {
                  return Text(
                    defaultPageMap[defaultPage] ?? 'Recommended',
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
                await setting.put(SettingBoxKey.showRating, showRating);
                setState(() {});
              },
              title: Text('Show ratings', style: TextStyle(fontFamily: fontFamily)),
              description: Text('When off, rating info is hidden in the overview',
                  style: TextStyle(fontFamily: fontFamily)),
              initialValue: showRating,
            ),
          ]),
          SettingsSection(tiles: [
            SettingsTile.switchTile(
              onToggle: (value) async {
                forceEnglish = value ?? !forceEnglish;
                await setting.put(
                    SettingBoxKey.forceEnglishTranslation, forceEnglish);
                setState(() {});
              },
              title: Text('Force English',
                  style: TextStyle(fontFamily: fontFamily)),
              description: Text(
                  'Translate anime titles and summaries to English when the source is not English',
                  style: TextStyle(fontFamily: fontFamily)),
              initialValue: forceEnglish,
            ),
          ]),
        ],
      ),
    );
  }
}
