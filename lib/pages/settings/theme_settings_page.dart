import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/settings/color_type.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

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
  final PopularController popularController = Modular.get<PopularController>();

  @override
  void initState() {
    super.initState();
    defaultThemeMode =
        setting.get(SettingBoxKey.themeMode, defaultValue: 'system');
    defaultThemeColor =
        setting.get(SettingBoxKey.themeColor, defaultValue: 'default');
    oledEnhance = setting.get(SettingBoxKey.oledEnhance, defaultValue: false);
  }

  void onBackPressed(BuildContext context) {}

  void setTheme(Color? color) {
    var defaultDarkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: color,
    );
    var oledDarkTheme = Utils.oledDarkTheme(defaultDarkTheme);
    AdaptiveTheme.of(context).setTheme(
      light: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: color,
      ),
      dark: oledEnhance ? oledDarkTheme : defaultDarkTheme,
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
    AdaptiveTheme.of(context).setTheme(
      light: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.green,
      ),
      dark: oledEnhance ? oledDarkTheme : defaultDarkTheme,
    );
    defaultThemeColor = 'default';
    setting.put(SettingBoxKey.themeColor, 'default');
  }

  void updateTheme(String theme) async {
    if (theme == 'dark') {
      AdaptiveTheme.of(context).setDark();
    }
    if (theme == 'light') {
      AdaptiveTheme.of(context).setLight();
    }
    if (theme == 'system') {
      AdaptiveTheme.of(context).setSystem();
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
                                spacing: 22,
                                runSpacing: 18,
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
                                            Container(
                                              width: 46,
                                              height: 46,
                                              decoration: BoxDecoration(
                                                color:
                                                    e['color'].withOpacity(0.8),
                                                borderRadius:
                                                    BorderRadius.circular(50),
                                                border: Border.all(
                                                  width: 2,
                                                  color: e['color']
                                                      .withOpacity(0.8),
                                                ),
                                              ),
                                              child: AnimatedOpacity(
                                                opacity: (e['color']
                                                                .value
                                                                .toRadixString(
                                                                    16) ==
                                                            defaultThemeColor ||
                                                        (defaultThemeColor ==
                                                                'default' &&
                                                            index == 0))
                                                    ? 1
                                                    : 0,
                                                duration: const Duration(
                                                    milliseconds: 200),
                                                child: const Icon(
                                                  Icons.done,
                                                  color: Colors.black,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              e['label'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline,
                                              ),
                                            ),
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
                  ],
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
