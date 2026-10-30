import 'package:flutter/material.dart';

/// Identify the original bundled glyph; UIKit renders this same font instead
/// of substituting an SF Symbol. Directional glyphs keep Flutter's mirroring.
Map<String, Object?> duoIcon(
  IconData icon, {
  TextDirection direction = TextDirection.ltr,
}) => {
  'codePoint': icon.codePoint,
  'family': icon.fontPackage == null
      ? icon.fontFamily
      : 'packages/${icon.fontPackage}/${icon.fontFamily}',
  'rtl': icon.matchTextDirection && direction == TextDirection.rtl,
};

/// Same normal/selected icons as ScaffoldMenu's original bar and rail.
List<Map<String, Object?>> duoTabIcons(
  Orientation orientation,
  TextDirection direction,
) {
  final icons = orientation == Orientation.portrait
      ? const [
          (Icons.home_outlined, Icons.home),
          (Icons.timeline_outlined, Icons.timeline),
          (Icons.favorite_outlined, Icons.favorite),
          (Icons.settings, Icons.settings),
        ]
      : const [
          (Icons.home_outlined, Icons.home),
          (Icons.timeline_outlined, Icons.timeline),
          (Icons.favorite_border, Icons.favorite),
          (Icons.settings_outlined, Icons.settings),
        ];
  return [
    for (final pair in icons)
      {
        'icon': duoIcon(pair.$1, direction: direction),
        'selectedIcon': duoIcon(pair.$2, direction: direction),
      },
  ];
}
