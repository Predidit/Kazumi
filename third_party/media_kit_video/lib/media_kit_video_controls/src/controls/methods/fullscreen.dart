/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'package:flutter/material.dart';
import 'package:synchronized/synchronized.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:media_kit_video/media_kit_video_controls/src/controls/methods/video_state.dart';

import 'package:media_kit_video/media_kit_video_controls/src/controls/widgets/video_controls_theme_data_injector.dart';

/// Whether a [Video] present in the current [BuildContext] is in fullscreen or not.
bool isFullscreen(BuildContext context) =>
    FullscreenInheritedWidget.maybeOf(context) != null;

/// Makes the [Video] present in the current [BuildContext] enter fullscreen.
Future<void> enterFullscreen(BuildContext context) {
  return lock.synchronized(() async {
    if (!isFullscreen(context)) {
      if (context.mounted) {
        final stateValue = state(context);
        final contextNotifierValue = contextNotifier(context);
        final videoViewParametersNotifierValue =
            videoViewParametersNotifier(context);
        final controllerValue = controller(context);
        Navigator.of(context, rootNavigator: true).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => Material(
              child: VideoControlsThemeDataInjector(
                // NOTE: Make various *VideoControlsThemeData from the parent context available in the fullscreen context.
                context: context,
                child: VideoStateInheritedWidget(
                  state: stateValue,
                  contextNotifier: contextNotifierValue,
                  videoViewParametersNotifier: videoViewParametersNotifierValue,
                  disposeNotifiers: false,
                  child: FullscreenInheritedWidget(
                    parent: stateValue,
                    // Another [VideoStateInheritedWidget] inside [FullscreenInheritedWidget] is important to notify about the fullscreen [BuildContext].
                    child: VideoStateInheritedWidget(
                      state: stateValue,
                      contextNotifier: contextNotifierValue,
                      videoViewParametersNotifier:
                          videoViewParametersNotifierValue,
                      disposeNotifiers: false,
                      child: Video(
                        controller: controllerValue,
                        // Do not restrict the video's width & height in fullscreen mode:
                        width: null,
                        height: null,
                        fit: videoViewParametersNotifierValue.value.fit,
                        fill: videoViewParametersNotifierValue.value.fill,
                        alignment:
                            videoViewParametersNotifierValue.value.alignment,
                        aspectRatio:
                            videoViewParametersNotifierValue.value.aspectRatio,
                        filterQuality: videoViewParametersNotifierValue
                            .value.filterQuality,
                        controls:
                            videoViewParametersNotifierValue.value.controls,
                        // Do not acquire or modify existing wakelock in fullscreen mode:
                        wakelock: false,
                        pauseUponEnteringBackgroundMode:
                            stateValue.widget.pauseUponEnteringBackgroundMode,
                        resumeUponEnteringForegroundMode:
                            stateValue.widget.resumeUponEnteringForegroundMode,
                        subtitleViewConfiguration:
                            videoViewParametersNotifierValue
                                .value.subtitleViewConfiguration,
                        onEnterFullscreen: stateValue.widget.onEnterFullscreen,
                        onExitFullscreen: stateValue.widget.onExitFullscreen,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        await onEnterFullscreen(context)?.call();
      }
    }
  });
}

/// Makes the [Video] present in the current [BuildContext] exit fullscreen.
Future<void> exitFullscreen(BuildContext context) {
  return lock.synchronized(() async {
    if (isFullscreen(context)) {
      if (context.mounted) {
        await Navigator.of(context).maybePop();
        // It is known that this [context] will have a [FullscreenInheritedWidget] above it.
        if (context.mounted) {
          FullscreenInheritedWidget.of(context).parent.refreshView();
        }
      }
      // [exitNativeFullscreen] is moved to [WillPopScope] in [FullscreenInheritedWidget].
      // This is because [exitNativeFullscreen] needs to be called when the user presses the back button.
    }
  });
}

/// Toggles fullscreen for the [Video] present in the current [BuildContext].
Future<void> toggleFullscreen(BuildContext context) {
  if (isFullscreen(context)) {
    return exitFullscreen(context);
  } else {
    return enterFullscreen(context);
  }
}

/// For synchronizing [enterFullscreen] & [exitFullscreen] operations.
final Lock lock = Lock();
