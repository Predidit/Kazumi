import 'package:material_ui/material_ui.dart';

ThemeData oledDarkTheme(ThemeData defaultDarkTheme) {
  return defaultDarkTheme.copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: defaultDarkTheme.colorScheme.copyWith(
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
    ),
  );
}
