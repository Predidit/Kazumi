import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class PlayerMenuService {
  PlayerMenuService._();

  static const _appMenuChannel = MethodChannel('com.predidit.kazumi/appmenu');

  static Future<void> dispose() async {
    if (!Platform.isMacOS) return;
    _appMenuChannel.setMethodCallHandler(null);
    await _appMenuChannel.invokeMethod('setMenuEnabled', {
      'menu': 'PlayerMenu',
      'enable': false,
    });
  }

  static Future<void> initialize(
    Map<String, FutureOr<void> Function()> actions,
  ) async {
    if (!Platform.isMacOS) return;
    await _appMenuChannel.invokeMethod('setMenuEnabled', {
      'menu': 'PlayerMenu',
      'enable': true,
    });
    _appMenuChannel.setMethodCallHandler((call) async {
      final action = actions[call.method];
      await action?.call();
    });
  }
}
