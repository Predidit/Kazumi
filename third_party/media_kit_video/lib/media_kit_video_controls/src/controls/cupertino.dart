/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
// ignore_for_file: non_constant_identifier_names
import 'package:flutter/cupertino.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:media_kit_video/media_kit_video_controls/src/controls/widgets/video_controls_theme_data_injector.dart';

/// {@template cupertino_video_controls}
///
/// [Video] controls which use Cupertino design.
///
/// {@endtemplate}
Widget CupertinoVideoControls(VideoState state) {
  return const VideoControlsThemeDataInjector(
    child: _CupertinoVideoControls(),
  );
}

/// [MaterialDesktopVideoControlsThemeData] available in this [context].
CupertinoVideoControlsThemeData _theme(BuildContext context) =>
    FullscreenInheritedWidget.maybeOf(context) == null
        ? CupertinoVideoControlsTheme.maybeOf(context)?.normal ??
            kDefaultCupertinoVideoControlsThemeData
        : CupertinoVideoControlsTheme.maybeOf(context)?.fullscreen ??
            kDefaultCupertinoVideoControlsThemeDataFullscreen;

/// Default [CupertinoVideoControlsThemeData].
const kDefaultCupertinoVideoControlsThemeData =
    CupertinoVideoControlsThemeData();

/// Default [CupertinoVideoControlsThemeData] for fullscreen.
const kDefaultCupertinoVideoControlsThemeDataFullscreen =
    CupertinoVideoControlsThemeData();

/// {@template cupertino_video_controls_theme_data}
///
/// Theming related data for [CupertinoVideoControls]. These values are used to theme the descendant [CupertinoVideoControls].
///
/// {@endtemplate}
class CupertinoVideoControlsThemeData {
  const CupertinoVideoControlsThemeData();
}

/// {@template cupertino_video_controls_theme}
///
/// Inherited widget which provides [CupertinoVideoControlsThemeData] to descendant widgets.
///
/// {@endtemplate}
class CupertinoVideoControlsTheme extends InheritedWidget {
  final CupertinoVideoControlsThemeData normal;
  final CupertinoVideoControlsThemeData fullscreen;
  const CupertinoVideoControlsTheme({
    super.key,
    required this.normal,
    required this.fullscreen,
    required super.child,
  });

  static CupertinoVideoControlsTheme? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CupertinoVideoControlsTheme>();
  }

  static CupertinoVideoControlsTheme of(BuildContext context) {
    final CupertinoVideoControlsTheme? result = maybeOf(context);
    assert(
      result != null,
      'No [CupertinoVideoControlsTheme] found in [context]',
    );
    return result!;
  }

  @override
  bool updateShouldNotify(CupertinoVideoControlsTheme oldWidget) =>
      identical(normal, oldWidget.normal) &&
      identical(fullscreen, oldWidget.fullscreen);
}

/// {@macro cupertino_video_controls}
class _CupertinoVideoControls extends StatefulWidget {
  const _CupertinoVideoControls({Key? key}) : super(key: key);

  @override
  State<_CupertinoVideoControls> createState() =>
      _CupertinoVideoControlsState();
}

/// {@macro cupertino_video_controls}
class _CupertinoVideoControlsState extends State<_CupertinoVideoControls> {
  @override
  Widget build(BuildContext context) {
    // TODO: Missing implementation.
    return Container();
  }
}
