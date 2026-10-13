/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

import 'package:media_kit/media_kit.dart';

import 'package:media_kit_video/src/video_controller/platform_video_controller.dart';

/// {@template ohos_video_controller}
///
/// OhosVideoController
/// ----------------------
///
/// The [PlatformVideoController] implementation based on native C/C++ used on Ohos.
///
/// {@endtemplate}
class OhosVideoController extends PlatformVideoController {
  /// Whether [OhosVideoController] is supported on the current platform or not.
  static bool get supported => Platform.operatingSystem == 'ohos';

  /// Pointer address to the global object reference of `OHNativeWindow`.
  final ValueNotifier<int?> wid = ValueNotifier<int?>(null);

  /// [Lock] used to synchronize [onLoadHooks], [onUnloadHooks] & [subscription].
  final lock = Lock();

  NativePlayer get platform => player.platform as NativePlayer;

  Future<void> setProperty(String key, String value) async {
    await platform.setProperty(key, value, waitForInitialization: false);
  }

  Future<void> setProperties(Map<String, String> properties) async {
    for (final entry in properties.entries) {
      await setProperty(entry.key, entry.value);
    }
  }

  /// [StreamSubscription] for listening to video [Rect].
  StreamSubscription<VideoParams>? videoParamsSubscription;

  /// {@macro ohos_video_controller}
  OhosVideoController._(
    super.player,
    super.configuration,
  ) {
    videoParamsSubscription = player.stream.videoParams.listen(
      (event) => lock.synchronized(() async {
        final int width;
        final int height;
        if (event.rotate == 0 || event.rotate == 180) {
          width = event.dw ?? 0;
          height = event.dh ?? 0;
        } else {
          // width & height are swapped for 90 or 270 degrees rotation.
          width = event.dh ?? 0;
          height = event.dw ?? 0;
        }

        final isZero = width == 0 || height == 0;
        final isSame = width == rect.value?.width.toInt() &&
            height == rect.value?.height.toInt();
        if (isZero || isSame) {
          return;
        }

        final handle = await player.handle;

        await _channel.invokeMethod(
          'VideoOutputManager.SetSurfaceSize',
          {
            'handle': handle.toString(),
            'width': width.toString(),
            'height': height.toString(),
          },
        );
        await setProperties({
          'ohos-surface-size': [width, height].join('x'),
        });

        rect.value = Rect.fromLTWH(
          0.0,
          0.0,
          width.toDouble(),
          height.toDouble(),
        );

        if (!waitUntilFirstFrameRenderedCompleter.isCompleted) {
          waitUntilFirstFrameRenderedCompleter.complete();
        }
      }),
    );
  }

  /// {@macro ohos_video_controller}
  static Future<PlatformVideoController> create(
    Player player,
    VideoControllerConfiguration configuration,
  ) async {
    final bool isEmulator = await _channel.invokeMethod('Utils.IsEmulator');
    if (isEmulator) {
      throw UnsupportedError(
        '[VideoController] does not support emulator.'
        ' '
        'Please use actual device.',
      );
    }

    Future<String> getDefaultHwdec() async {
      bool hw = configuration.enableHardwareAcceleration;
      return hw ? 'auto' : 'no';
    }

    // Update [configuration] to have default values.
    configuration = configuration.copyWith(
      vo: configuration.vo ?? 'gpu-next',
      hwdec: configuration.hwdec ?? await getDefaultHwdec(),
    );

    // Retrieve the native handle of the [Player].
    final handle = await player.handle;
    // Return the existing [VideoController] if it's already created.
    if (_controllers.containsKey(handle)) {
      return _controllers[handle]!;
    }

    // Creation:
    final controller = OhosVideoController._(
      player,
      configuration,
    );

    // Register [_dispose] for execution upon [Player.dispose].
    player.platform?.release.add(controller._dispose);

    // Store the [VideoController] in the [_controllers].
    _controllers[handle] = controller;

    final Map<dynamic, dynamic>? data = await _channel.invokeMethod(
      'VideoOutputManager.Create',
      {
        'handle': handle.toString(),
      },
    );

    if (data == null) {
      throw StateError('[OhosVideoController] failed to create video output.');
    }

    final id = (data['id'] as num).toInt();
    final wid = (data['wid'] as num).toInt();
    final rect = Rect.fromLTWH(
      (data['rect']['left'] as num).toDouble(),
      (data['rect']['top'] as num).toDouble(),
      (data['rect']['width'] as num).toDouble(),
      (data['rect']['height'] as num).toDouble(),
    );

    controller.id.value = id;
    controller.rect.value = rect;
    controller.wid.value = wid;

    await controller.lock.synchronized(() async {
      // MPV's HarmonyOS video output requires a valid surface ID before the
      // GPU video output is initialized.
      await controller.setProperty('vo', 'null');
      await controller.setProperties(
        {
          'ohos-surface-size': '${rect.width.toInt()}x${rect.height.toInt()}',
          'wid': wid.toString(),
          'hwdec': configuration.hwdec!,
          'vid': 'auto',
          'force-window': 'yes',
          'sub-use-margins': 'no',
          'sub-scale-with-window': 'no',
          'osd-font': 'HarmonyOS Sans SC',
        },
      );
      await controller.setProperty('vo', configuration.vo!);
    });

    // Return the [PlatformVideoController].
    return controller;
  }

  /// Sets the required size of the video output.
  /// This may yield substantial performance improvements if a small [width] & [height] is specified.
  ///
  /// Remember:
  /// * “Premature optimization is the root of all evil”
  /// * “With great power comes great responsibility”
  @override
  Future<void> setSize({
    int? width,
    int? height,
  }) {
    throw UnsupportedError(
      '[OhosVideoController.setSize] is not available on Ohos',
    );
  }

  /// Disposes the instance. Releases allocated resources back to the system.
  Future<void> _dispose() async {
    await videoParamsSubscription?.cancel();
    final handle = await player.handle;
    _controllers.remove(handle);
    await _channel.invokeMethod(
      'VideoOutputManager.Dispose',
      {
        'handle': handle.toString(),
      },
    );
    wid.dispose();
    super.dispose();
  }

  /// Currently created [OhosVideoController]s.
  static final _controllers = HashMap<int, OhosVideoController>();

  /// [MethodChannel] for invoking platform specific native implementation.
  static const _channel = MethodChannel('com.alexmercerind/media_kit_video');
}
