import 'package:flutter/material.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Lets [RouteAware] pages learn they were covered or revealed again.
///
/// Restricted to [PageRoute] on purpose: dialogs and bottom sheets are
/// PopupRoutes, and sitting under one does not make a page hidden.
final rootRouteObserver = RouteObserver<PageRoute<void>>();

final _closedByExternalNavigation = <Route<Object?>>{};

/// Marks [route] to close, not be covered, when a deep link opens a page.
void closeOnExternalNavigation(Route<Object?> route) {
  _closedByExternalNavigation.add(route);
}

void clearExternalNavigationMark(Route<Object?> route) {
  _closedByExternalNavigation.remove(route);
}

/// Pops marked routes and everything above them like the back button, so
/// [PopScope] and local history entries unwind. False if a route vetoes.
bool popForExternalNavigation(NavigatorState navigator) {
  bool hasMarkedRoute() => _closedByExternalNavigation
      .any((route) => route.isActive && route.navigator == navigator);

  var vetoed = false;
  navigator.popUntil((current) {
    if (!hasMarkedRoute()) return true;
    vetoed = current.popDisposition == RoutePopDisposition.doNotPop;
    return vetoed;
  });
  return !vetoed;
}
