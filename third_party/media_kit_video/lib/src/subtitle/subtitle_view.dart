/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:media_kit_video/src/video_controller/video_controller.dart';

/// {@template subtitle_view}
///
/// SubtitleView
/// ------------
///
/// [SubtitleView] widget is used to display the subtitles on top of the [Video].
///
/// {@endtemplate}
class SubtitleView extends StatefulWidget {
  /// The [VideoController] reference to control this [SubtitleView] output.
  final VideoController controller;

  /// The configuration to be used for the subtitles.
  final SubtitleViewConfiguration configuration;

  /// {@macro subtitle_view}
  const SubtitleView({
    Key? key,
    required this.controller,
    required this.configuration,
  }) : super(key: key);

  @override
  SubtitleViewState createState() => SubtitleViewState();
}

class SubtitleViewState extends State<SubtitleView> {
  late List<String> subtitle = widget.controller.player.state.subtitle;
  late EdgeInsets padding = widget.configuration.padding;
  late Duration duration = const Duration(milliseconds: 100);

  // The [StreamSubscription] to listen to the subtitle changes.
  StreamSubscription<List<String>>? subscription;

  // The reference width for calculating the visible text scale factor.
  static const kTextScaleFactorReferenceWidth = 1920.0;
  // The reference height for calculating the visible text scale factor.
  static const kTextScaleFactorReferenceHeight = 1080.0;

  @override
  void initState() {
    subscription = widget.controller.player.stream.subtitle.listen((value) {
      setState(() {
        subtitle = value;
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  /// Sets the padding to be used for the subtitles.
  ///
  /// The [duration] argument may be specified to set the duration of the animation.
  void setPadding(
    EdgeInsets padding, {
    Duration duration = const Duration(milliseconds: 100),
  }) {
    if (this.duration != duration) {
      setState(() {
        this.duration = duration;
      });
    }
    setState(() {
      this.padding = padding;
    });
  }

  /// {@macro subtitle_view}
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the visible text scale factor.

        final nr = (constraints.maxWidth * constraints.maxHeight);
        const dr =
            kTextScaleFactorReferenceWidth * kTextScaleFactorReferenceHeight;
        final textScaleFactor = sqrt((nr / dr).clamp(0.0, 1.0));

        final textScaler = widget.configuration.textScaler ??
            TextScaler.linear(textScaleFactor);
        return Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            padding: padding,
            duration: duration,
            alignment: Alignment.bottomCenter,
            child: Text(
              [
                for (final line in subtitle)
                  if (line.trim().isNotEmpty) line.trim(),
              ].join('\n'),
              style: widget.configuration.style,
              textAlign: widget.configuration.textAlign,
              textScaler: textScaler,
            ),
          ),
        );
      },
    );
  }
}

/// {@template subtitle_view_configuration}
/// SubtitleViewConfiguration
/// -------------------------
///
/// Configurable options for customizing the [SubtitleView] behaviour.
/// {@endtemplate}
class SubtitleViewConfiguration {
  /// Whether the subtitles should be visible or not.
  final bool visible;

  /// The text style to be used for the subtitles.
  final TextStyle style;

  /// The text alignment to be used for the subtitles.
  final TextAlign textAlign;

  /// The text scaler to be used for the subtitles.
  final TextScaler? textScaler;

  /// The padding to be used for the subtitles.
  final EdgeInsets padding;

  /// {@macro subtitle_view_configuration}
  const SubtitleViewConfiguration({
    this.visible = true,
    this.style = const TextStyle(
      height: 1.4,
      fontSize: 32.0,
      letterSpacing: 0.0,
      wordSpacing: 0.0,
      color: Color(0xffffffff),
      fontWeight: FontWeight.normal,
      backgroundColor: Color(0xaa000000),
    ),
    this.textAlign = TextAlign.center,
    this.textScaler,
    this.padding = const EdgeInsets.fromLTRB(
      16.0,
      0.0,
      16.0,
      24.0,
    ),
  });
}
