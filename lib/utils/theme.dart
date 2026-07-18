import 'package:flutter/material.dart';
import 'package:kazumi/design_system/kazumi_theme.dart';

ThemeData oledDarkTheme(ThemeData defaultDarkTheme) {
  final oled = defaultDarkTheme.copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: defaultDarkTheme.colorScheme.copyWith(
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
    ),
  );
  return applyKazumiDesignSystem(oled);
}
