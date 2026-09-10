import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/async_serial_queue.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/theme.dart';

typedef _Appearance = ({
  ThemeMode mode,
  Color? color,
  bool dynamicColor,
  bool systemFont,
  bool oled,
  bool windowButtons,
});

class ThemeProvider extends ChangeNotifier {
  ThemeProvider() {
    _rebuildThemes();
    _subscription = GStorage.watchSettings(_keys).listen((_) => _reload());
  }

  static const _keys = [
    SettingsKeys.themeMode,
    SettingsKeys.themeColor,
    SettingsKeys.useDynamicColor,
    SettingsKeys.useSystemFont,
    SettingsKeys.oledEnhance,
    SettingsKeys.showWindowButton,
  ];

  final _writes = AsyncSerialQueue();
  late final StreamSubscription<void> _subscription;
  _Appearance _appearance = _readAppearance();
  late ThemeData _light;
  late ThemeData _dark;
  bool _disposed = false;

  ThemeMode get themeMode => _appearance.mode;
  Color? get themeColor => _appearance.color;
  bool get useDynamicColor => _appearance.dynamicColor;
  bool get useSystemFont => _appearance.systemFont;
  bool get oledEnhance => _appearance.oled;
  bool get showWindowButton => _appearance.windowButtons;
  String? get currentFontFamily => useSystemFont ? null : customAppFontFamily;

  static _Appearance _readAppearance() {
    final color =
        int.tryParse(GStorage.getSetting(SettingsKeys.themeColor), radix: 16);
    return (
      mode: switch (GStorage.getSetting(SettingsKeys.themeMode)) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      color: color == null ? null : Color(color),
      dynamicColor: GStorage.getSetting(SettingsKeys.useDynamicColor),
      systemFont: GStorage.getSetting(SettingsKeys.useSystemFont),
      oled: GStorage.getSetting(SettingsKeys.oledEnhance),
      windowButtons: GStorage.getSetting(SettingsKeys.showWindowButton),
    );
  }

  void _reload() {
    if (_disposed) return;
    final appearance = _readAppearance();
    if (appearance == _appearance) return;
    _appearance = appearance;
    _rebuildThemes();
    notifyListeners();
  }

  void _rebuildThemes() {
    _light = _buildTheme(Brightness.light);
    _dark = _buildTheme(Brightness.dark);
  }

  ThemeData _buildTheme(Brightness brightness, [ColorScheme? scheme]) {
    final theme = ThemeData(
      useMaterial3: true,
      fontFamily: currentFontFamily,
      brightness: brightness,
      colorSchemeSeed: scheme == null ? themeColor ?? Colors.green : null,
      colorScheme: scheme,
      progressIndicatorTheme: progressIndicatorTheme2024,
      sliderTheme: sliderTheme2024,
      pageTransitionsTheme: pageTransitionsTheme2024,
    );
    return brightness == Brightness.dark && oledEnhance
        ? oledDarkTheme(theme)
        : theme;
  }

  ({ThemeData light, ThemeData dark}) themes({
    ColorScheme? dynamicLight,
    ColorScheme? dynamicDark,
  }) {
    if (useDynamicColor && dynamicLight != null && dynamicDark != null) {
      return (
        light: _buildTheme(Brightness.light, dynamicLight),
        dark: _buildTheme(Brightness.dark, dynamicDark),
      );
    }
    return (light: _light, dark: _dark);
  }

  bool isEffectiveDark() => switch (themeMode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          SchedulerBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark,
      };

  Future<void> _write<T>(SettingKey<T> key, T value) => _writes.run(() async {
        if (_disposed) return;
        if (GStorage.getSetting(key) != value) {
          await GStorage.putSetting(key, value);
        }
        _reload();
      });

  Future<void> setThemeMode(ThemeMode mode) =>
      _write(SettingsKeys.themeMode, mode.name);

  Future<void> setThemeColor(Color? color) => _write(SettingsKeys.themeColor,
      color?.toARGB32().toRadixString(16) ?? 'default');

  Future<void> setDynamic(bool enabled) =>
      _write(SettingsKeys.useDynamicColor, enabled);

  Future<void> setSystemFont(bool enabled) =>
      _write(SettingsKeys.useSystemFont, enabled);

  Future<void> setOledEnhance(bool enabled) =>
      _write(SettingsKeys.oledEnhance, enabled);

  Future<void> setShowWindowButton(bool enabled) =>
      _write(SettingsKeys.showWindowButton, enabled);

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
