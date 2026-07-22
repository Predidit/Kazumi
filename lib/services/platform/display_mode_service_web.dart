import 'dart:js_interop';

import 'package:kazumi/services/logging/logger.dart';
import 'package:web/web.dart' as web;

class DisplayModeService {
  DisplayModeService._();

  /// Apple mobile WebKit remains in CSS fullscreen so the inline video and
  /// danmaku overlay stay in the same rendering tree.
  static Future<void> enterFullScreen({bool lockOrientation = true}) async {
    if (_prefersInlineFullscreen()) return;
    final root = web.document.documentElement;
    if (root == null || web.document.fullscreenElement != null) return;
    try {
      await root.requestFullscreen().toDart;
    } catch (error, stackTrace) {
      // The controller can still commit its CSS fullscreen state if browser
      // fullscreen is unavailable or the transient user activation expired.
      KazumiLogger().w(
        'Display: browser fullscreen denied; using inline layout',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> exitFullScreen({bool lockOrientation = true}) async {
    if (_prefersInlineFullscreen() || web.document.fullscreenElement == null) {
      return;
    }
    try {
      await web.document.exitFullscreen().toDart;
    } catch (error, stackTrace) {
      KazumiLogger().w(
        'Display: browser fullscreen exit failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> landscape() async {}

  static Future<void> verticalScreen() async {}

  static Future<void> unlockScreenRotation() async {}

  static bool _prefersInlineFullscreen() {
    final navigator = web.window.navigator;
    final userAgent = navigator.userAgent;
    return RegExp(
          r'\b(?:iPhone|iPad|iPod)\b',
          caseSensitive: false,
        ).hasMatch(userAgent) ||
        (userAgent.contains('Macintosh') && navigator.maxTouchPoints > 1);
  }
}
