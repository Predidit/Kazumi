// This file is a part of media_kit (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

import 'package:media_kit/media_kit.dart';

import 'package:media_kit_video/src/utils/query_decoders.dart';
import 'package:media_kit_video/src/video_controller/platform_video_controller.dart';

/// {@template android_video_controller}
///
/// AndroidVideoController
/// ----------------------
///
/// The [PlatformVideoController] implementation based on native JNI & C/C++ used on Android.
///
/// {@endtemplate}
class AndroidVideoController extends PlatformVideoController {
  /// Whether [AndroidVideoController] is supported on the current platform or not.
  static bool get supported => Platform.isAndroid;

  /// Pointer address to the global object reference of `android.view.Surface` i.e. `(intptr_t)(*android.view.Surface)`.
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

  /// Listener for updating the --wid property.
  Future<void> widListener() => lock.synchronized(_attachSurface);

  Future<void> _attachSurface() async {
    if (_disposed) return;
    final dimensions = rect.value;
    final width = dimensions?.width.toInt() ?? 1;
    final height = dimensions?.height.toInt() ?? 1;
    final widValue = wid.value?.toString() ?? '0';
    final vo = widValue == '0' ? 'null' : configuration.vo!;
    await setProperties({
      // The Vulkan Android context caches the surface size at VO creation.
      'vo': 'null',
      'android-surface-size': '${width}x$height',
      'wid': widValue,
    });
    await setProperty('vo', vo);
    // Recreating the VO discards its last frame. A paused stream supplies no
    // next frame to refill the newly sized surface. Use mpv's exact playhead
    // instead of seeking a running player to a stale Dart stream position.
    if (widValue != '0' && configuration.vo != 'mediacodec_embed' &&
        !player.state.playing && player.state.playlist.medias.isNotEmpty) {
      final pos = await platform.getProperty('time-pos', waitForInitialization: false);
      final seekable = await platform.getProperty('seekable', waitForInitialization: false);
      if (!_disposed && !player.state.playing && seekable == 'yes' && double.tryParse(pos)?.isFinite == true) {
        await platform.command(['seek', pos, 'absolute+exact'], waitForInitialization: false);
      }
    }
    if (configuration.vo == 'mediacodec_embed') {
      await setProperty('vid', widValue == '0' ? 'no' : 'auto');
    }
  }

  int? _sourceWidth, _sourceHeight, _outputWidth, _outputHeight;
  bool _disposed = false;
  bool _canResizeInPlace = false;

  Future<void> _applySize() async {
    if (_disposed) return;
    final width = _outputWidth ?? _sourceWidth;
    final height = _outputHeight ?? _sourceHeight;
    if (width == null || height == null || width <= 0 || height <= 0) return;
    if (width == rect.value?.width && height == rect.value?.height) return;
    final handle = await player.handle;
    final previousWid = wid.value;
    await _channel.invokeMethod('VideoOutputManager.SetSurfaceSize', {
      'handle': handle.toString(),
      'width': width.toString(),
      'height': height.toString(),
    });
    if (_disposed) return;
    rect.value = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    // SurfaceTexture keeps the same global ref on resize. A new ref, when
    // available, is handled by widListener instead.
    if (previousWid != null && previousWid != 0 && previousWid == wid.value &&
        configuration.vo != 'mediacodec_embed') {
      if (_canResizeInPlace) {
        await setProperty('android-surface-size', '${width}x$height');
      } else {
        await _attachSurface();
      }
    }
    if (!waitUntilFirstFrameRenderedCompleter.isCompleted) {
      waitUntilFirstFrameRenderedCompleter.complete();
    }
  }

  /// [StreamSubscription] for listening to video [Rect].
  StreamSubscription<VideoParams>? videoParamsSubscription;

  /// {@macro android_video_controller}
  AndroidVideoController._(
    super.player,
    super.configuration,
  ) {
    wid.addListener(widListener);
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

        if (width <= 0 || height <= 0) return;
        _sourceWidth = width;
        _sourceHeight = height;
        await _applySize();
      }),
    );
  }

  /// {@macro android_video_controller}
  static Future<PlatformVideoController> create(
    Player player,
    VideoControllerConfiguration configuration,
  ) async {
    Future<String> getDefaultHwdec() async {
      // Enforce software rendering in emulators.
      bool hw = configuration.enableHardwareAcceleration;
      final bool isEmulator = await _channel.invokeMethod('Utils.IsEmulator');
      if (isEmulator) {
        hw = false;
        debugPrint('media_kit: Emulator detected.');
        debugPrint('media_kit: Enforcing S/W rendering.');
      }
      return hw ? 'auto-safe' : 'no';
    }

    // Update [configuration] to have default values.
    configuration = configuration.copyWith(
      vo: configuration.vo ?? 'gpu',
      hwdec: configuration.hwdec ?? await getDefaultHwdec(),
    );

    // Retrieve the native handle of the [Player].
    final handle = await player.handle;
    // Return the existing [VideoController] if it's already created.
    if (_controllers.containsKey(handle)) {
      return _controllers[handle]!;
    }

    final decoders = await queryDecoders(handle);
    if (!decoders.contains('h264')) {
      throw UnsupportedError(
        '[VideoController] requires a libmpv build with video decoders.',
      );
    }

    // Creation:
    final controller = AndroidVideoController._(
      player,
      configuration,
    );

    // Register [_dispose] for execution upon [Player.dispose].
    player.platform?.release.add(controller._dispose);

    // Store the [VideoController] in the [_controllers].
    _controllers[handle] = controller;

    // Create may immediately publish a Surface. Keep its first attachment and
    // video-parameter callbacks behind all initial mpv option writes.
    await controller.lock.synchronized(() async {
      await controller.setProperty('vo', 'null');
      controller._canResizeInPlace = (await controller.platform.getProperty(
        'option-info/kazumi-surface-size/name', waitForInitialization: false,
      )).isNotEmpty;
      var gpuApi = 'auto';
      if (configuration.vo == 'gpu-next') {
        gpuApi = 'vulkan,opengl';
        final uuid = configuration.androidVulkanDeviceUuid;
        if (uuid != null) {
          await controller.setProperty('vulkan-device', uuid);
          final applied = await controller.platform.getProperty(
            'options/vulkan-device',
            waitForInitialization: false,
          );
          if (applied == uuid) gpuApi = 'vulkan';
        }
      }
      await controller.setProperties({
        'gpu-api': gpuApi,
        'hwdec': configuration.hwdec!,
        'vid': 'auto',
        'force-window': 'yes',
        'sub-use-margins': 'no',
        'sub-font-provider': 'none',
        'sub-scale-with-window': 'yes',
        'hwdec-codecs': 'h264,hevc,mpeg4,mpeg2video,vp8,vp9,av1',
      });
      await _channel.invokeMethod('VideoOutputManager.Create', {
        'handle': handle.toString(),
        'enableSurfaceProducer': configuration.enableAndroidSurfaceProducer,
      });
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
  Future<void> setSize({int? width, int? height}) => lock.synchronized(() async {
    if (configuration.vo == 'mediacodec_embed') return;
    _outputWidth = width;
    _outputHeight = height;
    await _applySize();
  });

  /// Disposes the instance. Releases allocated resources back to the system.
  Future<void> _dispose() async {
    _disposed = true;
    wid.removeListener(widListener);
    await videoParamsSubscription?.cancel();
    await lock.synchronized(() async {});
    super.dispose();
    wid.dispose();
    final handle = await player.handle;
    _controllers.remove(handle);
    await _channel.invokeMethod(
      'VideoOutputManager.Dispose',
      {
        'handle': handle.toString(),
      },
    );
  }

  /// Currently created [AndroidVideoController]s.
  static final _controllers = HashMap<int, AndroidVideoController>();

  /// [MethodChannel] for invoking platform specific native implementation.
  static final _channel =
      const MethodChannel('com.alexmercerind/media_kit_video')
        ..setMethodCallHandler(
          (MethodCall call) async {
            try {
              debugPrint(call.method.toString());
              debugPrint(call.arguments.toString());
              switch (call.method) {
                case 'VideoOutput.Resize':
                  {
                    // Notify about updated texture ID & [Rect].
                    final int handle = call.arguments['handle'];
                    final Rect rect = Rect.fromLTWH(
                      call.arguments['rect']['left'] * 1.0,
                      call.arguments['rect']['top'] * 1.0,
                      call.arguments['rect']['width'] * 1.0,
                      call.arguments['rect']['height'] * 1.0,
                    );
                    final int id = call.arguments['id'];
                    final int wid = call.arguments['wid'];
                    _controllers[handle]?.rect.value = rect;
                    _controllers[handle]?.id.value = id;
                    _controllers[handle]?.wid.value = wid;
                    break;
                  }
                case 'VideoOutput.WaitUntilFirstFrameRenderedNotify':
                  {
                    // Notify about updated texture ID & [Rect].
                    final int handle = call.arguments['handle'];
                    debugPrint(handle.toString());
                    // Notify about the first frame being rendered.
                    final completer = _controllers[handle]
                        ?.waitUntilFirstFrameRenderedCompleter;
                    if (!(completer?.isCompleted ?? true)) {
                      completer?.complete();
                    }
                    break;
                  }
                default:
                  {
                    break;
                  }
              }
            } catch (exception, stacktrace) {
              debugPrint(exception.toString());
              debugPrint(stacktrace.toString());
            }
          },
        );
}
