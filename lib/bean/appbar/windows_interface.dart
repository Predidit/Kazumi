import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

enum CustomTitleBarHoveredButton {
  none(0),
  minimize(1),
  maximize(2),
  close(3);

  const CustomTitleBarHoveredButton(this.value);
  final int value;

  static CustomTitleBarHoveredButton fromValue(dynamic value) {
    final int v = value is int ? value : 0;
    for (final button in CustomTitleBarHoveredButton.values) {
      if (button.value == v) {
        return button;
      }
    }
    return CustomTitleBarHoveredButton.none;
  }
}

enum WindowsTitleButtonEventType {
  hover,
  down,
  up,
  click,
}

class WindowsTitleButtonEvent {
  const WindowsTitleButtonEvent({
    required this.type,
    required this.button,
  });

  final WindowsTitleButtonEventType type;
  final CustomTitleBarHoveredButton button;
}

class WindowsInterface {
  WindowsInterface._();

  static final WindowsInterface instance = WindowsInterface._();
  static const MethodChannel _channel =
      MethodChannel('com.predidit.kazumi/windows_interface');

  final StreamController<WindowsTitleButtonEvent> _eventController =
      StreamController<WindowsTitleButtonEvent>.broadcast();
  bool _initialized = false;

  Stream<WindowsTitleButtonEvent> get events => _eventController.stream;

  Future<void> ensureInitialized() async {
    if (!Platform.isWindows || _initialized) {
      return;
    }
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> setWindowsTitleHeight(int height) async {
    if (!Platform.isWindows) {
      return;
    }
    await _channel.invokeMethod('setWindowsTitleHeight', height);
  }

  Future<void> setWindowsTitleButtonWidth(int width) async {
    if (!Platform.isWindows) {
      return;
    }
    await _channel.invokeMethod('setWindowsTitleButtonWidth', width);
  }

  Future<void> setWindowsTitleTopInset(int inset) async {
    if (!Platform.isWindows) {
      return;
    }
    await _channel.invokeMethod('setWindowsTitleTopInset', inset);
  }

  Future<void> setWindowsTitleBarEnabled(bool enabled) async {
    if (!Platform.isWindows) {
      return;
    }
    await _channel.invokeMethod('setWindowsTitleBarEnabled', enabled);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    final CustomTitleBarHoveredButton button =
        CustomTitleBarHoveredButton.fromValue(call.arguments);
    switch (call.method) {
      case 'onTitleButtonHover':
        _eventController.add(WindowsTitleButtonEvent(
          type: WindowsTitleButtonEventType.hover,
          button: button,
        ));
        break;
      case 'onTitleButtonDown':
        _eventController.add(WindowsTitleButtonEvent(
          type: WindowsTitleButtonEventType.down,
          button: button,
        ));
        break;
      case 'onTitleButtonUp':
        _eventController.add(WindowsTitleButtonEvent(
          type: WindowsTitleButtonEventType.up,
          button: button,
        ));
        break;
      case 'onTitleButtonClick':
        _eventController.add(WindowsTitleButtonEvent(
          type: WindowsTitleButtonEventType.click,
          button: button,
        ));
        break;
      default:
        break;
    }
  }
}
