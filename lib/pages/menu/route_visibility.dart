import 'package:flutter/material.dart';

class RouteVisibility extends InheritedWidget {
  const RouteVisibility({
    super.key,
    required this.isCovered,
    required super.child,
  });

  final bool isCovered;

  static bool isCoveredOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<RouteVisibility>()
            ?.isCovered ??
        false;
  }

  @override
  bool updateShouldNotify(RouteVisibility oldWidget) =>
      isCovered != oldWidget.isCovered;
}
