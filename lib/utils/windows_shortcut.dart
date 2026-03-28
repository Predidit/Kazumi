import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Windows desktop shortcut utility using MethodChannel
class WindowsShortcut {
  static const MethodChannel _channel = MethodChannel('com.predidit.kazumi/shortcut');

  /// Create a desktop shortcut for the application
  static Future<bool> createDesktopShortcut({
    String shortcutName = 'Kazumi',
    String description = 'Kazumi - Anime Player',
  }) async {
    if (!Platform.isWindows) return false;

    try {
      final result = await _channel.invokeMethod<bool>('createDesktopShortcut', {
        'shortcutName': shortcutName,
        'description': description,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to create desktop shortcut: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Failed to create desktop shortcut: $e');
      return false;
    }
  }
}