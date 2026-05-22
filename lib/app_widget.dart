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
  bool _didApplyStoredThemeSettings = false;
  Brightness? _lastTitleBarBrightness;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    Modular.setObservers([KazumiDialog.observer]);
    _initializePlatformIntegrations();
  }

  Future<void> _initializePlatformIntegrations() async {
    if (Utils.isDesktop()) {
      await windowManager.setPreventClose(true);
      await _handleTray();
    }
    await _configurePreferredDisplayMode();
  }

  Future<void> _configurePreferredDisplayMode() async {
    if (!Platform.isAndroid) return;

    try {
      final modes = await FlutterDisplayMode.supported;
      final storageDisplay = setting.get(SettingBoxKey.displayMode);
      DisplayMode selectedMode = DisplayMode.auto;
      if (storageDisplay != null) {
        selectedMode = modes.firstWhere(
          (e) => e.toString() == storageDisplay,
          orElse: () => DisplayMode.auto,
        );
      }
      final preferred = modes.firstWhere(
        (el) => el == selectedMode,
        orElse: () => DisplayMode.auto,
      );
      await FlutterDisplayMode.setPreferredMode(preferred);
    } catch (e) {
      KazumiLogger().e('DisPlay: set preferred mode failed', error: e);
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context);
    _applyStoredThemeSettings(themeProvider);
    _syncWindowsTitleBarBrightness(themeProvider);
  }

  void _applyStoredThemeSettings(ThemeProvider themeProvider) {
    if (_didApplyStoredThemeSettings) return;
    _didApplyStoredThemeSettings = true;

    themeProvider.setThemeMode(_storedThemeMode(), notify: false);
    themeProvider.setDynamic(
      setting.get(SettingBoxKey.useDynamicColor, defaultValue: false),
      notify: false,
    );
    themeProvider.setFontFamily(
      setting.get(SettingBoxKey.useSystemFont, defaultValue: false),
      notify: false,
    );

    final color = _storedThemeColor();
    final oledEnhance =
        setting.get(SettingBoxKey.oledEnhance, defaultValue: false);
    final defaultDarkTheme = _buildAppTheme(
      brightness: Brightness.dark,
      color: color,
      fontFamily: themeProvider.currentFontFamily,
    );
    themeProvider.setTheme(
      _buildAppTheme(
        brightness: Brightness.light,
        color: color,
        fontFamily: themeProvider.currentFontFamily,
      ),
      oledEnhance ? Utils.oledDarkTheme(defaultDarkTheme) : defaultDarkTheme,
      notify: false,
    );
  }

  ThemeMode _storedThemeMode() {
    return switch (
        setting.get(SettingBoxKey.themeMode, defaultValue: 'system')) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  Color _storedThemeColor() {
    final defaultThemeColor =
        setting.get(SettingBoxKey.themeColor, defaultValue: 'default');
    if (defaultThemeColor == 'default') {
      return Colors.green;
    }
    return Color(int.parse(defaultThemeColor, radix: 16));
  }

  ThemeData _buildAppTheme({
    required Brightness brightness,
    required String? fontFamily,
    Color? color,
    ColorScheme? colorScheme,
  }) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: brightness,
      colorSchemeSeed: color,
      colorScheme: colorScheme,
      progressIndicatorTheme: progressIndicatorTheme2024,
      sliderTheme: sliderTheme2024,
      pageTransitionsTheme: pageTransitionsTheme2024,
    );
  }

  void _syncWindowsTitleBarBrightness(ThemeProvider themeProvider) {
    if (!Platform.isWindows) return;

    final brightness =
        themeProvider.isEffectiveDark() ? Brightness.dark : Brightness.light;
    if (_lastTitleBarBrightness == brightness) return;

    _lastTitleBarBrightness = brightness;
    windowManager.setBrightness(brightness).catchError((e) {
      KazumiLogger().w('Window: set title bar brightness failed', error: e);
    });
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

  @override
  Future<void> didChangePlatformBrightness() async {
    super.didChangePlatformBrightness();
    final ThemeProvider themeProvider =
        Provider.of<ThemeProvider>(context, listen: false);
    KazumiLogger().i(
        "Platform brightness changed, themeMode: ${themeProvider.themeMode}");

    _syncWindowsTitleBarBrightness(themeProvider);
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
    bool oledEnhance =
        setting.get(SettingBoxKey.oledEnhance, defaultValue: false);

    var app = DynamicColorBuilder(
      builder: (theme, darkTheme) {
        final useDynamicColor =
            themeProvider.useDynamicColor && theme != null && darkTheme != null;
        final lightTheme = useDynamicColor
            ? _buildAppTheme(
                brightness: Brightness.light,
                colorScheme: theme,
                fontFamily: themeProvider.currentFontFamily,
              )
            : themeProvider.light;
        final dynamicDarkTheme = useDynamicColor
            ? _buildAppTheme(
                brightness: Brightness.dark,
                colorScheme: darkTheme,
                fontFamily: themeProvider.currentFontFamily,
              )
            : themeProvider.dark;
        final effectiveDarkTheme = useDynamicColor && oledEnhance
            ? Utils.oledDarkTheme(dynamicDarkTheme)
            : dynamicDarkTheme;

        return MaterialApp.router(
          title: "Kazumi",
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [
            Locale.fromSubtags(
                languageCode: 'zh', scriptCode: 'Hans', countryCode: "CN")
          ],
          locale: const Locale.fromSubtags(
              languageCode: 'zh', scriptCode: 'Hans', countryCode: "CN"),
          theme: lightTheme,
          darkTheme: effectiveDarkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: Modular.routerConfig,
        );
      },
    );

    return app;
  }
}
