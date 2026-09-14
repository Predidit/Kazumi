import 'package:flutter/material.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Lets [RouteAware] pages learn they were covered or revealed again.
///
/// Restricted to [PageRoute] on purpose: dialogs and bottom sheets are
/// PopupRoutes, and sitting under one does not make a page hidden.
final rootRouteObserver = RouteObserver<PageRoute<void>>();

/// The top route of the root navigator, kept current by [topRouteObserver].
final currentTopRoute = ValueNotifier<Route<dynamic>?>(null);

/// Bumped whenever the top route of the root navigator changes.
///
/// The global gamepad scope lives above the [Navigator], so it cannot observe
/// route changes itself; it listens to this revision and re-targets primary
/// focus into the new top route afterwards.
final topRouteRevision = ValueNotifier<int>(0);

/// Keeps [currentTopRoute] and [topRouteRevision] in sync with the root
/// navigator.
final NavigatorObserver topRouteObserver = _TopRouteObserver();

class _TopRouteObserver extends NavigatorObserver {
  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    currentTopRoute.value = topRoute;
    topRouteRevision.value++;
  }
}
