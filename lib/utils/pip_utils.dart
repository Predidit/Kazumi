import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:window_manager/window_manager.dart';

class PipUtils {
  static bool androidPIPInited = false;

  static Future<bool> isAndroidPIPSupported() async {
    if (!Platform.isAndroid) {
      return false;
    }
    const pipChannel = MethodChannel('com.predidit.kazumi/pip');
    try {
      final bool? supported =
          await pipChannel.invokeMethod('isPictureInPictureSupported');
      return supported ?? false;
    } on PlatformException catch (e) {
      KazumiLogger().e("Failed to check Android PIP support: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> enterAndroidPIPWindow(
      {int width = 16, int height = 9}) async {
    if (!Platform.isAndroid) {
      return false;
    }
    const pipChannel = MethodChannel('com.predidit.kazumi/pip');
    try {
      final bool? entered =
          await pipChannel.invokeMethod('enterPictureInPictureMode', {
        'width': width,
        'height': height,
      });
      return entered ?? false;
    } on PlatformException catch (e) {
      KazumiLogger().e("Failed to enter Android PIP mode: '${e.message}'.");
      return false;
    }
  }

  static Future<void> updateAndroidPIPActions({
    required bool playing,
    required bool danmakuEnabled,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    const pipChannel = MethodChannel('com.predidit.kazumi/pip');
    try {
      await pipChannel.invokeMethod('updatePictureInPictureActions', {
        'playing': playing,
        'danmakuEnabled': danmakuEnabled,
      });
    } on PlatformException catch (e) {
      KazumiLogger().e("Failed to update Android PIP actions: '${e.message}'.");
    }
  }

  static Future<void> setAndroidAutoEnterPIPEnabled(bool enabled) async {
    if (!Platform.isAndroid) {
      return;
    }
    const pipChannel = MethodChannel('com.predidit.kazumi/pip');
    try {
      await pipChannel.invokeMethod('setAndroidAutoEnterPIPEnabled', {
        'enabled': enabled,
      });
    } on PlatformException catch (e) {
      KazumiLogger().e(
          "Failed to set Android auto-enter PIP enabled state: '${e.message}'.");
    }
  }

  static Future<void> setAndroidPIPInPlayerPage(bool inPlayerPage) async {
    if (!Platform.isAndroid) {
      return;
    }
    const pipChannel = MethodChannel('com.predidit.kazumi/pip');
    try {
      await pipChannel.invokeMethod('setAndroidPIPInPlayerPage', {
        'inPlayerPage': inPlayerPage,
      });
    } on PlatformException catch (e) {
      KazumiLogger().e("Failed to set Android PIP page state: '${e.message}'.");
    }
  }

  // 进入桌面设备小窗模式
  static Future<void> enterDesktopPIPWindow() async {
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSize(const Size(480, 270));
  }

  // 退出桌面设备小窗模式
  static Future<void> exitDesktopPIPWindow() async {
    bool isLowResolution = await Utils.isLowResolution();
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSize(
        isLowResolution ? const Size(800, 600) : const Size(1280, 860));
    await windowManager.center();
  }

  static void initPipHandler({
    required Future<void> Function(String action) onAction,
  }) {
    const MethodChannel pipChannel = MethodChannel('com.predidit.kazumi/pip');
    if (androidPIPInited) return;
    androidPIPInited = true;

    pipChannel.setMethodCallHandler((call) async {
      if (!Platform.isAndroid || call.method != 'onAction') {
        return;
      }

      final args = call.arguments;
      final String? action =
          (args is Map) ? args['action'] as String? : null;

      if (action != null) {
        await onAction(action);
      }
    });
  }

  static void disposePipHandler() {
    const MethodChannel pipChannel = MethodChannel('com.predidit.kazumi/pip');
    pipChannel.setMethodCallHandler(null);
    androidPIPInited = false;
  }
}
