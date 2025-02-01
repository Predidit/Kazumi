import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:provider/provider.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget>
    with TrayListener, WidgetsBindingObserver {
  Box setting = GStorage.setting;

  final TrayManager trayManager = TrayManager.instance;

  @override
  void initState() {
    trayManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        windowManager.show();
      case 'exit':
        exit(0);
    }
  }

  /// 处理前后台变更
  /// windows/linux 在程序后台或失去焦点时只会触发 inactive 不会触发 paused
  /// android/ios/macos 在程序后台时会先触发 inactive 再触发 paused, 回到前台时会先触发 inactive 再触发 resumed
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      debugPrint("应用进入后台");
      bool webDavEnable =
          await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
      bool webDavEnableHistory =
          await setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);
      if (webDavEnable && webDavEnableHistory) {
        try {
          var webDav = WebDav();
          webDav.updateHistory();
        } catch (e) {
          KazumiLogger().log(Level.error, '同步记录失败 ${e.toString()}');
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("应用回到前台");
      bool webDavEnable =
          await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
      bool webDavEnableHistory =
          await setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);
      if (webDavEnable && webDavEnableHistory) {
        try {
          var webDav = WebDav();
          webDav.downloadAndPatchHistory();
        } catch (e) {
          KazumiLogger().log(Level.error, '同步观看记录失败 ${e.toString()}');
        }
      }
    } else if (state == AppLifecycleState.inactive) {
      debugPrint("应用处于非活动状态");
      if (Platform.isWindows || Platform.isLinux) {
        bool webDavEnable =
            await setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
        bool webDavEnableHistory =
            await setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);
        if (webDavEnable && webDavEnableHistory) {
          try {
            var webDav = WebDav();
            webDav.updateHistory();
          } catch (e) {
            KazumiLogger().log(Level.error, '同步记录失败 ${e.toString()}');
          }
        }
      }
    }
  }

  Future<void> _handleTray() async {
    if (Platform.isWindows) {
      await trayManager.setIcon('assets/images/logo/logo_lanczos.ico');
    } else if (Platform.environment.containsKey('FLATPAK_ID') ||
        Platform.environment.containsKey('SNAP')) {
      await trayManager.setIcon('io.github.Predidit.Kazumi');
    } else {
      await trayManager.setIcon('assets/images/logo/logo_rounded.png');
    }

    if (!Platform.isLinux) {
      await trayManager.setToolTip('Kazumi');
    }

    Menu trayMenu = Menu(items: [
      MenuItem(key: 'show_window', label: '显示窗口'),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: '退出 Kazumi')
    ]);
    await trayManager.setContextMenu(trayMenu);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeProvider themeProvider = Provider.of<ThemeProvider>(context);
    if (Utils.isDesktop()) {
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
    final defaultThemeMode =
        setting.get(SettingBoxKey.themeMode, defaultValue: 'system');
    if (defaultThemeMode == 'dark') {
      themeProvider.setThemeMode(ThemeMode.dark, notify: false);
    }
    if (defaultThemeMode == 'light') {
      themeProvider.setThemeMode(ThemeMode.light, notify: false);
    }
    if (defaultThemeMode == 'system') {
      themeProvider.setThemeMode(ThemeMode.system, notify: false);
    }
    var defaultDarkTheme = ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: color);
    var oledDarkTheme = Utils.oledDarkTheme(defaultDarkTheme);
    themeProvider.setTheme(
      ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: color,
      ),
      oledEnhance ? oledDarkTheme : defaultDarkTheme,
      notify: false,
    );
    var app = DynamicColorBuilder(
      builder: (theme, darkTheme) {
        if (themeProvider.useDynamicColor) {
          themeProvider.setTheme(
            ThemeData(colorScheme: theme, brightness: Brightness.light),
            oledEnhance
                ? Utils.oledDarkTheme(ThemeData(
                    colorScheme: darkTheme, brightness: Brightness.dark))
                : ThemeData(
                    colorScheme: darkTheme, brightness: Brightness.dark),
            notify: false,
          );
        }
        return MaterialApp.router(
          title: "Kazumi",
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [
            Locale.fromSubtags(
                languageCode: 'zh', scriptCode: 'Hans', countryCode: "CN")
          ],
          locale: const Locale.fromSubtags(
              languageCode: 'zh', scriptCode: 'Hans', countryCode: "CN"),
          theme: themeProvider.light,
          darkTheme: themeProvider.dark,
          themeMode: themeProvider.themeMode,
          routerConfig: Modular.routerConfig,
        );
      },
    );
    Modular.setObservers([KazumiDialog.observer]);

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
        KazumiLogger().log(Level.error, '高帧率设置失败 ${e.toString()}');
      }
    }

    return app;
  }
}
