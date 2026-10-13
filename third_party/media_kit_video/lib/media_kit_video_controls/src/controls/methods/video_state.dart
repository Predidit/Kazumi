/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'package:flutter/widgets.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit_video/src/utils/dispose_safe_notifer.dart';

/// Returns the [VideoState] associated with the [Video] present in the current [BuildContext].
VideoState state(BuildContext context) =>
    VideoStateInheritedWidget.of(context).state;

/// Returns the [ValueNotifier<BuildContext>] associated with the [Video] present in the current [BuildContext].
DisposeSafeNotifier<BuildContext?> contextNotifier(BuildContext context) =>
    VideoStateInheritedWidget.of(context).contextNotifier;

/// Returns the [ValueNotifier<VideoViewParameters>] associated with the [Video] present in the current [BuildContext].
ValueNotifier<VideoViewParameters> videoViewParametersNotifier(
        BuildContext context) =>
    VideoStateInheritedWidget.of(context).videoViewParametersNotifier;

/// Returns the [VideoController] associated with the [Video] present in the current [BuildContext].
VideoController controller(BuildContext context) =>
    VideoStateInheritedWidget.of(context).state.widget.controller;

/// Returns the callback which must be invoked when the video enters fullscreen mode.
Future<void> Function()? onEnterFullscreen(BuildContext context) =>
    VideoStateInheritedWidget.of(context).state.widget.onEnterFullscreen;

/// Returns the callback which must be invoked when the video exits fullscreen mode.
Future<void> Function()? onExitFullscreen(BuildContext context) =>
    VideoStateInheritedWidget.of(context).state.widget.onExitFullscreen;
