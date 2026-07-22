import 'dart:io' as io;

export 'package:tray_manager/tray_manager.dart';
export 'package:window_manager/window_manager.dart';

class KazumiPlatform {
  KazumiPlatform._();

  static const bool isWeb = false;
  static bool get isAndroid => io.Platform.isAndroid;
  static bool get isIOS => io.Platform.isIOS;
  static bool get isWindows => io.Platform.isWindows;
  static bool get isMacOS => io.Platform.isMacOS;
  static bool get isLinux => io.Platform.isLinux;
  static Map<String, String> get environment => io.Platform.environment;
}

Never exitApplicationProcess([int code = 0]) => io.exit(code);
