import 'package:flutter/material.dart';

// A simple dialog helper class to show dialogs and toasts based on flutter native implementation (replace flutter_smart_dialog)
// flutter_smart_dialog use overlays and self-managed route stack to show dialogs.
// It's powerful but can't behave like the default showDialog, e.g. the lack of mask animation. the lack of snackbar.
// Use the implementation should be careful, because shared route stack with the whole app, it may cause some unexpected behaviors.
// Don't use it in double PopScope widget.
class KazumiDialog {
  /// The global observer that tracks contexts across the application
  static final KazumiDialogObserver observer = KazumiDialogObserver();

  KazumiDialog._internal();

  static Future<T?> show<T>({
    BuildContext? context,
    bool? clickMaskDismiss,
    VoidCallback? onDismiss,
    required WidgetBuilder builder,
  }) async {
    final ctx = context ?? observer.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        final result = await showDialog<T>(
          context: ctx,
          barrierDismissible: clickMaskDismiss ?? true,
          builder: builder,
          routeSettings: const RouteSettings(name: 'KazumiDialog'),
        );
        onDismiss?.call();
        return result;
      } catch (e) {
        debugPrint('Kazumi Dialog Error: Failed to show dialog: $e');
        return null;
      }
    } else {
      debugPrint(
          'Kazumi Dialog Error: No context available to show the dialog');
      return null;
    }
  }

  static void showToast({
    required String message,
    BuildContext? context,
    bool showUndoButton = false,
    Duration duration = const Duration(seconds: 2),
  }) {
    final ctx = context ?? observer.scaffoldContext;
    if (ctx != null && ctx.mounted) {
      try {
        ScaffoldMessenger.of(ctx)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              duration: duration,
              action: showUndoButton
                  ? SnackBarAction(
                      label: 'Dismiss',
                      onPressed: () {},
                    )
                  : null,
            ),
          );
      } catch (e) {
        debugPrint('Kazumi Dialog Error: Failed to show toast: $e');
      }
    } else {
      debugPrint(
          'Kazumi Dialog Error: No Scaffold context available to show Toast');
    }
  }

  static Future<void> showLoading({
    BuildContext? context,
    String? msg,
  }) async {
    final ctx = context ?? observer.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        await showDialog(
          context: ctx,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Center(
              child: Card(
                elevation: 8.0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        msg ?? 'Loading...',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          routeSettings: const RouteSettings(name: 'KazumiDialog'),
        );
      } catch (e) {
        debugPrint('Kazumi Dialog Error: Failed to show loading dialog: $e');
      }
    } else {
      debugPrint(
          'Kazumi Dialog Error: No context available to show the loading dialog');
    }
  }

  static void dismiss() {
    if (observer.hasKazumiDialog && observer.kazumiDialogContext != null) {
      try {
        Navigator.of(observer.kazumiDialogContext!).pop();
      } catch (e) {
        debugPrint('Kazumi Dialog Error: Failed to dismiss dialog: $e');
      }
    } else {
      debugPrint('Kazumi Dialog Debug: No active KazumiDialog to dismiss');
    }
  }
}

/// Navigator observer to track contexts and dialog routes
class KazumiDialogObserver extends NavigatorObserver {
  /// List of active dialog routes
  final List<Route<dynamic>> _kazumiDialogRoutes = [];

  /// The most recent context from any MaterialPageRoute or PopupRoute
  BuildContext? _currentContext;

  /// The most recent context from any route containing a Scaffold
  BuildContext? _scaffoldContext;

  BuildContext? get currentContext => _currentContext;

  BuildContext? get scaffoldContext => _scaffoldContext ?? _currentContext;

  bool get hasKazumiDialog => _kazumiDialogRoutes.isNotEmpty;

  BuildContext? get kazumiDialogContext => _kazumiDialogRoutes.isNotEmpty
      ? _kazumiDialogRoutes.last.navigator?.context
      : null;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    /// workaround for #533
    /// we can't remove snackbar when push a new route
    /// otherwise, framework will throw an exception, and can't be caught
    /// need other way to remove snackbar here
    // _removeCurrentSnackBar(previousRoute);
    if (_isKazumiDialogRoute(route)) {
      _kazumiDialogRoutes.add(route);
    }
    if (route.navigator?.context != null) {
      _updateContexts(route.navigator!.context, route);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _removeCurrentSnackBar(route);
    if (_isKazumiDialogRoute(route)) {
      _kazumiDialogRoutes.remove(route);
    }
    if (previousRoute?.navigator?.context != null) {
      _updateContexts(previousRoute!.navigator!.context, previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (_isKazumiDialogRoute(oldRoute!)) {
      _kazumiDialogRoutes.remove(oldRoute);
    }
    if (_isKazumiDialogRoute(newRoute!)) {
      _kazumiDialogRoutes.add(newRoute);
    }
    if (newRoute.navigator?.context != null) {
      _updateContexts(newRoute.navigator!.context, newRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);

    if (_isKazumiDialogRoute(route)) {
      _kazumiDialogRoutes.remove(route);
    }

    if (previousRoute?.navigator?.context != null) {
      _updateContexts(previousRoute!.navigator!.context, previousRoute);
    }
  }

  void _updateContexts(BuildContext context, Route<dynamic> route) {
    _currentContext = context;
    if (_hasScaffold(context)) {
      _scaffoldContext = context;
    }
  }

  bool _hasScaffold(BuildContext context) {
    return Scaffold.maybeOf(context) != null;
  }

  bool _isKazumiDialogRoute(Route<dynamic> route) {
    return route.settings.name == 'KazumiDialog';
  }

  void _removeCurrentSnackBar(Route<dynamic>? route) {
    if (route?.navigator?.context != null) {
      try {
        ScaffoldMessenger.maybeOf(route!.navigator!.context)
            ?.removeCurrentSnackBar();
      } catch (_) {}
    }
  }
}
