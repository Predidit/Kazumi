import 'package:flutter/material.dart';
import 'package:kazumi/utils/constants.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  bool useDynamicColor = false;
  late ThemeData light;
  late ThemeData dark;
  String? currentFontFamily = customAppFontFamily;

  /// Returns true if the effective theme is dark mode.
  /// When themeMode is ThemeMode.system, uses the provided platform brightness.
  bool isEffectiveDark(Brightness platformBrightness) {
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    return platformBrightness == Brightness.dark;
  }

  void setTheme(ThemeData light, ThemeData dark, {bool notify = true}) {
    this.light = light;
    this.dark = dark;
    if (notify) notifyListeners();
  }

  void setThemeMode(ThemeMode mode, {bool notify = true}) {
    themeMode = mode;
    if (notify) notifyListeners();
  }

  void setDynamic(bool useDynamicColor, {bool notify = true}) {
    this.useDynamicColor = useDynamicColor;
    if (notify) notifyListeners();
  }

  void setFontFamily(bool useSystemFont, {bool notify = true}) {
    currentFontFamily = useSystemFont ? null : customAppFontFamily;
    if (notify) notifyListeners();
  }
}
