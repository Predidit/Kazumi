import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  bool useDynamicColor = false;
  late ThemeData light;
  late ThemeData dark;

  void setTheme(ThemeData light, ThemeData dark) {
    this.light = light;
    this.dark = dark;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void setDynamic(bool useDynamicColor) {
    this.useDynamicColor = useDynamicColor;
    notifyListeners();
  }
}
