import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/platform/window_state_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/utils/device.dart';

class PipUtils {
  static bool androidPIPInited = false;
  // 协调桌面小窗的比例更新
  static bool _desktopPipAspectUpdatesEnabled = false;
  static Future<void> _desktopPipAspectTail = Future<void>.value();

  // 比例约分
  static Size getPIPAspectSize({required int width, required int height}) {
    if (width <= 0 || height <= 0) {
      return const Size(16, 9);
    }
    final int divisor = width.gcd(height);
    return Size(width / divisor, height / divisor);
  }

  static Future<bool> isAndroidPIPSupported() async {
    if (!Platform.isAndroid) {
      return false;
    }
    const pipChannel = MethodChannel('com.predidit.kazumi/pip');
    try {
      final bool? supported =
          await pipChannel.invokeMethod('isPictureInPictureSupported');
      return supported ?? false;
    } on PlatformException catch (e) {
      KazumiLogger().e("Failed to check Android PIP support: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> enterAndroidPIPWindow(
      {int width = 16, int height = 9}) async {
    if (!Platform.isAndroid) {
      return false;
    }
    final Size aspectSize = getPIPAspectSize(width: width, height: height);
    const pipChannel = MethodChannel('com.predidit.kazumi/pip');
    try {
      final bool? entered =
          await pipChannel.invokeMethod('enterPictureInPictureMode', {
        'width': aspectSize.width.toInt(),
        'height': aspectSize.height.toInt(),
      });
      return entered ?? false;
    } on PlatformException catch (e) {
      KazumiLogger().e("Failed to enter Android PIP mode: '${e.message}'.");
      return false;
    }
  }

  static Future<void> updateAndroidPIPActions({
    required bool playing,
    required bool danmakuEnabled,
    int width = 16,
    int height = 9,
    Rect? sourceRect,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    final Size aspectSize = getPIPAspectSize(width: width, height: height);
    const pipChannel = MethodChannel('com.predidit.kazumi/pip');
    try {
      await pipChannel.invokeMethod('updatePictureInPictureActions', {
        'playing': playing,
        'danmakuEnabled': danmakuEnabled,
        'width': aspectSize.width.toInt(),
        'height': aspectSize.height.toInt(),
        if (sourceRect != null) ...{
          'sourceLeft': sourceRect.left.round(),
          'sourceTop': sourceRect.top.round(),
          'sourceRight': sourceRect.right.round(),
          'sourceBottom': sourceRect.bottom.round(),
        },
      });
    } on PlatformException catch (e) {
      KazumiLogger().e("Failed to update Android PIP actions: '${e.message}'.");
    }
  }

  static Future<void> setAndroidAutoEnterPIPEnabled(bool enabled) async {
    if (!Platform.isAndroid) {
      return;
    }
    const pipChannel = MethodChannel('com.predidit.kazumi/pip');
    try {
      await pipChannel.invokeMethod('setAndroidAutoEnterPIPEnabled', {
        'enabled': enabled,
      });
    } on PlatformException catch (e) {
      KazumiLogger().e(
          "Failed to set Android auto-enter PIP enabled state: '${e.message}'.");
    }
  }

  static Future<void> setAndroidPIPInPlayerPage(bool inPlayerPage) async {
    if (!Platform.isAndroid) {
      return;
    }
    const pipChannel = MethodChannel('com.predidit.kazumi/pip');
    try {
      await pipChannel.invokeMethod('setAndroidPIPInPlayerPage', {
        'inPlayerPage': inPlayerPage,
      });
    } on PlatformException catch (e) {
      KazumiLogger().e("Failed to set Android PIP page state: '${e.message}'.");
    }
  }

  // 进入桌面设备小窗模式，并用播放源比例固定窗口宽高比
  static Future<void> enterDesktopPIPWindow({
    int width = 16,
    int height = 9,
  }) async {
    if (Platform.isWindows) {
      // 快照采集后，按当前状态解除最大化
      await WindowStateService.instance.beginPip();
    }
    try {
      if (Platform.isWindows) {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        }
      }
      await windowManager.setAlwaysOnTop(true);
      _desktopPipAspectUpdatesEnabled = true;
      await updateDesktopPIPAspect(width: width, height: height);
    } catch (_) {
      _desktopPipAspectUpdatesEnabled = false;
      if (Platform.isWindows) {
        // 异常则尝试取消小窗模式并恢复状态
        await exitDesktopPIPWindow();
      }
      rethrow;
    }
  }

  /// 更新桌面设备小窗模式的比例和尺寸
  static Future<void> updateDesktopPIPAspect({int width = 16, int height = 9}) {
    if (!_desktopPipAspectUpdatesEnabled) {
      return Future<void>.value();
    }
    // 串行执行两个窗口命令，避免不同通知交错
    final update = _desktopPipAspectTail.then((_) async {
      if (!_desktopPipAspectUpdatesEnabled) {
        return;
      }
      final Size aspectSize = getPIPAspectSize(width: width, height: height);
      final double aspectRatio = aspectSize.width / aspectSize.height;
      const double pipWidth = 480;
      await windowManager.setAspectRatio(aspectRatio);
      // 退出可能在等待ratio命令时开始，不再发出设置小窗尺寸命令
      if (!_desktopPipAspectUpdatesEnabled) {
        return;
      }
      await windowManager.setSize(Size(pipWidth, pipWidth / aspectRatio));
    });
    // 用于退出等待，错误仍通过原Future交给调用方
    _desktopPipAspectTail = update.then<void>((_) {}, onError: (Object _) {});
    return update;
  }

  // 退出桌面设备小窗模式
  static Future<void> exitDesktopPIPWindow() async {
    // isPip可能最后清除，必须先拒绝新的尺寸通知
    _desktopPipAspectUpdatesEnabled = false;
    // 已发出的原生命令无法撤销，先等其返回，再解除比例锁并恢复布局
    await _desktopPipAspectTail;
    if (Platform.isWindows) {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setAspectRatio(0);
      await WindowStateService.instance.restoreAfterPip();
      return;
    }
    final defaultSize = await defaultDesktopWindowSize();
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setAspectRatio(0);
    await windowManager.setSize(defaultSize);
    await windowManager.center();
  }

  static void initPipHandler({
    required Future<void> Function(String action) onAction,
    required void Function(bool inPipMode) onModeChanged,
  }) {
    const MethodChannel pipChannel = MethodChannel('com.predidit.kazumi/pip');
    if (androidPIPInited) return;
    androidPIPInited = true;

    pipChannel.setMethodCallHandler((call) async {
      if (!Platform.isAndroid) {
        return;
      }

      final Object? args = call.arguments;
      final Map? arguments = (args is Map) ? args : null;

      switch (call.method) {
        case 'onModeChanged':
          final bool? inPipMode = arguments?['isInPipMode'] as bool?;
          if (inPipMode != null) {
            onModeChanged(inPipMode);
          }
        case 'onAction':
          final String? action = arguments?['action'] as String?;
          if (action != null) {
            await onAction(action);
          }
      }
    });
  }

  static void disposePipHandler() {
    const MethodChannel pipChannel = MethodChannel('com.predidit.kazumi/pip');
    pipChannel.setMethodCallHandler(null);
    androidPIPInited = false;
  }
}
