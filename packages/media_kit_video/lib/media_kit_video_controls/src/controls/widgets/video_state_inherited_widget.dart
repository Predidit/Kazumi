/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit_video/src/utils/dispose_safe_notifer.dart';

/// {@template video_state_inherited_widget}
///
/// Inherited widget which provides [VideoState] associated with the parent [Video] widget to descendant widgets.
///
/// {@endtemplate}
class VideoStateInheritedWidget extends InheritedWidget {
  final VideoState state;
  final DisposeSafeNotifier<BuildContext?> contextNotifier;
  final ValueNotifier<VideoViewParameters> videoViewParametersNotifier;

  final bool disposeNotifiers;
  VideoStateInheritedWidget({
    super.key,
    required this.state,
    required this.contextNotifier,
    required this.videoViewParametersNotifier,
    required Widget child,
    this.disposeNotifiers = true,
  }) : super(
          child: VideoStateInheritedWidgetContextNotifier(
            state: state,
            contextNotifier: contextNotifier,
            videoViewParametersNotifier: videoViewParametersNotifier,
            disposeNotifiers: disposeNotifiers,
            child: child,
          ),
        );

  static VideoStateInheritedWidget? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<VideoStateInheritedWidget>();
  }

  static VideoStateInheritedWidget of(BuildContext context) {
    final VideoStateInheritedWidget? result = maybeOf(context);
    assert(
      result != null,
      'No [VideoStateInheritedWidget] found in [context]',
    );
    return result!;
  }

  @override
  bool updateShouldNotify(VideoStateInheritedWidget oldWidget) =>
      identical(state, oldWidget.state) &&
      identical(contextNotifier, oldWidget.contextNotifier);
}

/// {@template video_state_inherited_widget_context_notifier}
///
/// This widget is used to notify the [VideoState._contextNotifier] about the most recent [BuildContext] associated with the [Video] widget.
///
/// {@endtemplate}
class VideoStateInheritedWidgetContextNotifier extends StatefulWidget {
  final VideoState state;
  final DisposeSafeNotifier<BuildContext?> contextNotifier;
  final ValueNotifier<VideoViewParameters?> videoViewParametersNotifier;
  final bool disposeNotifiers;
  final Widget child;

  const VideoStateInheritedWidgetContextNotifier({
    super.key,
    required this.state,
    required this.contextNotifier,
    required this.videoViewParametersNotifier,
    required this.disposeNotifiers,
    required this.child,
  });

  @override
  State<VideoStateInheritedWidgetContextNotifier> createState() =>
      VideoStateInheritedWidgetContextNotifierState();
}

class VideoStateInheritedWidgetContextNotifierState
    extends State<VideoStateInheritedWidgetContextNotifier> {
  static final fallback = HashMap<VideoState, BuildContext>.identity();

  @override
  void dispose() {
    if (!widget.contextNotifier.disposed) {
      // Restore the original [BuildContext] associated with this [Video] widget.
      widget.contextNotifier.value = fallback[widget.state];
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only update the [BuildContext] associated with this [Video] widget if it is not already set or if the [Video] widget is in fullscreen mode.
    // This is being done because the [Video] widget is rebuilt when it enters/exits fullscreen mode... & things don't work properly if we let [BuildContext] update in every rebuild.
    if (widget.contextNotifier.value == null || isFullscreen(context)) {
      widget.contextNotifier.value = context;
      fallback[widget.state] ??= context;
    }

    return widget.child;
  }
}
