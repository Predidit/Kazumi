import 'package:flutter/material.dart';

// A simple dialog helper class to show dialogs and toasts based on flutter native implementation (replace flutter_smart_dialog)
// flutter_smart_dialog use overlays and self-managed route stack to show dialogs.
// It's powerful but can't behave like the default showDialog, e.g. the lack of mask animation. the lack of snackbar.
// Use the implementation should be careful, because shared route stack with the whole app, it may cause some unexpected behaviors.
// Don't use it in double PopScope widget.
class KazumiDialog {
  static final KazumiDialogObserver _observer =
      KazumiDialogObserver._internal();

  static KazumiDialogObserver get observer => _observer;

  KazumiDialog._internal();

  static Future<void> show({
    BuildContext? context,
    bool? clickMaskDismiss,
    VoidCallback? onDismiss,
    required WidgetBuilder builder,
  }) async {
    context ??= _observer.currentContext;
    if (context != null) {
      await showDialog(
        context: context,
        barrierDismissible: clickMaskDismiss ?? true,
        builder: builder,
        routeSettings: const RouteSettings(name: 'KazumiDialog'),
      );
      onDismiss?.call();
    } else {
      debugPrint(
          'Kazumi Dialog Error: No context available to show the dialog');
    }
  }

  static void showToast({
    required String message,
    BuildContext? context,
    bool showUndoButton = false,
    Duration duration = const Duration(seconds: 2),
  }) {
    final scaffoldContext = context ?? _observer.currentContext;
    if (scaffoldContext != null) {
      ScaffoldMessenger.of(scaffoldContext)
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
    } else {
      debugPrint(
          'Kazumi Dialog Error: No Scaffold context available to show Toast');
    }
  }

  static Future<void> showLoading({
    BuildContext? context,
    String? msg,
  }) async {
    context ??= _observer.currentContext;
    if (context != null) {
      await showDialog(
        context: context,
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
    } else {
      debugPrint(
          'Kazumi Dialog Error: No context available to show the loading dialog');
    }
  }

  static void dismiss() {
    if (_observer.hasKazumiDialog) {
      Navigator.of(_observer.kazumiDialogContext!).pop();
    } else {
      debugPrint('Kazumi Dialog Error: No KazumiDialog to dismiss');
    }
  }
}

class KazumiDialogObserver extends NavigatorObserver {
  static final KazumiDialogObserver observer = KazumiDialogObserver._internal();

  factory KazumiDialogObserver() {
    return observer;
  }

  KazumiDialogObserver._internal();

  final List<Route<dynamic>> _kazumiDialogRoutes = [];
  BuildContext? currentContext;

  bool get hasKazumiDialog => _kazumiDialogRoutes.isNotEmpty;
  BuildContext? get kazumiDialogContext => _kazumiDialogRoutes.isNotEmpty
      ? _kazumiDialogRoutes.last.navigator?.context
      : null;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _removeCurrentSnackBar(previousRoute);
    if (_isKazumiDialogRoute(route)) {
      _kazumiDialogRoutes.add(route);
      currentContext = route.navigator?.context;
    } else if (route is MaterialPageRoute || route is PopupRoute) {
      currentContext = route.navigator?.context;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _removeCurrentSnackBar(route);
    if (_isKazumiDialogRoute(route)) {
      _kazumiDialogRoutes.remove(route);
    }
    if (_kazumiDialogRoutes.isNotEmpty) {
      currentContext = _kazumiDialogRoutes.last.navigator?.context;
    } else if (previousRoute is MaterialPageRoute ||
        previousRoute is PopupRoute) {
      currentContext = previousRoute?.navigator?.context;
    } else {
      currentContext = null;
    }
  }

  bool _isKazumiDialogRoute(Route<dynamic> route) {
    return route.settings.name == 'KazumiDialog';
  }

  void _removeCurrentSnackBar(Route<dynamic>? route) {
    if (route?.navigator?.context != null) {
      ScaffoldMessenger.of(route!.navigator!.context).removeCurrentSnackBar();
    }
  }
}
