/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js' as js;
import 'dart:html' as html;

import 'dart:ui_web';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'package:media_kit_video/src/video_controller/platform_video_controller.dart';

/// {@template web_video_controller}
///
/// WebVideoController
/// ------------------
///
/// The [WebVideoController] implementation based on HTML & JavaScript used on web.
///
/// {@endtemplate}
class WebVideoController extends PlatformVideoController {
  /// Whether [WebVideoController] is supported on the current platform or not.
  static const bool supported = kIsWeb;

  /// {@macro web_video_controller}
  WebVideoController._(
    super.player,
    super.configuration,
  );

  /// {@macro web_video_controller}
  static Future<PlatformVideoController> create(
    Player player,
    VideoControllerConfiguration configuration,
  ) async {
    // Retrieve the native handle of the [Player].
    final handle = await player.handle;

    final controller = WebVideoController._(
      player,
      configuration,
    );
    // Register [_dispose] for execution upon [Player.dispose].
    player.platform?.release.add(controller._dispose);

    // Retrieve the [html.VideoElement] instance from [js.context].
    controller._element = js.context[_kInstances][handle];
    // Register the [html.VideoElement] as platform view.
    platformViewRegistry.registerViewFactory(
      'com.alexmercerind.media_kit_video.$handle',
      (int _) => controller._element!,
    );

    // On web implementation, we are having [handle] & [controller.id] same, which in itself is a simple counter based value managed within [Player].
    // Since there is no texture creation or rendering involved.
    controller.id.value = handle;

    // Listen to the resize event of the [html.VideoElement].
    controller._resizeStreamSubscription = controller._element?.onResize.listen(
      (event) {
        debugPrint(
          'media_kit: WebVideoController: ${controller._element?.videoWidth}, ${controller._element?.videoHeight}',
        );
        // Update the size of the [PlatformVideoController].
        controller.rect.value = Rect.fromLTWH(
          0.0,
          0.0,
          controller._element?.videoWidth.toDouble() ?? 0.0,
          controller._element?.videoHeight.toDouble() ?? 0.0,
        );
      },
    );

    // Notify about the first frame being rendered.
    // Case: If some [Media] is already playing when [VideoController] is created.
    if (player.state.width != null && player.state.height != null) {
      if (!controller.waitUntilFirstFrameRenderedCompleter.isCompleted) {
        controller.waitUntilFirstFrameRenderedCompleter.complete();
      }
    }

    controller._element?.onCanPlayThrough.listen(
      (_) {
        // Notify about first frame being rendered.
        if (!controller.waitUntilFirstFrameRenderedCompleter.isCompleted) {
          controller.waitUntilFirstFrameRenderedCompleter.complete();
        }
      },
    );

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
      '[AndroidVideoController.setSize] is not available on web',
    );
  }

  /// Disposes the instance. Releases allocated resources back to the system.
  Future<void> _dispose() async {
    super.dispose();
    await _resizeStreamSubscription?.cancel();
  }

  /// HTML [html.VideoElement] instance reference.
  html.VideoElement? _element;

  StreamSubscription<html.Event>? _resizeStreamSubscription;

  /// JavaScript object attribute used to store various [VideoElement] instances in [js.context].
  static const _kInstances = '\$com.alexmercerind.media_kit.instances';
}
