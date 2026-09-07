import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:kazumi/navigation.dart';
import 'package:kazumi/utils/constants.dart';

/// Single-use ownership of a route, including before its first frame.
class KazumiDialogHandle<T> {
  Route<T>? _route;
  bool _used = false;
  bool _dismissed = false;

  bool get isActive => !_dismissed && (_route?.isActive ?? false);

  void dismiss({T? popWith}) {
    if (_dismissed) return;
    _dismissed = true;
    final route = _route;
    if (route != null) KazumiDialog._dismissRoute(route, popWith);
  }

  void _attach(Route<T> route) {
    _used = true;
    _route = route;
  }

  void _finish() {
    _dismissed = true;
    _route = null;
  }
}

class KazumiDialog {
  static final KazumiDialogObserver observer = KazumiDialogObserver();
  static int _toastRevision = 0;

  KazumiDialog._internal();

  static Future<T?> show<T>({
    BuildContext? context,
    KazumiDialogHandle<T>? handle,
    bool clickMaskDismiss = true,
    FutureOr<void> Function()? onDismiss,
    required WidgetBuilder builder,
  }) async {
    final dialog = handle ?? KazumiDialogHandle<T>();
    if (dialog._used) {
      throw StateError('A dialog handle can only be used once.');
    }
    try {
      final ctx = context ??
          rootNavigatorKey.currentContext ??
          observer.navigator?.context;
      if (ctx == null || !ctx.mounted || dialog._dismissed) return null;
      final navigator = Navigator.of(ctx, rootNavigator: true);
      final route = DialogRoute<T>(
        context: ctx,
        builder: builder,
        themes: InheritedTheme.capture(from: ctx, to: navigator.context),
        barrierColor: DialogTheme.of(ctx).barrierColor ??
            Theme.of(ctx).dialogTheme.barrierColor ??
            Colors.black54,
        barrierDismissible: clickMaskDismiss,
        traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
        settings: const RouteSettings(name: 'KazumiDialog'),
      );
      dialog._attach(route);
      return await navigator.push<T>(route);
    } catch (e) {
      debugPrint('Kazumi Dialog Error: Failed to show dialog: $e');
      return null;
    } finally {
      dialog._finish();
      await onDismiss?.call();
    }
  }

  static void showToast({
    required String message,
    BuildContext? context,
    bool showActionButton = false,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration duration = const Duration(seconds: 2),
  }) {
    final messenger = _resolveScaffoldMessenger(context);
    if (messenger != null && messenger.mounted) {
      final toastContext =
          context != null && context.mounted ? context : messenger.context;
      try {
        _toastRevision++;
        messenger
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              width: MediaQuery.sizeOf(toastContext).width >
                      LayoutBreakpoint.medium['width']!
                  ? 600
                  : null,
              duration: duration,
              persist: false,
              action: showActionButton
                  ? SnackBarAction(
                      label: actionLabel ?? 'Dismiss',
                      onPressed: () {
                        // Let SnackBarAction close the old toast before replacing it.
                        if (onActionPressed != null) {
                          scheduleMicrotask(onActionPressed);
                        }
                      },
                    )
                  : null,
            ),
          );
      } catch (e) {
        debugPrint('Kazumi Dialog Error: Failed to show toast: $e');
      }
    } else {
      debugPrint(
          'Kazumi Dialog Error: No ScaffoldMessenger available to show Toast');
    }
  }

  static void dismiss<T>({BuildContext? context, T? popWith}) {
    if (context != null && !context.mounted) return;
    final route =
        context == null ? observer._lastDialogRoute : ModalRoute.of(context);
    if (route != null && route.settings.name == 'KazumiDialog') {
      _dismissRoute(route, popWith);
    }
  }

  static void _dismissRoute<T>(Route<T> route, T? result) {
    if (!route.isActive) return;
    // Owners may be disposed while Navigator is reconciling its routes.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dismissRoute(route, result);
      });
      return;
    }
    final navigator = route.navigator;
    if (navigator == null || !navigator.mounted) return;
    if (route.isCurrent) {
      navigator.pop<T>(result);
    } else {
      navigator.removeRoute<T>(route, result);
    }
  }

  static ScaffoldMessengerState? _resolveScaffoldMessenger(
    BuildContext? context,
  ) {
    if (context != null && context.mounted) {
      final scopedMessenger = ScaffoldMessenger.maybeOf(context);
      if (scopedMessenger != null) {
        return scopedMessenger;
      }
    }
    return rootScaffoldMessengerKey.currentState;
  }
}

class KazumiDialogObserver extends NavigatorObserver {
  final List<Route<dynamic>> _kazumiDialogRoutes = [];
  bool _snackBarClearScheduled = false;

  bool get hasKazumiDialog => _kazumiDialogRoutes.isNotEmpty;

  Route<dynamic>? get _lastDialogRoute =>
      _kazumiDialogRoutes.isEmpty ? null : _kazumiDialogRoutes.last;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_isKazumiDialogRoute(route)) {
      _kazumiDialogRoutes.add(route);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PageRoute) _scheduleSnackBarClear();
    if (_isKazumiDialogRoute(route)) {
      _kazumiDialogRoutes.remove(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute is PageRoute) _scheduleSnackBarClear();
    if (_isKazumiDialogRoute(oldRoute)) {
      _kazumiDialogRoutes.remove(oldRoute);
    }
    if (newRoute != null && _isKazumiDialogRoute(newRoute)) {
      _kazumiDialogRoutes.add(newRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (route is PageRoute) _scheduleSnackBarClear();

    if (_isKazumiDialogRoute(route)) {
      _kazumiDialogRoutes.remove(route);
    }
  }

  bool _isKazumiDialogRoute(Route<dynamic>? route) =>
      route?.settings.name == 'KazumiDialog';

  void _scheduleSnackBarClear() {
    if (_snackBarClearScheduled) return;
    _snackBarClearScheduled = true;
    final revision = KazumiDialog._toastRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snackBarClearScheduled = false;
      // Only clear the old page's toast, never one posted after navigation.
      if (revision == KazumiDialog._toastRevision) {
        rootScaffoldMessengerKey.currentState?.removeCurrentSnackBar();
      }
    });
  }
}
