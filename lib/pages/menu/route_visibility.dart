import 'package:flutter/material.dart';

/// Whether the surrounding route subtree is covered by another page.
///
/// Published by the page that owns the route, so long-lived children can stop
/// background work while hidden instead of inspecting the navigation stack.
class RouteVisibility extends InheritedWidget {
  const RouteVisibility({
    super.key,
    required this.isCovered,
    required super.child,
  });

  final bool isCovered;

  /// Subscribes; dependents are notified only when the state flips.
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
