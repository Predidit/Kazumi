import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kazumi/utils/device.dart';

BoxConstraints adaptiveBottomSheetConstraints(
  BuildContext context, {
  double maxHeightFactor = 0.75,
  double compactLandscapeMaxHeightFactor = 0.9,
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
  Color? backgroundColor,
  bool showDragHandle = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: showDragHandle,
    constraints: adaptiveBottomSheetConstraints(
      context,
      maxHeightFactor: maxHeightFactor,
      compactLandscapeMaxHeightFactor: compactLandscapeMaxHeightFactor,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
  );
}
