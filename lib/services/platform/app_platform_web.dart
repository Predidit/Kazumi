import 'package:flutter/material.dart';

class KazumiPlatform {
  KazumiPlatform._();

  static const bool isWeb = true;
  static const bool isAndroid = false;
  static const bool isIOS = false;
  static const bool isWindows = false;
  static const bool isMacOS = false;
  static const bool isLinux = false;
  static const Map<String, String> environment = <String, String>{};
}

Never exitApplicationProcess([int code = 0]) {
  throw UnsupportedError('A browser tab cannot terminate its host process');
}

enum TitleBarStyle { normal, hidden }

class WindowOptions {
  const WindowOptions({
    this.size,
    this.center,
    this.skipTaskbar,
    this.titleBarStyle,
    this.windowButtonVisibility,
    this.title,
  });

  final Size? size;
  final bool? center;
  final bool? skipTaskbar;
  final TitleBarStyle? titleBarStyle;
  final bool? windowButtonVisibility;
  final String? title;
}

mixin WindowListener {
  void onWindowClose() {}
  void onWindowRestore() {}
  void onWindowEnterFullScreen() {}
  void onWindowLeaveFullScreen() {}
}

class _WebWindowManager {
  void addListener(WindowListener listener) {}
  void removeListener(WindowListener listener) {}
  Future<void> ensureInitialized() async {}
  Future<void> setMinimumSize(Size size) async {}
  Future<void> setPreventClose(bool value) async {}
  Future<void> setBrightness(Brightness brightness) async {}
  Future<void> show() async {}
  Future<void> hide() async {}
  Future<void> focus() async {}

  void waitUntilReadyToShow(
    WindowOptions? options,
    Future<void> Function() callback,
  ) {
    callback();
  }
}

final windowManager = _WebWindowManager();

mixin TrayListener {
  void onTrayIconMouseDown() {}
  void onTrayIconRightMouseDown() {}
  void onTrayMenuItemClick(MenuItem menuItem) {}
}

class TrayManager {
  TrayManager._();

  static final TrayManager instance = TrayManager._();

  void addListener(TrayListener listener) {}
  void removeListener(TrayListener listener) {}
  Future<void> setIcon(String path) async {}
  Future<void> setToolTip(String value) async {}
  Future<void> setContextMenu(Menu menu) async {}
  Future<void> popUpContextMenu() async {}
}

class Menu {
  Menu({required this.items});
  final List<MenuItem> items;
}

class MenuItem {
  MenuItem({this.key, this.label});
  MenuItem.separator()
      : key = null,
        label = null;

  final String? key;
  final String? label;
}
