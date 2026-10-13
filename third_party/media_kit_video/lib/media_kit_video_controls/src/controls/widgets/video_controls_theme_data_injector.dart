/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'package:flutter/widgets.dart';

import 'package:media_kit_video/media_kit_video_controls/src/controls/cupertino.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/material.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/material_desktop.dart';

/// {@template video_controls_theme_data_injector}
///
/// VideoControlsThemeDataInjector
/// ------------------------------
///
/// Makes the various `*VideoControlsTheme` [InheritedWidget]s from provided [context] to current [BuildContext] and its descendants.
///
/// The fallback to default values is done by [VideoControlsThemeDataInjector] itself.
///
/// * [CupertinoVideoControlsTheme]
/// * [MaterialVideoControlsTheme]
/// * [MaterialDesktopVideoControlsTheme]
///
/// {@endtemplate}
class VideoControlsThemeDataInjector extends StatefulWidget {
  final Widget child;
  final BuildContext? context;

  /// {@macro video_controls_theme_data_injector}
  const VideoControlsThemeDataInjector({
    Key? key,
    required this.child,
    this.context,
  }) : super(key: key);

  @override
  State<VideoControlsThemeDataInjector> createState() =>
      _VideoControlsThemeDataInjectorState();
}

class _VideoControlsThemeDataInjectorState
    extends State<VideoControlsThemeDataInjector> {
  late final builders = <Widget Function(Widget)>[
    // CupertinoVideoControlsTheme
    (child) {
      final theme = CupertinoVideoControlsTheme.maybeOf(
        widget.context ?? context,
      );
      final normal = theme?.normal ?? kDefaultCupertinoVideoControlsThemeData;
      final fullscreen = theme?.fullscreen ??
          kDefaultCupertinoVideoControlsThemeDataFullscreen;
      return CupertinoVideoControlsTheme(
        normal: normal,
        fullscreen: fullscreen,
        child: child,
      );
    },
    // MaterialVideoControlsTheme
    (child) {
      final theme = MaterialVideoControlsTheme.maybeOf(
        widget.context ?? context,
      );
      final normal = theme?.normal ?? kDefaultMaterialVideoControlsThemeData;
      final fullscreen =
          theme?.fullscreen ?? kDefaultMaterialVideoControlsThemeDataFullscreen;
      return MaterialVideoControlsTheme(
        normal: normal,
        fullscreen: fullscreen,
        child: child,
      );
    },
    // MaterialDesktopVideoControlsTheme
    (child) {
      final theme = MaterialDesktopVideoControlsTheme.maybeOf(
        widget.context ?? context,
      );
      final normal =
          theme?.normal ?? kDefaultMaterialDesktopVideoControlsThemeData;
      final fullscreen = theme?.fullscreen ??
          kDefaultMaterialDesktopVideoControlsThemeDataFullscreen;
      return MaterialDesktopVideoControlsTheme(
        normal: normal,
        fullscreen: fullscreen,
        child: child,
      );
    },
    // NOTE: Add more builders if more *VideoControlsTheme are implemented.
  ];

  @override
  Widget build(BuildContext context) {
    return builders.fold<Widget>(
      widget.child,
      (child, builder) => builder(child),
    );
  }
}
