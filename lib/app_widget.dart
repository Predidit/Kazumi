import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/platform/app_platform.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/theme.dart';
import 'package:kazumi/services/platform/application_lifecycle_service.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';
import 'package:kazumi/design_system/kazumi_surfaces.dart';
import 'package:kazumi/design_system/kazumi_theme.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget>
    with TrayListener, WidgetsBindingObserver, WindowListener {
  final TrayManager trayManager = TrayManager.instance;
  bool showingExitDialog = false;
  Future<void>? _exitFuture;
  bool _didApplyStoredThemeSettings = false;
  Brightness? _lastTitleBarBrightness;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
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
    if (!KazumiPlatform.isAndroid) return;

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
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) {
      setState(() {});
    }
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

  /// dynamic_color builds its ColorScheme from the legacy CorePalette path,
  /// which leaves the surfaceContainer* roles unset. ColorScheme then falls
  /// back to `surface` for all of them, so cards and other containers become
  /// indistinguishable from the page background. Rebuild the surface family
  /// from the dynamic primary when that happens.
  ColorScheme _completeDynamicScheme(
      ColorScheme scheme, Brightness brightness) {
    if (scheme.surfaceContainerLow != scheme.surface) return scheme;
    final seeded = ColorScheme.fromSeed(
      seedColor: scheme.primary,
      brightness: brightness,
    );
    return scheme.copyWith(
      surface: seeded.surface,
      surfaceDim: seeded.surfaceDim,
      surfaceBright: seeded.surfaceBright,
      surfaceContainerLowest: seeded.surfaceContainerLowest,
      surfaceContainerLow: seeded.surfaceContainerLow,
      surfaceContainer: seeded.surfaceContainer,
      surfaceContainerHigh: seeded.surfaceContainerHigh,
      surfaceContainerHighest: seeded.surfaceContainerHighest,
    );
  }

  ThemeData _buildAppTheme({
    required Brightness brightness,
    required String? fontFamily,
    Color? color,
    ColorScheme? colorScheme,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: brightness,
      colorSchemeSeed: color,
      colorScheme: colorScheme == null
          ? null
          : _completeDynamicScheme(colorScheme, brightness),
      progressIndicatorTheme: progressIndicatorTheme2024,
      sliderTheme: sliderTheme2024,
      pageTransitionsTheme: pageTransitionsTheme2024,
    );
    return applyKazumiDesignSystem(base);
  }

  void _syncWindowsTitleBarBrightness(ThemeProvider themeProvider) {
    if (!KazumiPlatform.isWindows) return;

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
        unawaited(_exitApplication());
    }
  }

  Future<void> _exitApplication() {
    return _exitFuture ??= _performExit();
  }

  Future<void> _performExit() async {
    await ApplicationLifecycleService.flushBeforeExit();
    exitApplicationProcess();
  }

  /// 处理窗口关闭事件，
  /// 需要使用 `windowManager.close()` 来触发，`exit(0)` 会直接退出程序
  @override
  void onWindowClose() {
    final exitBehavior = GStorage.getSetting(SettingsKeys.exitBehavior);

    switch (exitBehavior) {
      case 0:
        unawaited(_exitApplication());
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
                      await GStorage.putSetting(SettingsKeys.exitBehavior, 0);
                    }
                    await _exitApplication();
                  },
                  child: const Text('退出 Kazumi')),
              TextButton(
                  onPressed: () async {
                    if (saveExitBehavior) {
                      await GStorage.putSetting(SettingsKeys.exitBehavior, 1);
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
    final ThemeProvider themeProvider = context.read<ThemeProvider>();
    KazumiLogger().i(
        "Platform brightness changed, themeMode: ${themeProvider.themeMode}");

    _syncWindowsTitleBarBrightness(themeProvider);
  }

  Future<void> _handleTray() async {
    if (KazumiPlatform.isWindows) {
      await trayManager.setIcon('assets/images/logo/logo_lanczos.ico');
    } else if (KazumiPlatform.environment.containsKey('FLATPAK_ID') ||
        KazumiPlatform.environment.containsKey('SNAP')) {
      await trayManager.setIcon('io.github.Predidit.Kazumi');
    } else {
      await trayManager.setIcon('assets/images/logo/logo_rounded.png');
    }

    if (!KazumiPlatform.isLinux) {
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
        final accessibility =
            WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
        final reduceMotion = accessibility.disableAnimations ||
            accessibility.accessibleNavigation;
        final highContrastTheme = _buildAppTheme(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: lightTheme.colorScheme.primary,
            brightness: Brightness.light,
            contrastLevel: 1,
          ),
          fontFamily: themeProvider.currentFontFamily,
        );
        final highContrastDarkTheme = _buildAppTheme(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: effectiveDarkTheme.colorScheme.primary,
            brightness: Brightness.dark,
            contrastLevel: 1,
          ),
          fontFamily: themeProvider.currentFontFamily,
        );
        final resolvedLightTheme = applyKazumiMotionPreference(
          lightTheme,
          reduceMotion: reduceMotion,
        );
        final resolvedDarkTheme = applyKazumiMotionPreference(
          effectiveDarkTheme,
          reduceMotion: reduceMotion,
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
          theme: resolvedLightTheme,
          darkTheme: resolvedDarkTheme,
          highContrastTheme: applyKazumiMotionPreference(
            highContrastTheme,
            reduceMotion: reduceMotion,
          ),
          highContrastDarkTheme: applyKazumiMotionPreference(
            highContrastDarkTheme,
            reduceMotion: reduceMotion,
          ),
          themeMode: themeProvider.themeMode,
          themeAnimationDuration: reduceMotion
              ? Duration.zero
              : KazumiDesignTokens.motionEmphasized,
          themeAnimationCurve: KazumiDesignTokens.standardCurve,
          builder: (context, child) {
            Widget content = HeroMode(
              enabled: !reduceMotion,
              child: child ?? const SizedBox.shrink(),
            );
            content = KazumiAppBackdrop(child: content);
            if (reduceMotion) {
              content = SkeletonizerConfig(
                data: SkeletonizerConfigData(
                  effect: SolidColorEffect(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
                child: content,
              );
            }
            return content;
          },
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          routerConfig: ModularApp.routerConfigOf(context),
        );
      },
    );

    return app;
  }
}
