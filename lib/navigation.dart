import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/utils/device.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Lets [RouteAware] pages learn they were covered or revealed again.
///
/// Restricted to [PageRoute] on purpose: dialogs and bottom sheets are
/// PopupRoutes, and sitting under one does not make a page hidden.
final rootRouteObserver = RouteObserver<PageRoute<void>>();

class MouseBackNavigationBlocker extends StatelessWidget {
  const MouseBackNavigationBlocker({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class DesktopMouseBackNavigation extends StatefulWidget {
  const DesktopMouseBackNavigation({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<DesktopMouseBackNavigation> createState() =>
      _DesktopMouseBackNavigationState();
}

class _BackButtonGestureArenaMember implements GestureArenaMember {
  const _BackButtonGestureArenaMember();

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {}
}

class _MouseBackTapRegionSurface extends SingleChildRenderObjectWidget {
  const _MouseBackTapRegionSurface({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMouseBackTapRegionSurface();
}

class _RenderMouseBackTapRegionSurface extends RenderTapRegionSurface {
  final Set<int> _ignoredPointers = <int>{};

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event.kind == PointerDeviceKind.mouse) {
      if (event is PointerDownEvent && event.buttons == kBackMouseButton) {
        _ignoredPointers.add(event.pointer);
        return;
      }
      if (event is PointerUpEvent && _ignoredPointers.remove(event.pointer)) {
        return;
      }
      if (event is PointerCancelEvent) {
        _ignoredPointers.remove(event.pointer);
      }
    }
    super.handleEvent(event, entry);
  }
}

class _DesktopMouseBackNavigationState
    extends State<DesktopMouseBackNavigation> {
  static const _arenaMember = _BackButtonGestureArenaMember();
  int? _activeBackPointer;

  static Route<dynamic>? _topRoute(NavigatorState navigator) {
    Route<dynamic>? current;
    navigator.popUntil((route) {
      current = route;
      return true;
    });
    return current;
  }

  static bool _isRouteBlocked(Route<dynamic>? route) {
    if (route == null || route is PopupRoute) {
      return true;
    }
    if (route is! ModalRoute) {
      return false;
    }
    final subtreeContext = route.subtreeContext;
    if (subtreeContext == null || !subtreeContext.mounted) {
      return false;
    }
    var blocked = false;
    void visit(Element element) {
      if (blocked) {
        return;
      }
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) {
        return;
      }
      if (widget is MouseBackNavigationBlocker) {
        blocked = true;
        return;
      }
      if (element is StatefulElement && element.state is NavigatorState) {
        final nestedNavigator = element.state as NavigatorState;
        if (nestedNavigator.mounted &&
            _isRouteBlocked(_topRoute(nestedNavigator))) {
          blocked = true;
        }
        return;
      }
      element.visitChildElements(visit);
    }

    subtreeContext.visitChildElements(visit);
    return blocked;
  }

  bool _canHandleMouseBack() {
    if (!isDesktop() ||
        KazumiDialog.observer.hasKazumiDialog ||
        KazumiMenuButton.hasOpenMenu) {
      return false;
    }
    final rootNavigator = rootNavigatorKey.currentState;
    if (rootNavigator == null || !rootNavigator.mounted) {
      return false;
    }
    return !_isRouteBlocked(_topRoute(rootNavigator));
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse) {
      return;
    }
    if (event.buttons == kBackMouseButton) {
      GestureBinding.instance.gestureArena
          .add(event.pointer, _arenaMember)
          .resolve(GestureDisposition.accepted);
      _activeBackPointer = _canHandleMouseBack() ? event.pointer : null;
    } else {
      _activeBackPointer = null;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activeBackPointer == event.pointer &&
        event.buttons != kBackMouseButton) {
      _activeBackPointer = null;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_activeBackPointer == event.pointer) {
      _activeBackPointer = null;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final pointer = _activeBackPointer;
    _activeBackPointer = null;
    if (pointer != event.pointer ||
        event.kind != PointerDeviceKind.mouse ||
        event.buttons != 0) {
      return;
    }
    if (_canHandleMouseBack()) {
      final rootNavigator = rootNavigatorKey.currentState;
      if (rootNavigator != null && rootNavigator.mounted) {
        unawaited(rootNavigator.maybePop());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop()) {
      return widget.child;
    }
    return _MouseBackTapRegionSurface(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerCancel: _onPointerCancel,
        onPointerUp: _onPointerUp,
        child: widget.child,
      ),
    );
  }
}
