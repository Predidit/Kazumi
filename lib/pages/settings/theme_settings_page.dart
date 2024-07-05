import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive/hive.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/settings/color_type.dart';
import 'package:kazumi/bean/settings/settings.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/menu/side_menu.dart';
import 'package:kazumi/utils/utils.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  dynamic navigationBarState;
  Box setting = GStorage.setting;
  late dynamic defaultDanmakuArea;
  late dynamic defaultThemeMode;
  late dynamic defaultThemeColor;
  late bool oledEnhance;
  final PopularController popularController = Modular.get<PopularController>();

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
    defaultThemeMode =
        setting.get(SettingBoxKey.themeMode, defaultValue: 'system');
    defaultThemeColor =
        setting.get(SettingBoxKey.themeColor, defaultValue: 'default');
    oledEnhance = setting.get(SettingBoxKey.oledEnhance, defaultValue: false);
  }

  void onBackPressed(BuildContext context) {
    navigationBarState.showNavigate();
  }

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigationBarState.hideNavigate();
    });
    return PopScope(
      canPop: true,
      onPopInvoked: (bool didPop) async {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('外观设置')),
        body: Column(
          children: [
            ListTile(
              onTap: () async {
                final List<Map<String, dynamic>> colorThemes = colorThemeTypes;
                SmartDialog.show(
                    useAnimation: false,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('配色方案'),
                        content: StatefulBuilder(builder:
                            (BuildContext context, StateSetter setState) {
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
                                      SmartDialog.dismiss();
                                    },
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: e['color'].withOpacity(0.8),
                                            borderRadius:
                                                BorderRadius.circular(50),
                                            border: Border.all(
                                              width: 2,
                                              color:
                                                  e['color'].withOpacity(0.8),
                                            ),
                                          ),
                                          child: const AnimatedOpacity(
                                            opacity: 0,
                                            duration:
                                                Duration(milliseconds: 200),
                                            child: Icon(
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
              dense: false,
              title: const Text('配色方案'),
            ),
            Platform.isAndroid
                ? ListTile(
                    onTap: () async {
                      Modular.to.pushNamed('/tab/my/theme/display');
                    },
                    dense: false,
                    title: const Text('屏幕帧率'),
                    // trailing: const Icon(Icons.navigate_next),
                  )
                : Container(),
            ListTile(
              onTap: () {
                SmartDialog.show(
                    useAnimation: false,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('主题模式'),
                        content: StatefulBuilder(
                          builder:
                              (BuildContext context, StateSetter setState) {
                            return Wrap(
                              spacing: 8,
                              runSpacing: 2,
                              children: [
                                defaultThemeMode == 'system'
                                    ? FilledButton(
                                        onPressed: () {
                                          updateTheme('system');
                                          SmartDialog.dismiss();
                                        },
                                        child: const Text("跟随系统"))
                                    : FilledButton.tonal(
                                        onPressed: () {
                                          updateTheme('system');
                                          SmartDialog.dismiss();
                                        },
                                        child: const Text("跟随系统")),
                                defaultThemeMode == 'light'
                                    ? FilledButton(
                                        onPressed: () {
                                          updateTheme('light');
                                          SmartDialog.dismiss();
                                        },
                                        child: const Text("浅色"))
                                    : FilledButton.tonal(
                                        onPressed: () {
                                          updateTheme('light');
                                          SmartDialog.dismiss();
                                        },
                                        child: const Text("浅色")),
                                defaultThemeMode == 'dark'
                                    ? FilledButton(
                                        onPressed: () {
                                          updateTheme('dark');
                                          SmartDialog.dismiss();
                                        },
                                        child: const Text("深色"))
                                    : FilledButton.tonal(
                                        onPressed: () {
                                          updateTheme('dark');
                                          SmartDialog.dismiss();
                                        },
                                        child: const Text("深色")),
                              ],
                            );
                          },
                        ),
                      );
                    });
              },
              dense: false,
              title: const Text('主题模式'),
              subtitle: Text(
                  defaultThemeMode == 'light'
                      ? '浅色'
                      : (defaultThemeMode == 'dark' ? '深色' : '跟随系统'),
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium!
                      .copyWith(color: Theme.of(context).colorScheme.outline)),
            ),
            InkWell(
              child: SetSwitchItem(
                title: 'OLED优化',
                subTitle: '深色模式下使用纯黑背景',
                setKey: SettingBoxKey.oledEnhance,
                callFn: (_) => {updateOledEnhance()},
                defaultVal: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
