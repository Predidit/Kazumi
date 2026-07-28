import 'dart:io';
import 'package:flutter/services.dart';
import 'package:kazumi/services/logging/logger.dart';

class WindowsShortcut {
  static const _channel = MethodChannel('com.predidit.kazumi/shortcut');

  static Future<bool> createDesktopShortcut() async {
    if (!Platform.isWindows) return false;
    try {
      return await _channel.invokeMethod<bool>('createDesktopShortcut') ??
          false;
    } catch (e) {
      KazumiLogger().e('Failed to create desktop shortcut', error: e);
      return false;
    }
  }
}
