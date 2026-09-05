import 'package:flutter/material.dart';

import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/utils/constants.dart';

class KazumiDialog {
  static final KazumiDialogObserver observer = KazumiDialogObserver();

  KazumiDialog._internal();

  static Future<T?> show<T>({
    BuildContext? context,
    bool? clickMaskDismiss,
    VoidCallback? onDismiss,
    required WidgetBuilder builder,
  }) async {
    final ctx =
        context ?? rootNavigatorKey.currentContext ?? observer.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        final result = await showDialog<T>(
          context: ctx,
          useRootNavigator: true,
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
    bool showActionButton = false,
    String? actionLabel,
    Function()? onActionPressed,
    Duration duration = const Duration(seconds: 2),
  }) {
    final messenger = _resolveScaffoldMessenger(context);
    final toastContext = _resolveToastContext(context);
    if (messenger != null && toastContext != null && toastContext.mounted) {
      try {
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
                        onActionPressed?.call();
                        messenger.hideCurrentSnackBar();
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

  static Future<void> showLoading({
    BuildContext? context,
    String? msg,
    bool barrierDismissible = false,
    Function()? onDismiss,
  }) async {
    final ctx =
        context ?? rootNavigatorKey.currentContext ?? observer.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        await showDialog(
          context: ctx,
          useRootNavigator: true,
          barrierDismissible: barrierDismissible,
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
                      const LoadingIndicator(),
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
        onDismiss?.call();
      } catch (e) {
        debugPrint('Kazumi Dialog Error: Failed to show loading dialog: $e');
      }
    } else {
      debugPrint(
          'Kazumi Dialog Error: No context available to show the loading dialog');
    }
  }

  static void dismiss<T>({T? popWith}) {
    if (observer.hasKazumiDialog && observer.kazumiDialogContext != null) {
      try {
        Navigator.of(observer.kazumiDialogContext!).pop(popWith);
      } catch (e) {
        debugPrint('Kazumi Dialog Error: Failed to dismiss dialog: $e');
      }
    } else {
      debugPrint('Kazumi Dialog Debug: No active KazumiDialog to dismiss');
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

  static BuildContext? _resolveToastContext(BuildContext? context) {
    if (context != null && context.mounted) {
      return context;
    }
    final messengerContext = rootScaffoldMessengerKey.currentContext;
    if (messengerContext != null && messengerContext.mounted) {
      return messengerContext;
    }
    return observer.scaffoldContext;
  }
}

class KazumiDialogObserver extends NavigatorObserver {
  final List<Route<dynamic>> _kazumiDialogRoutes = [];
  bool _snackBarClearScheduled = false;

  BuildContext? _currentContext;

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
    if (_isKazumiDialogRoute(route)) {
      _kazumiDialogRoutes.add(route);
    }
    if (route.navigator?.context != null) {
      _updateContexts(route.navigator!.context);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _scheduleSnackBarClear();
    if (_isKazumiDialogRoute(route)) {
      _kazumiDialogRoutes.remove(route);
    }
    if (previousRoute?.navigator?.context != null) {
      _updateContexts(previousRoute!.navigator!.context);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _scheduleSnackBarClear();
    if (_isKazumiDialogRoute(oldRoute)) {
      _kazumiDialogRoutes.remove(oldRoute);
    }
    if (newRoute != null && _isKazumiDialogRoute(newRoute)) {
      _kazumiDialogRoutes.add(newRoute);
    }
    final context = newRoute?.navigator?.context;
    if (context != null) {
      _updateContexts(context);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _scheduleSnackBarClear();

    if (_isKazumiDialogRoute(route)) {
      _kazumiDialogRoutes.remove(route);
    }

    if (previousRoute?.navigator?.context != null) {
      _updateContexts(previousRoute!.navigator!.context);
    }
  }

  void _updateContexts(BuildContext context) {
    _currentContext = context;
    if (Scaffold.maybeOf(context) != null) {
      _scaffoldContext = context;
    }
  }

  bool _isKazumiDialogRoute(Route<dynamic>? route) =>
      route?.settings.name == 'KazumiDialog';

  void _scheduleSnackBarClear() {
    if (_snackBarClearScheduled) return;
    _snackBarClearScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snackBarClearScheduled = false;
      // Defer snackbar removal until Navigator finishes reconciling routes.
      rootScaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    });
  }
}
