/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';

import 'package:media_kit_video/src/video_controller/platform_video_controller.dart';

import 'package:media_kit_video/src/video_controller/native_video_controller/native_video_controller.dart';
import 'package:media_kit_video/src/video_controller/android_video_controller/android_video_controller.dart';
import 'package:media_kit_video/src/video_controller/ohos_video_controller/ohos_video_controller.dart';
import 'package:media_kit_video/src/video_controller/web_video_controller/web_video_controller.dart';

/// {@template video_controller}
///
/// VideoController
/// ---------------
///
/// [VideoController] is used to initialize & display video output.
/// It takes reference to existing [Player] instance from `package:media_kit`.
///
/// Passing [VideoController] to [Video] widget will cause the video output to be displayed.
///
/// ```dart
/// late final player = Player();
/// late final controller = VideoController(player);
/// ```
///
/// **Configurable options:**
///
/// 1. You can limit size of the video output by specifying [VideoControllerConfiguration.width] & [VideoControllerConfiguration.height].
///    * A smaller width & height may yield substantial performance improvements.
///    * By default, both [VideoControllerConfiguration.height] & [VideoControllerConfiguration.width] are `null` i.e. output is based on video's resolution.
/// 2. You can reduce scale of the video output by specifying [VideoControllerConfiguration.scale].
///    * A smaller scale may yield substantial performance improvements. Specifying this value will cause [VideoControllerConfiguration.width] & [VideoControllerConfiguration.height] to be ignored.
///    * By default, [VideoControllerConfiguration.scale] is `1.0` i.e. output is based on video's resolution.
/// 3. You can switch between GPU & CPU rendering by specifying [VideoControllerConfiguration.enableHardwareAcceleration].
///    * Disabling the option may improve stability on certain devices.
///    * By default, [VideoControllerConfiguration.enableHardwareAcceleration] is `true` i.e. GPU (Direct3D/OpenGL/METAL) is utilized.
///
/// **Platform specific limitations & differences:**
///
/// **Android**
/// * [VideoControllerConfiguration.width] & [VideoControllerConfiguration.height] arguments have no effect.
///
/// **Web**
/// * [VideoControllerConfiguration.width] & [VideoControllerConfiguration.height] arguments have no effect.
/// * Only single [Video] output can be displayed for a [VideoController].
///   Displaying multiple [Video] widgets with same [VideoController] will cause only last mounted [Video] to be displayed.
/// * [VideoControllerConfiguration.enableHardwareAcceleration] is ignored i.e. GPU usage is dependent upon the web browser.
///
/// {@endtemplate}
class VideoController {
  /// The [Player] instance associated with this [VideoController].
  final Player player;

  /// Platform specific internal implementation initialized depending upon the current platform.
  final platform = Completer<PlatformVideoController>();

  /// Platform specific internal implementation initialized depending upon the current platform.
  final notifier = ValueNotifier<PlatformVideoController?>(null);

  /// Texture ID of the video output, registered with Flutter engine by the native implementation.
  final ValueNotifier<int?> id = ValueNotifier<int?>(null);

  /// [Rect] of the video output, received from the native implementation.
  final ValueNotifier<Rect?> rect = ValueNotifier<Rect?>(null);

  /// {@macro video_controller}
  VideoController(
    this.player, {
    VideoControllerConfiguration configuration =
        const VideoControllerConfiguration(),
  }) {
    player.platform?.isVideoControllerAttached = true;

    () async {
      final completer = Completer();
      WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
      await completer.future;

      try {
        if (NativeVideoController.supported) {
          final result = await NativeVideoController.create(
            player,
            configuration,
          );
          platform.complete(result);
          notifier.value = result;
        } else if (AndroidVideoController.supported) {
          final result = await AndroidVideoController.create(
            player,
            configuration,
          );
          platform.complete(result);
          notifier.value = result;
        } else if (OhosVideoController.supported) {
          final result = await OhosVideoController.create(
            player,
            configuration,
          );
          platform.complete(result);
          notifier.value = result;
        } else if (WebVideoController.supported) {
          final result = await WebVideoController.create(
            player,
            configuration,
          );
          platform.complete(result);
          notifier.value = result;
        }

        if (platform.isCompleted) {
          // Populate [id] & [rect] [ValueNotifier]s with the values from [platform] implementation of [PlatformVideoController].
          final controller = await platform.future;
          // Add listeners.
          void fn0() => id.value = controller.id.value;
          void fn1() => rect.value = controller.rect.value;
          fn0();
          fn1();
          controller.id.addListener(fn0);
          controller.rect.addListener(fn1);
          // Remove listeners upon [Player.dispose].
          player.platform?.release.add(() async {
            controller.id.removeListener(fn0);
            controller.rect.removeListener(fn1);
          });
        } else {
          platform.completeError(
            UnimplementedError(
              '[VideoController] is unavailable for this platform.',
            ),
          );
        }
      } catch (exception, stacktrace) {
        platform.completeError(exception);
        debugPrint(exception.toString());
        debugPrint(stacktrace.toString());
      }

      if (!(player.platform?.videoControllerCompleter.isCompleted ?? true)) {
        player.platform?.videoControllerCompleter.complete();
      }
    }();
  }

  /// Sets the required size of the video output.
  /// This may yield substantial performance improvements if a small [width] & [height] is specified.
  ///
  /// Remember:
  /// * “Premature optimization is the root of all evil”
  /// * “With great power comes great responsibility”
  Future<void> setSize({
    int? width,
    int? height,
  }) async {
    final instance = await platform.future;
    return instance.setSize(
      width: width,
      height: height,
    );
  }

  /// A [Future] that completes when the first video frame has been rendered.
  Future<void> get waitUntilFirstFrameRendered async {
    final instance = await platform.future;
    return instance.waitUntilFirstFrameRendered;
  }
}
