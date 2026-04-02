import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WindowsShortcut {
  static const _channel = MethodChannel('com.predidit.kazumi/shortcut');

  static Future<bool> createDesktopShortcut() async {
    if (!Platform.isWindows) return false;
    try {
      return await _channel.invokeMethod<bool>('createDesktopShortcut') ?? false;
    } catch (e) {
      debugPrint('Failed to create desktop shortcut: $e');
      return false;
    }
  }
}