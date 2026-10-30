import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/logging/logger.dart';

/// The Flutter router owns navigation. UIKit owns only the adaptive bars.
class DuoNavigation {
  static const channel = MethodChannel('com.predidit.kazumi/duo_navigation');
  static final enabled = ValueNotifier(false);
  static Future<void>? _initialization;
  static bool _observingFrames = false;
  static final _headers = <Object, DuoHeaderRegistration>{};
  static DuoHeaderRegistration? _active;
  static DuoChrome? _chrome;
  static String? _lastChrome;
  static int _actionOwner = 0;
  static String? _lastTabs;
  static ValueChanged<int>? onTabSelected;

  static Future<void> initialize() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'select' && call.arguments is int) {
        onTabSelected?.call(call.arguments as int);
      } else if (call.method == 'chromeAction' && call.arguments is Map) {
        final args = call.arguments as Map;
        if (_active?.isActive == true && args['owner'] == _actionOwner) {
          _chrome?.callbacks[args['id']]?.call();
        }
      }
    });
    try {
      enabled.value = await channel.invokeMethod<bool>('enable') ?? false;
    } on MissingPluginException {
      // Older runners and unsupported devices retain Flutter's navigation.
    } on PlatformException catch (error) {
      KazumiLogger().e('Duo navigation unavailable', error: error);
    }
    if (enabled.value && !_observingFrames) {
      _observingFrames = true;
      // Publish registered action state after Flutter draws a frame. This
      // includes reactive controls without requesting an animation loop.
      WidgetsBinding.instance.addPersistentFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _flush());
      });
    }
  }

  static Future<void> setTabs({
    required int index,
    required bool visible,
    required bool dark,
    List<Map<String, Object?>>? icons,
    Map<String, Object?>? theme,
  }) async {
    if (!enabled.value) return;
    final args = {
      'index': index,
      'visible': visible,
      'dark': dark,
      'icons': ?icons,
      'theme': ?theme,
    };
    final encoded = jsonEncode(args);
    if (encoded == _lastTabs) return;
    _lastTabs = encoded;
    await _send('update', args);
  }

  static void register(Object key, DuoHeaderRegistration registration) {
    _headers[key] = registration;
  }

  static void unregister(Object key) {
    _headers.remove(key);
  }

  static void _flush() {
    if (!enabled.value) return;
    final candidates =
        _headers.values.where((header) => header.isActive).toList()
          ..sort((a, b) => b.depth.compareTo(a.depth));
    _active = candidates.firstOrNull;
    _chrome = _active?.snapshot();
    final payload = {
      'header': _active?.id ?? 0,
      'visible': _chrome != null && !_chrome!.hidden,
      'dark': _chrome?.dark ?? false,
      'theme': _chrome?.theme,
      'leading': _chrome?.leading,
      'actions': _chrome?.actions ?? [],
    };
    final encoded = jsonEncode(payload);
    if (encoded == _lastChrome) return;
    _lastChrome = encoded;
    payload.remove('header');
    payload['owner'] = ++_actionOwner;
    _send('chrome', payload);
  }

  static Future<void> _send(String method, Map<String, Object?> args) async {
    try {
      await channel.invokeMethod<void>(method, args);
    } on PlatformException catch (error) {
      KazumiLogger().e('Duo navigation $method failed', error: error);
    } on MissingPluginException {
      KazumiLogger().w('Duo navigation bridge disconnected');
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    enabled.value = false;
    _initialization = null;
    _headers.clear();
    _active = null;
    _chrome = null;
    _lastChrome = null;
    _actionOwner = 0;
    _lastTabs = null;
    onTabSelected = null;
    channel.setMethodCallHandler(null);
  }
}

class DuoHeaderRegistration {
  DuoHeaderRegistration({
    required this.id,
    required this.depth,
    required this.routes,
    required this.snapshot,
  });

  final int id;
  final int depth;
  final List<ModalRoute<dynamic>> routes;
  final DuoChrome Function() snapshot;

  bool get isActive => routes.every(
    (route) => route is PageRoute && route.isCurrent && route.isActive,
  );
}

class DuoChrome {
  DuoChrome({
    required this.dark,
    required this.theme,
    required this.hidden,
    this.leading,
    required this.actions,
    required this.callbacks,
  });

  final bool dark;
  final Map<String, Object?> theme;
  final bool hidden;
  final Map<String, Object?>? leading;
  final List<Map<String, Object?>> actions;
  final Map<String, VoidCallback> callbacks;
}
