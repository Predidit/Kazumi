import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/palette_card.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/settings/color_type.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:provider/provider.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  Box setting = GStorage.setting;
  late dynamic defaultDanmakuArea;
  late dynamic defaultThemeMode;
  late dynamic defaultThemeColor;
  late bool oledEnhance;
  late bool useDynamicColor;
  final PopularController popularController = Modular.get<PopularController>();
  late final ThemeProvider themeProvider;

  @override
  void initState() {
    super.initState();
    defaultThemeMode =
        setting.get(SettingBoxKey.themeMode, defaultValue: 'system');
    defaultThemeColor =
        setting.get(SettingBoxKey.themeColor, defaultValue: 'default');
    oledEnhance = setting.get(SettingBoxKey.oledEnhance, defaultValue: false);
    useDynamicColor =
        setting.get(SettingBoxKey.useDynamicColor, defaultValue: false);
    themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  }

  void onBackPressed(BuildContext context) {}

  void setTheme(Color? color) {
    var defaultDarkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: color,
    );
    var oledDarkTheme = Utils.oledDarkTheme(defaultDarkTheme);
    themeProvider.setTheme(
      ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: color,
      ),
      oledEnhance ? oledDarkTheme : defaultDarkTheme,
    );
    defaultThemeColor = color?.value.toRadixString(16) ?? 'default';
    setting.put(SettingBoxKey.themeColor, defaultThemeColor);
  }

  void resetTheme() {
    var defaultDarkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.green,
    );
    var oledDarkTheme = Utils.oledDarkTheme(defaultDarkTheme);
    themeProvider.setTheme(
      ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.green,
      ),
      oledEnhance ? oledDarkTheme : defaultDarkTheme,
    );
    defaultThemeColor = 'default';
    setting.put(SettingBoxKey.themeColor, 'default');
  }

  void updateTheme(String theme) async {
    if (theme == 'dark') {
      themeProvider.setThemeMode(ThemeMode.dark);
    }
    if (theme == 'light') {
      themeProvider.setThemeMode(ThemeMode.light);
    }
    if (theme == 'system') {
      themeProvider.setThemeMode(ThemeMode.system);
    }
    await setting.put(SettingBoxKey.themeMode, theme);
    setState(() {
      defaultThemeMode = theme;
    });
  }

  void updateOledEnhance() {
    dynamic color;
    oledEnhance = setting.get(SettingBoxKey.oledEnhance, defaultValue: false);
    if (defaultThemeColor == 'default') {
      color = Colors.green;
    } else {
      color = Color(int.parse(defaultThemeColor, radix: 16));
    }
    setTheme(color);
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
        appBar: const SysAppBar(title: Text('外观设置')),
        body: Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
            child: SettingsList(
              sections: [
                SettingsSection(
                  title: const Text('外观'),
                  tiles: [
                    SettingsTile.navigation(
                      onPressed: (_) {
                        KazumiDialog.show(builder: (context) {
                          return AlertDialog(
                            title: const Text('深色模式'),
                            content: StatefulBuilder(
                              builder:
                                  (BuildContext context, StateSetter setState) {
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: Utils.isDesktop() ? 8 : 0,
                                  children: [
                                    defaultThemeMode == 'system'
                                        ? FilledButton(
                                            onPressed: () {
                                              updateTheme('system');
                                              KazumiDialog.dismiss();
                                            },
                                            child: const Text("跟随系统"))
                                        : FilledButton.tonal(
                                            onPressed: () {
                                              updateTheme('system');
                                              KazumiDialog.dismiss();
                                            },
                                            child: const Text("跟随系统")),
                                    defaultThemeMode == 'light'
                                        ? FilledButton(
                                            onPressed: () {
                                              updateTheme('light');
                                              KazumiDialog.dismiss();
                                            },
                                            child: const Text("浅色"))
                                        : FilledButton.tonal(
                                            onPressed: () {
                                              updateTheme('light');
                                              KazumiDialog.dismiss();
                                            },
                                            child: const Text("浅色")),
                                    defaultThemeMode == 'dark'
                                        ? FilledButton(
                                            onPressed: () {
                                              updateTheme('dark');
                                              KazumiDialog.dismiss();
                                            },
                                            child: const Text("深色"))
                                        : FilledButton.tonal(
                                            onPressed: () {
                                              updateTheme('dark');
                                              KazumiDialog.dismiss();
                                            },
                                            child: const Text("深色")),
                                  ],
                                );
                              },
                            ),
                          );
                        });
                      },
                      title: const Text('深色模式'),
                      value: Text(
                        defaultThemeMode == 'light'
                            ? '浅色'
                            : (defaultThemeMode == 'dark' ? '深色' : '跟随系统'),
                      ),
                    ),
                    SettingsTile.navigation(
                      enabled: !useDynamicColor,
                      onPressed: (_) async {
                        KazumiDialog.show(builder: (context) {
                          return AlertDialog(
                            title: const Text('配色方案'),
                            content: StatefulBuilder(builder:
                                (BuildContext context, StateSetter setState) {
                              final List<Map<String, dynamic>> colorThemes =
                                  colorThemeTypes;
                              return Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: Utils.isDesktop() ? 8 : 0,
                                children: [
                                  ...colorThemes.map(
                                    (e) {
                                      final index = colorThemes.indexOf(e);
                                      return GestureDetector(
                                        onTap: () {
                                          index == 0
                                              ? resetTheme()
                                              : setTheme(e['color']);
                                          KazumiDialog.dismiss();
                                        },
                                        child: Column(
                                          children: [
                                            PaletteCard(
                                              color: e['color'],
                                              selected: (e['color']
                                                          .value
                                                          .toRadixString(16) ==
                                                      defaultThemeColor ||
                                                  (defaultThemeColor ==
                                                          'default' &&
                                                      index == 0)),
                                            ),
                                            Text(e['label']),
                                          ],
                                        ),
                                      );
                                    },
                                  )
                                ],
                              );
                            }),
                          );
                        });
                      },
                      title: const Text('配色方案'),
                    ),
                    SettingsTile.switchTile(
                      enabled: !Platform.isIOS,
                      onToggle: (value) async {
                        useDynamicColor = value ?? !useDynamicColor;
                        await setting.put(
                            SettingBoxKey.useDynamicColor, useDynamicColor);
                        themeProvider.setDynamic(useDynamicColor);
                        setState(() {});
                      },
                      title: const Text('动态配色'),
                      initialValue: useDynamicColor,
                    ),
                  ],
                  bottomInfo: const Text('动态配色仅支持安卓12及以上和桌面平台'),
                ),
                SettingsSection(
                  tiles: [
                    SettingsTile.switchTile(
                      onToggle: (value) async {
                        oledEnhance = value ?? !oledEnhance;
                        await setting.put(
                            SettingBoxKey.oledEnhance, oledEnhance);
                        updateOledEnhance();
                        setState(() {});
                      },
                      title: const Text('OLED优化'),
                      description: const Text('深色模式下使用纯黑背景'),
                      initialValue: oledEnhance,
                    ),
                  ],
                ),
                SettingsSection(
                  bottomInfo: const Text('仅安卓可以修改'),
                  tiles: [
                    SettingsTile.navigation(
                      enabled: Platform.isAndroid,
                      onPressed: (_) async {
                        Modular.to.pushNamed('/settings/theme/display');
                      },
                      title: const Text('屏幕帧率'),
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
