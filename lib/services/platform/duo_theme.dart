import 'package:flutter/material.dart';

/// The same Material color roles used by the original bar/rail and app bar.
/// Send resolved colors so native controls follow seed, dynamic and dark themes.
Map<String, Object?> duoTheme(
  ThemeData theme, {
  required Orientation orientation,
  bool? dark,
}) {
  final colors = theme.colorScheme;
  final rail = orientation == Orientation.landscape;
  final selected = rail
      ? theme.navigationRailTheme.selectedIconTheme?.color
      : theme.navigationBarTheme.iconTheme?.resolve({
          WidgetState.selected,
        })?.color;
  final unselected = rail
      ? theme.navigationRailTheme.unselectedIconTheme?.color
      : theme.navigationBarTheme.iconTheme?.resolve({})?.color;
  final indicator = rail
      ? theme.navigationRailTheme.indicatorColor
      : theme.navigationBarTheme.indicatorColor;
  final forcedContrast =
      dark != null && dark != (theme.brightness == Brightness.dark);
  final action = forcedContrast
      ? (dark ? Colors.white : Colors.black)
      : theme.appBarTheme.actionsIconTheme?.color ??
            theme.appBarTheme.iconTheme?.color ??
            colors.onSurface;
  return {
    'primary': colors.primary.toARGB32(),
    'selected': (selected ?? colors.onSecondaryContainer).toARGB32(),
    'unselected': (unselected ?? colors.onSurfaceVariant).toARGB32(),
    'indicator': (indicator ?? colors.secondaryContainer).toARGB32(),
    'action': action.toARGB32(),
    'badgeBackground': (theme.badgeTheme.backgroundColor ?? colors.error)
        .toARGB32(),
    'badgeForeground': (theme.badgeTheme.textColor ?? colors.onError)
        .toARGB32(),
  };
}
