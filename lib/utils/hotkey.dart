import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class KazumiHotKey {
  static final HotKey videoVolumeUp =
      HotKey(key: PhysicalKeyboardKey.arrowUp, scope: HotKeyScope.inapp);

  static final HotKey videoVolumeDown =
      HotKey(key: PhysicalKeyboardKey.arrowDown, scope: HotKeyScope.inapp);

  static final HotKey videoDecrease =
      HotKey(key: PhysicalKeyboardKey.arrowLeft, scope: HotKeyScope.inapp);

  static final HotKey videoIncrease =
      HotKey(key: PhysicalKeyboardKey.arrowRight, scope: HotKeyScope.inapp);

  static final HotKey videoPause =
      HotKey(key: PhysicalKeyboardKey.space, scope: HotKeyScope.inapp);

  static final HotKey videoEscape =
      HotKey(key: PhysicalKeyboardKey.escape, scope: HotKeyScope.inapp);

  static final HotKey videoFullscreen =
      HotKey(key: PhysicalKeyboardKey.keyF, scope: HotKeyScope.inapp);

  static final HotKey videoDanmaku =
      HotKey(key: PhysicalKeyboardKey.keyD, scope: HotKeyScope.inapp);

  static final HotKey appMinimize = HotKey(
      key: PhysicalKeyboardKey.keyH,
      modifiers: [HotKeyModifier.shift],
      scope: HotKeyScope.inapp);
}
