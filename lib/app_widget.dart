import 'dart:io';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:window_manager/window_manager.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> with TrayListener {
  Box setting = GStorage.setting;

  final TrayManager trayManager = TrayManager.instance;

  @override
  void initState() {
    trayManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onTrayIconMouseDown(){
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown(){
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key){
      case 'show_window':
        windowManager.show();
      case 'exit':
        exit(0);
    }
  }

  Future<void> _handleTray() async {
    await trayManager.setIcon(
      Platform.isWindows
          ? 'assets/images/logo/logo_windows.ico'
          : 'assets/images/logo/logo_rounded.png'
    );
    if (!Platform.isLinux) {
      await trayManager.setToolTip('Kazumi');
    }
    Menu trayMenu = Menu(
        items: [
          MenuItem(
              key: 'show_window',
              label: '显示窗口'
          ),
          MenuItem.separator(),
          MenuItem(
              key: 'exit',
              label: '退出 Kazumi'
          )
        ]
    );
    await trayManager.setContextMenu(trayMenu);
  }

  @override
  Widget build(BuildContext context) {
    if(Utils.isDesktop()) {
      _handleTray();
    }
    dynamic color;
    dynamic defaultThemeColor =
        setting.get(SettingBoxKey.themeColor, defaultValue: 'default');
    if (defaultThemeColor == 'default') {
      color = Colors.green;
    } else {
      color = Color(int.parse(defaultThemeColor, radix: 16));
    }
    bool oledEnhance =
        setting.get(SettingBoxKey.oledEnhance, defaultValue: false);
    var defaultDarkTheme = ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: color);
    var oledDarkTheme = Utils.oledDarkTheme(defaultDarkTheme);
    var app = AdaptiveTheme(
      light: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorSchemeSeed: color),
      dark: oledEnhance ? oledDarkTheme : defaultDarkTheme,
      initial: AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => MaterialApp.router(
        title: "Kazumi",
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [
          Locale.fromSubtags(
              languageCode: 'zh', scriptCode: 'Hans', countryCode: "CN")
        ],
        locale: const Locale.fromSubtags(
            languageCode: 'zh', scriptCode: 'Hans', countryCode: "CN"),
        theme: theme,
        darkTheme: darkTheme,
        routerConfig: Modular.routerConfig,
        builder: FlutterSmartDialog.init(),
      ),
    );
    Modular.setObservers([FlutterSmartDialog.observer]);

    // 强制设置高帧率
    if (Platform.isAndroid) {
      try {
        late List modes;
        FlutterDisplayMode.supported.then((value) {
          modes = value;
          var storageDisplay = setting.get(SettingBoxKey.displayMode);
          DisplayMode f = DisplayMode.auto;
          if (storageDisplay != null) {
            f = modes.firstWhere((e) => e.toString() == storageDisplay);
          }
          DisplayMode preferred = modes.toList().firstWhere((el) => el == f);
          FlutterDisplayMode.setPreferredMode(preferred);
        });
      } catch (e) {
        KazumiLogger().log(Level.error ,'高帧率设置失败 ${e.toString()}');
      }
    }

    return app;
  }
}
