// Adapted from m3e_core 1.1.2's M3EBottomSheet (MIT).
// Copyright (c) 2026 Mudit Purohit. See licenses/m3e_core.txt.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'package:kazumi/utils/device.dart';

BoxConstraints _adaptiveBottomSheetConstraints(
  BuildContext context, {
  required double maxHeightFactor,
  required double compactLandscapeMaxHeightFactor,
}) {
  final size = MediaQuery.sizeOf(context);
  final isLandscape = size.width > size.height;
  final isLargeScreen = size.shortestSide >= 600;
  final useFullWidth = !isLandscape && size.width < 600;
  final maxWidth =
      useFullWidth ? size.width : math.min(size.width * 0.72, 640.0);
  final useExpandedLandscapeHeight =
      isLandscape && !isDesktop() && !isLargeScreen;
  final maxHeight = size.height *
      (useExpandedLandscapeHeight
          ? compactLandscapeMaxHeightFactor
          : maxHeightFactor);

  return BoxConstraints(
    maxWidth: maxWidth,
    maxHeight: maxHeight,
  );
}

Future<T?> showAdaptiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxHeightFactor = 0.75,
  double compactLandscapeMaxHeightFactor = 0.9,
  bool useRootNavigator = false,
}) {
  return _showMaterialBottomSheet<T>(
    context: context,
    builder: builder,
    useRootNavigator: useRootNavigator,
    constraints: _adaptiveBottomSheetConstraints(
      context,
      maxHeightFactor: maxHeightFactor,
      compactLandscapeMaxHeightFactor: compactLandscapeMaxHeightFactor,
    ),
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

Future<T?> _showMaterialBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required BoxConstraints constraints,
  required bool useRootNavigator,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // A single surface owns the handle and background to avoid a second cap.
    backgroundColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(),
    clipBehavior: Clip.none,
    constraints: constraints,
    isScrollControlled: true,
    useRootNavigator: useRootNavigator,
    showDragHandle: false,
    useSafeArea: true,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : _materialSheetAnimationStyle,
    builder: (context) => _MaterialSheetSurface(
      child: Builder(builder: builder),
    ),
  );
}

class _MaterialSheetSurface extends StatefulWidget {
  const _MaterialSheetSurface({required this.child});

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
        // Preserve the reference spring overshoot.
        _entrance.animateWith(SpringSimulation(
          SpringDescription.withDampingRatio(
            mass: 1,
            stiffness: 380,
            ratio: 0.8,
          ),
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
              Semantics(
                label:
                    MaterialLocalizations.of(context).modalBarrierDismissLabel,
                onDismiss: () => Navigator.of(context).maybePop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
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
