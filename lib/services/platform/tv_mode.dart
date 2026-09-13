import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/logging/logger.dart';

/// Android TV capability, resolved before the widget tree is created.
class TvMode {
  TvMode._();

  static const _channel = MethodChannel('com.predidit.kazumi/intent');
  static bool _enabled = false;
  static bool get enabled => _enabled;

  static Future<void> initialize() async {
    _enabled = false;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      _enabled = await _channel.invokeMethod<bool>('isTelevision') ?? false;
    } on MissingPluginException {
      // An older platform implementation retains the existing layout policy.
    } on PlatformException catch (e) {
      KazumiLogger().e("Failed to detect Android TV: '${e.code}'.");
    }
  }
}
