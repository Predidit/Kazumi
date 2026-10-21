import 'package:flutter/material.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Lets [RouteAware] pages learn they were covered or revealed again.
///
/// Restricted to [PageRoute] on purpose: dialogs and bottom sheets are
/// PopupRoutes, and sitting under one does not make a page hidden.
final rootRouteObserver = RouteObserver<PageRoute<void>>();

/// The route of the open player page, if any.
///
/// Deep links close the player instead of stacking pages above it.
ModalRoute<Object?>? activePlayerRoute;

/// Pops [route] and every route above it the way the back button would, so
/// [PopScope] callbacks and local history entries (fullscreen, PiP) unwind.
///
/// Stops at the first route that vetoes popping (e.g. a screenshot export in
/// progress) and returns false; [route] then stays open.
bool popThroughRoute(NavigatorState navigator, Route<Object?> route) {
  var vetoed = false;
  navigator.popUntil((current) {
    if (!route.isActive) return true;
    vetoed = current.popDisposition == RoutePopDisposition.doNotPop;
    return vetoed;
  });
  return !vetoed;
}
