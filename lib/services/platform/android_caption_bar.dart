import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidCaptionBar {
  static const MethodChannel _channel =
      MethodChannel('com.predidit.kazumi/caption_bar');

  static final ValueNotifier<double> topInset = ValueNotifier<double>(0);

  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized || !Platform.isAndroid) {
      return;
    }
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCaptionBarTopInsetChanged') {
        final Object? value = call.arguments is Map
            ? (call.arguments as Map)['topInset']
            : call.arguments;
        _setTopInset(value);
      }
    });
    refresh();
  }

  static Future<void> refresh() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      final double inset =
          (await _channel.invokeMethod<num>('getCaptionBarTopInset'))
                  ?.toDouble() ??
              0;
      _setTopInset(inset);
    } catch (_) {
      _setTopInset(0);
    }
  }

  static void _setTopInset(Object? value) {
    final double inset = value is num ? value.toDouble() : 0;
    if (topInset.value == inset) {
      return;
    }
    topInset.value = inset;
  }
}
