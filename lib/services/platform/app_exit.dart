import 'dart:io';

import 'package:kazumi/services/platform/tray_service.dart';

class AppExit {
  AppExit._();

  static Future<Never> quit() async {
    try {
      await TrayService.dispose();
    } finally {
      exit(0);
    }
  }
}
