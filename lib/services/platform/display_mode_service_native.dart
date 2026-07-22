import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/platform/platform_environment_service.dart';
import 'package:kazumi/utils/device.dart';
import 'package:window_manager/window_manager.dart';

class DisplayModeService {
  DisplayModeService._();

  static const _intentChannel = MethodChannel('com.predidit.kazumi/intent');

  static Future<void> enterFullScreen({bool lockOrientation = true}) async {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      await windowManager.setFullScreen(true);
      return;
    }
    if (Platform.isAndroid) {
      await _intentChannel.invokeMethod('enterFullscreen');
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (!lockOrientation) return;
    if (Platform.isAndroid &&
        await PlatformEnvironmentService.isInMultiWindowMode()) {
      return;
    }
    await landscape();
  }

  static Future<void> exitFullScreen({bool lockOrientation = true}) async {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      await windowManager.setFullScreen(false);
    }
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        if (Platform.isAndroid) {
          await _intentChannel.invokeMethod('exitFullscreen');
        } else {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
        if (isCompact() && lockOrientation) {
          if (Platform.isAndroid &&
              await PlatformEnvironmentService.isInMultiWindowMode()) {
            return;
          }
          await verticalScreen();
        }
      }
    } catch (error, stackTrace) {
      KazumiLogger().e(
        'Display: failed to exit full screen',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> landscape() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } catch (error, stackTrace) {
      KazumiLogger().e(
        'Display: failed to enter landscape mode',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> verticalScreen() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  static Future<void> unlockScreenRotation() async {
    await SystemChrome.setPreferredOrientations(const []);
  }
}
