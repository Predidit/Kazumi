// Adapted from m3e_core 1.1.2's M3EBottomSheet (MIT).
// Copyright (c) 2026 Mudit Purohit. See licenses/m3e_core.txt.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'package:kazumi/bean/widget/expressive_motion.dart';

BoxConstraints _adaptiveBottomSheetConstraints(
  BuildContext context, {
  required double maxHeightFactor,
  required double compactLandscapeMaxHeightFactor,
}) {
  final size = MediaQuery.sizeOf(context);
  final isLandscape = size.width > size.height;
  final useFullWidth = !isLandscape && size.width < 600;
  final maxWidth =
      useFullWidth ? size.width : math.min(size.width * 0.72, 640.0);
  final useExpandedLandscapeHeight = isLandscape && size.height < 600;
  final maxHeight = size.height *
      (useExpandedLandscapeHeight
          ? compactLandscapeMaxHeightFactor
          : maxHeightFactor);

  return BoxConstraints(
    maxWidth: maxWidth,
    maxHeight: maxHeight,
  );
}

const ShapeBorder _materialSheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
);

// Native route motion and the extra surface entrance spring are separate.
const AnimationStyle _materialSheetAnimationStyle = AnimationStyle(
  duration: Duration(milliseconds: 250),
  reverseDuration: Duration(milliseconds: 200),
  curve: Easing.legacyDecelerate,
  reverseCurve: Easing.legacyDecelerate,
);

ModalBottomSheetRoute<T> adaptiveBottomSheetRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxHeightFactor = 0.75,
  double compactLandscapeMaxHeightFactor = 0.9,
  bool enableDrag = true,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final localizations = MaterialLocalizations.of(context);
  return ModalBottomSheetRoute<T>(
    builder: (context) => _MaterialSheetSurface(
      showDragHandle: enableDrag,
      child: Builder(builder: builder),
    ),
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    isScrollControlled: true,
    barrierLabel: localizations.scrimLabel,
    barrierOnTapHint:
        localizations.scrimOnTapHint(localizations.bottomSheetLabel),
    // A single surface owns the handle and background to avoid a second cap.
    backgroundColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(),
    clipBehavior: Clip.none,
    constraints: _adaptiveBottomSheetConstraints(
      context,
      maxHeightFactor: maxHeightFactor,
      compactLandscapeMaxHeightFactor: compactLandscapeMaxHeightFactor,
    ),
    modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
    enableDrag: enableDrag,
    showDragHandle: false,
    useSafeArea: true,
    settings: routeSettings,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : _materialSheetAnimationStyle,
  );
}

Future<T?> showAdaptiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxHeightFactor = 0.75,
  double compactLandscapeMaxHeightFactor = 0.9,
  bool enableDrag = true,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
}) {
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    adaptiveBottomSheetRoute<T>(
      context: context,
      builder: builder,
      maxHeightFactor: maxHeightFactor,
      compactLandscapeMaxHeightFactor: compactLandscapeMaxHeightFactor,
      enableDrag: enableDrag,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
    ),
  );
}

class _MaterialSheetSurface extends StatefulWidget {
  const _MaterialSheetSurface({
    required this.showDragHandle,
    required this.child,
  });

  final bool showDragHandle;
  final Widget child;

  @override
  State<_MaterialSheetSurface> createState() => _MaterialSheetSurfaceState();
}

class _MaterialSheetSurfaceState extends State<_MaterialSheetSurface>
    with SingleTickerProviderStateMixin {
  late final _entrance = AnimationController.unbounded(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _entrance.value = 1;
    } else if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
        _entrance.animateWith(SpringSimulation(
          ExpressiveMotion.defaultSpatial,
          0,
          1,
          0,
          snapToEnd: false,
        ));
      });
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final background = colors.surface;
    final surface = Material(
      color: background,
      elevation: 0,
      shape: _materialSheetShape,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(
          scaffoldBackgroundColor: Colors.transparent,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showDragHandle)
                Semantics(
                  label: MaterialLocalizations.of(context)
                      .modalBarrierDismissLabel,
                  onDismiss: () => Navigator.of(context).maybePop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.onSurfaceVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 16),
              Flexible(child: widget.child),
            ],
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Cover the bottom gap during spring overshoot.
        Positioned(
          left: 0,
          right: 0,
          bottom: -400,
          height: 450,
          child: ColoredBox(color: background),
        ),
        AnimatedBuilder(
          animation: _entrance,
          child: surface,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, (1 - _entrance.value) * 200),
            child: Opacity(
              opacity: _entrance.value.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}
