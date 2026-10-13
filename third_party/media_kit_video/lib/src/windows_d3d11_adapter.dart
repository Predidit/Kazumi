import 'dart:async';

import 'package:flutter/services.dart';

/// A renderer error reported by the native Windows video output.
class WindowsVideoOutputError {
  const WindowsVideoOutputError({
    required this.playerHandle,
    required this.message,
  });

  final int playerHandle;
  final String message;
}

/// A hardware adapter available to the Windows D3D11 video renderer.
class WindowsD3D11Adapter {
  const WindowsD3D11Adapter({
    required this.id,
    required this.name,
    required this.dedicatedVideoMemoryMb,
  });

  factory WindowsD3D11Adapter.fromMap(Map<String, dynamic> value) {
    return WindowsD3D11Adapter(
      id: value['id'] as String,
      name: value['name'] as String,
      dedicatedVideoMemoryMb: (value['dedicatedVideoMemoryMb'] as num).toInt(),
    );
  }

  final String id;
  final String name;
  final int dedicatedVideoMemoryMb;

  String get displayName =>
      dedicatedVideoMemoryMb > 0 ? '$name ($dedicatedVideoMemoryMb MB)' : name;
}

/// Windows-specific adapter discovery for the native video renderer.
class MediaKitVideo {
  static const MethodChannel _channel = MethodChannel(
    'com.alexmercerind/media_kit_video',
  );
  static final StreamController<WindowsVideoOutputError> _videoOutputErrors =
      StreamController<WindowsVideoOutputError>.broadcast();

  static Stream<WindowsVideoOutputError> get windowsVideoOutputErrors =>
      _videoOutputErrors.stream;

  static void reportWindowsVideoOutputError(Object? arguments) {
    final values = Map<String, dynamic>.from(arguments as Map);
    _videoOutputErrors.add(
      WindowsVideoOutputError(
        playerHandle: values['handle'] as int,
        message: values['message'] as String,
      ),
    );
  }

  static Future<List<WindowsD3D11Adapter>> getWindowsD3D11Adapters() async {
    final adapters = await _channel.invokeMethod<List<dynamic>>(
      'Utils.GetD3D11Adapters',
    );
    return [
      for (final value in adapters ?? const [])
        WindowsD3D11Adapter.fromMap(Map<String, dynamic>.from(value as Map)),
    ];
  }
}
