import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

double playerPanelGutter(double maxWidth) =>
    maxWidth > 760 ? (maxWidth - 728) / 2 : 16.0;

ScrollBehavior playerPanelScrollBehavior(
  BuildContext context, {
  bool scrollbars = true,
}) =>
    ScrollConfiguration.of(context).copyWith(
      scrollbars: scrollbars,
      dragDevices: {
        ...ScrollConfiguration.of(context).dragDevices,
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
        PointerDeviceKind.trackpad,
      },
    );
