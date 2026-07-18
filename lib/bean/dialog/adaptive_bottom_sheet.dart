import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';
import 'package:kazumi/design_system/kazumi_surfaces.dart';

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
  bool showDragHandle = true,
  bool enableBlur = true,
}) {
  final tokens = context.design;
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) => KazumiGlassSurface(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(tokens.radiusSheet),
      ),
      color: backgroundColor,
      shadow: false,
      enableBlur: enableBlur,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: showDragHandle ? 48 : 0),
            child: builder(sheetContext),
          ),
          if (showDragHandle)
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: Center(
                child: IconButton(
                  tooltip: MaterialLocalizations.of(
                    sheetContext,
                  ).modalBarrierDismissLabel,
                  onPressed: () => Navigator.of(sheetContext).maybePop(),
                  icon: Container(
                    width: 36,
                    height: 4,
                    decoration: ShapeDecoration(
                      color: Theme.of(sheetContext).colorScheme.outline,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    constraints: adaptiveBottomSheetConstraints(
      context,
      maxHeightFactor: maxHeightFactor,
      compactLandscapeMaxHeightFactor: compactLandscapeMaxHeightFactor,
    ),
    shape: RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(tokens.radiusSheet),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    backgroundColor: Colors.transparent,
  );
}
