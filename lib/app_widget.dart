import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/metered_network_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/dialog/exit_confirmation_dialog.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/bean/widget/gamepad_navigation.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/services/platform/gamepad_input_service.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/theme.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget>
    with TrayListener, WidgetsBindingObserver, WindowListener {
  final TrayManager trayManager = TrayManager.instance;
  bool _isHandlingWindowClose = false;
  bool _didApplyStoredThemeSettings = false;
  Brightness? _lastTitleBarBrightness;
  late final GamepadInputService _gamepadInputService;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    _gamepadInputService = GamepadInputService(
      enabled: GStorage.getSetting(SettingsKeys.gamepadEnabled),
      stickDeadZone: GStorage.getSetting(SettingsKeys.gamepadStickDeadZone),
      initialRepeatDelay: Duration(
        milliseconds: GStorage.getSetting(SettingsKeys.gamepadRepeatDelay),
      ),
    );
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
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_gamepadInputService.dispose());
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = context.watch<ThemeProvider>();
    _applyStoredThemeSettings(themeProvider);
    _syncWindowsTitleBarBrightness(themeProvider);
  }

  void _applyStoredThemeSettings(ThemeProvider themeProvider) {
    if (_didApplyStoredThemeSettings) return;
    _didApplyStoredThemeSettings = true;

    themeProvider.setThemeMode(_storedThemeMode(), notify: false);
    themeProvider.setDynamic(
      GStorage.getSetting(SettingsKeys.useDynamicColor),
      notify: false,
    );
    themeProvider.setFontFamily(
      GStorage.getSetting(SettingsKeys.useSystemFont),
      notify: false,
    );

    final color = _storedThemeColor();
    final oledEnhance = GStorage.getSetting(SettingsKeys.oledEnhance);
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
      oledEnhance ? oledDarkTheme(defaultDarkTheme) : defaultDarkTheme,
      notify: false,
    );
  }

  ThemeMode _storedThemeMode() {
    return switch (GStorage.getSetting(SettingsKeys.themeMode)) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  Color _storedThemeColor() {
    final defaultThemeColor = GStorage.getSetting(SettingsKeys.themeColor);
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
    final effectiveColorScheme = colorScheme ??
        ColorScheme.fromSeed(
          seedColor: color ?? Colors.green,
          brightness: brightness,
        );
    // A controller-driven focus needs to be unmistakable: give every focused
    // button a solid outline in addition to the overlay tint.
    WidgetStateProperty<BorderSide?> focusedOutline() =>
        WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: effectiveColorScheme.primary, width: 2);
          }
          return BorderSide.none;
        });
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: brightness,
      colorScheme: effectiveColorScheme,
      focusColor: effectiveColorScheme.primary.withValues(alpha: 0.32),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(side: focusedOutline()),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(side: focusedOutline()),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(side: focusedOutline()),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(side: focusedOutline()),
      ),
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
    final ThemeProvider themeProvider = context.read<ThemeProvider>();
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
    final ThemeProvider themeProvider = context.watch<ThemeProvider>();
    bool oledEnhance = GStorage.getSetting(SettingsKeys.oledEnhance);

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
            ? oledDarkTheme(dynamicDarkTheme)
            : dynamicDarkTheme;

        return MaterialApp.router(
          title: "Kazumi",
          debugShowCheckedModeBanner: false,
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
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          routerConfig: ModularApp.routerConfigOf(context),
          builder: (context, child) => GamepadNavigationScope(
            service: _gamepadInputService,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );

    return app;
  }
}
