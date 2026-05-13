import 'package:flutter/material.dart';

/// 构建与桌面端 `ThemeData(useMaterial3: true, colorSchemeSeed: seed,
/// brightness: ...)` 同源的 ColorScheme。
///
/// Flutter 内部就是调 `ColorScheme.fromSeed(seedColor: seed,
/// brightness: ...)`，所以这里也走这个接口而不绕到 `material_color_utilities`
/// 的底层（避免 SDK 升级时 `DynamicSchemeVariant` 默认值漂移引发不一致）。
///
/// `oledEnhance && brightness == dark` 时按 `lib/utils/utils.dart` 的
/// `oledDarkTheme` 逻辑覆盖 4 个字段（其余字段保留）。
ColorScheme buildScheme({
  required Color seed,
  required Brightness brightness,
  required bool oledEnhance,
}) {
  var scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
  if (brightness == Brightness.dark && oledEnhance) {
    scheme = scheme.copyWith(
      surface: const Color(0xFF000000),
      onSurface: const Color(0xFFFFFFFF),
      onPrimary: const Color(0xFF000000),
      onSecondary: const Color(0xFF000000),
    );
  }
  return scheme;
}

/// 把 ColorScheme 的全部字段序列化为 `{name: "#RRGGBB"}` 形式。
///
/// 字段名用 camelCase 与 Flutter 一致，便于 web 端做 1:1 映射（kebab-case
/// 转换在前端完成：`primaryContainer` → `--primary-container`）。
///
/// 额外补一个 `scaffoldBackground` 字段——桌面端 ThemeData 未显式定制
/// `scaffoldBackgroundColor` 时默认值等于 `colorScheme.surface`。
Map<String, String> exportColorTokens(ColorScheme cs) {
  return {
    'primary': _hex(cs.primary),
    'onPrimary': _hex(cs.onPrimary),
    'primaryContainer': _hex(cs.primaryContainer),
    'onPrimaryContainer': _hex(cs.onPrimaryContainer),
    'secondary': _hex(cs.secondary),
    'onSecondary': _hex(cs.onSecondary),
    'secondaryContainer': _hex(cs.secondaryContainer),
    'onSecondaryContainer': _hex(cs.onSecondaryContainer),
    'tertiary': _hex(cs.tertiary),
    'onTertiary': _hex(cs.onTertiary),
    'tertiaryContainer': _hex(cs.tertiaryContainer),
    'onTertiaryContainer': _hex(cs.onTertiaryContainer),
    'error': _hex(cs.error),
    'onError': _hex(cs.onError),
    'errorContainer': _hex(cs.errorContainer),
    'onErrorContainer': _hex(cs.onErrorContainer),
    'surface': _hex(cs.surface),
    'onSurface': _hex(cs.onSurface),
    'onSurfaceVariant': _hex(cs.onSurfaceVariant),
    'surfaceDim': _hex(cs.surfaceDim),
    'surfaceBright': _hex(cs.surfaceBright),
    'surfaceContainerLowest': _hex(cs.surfaceContainerLowest),
    'surfaceContainerLow': _hex(cs.surfaceContainerLow),
    'surfaceContainer': _hex(cs.surfaceContainer),
    'surfaceContainerHigh': _hex(cs.surfaceContainerHigh),
    'surfaceContainerHighest': _hex(cs.surfaceContainerHighest),
    'outline': _hex(cs.outline),
    'outlineVariant': _hex(cs.outlineVariant),
    'shadow': _hex(cs.shadow),
    'scrim': _hex(cs.scrim),
    'inverseSurface': _hex(cs.inverseSurface),
    'onInverseSurface': _hex(cs.onInverseSurface),
    'inversePrimary': _hex(cs.inversePrimary),
    'scaffoldBackground': _hex(cs.surface),
  };
}

/// 导出 Material 3 type scale 的全部 15 个 role。
///
/// 取自 `ThemeData(useMaterial3: true).textTheme`，与桌面端走的是同一份
/// `Typography.material2021`，输出 fontSize/fontWeight/letterSpacing/height
/// 四个几何字段。颜色不导出——颜色随 ColorScheme 在前端单独应用。
Map<String, Map<String, dynamic>> exportTypographyTokens() {
  final tt = ThemeData(useMaterial3: true).textTheme;
  return {
    'displayLarge': _styleOf(tt.displayLarge),
    'displayMedium': _styleOf(tt.displayMedium),
    'displaySmall': _styleOf(tt.displaySmall),
    'headlineLarge': _styleOf(tt.headlineLarge),
    'headlineMedium': _styleOf(tt.headlineMedium),
    'headlineSmall': _styleOf(tt.headlineSmall),
    'titleLarge': _styleOf(tt.titleLarge),
    'titleMedium': _styleOf(tt.titleMedium),
    'titleSmall': _styleOf(tt.titleSmall),
    'labelLarge': _styleOf(tt.labelLarge),
    'labelMedium': _styleOf(tt.labelMedium),
    'labelSmall': _styleOf(tt.labelSmall),
    'bodyLarge': _styleOf(tt.bodyLarge),
    'bodyMedium': _styleOf(tt.bodyMedium),
    'bodySmall': _styleOf(tt.bodySmall),
  };
}

Map<String, dynamic> _styleOf(TextStyle? s) => {
      'size': s?.fontSize,
      'weight': s?.fontWeight?.value,
      'letterSpacing': s?.letterSpacing,
      'height': s?.height,
    };

String _hex(Color c) {
  final r = (c.r * 255).round() & 0xFF;
  final g = (c.g * 255).round() & 0xFF;
  final b = (c.b * 255).round() & 0xFF;
  return '#'
      '${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}
