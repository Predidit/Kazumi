import 'dart:io';

import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/device.dart';
import 'package:tray_manager/tray_manager.dart';

typedef AppExitCallback = void Function(int code);
typedef TrayIconDisposer = Future<void> Function();

/// Terminates the process after removing the tray icon.
///
/// `exit()` ends the process before the plugin can answer `WM_DESTROY`, so a
/// tray icon left registered stays in the notification area until the pointer
/// passes over it. Removing the icon first keeps that cleanup explicit.
class AppExit {
  AppExit({
    TrayIconDisposer? disposeTray,
    AppExitCallback? exitProcess,
  })  : _disposeTray = disposeTray ?? _removeTrayIcon,
        _exitProcess = exitProcess ?? exit;

  static final AppExit instance = AppExit();

  final TrayIconDisposer _disposeTray;
  final AppExitCallback _exitProcess;

  Future<void> quit({int code = 0}) async {
    try {
      await _disposeTray();
    } catch (e, stackTrace) {
      KazumiLogger().w('AppExit: failed to remove the tray icon',
          error: e, stackTrace: stackTrace);
    }
    _exitProcess(code);
  }

  static Future<void> _removeTrayIcon() async {
    if (!isDesktop()) return;
    await TrayManager.instance.destroy();
  }
}
