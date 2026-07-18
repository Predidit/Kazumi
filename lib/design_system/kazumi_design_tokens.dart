import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class KazumiDesignTokens extends ThemeExtension<KazumiDesignTokens> {
  const KazumiDesignTokens({
    required this.glassTint,
    required this.glassBorder,
    required this.surfaceHighlight,
    required this.focusRing,
    required this.hoverOverlay,
    required this.pressedOverlay,
    required this.selectedOverlay,
    required this.subtleShadow,
    required this.accentGlow,
    required this.secondaryGlow,
    required this.glassOpacity,
    this.radiusControl = 12,
    this.radiusCompact = 16,
    this.radiusSurface = 20,
    this.radiusSheet = 24,
    this.radiusDialog = 28,
    this.blurNavigation = 18,
    this.blurOverlay = 24,
    this.disabledOpacity = 0.38,
  });

  factory KazumiDesignTokens.from(ColorScheme colors) {
    final dark = colors.brightness == Brightness.dark;
    return KazumiDesignTokens(
      glassTint: colors.surface.withValues(alpha: dark ? 0.72 : 0.78),
      glassBorder: colors.outlineVariant.withValues(alpha: dark ? 0.42 : 0.5),
      surfaceHighlight: Colors.white.withValues(alpha: dark ? 0.09 : 0.68),
      focusRing: colors.primary.withValues(alpha: dark ? 0.9 : 0.82),
      hoverOverlay: colors.primary.withValues(alpha: dark ? 0.1 : 0.07),
      pressedOverlay: colors.primary.withValues(alpha: dark ? 0.18 : 0.13),
      selectedOverlay: colors.primary.withValues(alpha: dark ? 0.24 : 0.16),
      subtleShadow: Colors.black.withValues(alpha: dark ? 0.3 : 0.12),
      accentGlow: colors.primary.withValues(alpha: dark ? 0.2 : 0.14),
      secondaryGlow: colors.tertiary.withValues(alpha: dark ? 0.16 : 0.1),
      glassOpacity: dark ? 0.72 : 0.78,
    );
  }

  final Color glassTint;
  final Color glassBorder;
  final Color surfaceHighlight;
  final Color focusRing;
  final Color hoverOverlay;
  final Color pressedOverlay;
  final Color selectedOverlay;
  final Color subtleShadow;
  final Color accentGlow;
  final Color secondaryGlow;

  final double glassOpacity;
  final double radiusControl;
  final double radiusCompact;
  final double radiusSurface;
  final double radiusSheet;
  final double radiusDialog;
  final double blurNavigation;
  final double blurOverlay;
  final double disabledOpacity;

  static const double space2xs = 4;
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 20;
  static const double spaceXl = 24;
  static const double space2xl = 32;
  static const double readableContentWidth = 1200;
  static const double shellBreakpoint = 720;

  static const Duration motionInstant = Duration(milliseconds: 90);
  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motionStandard = Duration(milliseconds: 240);
  static const Duration motionEmphasized = Duration(milliseconds: 360);
  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeOutBack;

  @override
  KazumiDesignTokens copyWith({
    Color? glassTint,
    Color? glassBorder,
    Color? surfaceHighlight,
    Color? focusRing,
    Color? hoverOverlay,
    Color? pressedOverlay,
    Color? selectedOverlay,
    Color? subtleShadow,
    Color? accentGlow,
    Color? secondaryGlow,
    double? glassOpacity,
    double? radiusControl,
    double? radiusCompact,
    double? radiusSurface,
    double? radiusSheet,
    double? radiusDialog,
    double? blurNavigation,
    double? blurOverlay,
    double? disabledOpacity,
  }) {
    return KazumiDesignTokens(
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      surfaceHighlight: surfaceHighlight ?? this.surfaceHighlight,
      focusRing: focusRing ?? this.focusRing,
      hoverOverlay: hoverOverlay ?? this.hoverOverlay,
      pressedOverlay: pressedOverlay ?? this.pressedOverlay,
      selectedOverlay: selectedOverlay ?? this.selectedOverlay,
      subtleShadow: subtleShadow ?? this.subtleShadow,
      accentGlow: accentGlow ?? this.accentGlow,
      secondaryGlow: secondaryGlow ?? this.secondaryGlow,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      radiusControl: radiusControl ?? this.radiusControl,
      radiusCompact: radiusCompact ?? this.radiusCompact,
      radiusSurface: radiusSurface ?? this.radiusSurface,
      radiusSheet: radiusSheet ?? this.radiusSheet,
      radiusDialog: radiusDialog ?? this.radiusDialog,
      blurNavigation: blurNavigation ?? this.blurNavigation,
      blurOverlay: blurOverlay ?? this.blurOverlay,
      disabledOpacity: disabledOpacity ?? this.disabledOpacity,
    );
  }

  @override
  KazumiDesignTokens lerp(
    covariant ThemeExtension<KazumiDesignTokens>? other,
    double t,
  ) {
    if (other is! KazumiDesignTokens) return this;
    return KazumiDesignTokens(
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      surfaceHighlight:
          Color.lerp(surfaceHighlight, other.surfaceHighlight, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      hoverOverlay: Color.lerp(hoverOverlay, other.hoverOverlay, t)!,
      pressedOverlay: Color.lerp(pressedOverlay, other.pressedOverlay, t)!,
      selectedOverlay: Color.lerp(selectedOverlay, other.selectedOverlay, t)!,
      subtleShadow: Color.lerp(subtleShadow, other.subtleShadow, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      secondaryGlow: Color.lerp(secondaryGlow, other.secondaryGlow, t)!,
      glassOpacity: lerpDouble(glassOpacity, other.glassOpacity, t)!,
      radiusControl: lerpDouble(radiusControl, other.radiusControl, t)!,
      radiusCompact: lerpDouble(radiusCompact, other.radiusCompact, t)!,
      radiusSurface: lerpDouble(radiusSurface, other.radiusSurface, t)!,
      radiusSheet: lerpDouble(radiusSheet, other.radiusSheet, t)!,
      radiusDialog: lerpDouble(radiusDialog, other.radiusDialog, t)!,
      blurNavigation: lerpDouble(blurNavigation, other.blurNavigation, t)!,
      blurOverlay: lerpDouble(blurOverlay, other.blurOverlay, t)!,
      disabledOpacity: lerpDouble(disabledOpacity, other.disabledOpacity, t)!,
    );
  }
}

/// The continuous-corner shape used across the Windows visual system.
///
/// Flutter's rounded superellipse follows the same smooth-corner principle as
/// modern Apple surfaces while retaining a native Material shape contract for
/// focus, ink and hit testing.
RoundedSuperellipseBorder kazumiSmoothShape(
  double radius, {
  BorderSide side = BorderSide.none,
}) {
  return RoundedSuperellipseBorder(
    borderRadius: BorderRadius.circular(radius),
    side: side,
  );
}

extension KazumiDesignContext on BuildContext {
  KazumiDesignTokens get design =>
      Theme.of(this).extension<KazumiDesignTokens>() ??
      KazumiDesignTokens.from(Theme.of(this).colorScheme);

  bool get reduceMotion {
    final media = MediaQuery.maybeOf(this);
    return media?.disableAnimations == true ||
        media?.accessibleNavigation == true;
  }

  Duration motion(Duration duration) {
    return reduceMotion ? Duration.zero : duration;
  }
}
