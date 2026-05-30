import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/palette_card.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/settings/color_type.dart';
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/theme.dart';

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
  late bool showWindowButton;
  late bool useSystemFont;
  final PopularController popularController = Modular.get<PopularController>();
  late final ThemeProvider themeProvider;
  final MenuController menuController = MenuController();

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
    showWindowButton =
        setting.get(SettingBoxKey.showWindowButton, defaultValue: false);
    useSystemFont =
        setting.get(SettingBoxKey.useSystemFont, defaultValue: false);
    themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  void setTheme(Color? color) {
    var defaultDarkTheme = ThemeData(
        useMaterial3: true,
        fontFamily: themeProvider.currentFontFamily,
        brightness: Brightness.dark,
        colorSchemeSeed: color,
        progressIndicatorTheme: progressIndicatorTheme2024,
        sliderTheme: sliderTheme2024,
        pageTransitionsTheme: pageTransitionsTheme2024);
    var oledTheme = oledDarkTheme(defaultDarkTheme);
    themeProvider.setTheme(
      ThemeData(
          useMaterial3: true,
          fontFamily: themeProvider.currentFontFamily,
          brightness: Brightness.light,
          colorSchemeSeed: color,
          progressIndicatorTheme: progressIndicatorTheme2024,
          sliderTheme: sliderTheme2024,
          pageTransitionsTheme: pageTransitionsTheme2024),
      oledEnhance ? oledTheme : defaultDarkTheme,
    );
    defaultThemeColor = color?.toARGB32().toRadixString(16) ?? 'default';
    setting.put(SettingBoxKey.themeColor, defaultThemeColor);
  }

  void resetTheme() {
    var defaultDarkTheme = ThemeData(
        useMaterial3: true,
        fontFamily: themeProvider.currentFontFamily,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.green,
        progressIndicatorTheme: progressIndicatorTheme2024,
        sliderTheme: sliderTheme2024,
        pageTransitionsTheme: pageTransitionsTheme2024);
    var oledTheme = oledDarkTheme(defaultDarkTheme);
    themeProvider.setTheme(
      ThemeData(
          useMaterial3: true,
          fontFamily: themeProvider.currentFontFamily,
          brightness: Brightness.light,
          colorSchemeSeed: Colors.green,
          progressIndicatorTheme: progressIndicatorTheme2024,
          sliderTheme: sliderTheme2024,
          pageTransitionsTheme: pageTransitionsTheme2024),
      oledEnhance ? oledTheme : defaultDarkTheme,
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

    // Update Windows title bar theme
    if (Platform.isWindows) {
      await windowManager.setBrightness(
          themeProvider.isEffectiveDark() ? Brightness.dark : Brightness.light);
    }
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
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('Appearance settings')),
        body: SettingsList(
          maxWidth: 1000,
          sections: [
            SettingsSection(
              title: Text('Appearance', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    if (menuController.isOpen) {
                      menuController.close();
                    } else {
                      menuController.open();
                    }
                  },
                  title: Text('Dark mode', style: TextStyle(fontFamily: fontFamily)),
                  value: MenuAnchor(
                    consumeOutsideTap: true,
                    controller: menuController,
                    builder: (_, __, ___) {
                      return Text(
                        defaultThemeMode == 'light'
                            ? 'Light'
                            : (defaultThemeMode == 'dark' ? 'Dark' : 'Follow system'),
                        style: TextStyle(fontFamily: fontFamily),
                      );
                    },
                    menuChildren: [
                      MenuItemButton(
                        requestFocusOnHover: false,
                        onPressed: () => updateTheme('system'),
                        child: Container(
                          height: 48,
                          constraints: BoxConstraints(minWidth: 112),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.brightness_auto_rounded,
                                  color: defaultThemeMode == 'system'
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Follow system',
                                  style: TextStyle(
                                    color: defaultThemeMode == 'system'
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    fontFamily: fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      MenuItemButton(
                        requestFocusOnHover: false,
                        onPressed: () => updateTheme('light'),
                        child: Container(
                          height: 48,
                          constraints: BoxConstraints(minWidth: 112),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.light_mode_rounded,
                                  color: defaultThemeMode == 'light'
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Light',
                                  style: TextStyle(
                                      color: defaultThemeMode == 'light'
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null,
                                      fontFamily: fontFamily),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      MenuItemButton(
                        requestFocusOnHover: false,
                        onPressed: () => updateTheme('dark'),
                        child: Container(
                          height: 48,
                          constraints: BoxConstraints(minWidth: 112),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.dark_mode_rounded,
                                  color: defaultThemeMode == 'dark'
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Dark',
                                  style: TextStyle(
                                    color: defaultThemeMode == 'dark'
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    fontFamily: fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SettingsTile.navigation(
                  enabled: !useDynamicColor,
                  onPressed: (_) async {
                    KazumiDialog.show(builder: (context) {
                      return AlertDialog(
                        title: Text('Color scheme',
                            style: TextStyle(fontFamily: fontFamily)),
                        content: StatefulBuilder(builder:
                            (BuildContext context, StateSetter setState) {
                          final List<Map<String, dynamic>> colorThemes =
                              colorThemeTypes;
                          return Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: isDesktop() ? 8 : 0,
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
                                              (defaultThemeColor == 'default' &&
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
                  title: Text('Color scheme', style: TextStyle(fontFamily: fontFamily)),
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
                  title: Text('Dynamic color', style: TextStyle(fontFamily: fontFamily)),
                  initialValue: useDynamicColor,
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    useSystemFont = value ?? !useSystemFont;
                    await setting.put(
                        SettingBoxKey.useSystemFont, useSystemFont);
                    themeProvider.setFontFamily(useSystemFont);
                    dynamic color;
                    if (defaultThemeColor == 'default') {
                      color = Colors.green;
                    } else {
                      color = Color(int.parse(defaultThemeColor, radix: 16));
                    }
                    setTheme(color);
                    setState(() {});
                  },
                  title:
                      Text('Use system font', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('When off, use the MI Sans font',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: useSystemFont,
                ),
              ],
              bottomInfo: Text('Dynamic color is only supported on Android 12 and above and on desktop platforms',
                  style: TextStyle(fontFamily: fontFamily)),
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    oledEnhance = value ?? !oledEnhance;
                    await setting.put(SettingBoxKey.oledEnhance, oledEnhance);
                    updateOledEnhance();
                    setState(() {});
                  },
                  title:
                      Text('OLED optimization', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('Use a pure black background in dark mode',
                      style: TextStyle(fontFamily: fontFamily)),
                  initialValue: oledEnhance,
                ),
              ],
            ),
            if (isDesktop())
              SettingsSection(
                tiles: [
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      showWindowButton = value ?? !showWindowButton;
                      await setting.put(
                          SettingBoxKey.showWindowButton, showWindowButton);
                      setState(() {});
                    },
                    title: Text('Use system title bar',
                        style: TextStyle(fontFamily: fontFamily)),
                    description: Text('Takes effect after restarting the app',
                        style: TextStyle(fontFamily: fontFamily)),
                    initialValue: showWindowButton,
                  ),
                ],
              ),
            if (Platform.isAndroid)
              SettingsSection(
                tiles: [
                  SettingsTile.navigation(
                    onPressed: (_) async {
                      Modular.to.pushNamed('/settings/theme/display');
                    },
                    title:
                        Text('Screen refresh rate', style: TextStyle(fontFamily: fontFamily)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
