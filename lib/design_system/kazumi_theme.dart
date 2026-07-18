import 'package:flutter/material.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';

ThemeData applyKazumiDesignSystem(ThemeData base) {
  final colors = base.colorScheme;
  final tokens = KazumiDesignTokens.from(colors);
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(tokens.radiusControl),
  );
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(tokens.radiusCompact),
    side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.28)),
  );
  final dialogShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(tokens.radiusDialog),
    side: BorderSide(color: tokens.glassBorder),
  );

  final buttonStyle = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    shape: WidgetStatePropertyAll(controlShape),
    animationDuration: KazumiDesignTokens.motionFast,
    overlayColor: _interactiveOverlay(tokens),
    side: _focusSide(tokens),
  );

  final iconButtonStyle = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
    tapTargetSize: MaterialTapTargetSize.padded,
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusControl),
      ),
    ),
    animationDuration: KazumiDesignTokens.motionFast,
    overlayColor: _interactiveOverlay(tokens),
    side: _focusSide(tokens),
  );

  final textTheme = base.textTheme.copyWith(
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    ),
  );
  final themeExtensions = base.extensions.values.toList()
    ..removeWhere((extension) => extension is KazumiDesignTokens)
    ..add(tokens);
  final pageTransitions = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      ...base.pageTransitionsTheme.builders,
      TargetPlatform.windows: const KazumiWindowsPageTransitionsBuilder(),
    },
  );

  return base.copyWith(
    scaffoldBackgroundColor: colors.surface,
    canvasColor: colors.surface,
    splashFactory: InkRipple.splashFactory,
    hoverColor: tokens.hoverOverlay,
    focusColor: tokens.focusRing.withValues(alpha: 0.18),
    highlightColor: tokens.pressedOverlay,
    textTheme: textTheme,
    extensions: themeExtensions,
    pageTransitionsTheme: pageTransitions,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colors.onSurface,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colors.onSurface,
      ),
      iconTheme: IconThemeData(color: colors.onSurfaceVariant),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shadowColor: tokens.subtleShadow,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: cardShape,
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: colors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shadowColor: tokens.subtleShadow,
      shape: dialogShape,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titleTextStyle: textTheme.titleLarge?.copyWith(color: colors.onSurface),
      contentTextStyle:
          textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      modalElevation: 0,
      backgroundColor: colors.surfaceContainerHigh,
      modalBackgroundColor: colors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shadowColor: tokens.subtleShadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radiusSheet),
        ),
        side: BorderSide(color: tokens.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      dragHandleColor: colors.outline,
      dragHandleSize: const Size(36, 4),
      constraints: const BoxConstraints(maxWidth: 720),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: colors.inverseSurface,
      contentTextStyle:
          textTheme.bodyMedium?.copyWith(color: colors.onInverseSurface),
      actionTextColor: colors.inversePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusCompact),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.62),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        borderSide: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        borderSide: BorderSide(color: tokens.focusRing, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        borderSide: BorderSide(color: colors.error, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: buttonStyle.copyWith(
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: buttonStyle.copyWith(
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: tokens.focusRing, width: 2);
          }
          return BorderSide(color: colors.outlineVariant);
        }),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: buttonStyle.copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: iconButtonStyle),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusCompact),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusControl),
      ),
      selectedColor: colors.onSecondaryContainer,
      selectedTileColor: colors.secondaryContainer,
      iconColor: colors.onSurfaceVariant,
    ),
    navigationRailTheme: NavigationRailThemeData(
      elevation: 0,
      backgroundColor: Colors.transparent,
      minWidth: 88,
      indicatorColor: colors.secondaryContainer,
      indicatorShape: const StadiumBorder(),
      useIndicator: true,
      selectedIconTheme: IconThemeData(color: colors.onSecondaryContainer),
      unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle:
          textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 72,
      backgroundColor: colors.surfaceContainer.withValues(alpha: 0.94),
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.secondaryContainer,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return textTheme.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? colors.onSurface
              : colors.onSurfaceVariant,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colors.onSecondaryContainer
              : colors.onSurfaceVariant,
        );
      }),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(
        colors.surfaceContainerHigh.withValues(alpha: 0.78),
      ),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: _interactiveOverlay(tokens),
      side: WidgetStateProperty.resolveWith((states) {
        return BorderSide(
          color: states.contains(WidgetState.focused)
              ? tokens.focusRing
              : colors.outlineVariant.withValues(alpha: 0.55),
          width: states.contains(WidgetState.focused) ? 2 : 1,
        );
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusCompact),
        ),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusCompact),
            side: BorderSide(color: tokens.glassBorder),
          ),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      elevation: 0,
      color: colors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusCompact),
        side: BorderSide(color: tokens.glassBorder),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusCompact),
            side: BorderSide(color: tokens.glassBorder),
          ),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      showDuration: const Duration(seconds: 4),
      decoration: BoxDecoration(
        color: colors.inverseSurface,
        borderRadius: BorderRadius.circular(tokens.radiusControl),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: colors.onInverseSurface),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: colors.surfaceContainerHighest,
      selectedColor: colors.secondaryContainer,
      disabledColor: colors.onSurface.withValues(alpha: 0.08),
      side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusControl),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant.withValues(alpha: 0.48),
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
      color: colors.primary,
      linearTrackColor: colors.surfaceContainerHighest,
      circularTrackColor: colors.surfaceContainerHighest,
      strokeCap: StrokeCap.round,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered) ? 10 : 7,
      ),
      radius: const Radius.circular(999),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return colors.onSurfaceVariant.withValues(
          alpha: states.contains(WidgetState.hovered) ? 0.56 : 0.34,
        );
      }),
      trackColor: WidgetStatePropertyAll(
        colors.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      interactive: true,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: BorderSide(color: colors.outline),
      overlayColor: _interactiveOverlay(tokens),
    ),
    radioTheme: RadioThemeData(overlayColor: _interactiveOverlay(tokens)),
    switchTheme: SwitchThemeData(
      overlayColor: _interactiveOverlay(tokens),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.onSurface.withValues(alpha: tokens.disabledOpacity);
        }
        if (states.contains(WidgetState.selected)) {
          return colors.onPrimary;
        }
        return colors.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.onSurface.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.selected)) return colors.primary;
        return colors.surfaceContainerHighest;
      }),
    ),
  );
}

class KazumiWindowsPageTransitionsBuilder extends PageTransitionsBuilder {
  const KazumiWindowsPageTransitionsBuilder();

  static final Animatable<double> _opacityTween = Tween<double>(
    begin: 0,
    end: 1,
  ).chain(CurveTween(curve: KazumiDesignTokens.standardCurve));
  static final Animatable<Offset> _positionTween = Tween<Offset>(
    begin: const Offset(0, 0.018),
    end: Offset.zero,
  ).chain(CurveTween(curve: KazumiDesignTokens.standardCurve));

  @override
  Duration get transitionDuration => KazumiDesignTokens.motionStandard;

  @override
  Duration get reverseTransitionDuration => KazumiDesignTokens.motionFast;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst || context.reduceMotion) return child;
    return FadeTransition(
      opacity: animation.drive(_opacityTween),
      child: SlideTransition(
        position: animation.drive(_positionTween),
        child: child,
      ),
    );
  }
}

WidgetStateProperty<Color?> _interactiveOverlay(KazumiDesignTokens tokens) {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return Colors.transparent;
    if (states.contains(WidgetState.pressed)) return tokens.pressedOverlay;
    if (states.contains(WidgetState.hovered)) return tokens.hoverOverlay;
    if (states.contains(WidgetState.focused)) {
      return tokens.focusRing.withValues(alpha: 0.12);
    }
    return Colors.transparent;
  });
}

WidgetStateProperty<BorderSide?> _focusSide(KazumiDesignTokens tokens) {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.focused)) {
      return BorderSide(color: tokens.focusRing, width: 2);
    }
    return BorderSide.none;
  });
}
