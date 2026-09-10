import 'package:flutter/material.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// Dialogs and bottom sheets must not suspend the page beneath them.
final rootRouteObserver = RouteObserver<PageRoute<void>>();
