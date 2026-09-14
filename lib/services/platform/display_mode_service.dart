import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:window_manager/window_manager.dart';

class DisplayModeService {
  DisplayModeService._();

  static const _intentChannel = MethodChannel('com.predidit.kazumi/intent');
  static Future<void> _pendingFullscreen = Future.value();
  static Future<void>? _pendingSystemBars;
  static Object? _systemBarsOwner;
  static bool _systemBarsHidden = false;

  static Future<void> applyVideoFullscreen(bool fullscreen) {
    return _pendingFullscreen = _pendingFullscreen.then((_) async {
      if (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows) {
        await _attempt(() => windowManager.setFullScreen(fullscreen));
        return;
      }

      // Restore system orientation on exit, including an existing landscape.
      await _attempt(() => SystemChrome.setPreferredOrientations(
            fullscreen
                ? [
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight
                  ]
                : [],
          ));
    });
  }

  /// Outgoing pages cannot release chrome owned by the next visible page.
  static Future<void> setSystemBarsHidden({
    required Object owner,
    required bool hidden,
  }) {
    _systemBarsOwner = owner;
    return _setSystemBarsHidden(hidden);
  }

  static Future<void> releaseSystemBars(Object owner) {
    if (!identical(_systemBarsOwner, owner)) {
      return _pendingSystemBars ?? Future.value();
    }
    _systemBarsOwner = null;
    return _setSystemBarsHidden(false);
  }

  static Future<void> _setSystemBarsHidden(bool hidden) {
    if (_systemBarsHidden == hidden) {
      return _pendingSystemBars ?? Future.value();
    }
    _systemBarsHidden = hidden;
    // Rotation acknowledgements must not delay immersion or route cleanup.
    late final Future<void> request;
    request = (_pendingSystemBars ?? Future<void>.value())
        .then((_) => _attempt(() async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                await _intentChannel.invokeMethod(
                    'setSystemBarsHidden', hidden);
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                await SystemChrome.setEnabledSystemUIMode(
                  hidden
                      ? SystemUiMode.immersiveSticky
                      : SystemUiMode.edgeToEdge,
                );
              }
            }))
        .whenComplete(() {
      if (identical(_pendingSystemBars, request)) _pendingSystemBars = null;
    });
    return _pendingSystemBars = request;
  }

  static Future<void> _attempt(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error, stackTrace) {
      KazumiLogger().e('Display: failed to apply video display mode',
          error: error, stackTrace: stackTrace);
    }
  }
}
