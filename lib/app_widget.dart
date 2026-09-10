import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kazumi/app_injector.dart';
import 'package:kazumi/app_router.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/dialog/exit_confirmation_dialog.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/metered_network_service.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/device.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget>
    with TrayListener, WidgetsBindingObserver, WindowListener {
  late final _router = createAppRouter();
  final _themeProvider = appInjector.get<ThemeProvider>();
  final TrayManager trayManager = TrayManager.instance;
  bool _isHandlingWindowClose = false;
  Brightness? _lastTitleBarBrightness;

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_syncWindowsTitleBarBrightness);
    trayManager.addListener(this);
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    _syncWindowsTitleBarBrightness();
    _initializePlatformIntegrations();
  }

  Future<void> _initializePlatformIntegrations() async {
    if (isDesktop()) {
      await windowManager.setPreventClose(true);
      await _handleTray();
    }
    await _configurePreferredDisplayMode();
  }

  Future<void> _configurePreferredDisplayMode() async {
    if (!Platform.isAndroid) return;

    try {
      final modes = await FlutterDisplayMode.supported;
      final storageDisplay = GStorage.getSetting(SettingsKeys.displayMode);
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
    _themeProvider.removeListener(_syncWindowsTitleBarBrightness);
    _router.dispose();
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _syncWindowsTitleBarBrightness() {
    if (!Platform.isWindows) return;

    final brightness =
        _themeProvider.isEffectiveDark() ? Brightness.dark : Brightness.light;
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

  // windowManager.close() triggers this handler; exit() bypasses confirmation.
  @override
  Future<void> onWindowClose() async {
    if (_isHandlingWindowClose || !mounted) return;
    _isHandlingWindowClose = true;
    try {
      var action = switch (GStorage.getSetting(SettingsKeys.exitBehavior)) {
        0 => ExitDialogAction.exit,
        1 => ExitDialogAction.minimizeToTray,
        _ => null,
      };
      if (action == null) {
        final result = await KazumiDialog.show<ExitDialogResult>(
          builder: (_) => const ExitConfirmationDialog(),
        );
        if (result == null || !mounted) return;

        action = result.action;
        if (result.rememberChoice) {
          await GStorage.putSetting(
            SettingsKeys.exitBehavior,
            switch (action) {
              ExitDialogAction.exit => 0,
              ExitDialogAction.minimizeToTray => 1,
            },
          );
        }
      }

      if (!mounted) return;
      switch (action) {
        case ExitDialogAction.exit:
          exit(0);
        case ExitDialogAction.minimizeToTray:
          await windowManager.hide();
      }
    } finally {
      _isHandlingWindowClose = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      KazumiLogger()
          .i("AppLifecycleState.paused: Application moved to background");
    } else if (state == AppLifecycleState.resumed) {
      KazumiLogger()
          .i("AppLifecycleState.resumed: Application moved to foreground");
      await MeteredNetworkService.refresh();
    } else if (state == AppLifecycleState.inactive) {
      KazumiLogger().i("AppLifecycleState.inactive: Application is inactive");
    }
  }

  @override
  Future<void> didChangePlatformBrightness() async {
    super.didChangePlatformBrightness();
    final ThemeProvider themeProvider = _themeProvider;
    KazumiLogger().i(
        "Platform brightness changed, themeMode: ${themeProvider.themeMode}");

    _syncWindowsTitleBarBrightness();
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
    return DynamicColorBuilder(
      builder: (dynamicLight, dynamicDark) => ListenableBuilder(
        listenable: _themeProvider,
        builder: (context, _) {
          final themes = _themeProvider.themes(
            dynamicLight: dynamicLight,
            dynamicDark: dynamicDark,
          );
          return MaterialApp.router(
            title: "Kazumi",
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [
              Locale.fromSubtags(
                  languageCode: 'zh', scriptCode: 'Hans', countryCode: "CN")
            ],
            locale: const Locale.fromSubtags(
                languageCode: 'zh', scriptCode: 'Hans', countryCode: "CN"),
            theme: themes.light,
            darkTheme: themes.dark,
            themeMode: _themeProvider.themeMode,
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
