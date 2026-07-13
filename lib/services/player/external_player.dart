import 'package:flutter/services.dart';
import 'package:kazumi/services/logging/logger.dart';

enum LinuxExternalPlayerResult {
  launched,
  cancelled,
  unavailable,
  failed,
}

class ExternalPlayer {
  ExternalPlayer._();

  static const _platform = MethodChannel('com.predidit.kazumi/intent');

  static Future<bool> launchUrlWithMime(String url, String mimeType) async {
    try {
      await _platform.invokeMethod(
          'openWithMime', <String, String>{'url': url, 'mimeType': mimeType});
      return true;
    } on PlatformException catch (e) {
      KazumiLogger().e("ExternalPlayer: failed to open with mime", error: e);
      return false;
    }
  }

  static Future<bool> launchUrlWithReferer(String url, String referer) async {
    try {
      await _platform.invokeMethod(
          'openWithReferer', <String, String>{'url': url, 'referer': referer});
      return true;
    } on PlatformException catch (e) {
      KazumiLogger().e("ExternalPlayer: failed to open with referer", error: e);
      return false;
    }
  }

  static Future<LinuxExternalPlayerResult> launchLinuxDesktopPlayer(
      String url) async {
    try {
      final result = await _platform.invokeMethod<String>(
        'openWithDesktopPlayer',
        <String, String>{'url': url},
      );
      return switch (result) {
        'launched' => LinuxExternalPlayerResult.launched,
        'cancelled' => LinuxExternalPlayerResult.cancelled,
        'unavailable' => LinuxExternalPlayerResult.unavailable,
        _ => LinuxExternalPlayerResult.failed,
      };
    } on PlatformException catch (e) {
      KazumiLogger().e(
        "ExternalPlayer: failed to open Linux desktop player",
        error: e,
      );
      return LinuxExternalPlayerResult.failed;
    }
  }
}
