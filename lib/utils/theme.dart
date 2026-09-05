import 'package:material_ui/material_ui.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:kazumi/utils/constants.dart';

/// Shared by startup, dynamic colors and the appearance settings page.
ThemeData buildAppTheme({
  required Brightness brightness,
  required String? fontFamily,
  Color? color,
  ColorScheme? colorScheme,
}) {
  final theme = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    brightness: brightness,
    colorScheme: colorScheme ??
        M3EColorScheme.generate(
          seedColor: color ?? Colors.green,
          brightness: brightness,
        ),
    pageTransitionsTheme: pageTransitionsTheme2024,
  );
  return theme.copyWith(
    textTheme: theme.emphasizedTextTheme.copyWith(
      bodyLarge: theme.textTheme.bodyLarge,
      bodyMedium: theme.textTheme.bodyMedium,
      bodySmall: theme.textTheme.bodySmall,
    ),
  );
}

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
