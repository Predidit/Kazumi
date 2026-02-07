import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/utils/constants.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget>
    with TrayListener, WidgetsBindingObserver, WindowListener {
  Box setting = GStorage.setting;

  final TrayManager trayManager = TrayManager.instance;
  bool showingExitDialog = false;

  @override
  void initState() {
    trayManager.addListener(this);
    windowManager.addListener(this);
    setPreventClose();
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  void setPreventClose() async {
    if (Utils.isDesktop()) {
      await windowManager.setPreventClose(true);
      setState(() {});
    }
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
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

  /// 处理窗口关闭事件，
  /// 需要使用 `windowManager.close()` 来触发，`exit(0)` 会直接退出程序
  @override
  void onWindowClose() {
    final setting = GStorage.setting;
    final exitBehavior =
        setting.get(SettingBoxKey.exitBehavior, defaultValue: 2);

    switch (exitBehavior) {
      case 0:
        exit(0);
      case 1:
        KazumiDialog.dismiss();
        windowManager.hide();
        break;
      default:
        if (showingExitDialog) return;
        showingExitDialog = true;
        KazumiDialog.show(onDismiss: () {
          showingExitDialog = false;
        }, builder: (context) {
          bool saveExitBehavior = false; // 下次不再询问？

          return AlertDialog(
            title: const Text('退出确认'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('您想要退出 Kazumi 吗？'),
                const SizedBox(height: 24),
                StatefulBuilder(builder: (context, setState) {
                  onChanged(value) {
                    saveExitBehavior = value ?? false;
                    setState(() {});
                  }

                  return Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Checkbox(value: saveExitBehavior, onChanged: onChanged),
                      const Text('下次不再询问'),
                    ],
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () async {
                    if (saveExitBehavior) {
                      await setting.put(SettingBoxKey.exitBehavior, 0);
                    }
                    exit(0);
                  },
                  child: const Text('退出 Kazumi')),
              TextButton(
                  onPressed: () async {
                    if (saveExitBehavior) {
                      await setting.put(SettingBoxKey.exitBehavior, 1);
                    }
                    KazumiDialog.dismiss();
                    windowManager.hide();
                  },
                  child: const Text('最小化至托盘')),
              const TextButton(
                  onPressed: KazumiDialog.dismiss, child: Text('取消')),
            ],
          );
        });
    }
  }

  /// 处理前后台变更
  /// windows/linux 在程序后台或失去焦点时只会触发 inactive 不会触发 paused
  /// android/ios/macos 在程序后台时会先触发 inactive 再触发 paused, 回到前台时会先触发 inactive 再触发 resumed
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      KazumiLogger()
          .i("AppLifecycleState.paused: Application moved to background");
    } else if (state == AppLifecycleState.resumed) {
      KazumiLogger()
          .i("AppLifecycleState.resumed: Application moved to foreground");
    } else if (state == AppLifecycleState.inactive) {
      KazumiLogger().i("AppLifecycleState.inactive: Application is inactive");
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
    bool useSystemFont =
        setting.get(SettingBoxKey.useSystemFont, defaultValue: false);
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
    themeProvider.setFontFamily(useSystemFont, notify: false);
    var defaultDarkTheme = ThemeData(
        useMaterial3: true,
        fontFamily: themeProvider.currentFontFamily,
        brightness: Brightness.dark,
        colorSchemeSeed: color,
        progressIndicatorTheme: progressIndicatorTheme2024,
        sliderTheme: sliderTheme2024,
        pageTransitionsTheme: pageTransitionsTheme2024);
    var oledDarkTheme = Utils.oledDarkTheme(defaultDarkTheme);
    themeProvider.setTheme(
      ThemeData(
          useMaterial3: true,
          fontFamily: themeProvider.currentFontFamily,
          brightness: Brightness.light,
          colorSchemeSeed: color,
          progressIndicatorTheme: progressIndicatorTheme2024,
          sliderTheme: sliderTheme2024,
          pageTransitionsTheme: pageTransitionsTheme2024),
      oledEnhance ? oledDarkTheme : defaultDarkTheme,
      notify: false,
    );
    var app = DynamicColorBuilder(
      builder: (theme, darkTheme) {
        if (themeProvider.useDynamicColor) {
          themeProvider.setTheme(
            ThemeData(
                useMaterial3: true,
                fontFamily: themeProvider.currentFontFamily,
                colorScheme: theme,
                brightness: Brightness.light,
                progressIndicatorTheme: progressIndicatorTheme2024,
                sliderTheme: sliderTheme2024,
                pageTransitionsTheme: pageTransitionsTheme2024),
            oledEnhance
                ? Utils.oledDarkTheme(ThemeData(
                    useMaterial3: true,
                    fontFamily: themeProvider.currentFontFamily,
                    colorScheme: darkTheme,
                    brightness: Brightness.dark,
                    progressIndicatorTheme: progressIndicatorTheme2024,
                    sliderTheme: sliderTheme2024,
                    pageTransitionsTheme: pageTransitionsTheme2024))
                : ThemeData(
                    useMaterial3: true,
                    fontFamily: themeProvider.currentFontFamily,
                    colorScheme: darkTheme,
                    brightness: Brightness.dark,
                    progressIndicatorTheme: progressIndicatorTheme2024,
                    sliderTheme: sliderTheme2024,
                    pageTransitionsTheme: pageTransitionsTheme2024),
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
        KazumiLogger().e('DisPlay: set preferred mode failed', error: e);
      }
    }

    return app;
  }
}
