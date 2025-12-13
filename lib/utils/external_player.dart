import 'package:flutter/services.dart';
import 'package:kazumi/utils/logger.dart';

class ExternalPlayer {
  // 注意：仍需开发 iOS/Linux 设备的外部播放功能。
  // 在 Windows 设备上，对于其他可能的实现，使用 scheme 的方案没有效果。VLC / PotPlayer 等主流播放器更倾向于使用 CLI 命令。
  // 可行的 iOS 处理代码，请参见 ios/Runner/AppDelegate.swift 的注释部分。
  static const platform = MethodChannel('com.predidit.kazumi/intent');

  static Future<bool> launchURLWithMIME(String url, String mimeType) async {
    try {
      await platform.invokeMethod(
          'openWithMime', <String, String>{'url': url, 'mimeType': mimeType});
      return true;
    } on PlatformException catch (e) {
      KazumiLogger()
          .e("ExternalPlayer: failed to open with mime", error: e);
      return false;
    }
  }

  static Future<bool> launchURLWithReferer(String url, String referer) async {
    try {
      await platform.invokeMethod(
          'openWithReferer', <String, String>{'url': url, 'referer': referer});
      return true;
    } on PlatformException catch (e) {
      KazumiLogger()
          .e("ExternalPlayer: failed to open with referer", error: e);
      return false;
    }
  }
}
