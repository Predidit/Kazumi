/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
// ignore_for_file: non_constant_identifier_names
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:media_kit_video/media_kit_video_controls/src/controls/methods/video_state.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/extensions/duration.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/widgets/video_controls_theme_data_injector.dart';

/// {@template material_desktop_video_controls}
///
/// [Video] controls which use Material design.
///
/// {@endtemplate}
Widget MaterialDesktopVideoControls(VideoState state) {
  return const VideoControlsThemeDataInjector(
    child: _MaterialDesktopVideoControls(),
  );
}

/// [MaterialDesktopVideoControlsThemeData] available in this [context].
MaterialDesktopVideoControlsThemeData _theme(BuildContext context) =>
    FullscreenInheritedWidget.maybeOf(context) == null
        ? MaterialDesktopVideoControlsTheme.maybeOf(context)?.normal ??
            kDefaultMaterialDesktopVideoControlsThemeData
        : MaterialDesktopVideoControlsTheme.maybeOf(context)?.fullscreen ??
            kDefaultMaterialDesktopVideoControlsThemeDataFullscreen;

/// Default [MaterialDesktopVideoControlsThemeData].
const kDefaultMaterialDesktopVideoControlsThemeData =
    MaterialDesktopVideoControlsThemeData();

/// Default [MaterialDesktopVideoControlsThemeData] for fullscreen.
const kDefaultMaterialDesktopVideoControlsThemeDataFullscreen =
    MaterialDesktopVideoControlsThemeData();

/// {@template material_desktop_video_controls_theme_data}
///
/// Theming related data for [MaterialDesktopVideoControls]. These values are used to theme the descendant [MaterialDesktopVideoControls].
///
/// {@endtemplate}
class MaterialDesktopVideoControlsThemeData {
  // BEHAVIOR

  /// Whether to display seek bar.
  final bool displaySeekBar;

  /// Whether a skip next button should be displayed if there are more than one videos in the playlist.
  final bool automaticallyImplySkipNextButton;

  /// Whether a skip previous button should be displayed if there are more than one videos in the playlist.
  final bool automaticallyImplySkipPreviousButton;

  /// Modify volume on mouse scroll.
  final bool modifyVolumeOnScroll;

  /// Whether to toggle fullscreen on double press.
  final bool toggleFullscreenOnDoublePress;

  /// Whether to hide mouse on controls removal.(will need to move the mouse to be hidden check issue: https://github.com/flutter/flutter/issues/76622) works on macos without moving the mouse
  final bool hideMouseOnControlsRemoval;

  /// Whether to toggle play and pause on tap.
  final bool playAndPauseOnTap;

  /// Keyboards shortcuts.
  final Map<ShortcutActivator, VoidCallback>? keyboardShortcuts;

  /// Whether the controls are initially visible.
  final bool visibleOnMount;

  // GENERIC

  /// Padding around the controls.
  ///
  /// * Default: `EdgeInsets.zero`
  /// * Fullscreen: `MediaQuery.of(context).padding`
  final EdgeInsets? padding;

  /// [Duration] after which the controls will be hidden when there is no mouse movement.
  final Duration controlsHoverDuration;

  /// [Duration] for which the controls will be animated when shown or hidden.
  final Duration controlsTransitionDuration;

  /// Builder for the buffering indicator.
  final Widget Function(BuildContext)? bufferingIndicatorBuilder;

  // BUTTON BAR

  /// Buttons to be displayed in the primary button bar.
  final List<Widget> primaryButtonBar;

  /// Buttons to be displayed in the top button bar.
  final List<Widget> topButtonBar;

  /// Margin around the top button bar.
  final EdgeInsets topButtonBarMargin;

  /// Buttons to be displayed in the bottom button bar.
  final List<Widget> bottomButtonBar;

  /// Margin around the bottom button bar.
  final EdgeInsets bottomButtonBarMargin;

  /// Height of the button bar.
  final double buttonBarHeight;

  /// Size of the button bar buttons.
  final double buttonBarButtonSize;

  /// Color of the button bar buttons.
  final Color buttonBarButtonColor;

  // SEEK BAR

  /// [Duration] for which the seek bar will be animated when the user seeks.
  final Duration seekBarTransitionDuration;

  /// [Duration] for which the seek bar thumb will be animated when the user seeks.
  final Duration seekBarThumbTransitionDuration;

  /// Margin around the seek bar.
  final EdgeInsets seekBarMargin;

  /// Height of the seek bar.
  final double seekBarHeight;

  /// Height of the seek bar when hovered.
  final double seekBarHoverHeight;

  /// Height of the seek bar [Container].
  final double seekBarContainerHeight;

  /// [Color] of the seek bar.
  final Color seekBarColor;

  /// [Color] of the hovered section in the seek bar.
  final Color seekBarHoverColor;

  /// [Color] of the playback position section in the seek bar.
  final Color seekBarPositionColor;

  /// [Color] of the playback buffer section in the seek bar.
  final Color seekBarBufferColor;

  /// Size of the seek bar thumb.
  final double seekBarThumbSize;

  /// [Color] of the seek bar thumb.
  final Color seekBarThumbColor;

  // VOLUME BAR

  /// [Color] of the volume bar.
  final Color volumeBarColor;

  /// [Color] of the active region in the volume bar.
  final Color volumeBarActiveColor;

  /// Size of the volume bar thumb.
  final double volumeBarThumbSize;

  /// [Color] of the volume bar thumb.
  final Color volumeBarThumbColor;

  /// [Duration] for which the volume bar will be animated when the user hovers.
  final Duration volumeBarTransitionDuration;

  // SUBTITLE

  /// Whether to shift the subtitles upwards when the controls are visible.
  final bool shiftSubtitlesOnControlsVisibilityChange;

  /// {@macro material_desktop_video_controls_theme_data}
  const MaterialDesktopVideoControlsThemeData({
    this.displaySeekBar = true,
    this.automaticallyImplySkipNextButton = true,
    this.automaticallyImplySkipPreviousButton = true,
    this.toggleFullscreenOnDoublePress = true,
    this.playAndPauseOnTap = false,
    this.modifyVolumeOnScroll = true,
    this.keyboardShortcuts,
    this.visibleOnMount = false,
    this.hideMouseOnControlsRemoval = false,
    this.padding,
    this.controlsHoverDuration = const Duration(seconds: 3),
    this.controlsTransitionDuration = const Duration(milliseconds: 150),
    this.bufferingIndicatorBuilder,
    this.primaryButtonBar = const [],
    this.topButtonBar = const [],
    this.topButtonBarMargin = const EdgeInsets.symmetric(horizontal: 16.0),
    this.bottomButtonBar = const [
      MaterialDesktopSkipPreviousButton(),
      MaterialDesktopPlayOrPauseButton(),
      MaterialDesktopSkipNextButton(),
      MaterialDesktopVolumeButton(),
      MaterialDesktopPositionIndicator(),
      Spacer(),
      MaterialDesktopFullscreenButton(),
    ],
    this.bottomButtonBarMargin = const EdgeInsets.symmetric(horizontal: 16.0),
    this.buttonBarHeight = 56.0,
    this.buttonBarButtonSize = 28.0,
    this.buttonBarButtonColor = const Color(0xFFFFFFFF),
    this.seekBarTransitionDuration = const Duration(milliseconds: 300),
    this.seekBarThumbTransitionDuration = const Duration(milliseconds: 150),
    this.seekBarMargin = const EdgeInsets.symmetric(horizontal: 16.0),
    this.seekBarHeight = 3.2,
    this.seekBarHoverHeight = 5.6,
    this.seekBarContainerHeight = 36.0,
    this.seekBarColor = const Color(0x3DFFFFFF),
    this.seekBarHoverColor = const Color(0x3DFFFFFF),
    this.seekBarPositionColor = const Color(0xFFFF0000),
    this.seekBarBufferColor = const Color(0x3DFFFFFF),
    this.seekBarThumbSize = 12.0,
    this.seekBarThumbColor = const Color(0xFFFF0000),
    this.volumeBarColor = const Color(0x3DFFFFFF),
    this.volumeBarActiveColor = const Color(0xFFFFFFFF),
    this.volumeBarThumbSize = 12.0,
    this.volumeBarThumbColor = const Color(0xFFFFFFFF),
    this.volumeBarTransitionDuration = const Duration(milliseconds: 150),
    this.shiftSubtitlesOnControlsVisibilityChange = true,
  });

  /// Creates a copy of this [MaterialDesktopVideoControlsThemeData] with the given fields replaced by the non-null parameter values.
  MaterialDesktopVideoControlsThemeData copyWith({
    bool? displaySeekBar,
    bool? automaticallyImplySkipNextButton,
    bool? automaticallyImplySkipPreviousButton,
    bool? toggleFullscreenOnDoublePress,
    bool? playAndPauseOnTap,
    bool? modifyVolumeOnScroll,
    Map<ShortcutActivator, VoidCallback>? keyboardShortcuts,
    bool? visibleOnMount,
    bool? hideMouseOnControlsRemoval,
    Duration? controlsHoverDuration,
    Duration? controlsTransitionDuration,
    Widget Function(BuildContext)? bufferingIndicatorBuilder,
    List<Widget>? topButtonBar,
    EdgeInsets? topButtonBarMargin,
    List<Widget>? bottomButtonBar,
    EdgeInsets? bottomButtonBarMargin,
    double? buttonBarHeight,
    double? buttonBarButtonSize,
    Color? buttonBarButtonColor,
    Duration? seekBarTransitionDuration,
    Duration? seekBarThumbTransitionDuration,
    EdgeInsets? seekBarMargin,
    double? seekBarHeight,
    double? seekBarHoverHeight,
    double? seekBarContainerHeight,
    Color? seekBarColor,
    Color? seekBarHoverColor,
    Color? seekBarPositionColor,
    Color? seekBarBufferColor,
    double? seekBarThumbSize,
    Color? seekBarThumbColor,
    Color? volumeBarColor,
    Color? volumeBarActiveColor,
    double? volumeBarThumbSize,
    Color? volumeBarThumbColor,
    Duration? volumeBarTransitionDuration,
    bool? shiftSubtitlesOnControlsVisibilityChange,
  }) {
    return MaterialDesktopVideoControlsThemeData(
      displaySeekBar: displaySeekBar ?? this.displaySeekBar,
      automaticallyImplySkipNextButton: automaticallyImplySkipNextButton ??
          this.automaticallyImplySkipNextButton,
      automaticallyImplySkipPreviousButton:
          automaticallyImplySkipPreviousButton ??
              this.automaticallyImplySkipPreviousButton,
      toggleFullscreenOnDoublePress:
          toggleFullscreenOnDoublePress ?? this.toggleFullscreenOnDoublePress,
      playAndPauseOnTap: playAndPauseOnTap ?? this.playAndPauseOnTap,
      modifyVolumeOnScroll: modifyVolumeOnScroll ?? this.modifyVolumeOnScroll,
      keyboardShortcuts: keyboardShortcuts ?? this.keyboardShortcuts,
      visibleOnMount: visibleOnMount ?? this.visibleOnMount,
      hideMouseOnControlsRemoval:
          hideMouseOnControlsRemoval ?? this.hideMouseOnControlsRemoval,
      controlsHoverDuration:
          controlsHoverDuration ?? this.controlsHoverDuration,
      bufferingIndicatorBuilder:
          bufferingIndicatorBuilder ?? this.bufferingIndicatorBuilder,
      controlsTransitionDuration:
          controlsTransitionDuration ?? this.controlsTransitionDuration,
      topButtonBar: topButtonBar ?? this.topButtonBar,
      topButtonBarMargin: topButtonBarMargin ?? this.topButtonBarMargin,
      bottomButtonBar: bottomButtonBar ?? this.bottomButtonBar,
      bottomButtonBarMargin:
          bottomButtonBarMargin ?? this.bottomButtonBarMargin,
      buttonBarHeight: buttonBarHeight ?? this.buttonBarHeight,
      buttonBarButtonSize: buttonBarButtonSize ?? this.buttonBarButtonSize,
      buttonBarButtonColor: buttonBarButtonColor ?? this.buttonBarButtonColor,
      seekBarTransitionDuration:
          seekBarTransitionDuration ?? this.seekBarTransitionDuration,
      seekBarThumbTransitionDuration:
          seekBarThumbTransitionDuration ?? this.seekBarThumbTransitionDuration,
      seekBarMargin: seekBarMargin ?? this.seekBarMargin,
      seekBarHeight: seekBarHeight ?? this.seekBarHeight,
      seekBarHoverHeight: seekBarHoverHeight ?? this.seekBarHoverHeight,
      seekBarContainerHeight:
          seekBarContainerHeight ?? this.seekBarContainerHeight,
      seekBarColor: seekBarColor ?? this.seekBarColor,
      seekBarHoverColor: seekBarHoverColor ?? this.seekBarHoverColor,
      seekBarPositionColor: seekBarPositionColor ?? this.seekBarPositionColor,
      seekBarBufferColor: seekBarBufferColor ?? this.seekBarBufferColor,
      seekBarThumbSize: seekBarThumbSize ?? this.seekBarThumbSize,
      seekBarThumbColor: seekBarThumbColor ?? this.seekBarThumbColor,
      volumeBarColor: volumeBarColor ?? this.volumeBarColor,
      volumeBarActiveColor: volumeBarActiveColor ?? this.volumeBarActiveColor,
      volumeBarThumbSize: volumeBarThumbSize ?? this.volumeBarThumbSize,
      volumeBarThumbColor: volumeBarThumbColor ?? this.volumeBarThumbColor,
      volumeBarTransitionDuration:
          volumeBarTransitionDuration ?? this.volumeBarTransitionDuration,
      shiftSubtitlesOnControlsVisibilityChange:
          shiftSubtitlesOnControlsVisibilityChange ??
              this.shiftSubtitlesOnControlsVisibilityChange,
    );
  }
}

/// {@template material_desktop_video_controls_theme}
///
/// Inherited widget which provides [MaterialDesktopVideoControlsThemeData] to descendant widgets.
///
/// {@endtemplate}
class MaterialDesktopVideoControlsTheme extends InheritedWidget {
  final MaterialDesktopVideoControlsThemeData normal;
  final MaterialDesktopVideoControlsThemeData fullscreen;
  const MaterialDesktopVideoControlsTheme({
    super.key,
    required this.normal,
    required this.fullscreen,
    required super.child,
  });

  static MaterialDesktopVideoControlsTheme? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<
        MaterialDesktopVideoControlsTheme>();
  }

  static MaterialDesktopVideoControlsTheme of(BuildContext context) {
    final MaterialDesktopVideoControlsTheme? result = maybeOf(context);
    assert(
      result != null,
      'No [MaterialDesktopVideoControlsTheme] found in [context]',
    );
    return result!;
  }

  @override
  bool updateShouldNotify(MaterialDesktopVideoControlsTheme oldWidget) =>
      identical(normal, oldWidget.normal) &&
      identical(fullscreen, oldWidget.fullscreen);
}

/// {@macro material_desktop_video_controls}
class _MaterialDesktopVideoControls extends StatefulWidget {
  const _MaterialDesktopVideoControls();

  @override
  State<_MaterialDesktopVideoControls> createState() =>
      _MaterialDesktopVideoControlsState();
}

/// {@macro material_desktop_video_controls}
class _MaterialDesktopVideoControlsState
    extends State<_MaterialDesktopVideoControls> {
  late bool mount = _theme(context).visibleOnMount;
  late bool visible = _theme(context).visibleOnMount;

  Timer? _timer;

  late /* private */ var playlist = controller(context).player.state.playlist;
  late bool buffering = controller(context).player.state.buffering;

  DateTime last = DateTime.now();

  final List<StreamSubscription> subscriptions = [];

  double get subtitleVerticalShiftOffset =>
      (_theme(context).padding?.bottom ?? 0.0) +
      (_theme(context).bottomButtonBarMargin.vertical) +
      (_theme(context).bottomButtonBar.isNotEmpty
          ? _theme(context).buttonBarHeight
          : 0.0);

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (subscriptions.isEmpty) {
      subscriptions.addAll(
        [
          controller(context).player.stream.playlist.listen(
            (event) {
              setState(() {
                playlist = event;
              });
            },
          ),
          controller(context).player.stream.buffering.listen(
            (event) {
              setState(() {
                buffering = event;
              });
            },
          ),
        ],
      );

      if (_theme(context).visibleOnMount) {
        _timer = Timer(
          _theme(context).controlsHoverDuration,
          () {
            if (mounted) {
              setState(() {
                visible = false;
              });
              unshiftSubtitle();
            }
          },
        );
      }
    }
  }

  @override
  void dispose() {
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void shiftSubtitle() {
    if (_theme(context).shiftSubtitlesOnControlsVisibilityChange) {
      state(context).setSubtitleViewPadding(
        state(context).widget.subtitleViewConfiguration.padding +
            EdgeInsets.fromLTRB(
              0.0,
              0.0,
              0.0,
              subtitleVerticalShiftOffset,
            ),
      );
    }
  }

  void unshiftSubtitle() {
    if (_theme(context).shiftSubtitlesOnControlsVisibilityChange) {
      state(context).setSubtitleViewPadding(
        state(context).widget.subtitleViewConfiguration.padding,
      );
    }
  }

  void onHover() {
    setState(() {
      mount = true;
      visible = true;
    });
    shiftSubtitle();
    _timer?.cancel();
    _timer = Timer(_theme(context).controlsHoverDuration, () {
      if (mounted) {
        setState(() {
          visible = false;
        });
        unshiftSubtitle();
      }
    });
  }

  void onEnter() {
    setState(() {
      mount = true;
      visible = true;
    });
    shiftSubtitle();
    _timer?.cancel();
    _timer = Timer(_theme(context).controlsHoverDuration, () {
      if (mounted) {
        setState(() {
          visible = false;
        });
        unshiftSubtitle();
      }
    });
  }

  void onExit() {
    setState(() {
      visible = false;
    });
    unshiftSubtitle();
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        focusColor: const Color(0x00000000),
        hoverColor: const Color(0x00000000),
        splashColor: const Color(0x00000000),
        highlightColor: const Color(0x00000000),
      ),
      child: CallbackShortcuts(
        bindings: _theme(context).keyboardShortcuts ??
            {
              // Default key-board shortcuts.
              // https://support.google.com/youtube/answer/7631406
              const SingleActivator(LogicalKeyboardKey.mediaPlay): () =>
                  controller(context).player.play(),
              const SingleActivator(LogicalKeyboardKey.mediaPause): () =>
                  controller(context).player.pause(),
              const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () =>
                  controller(context).player.playOrPause(),
              const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () =>
                  controller(context).player.next(),
              const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious):
                  () => controller(context).player.previous(),
              const SingleActivator(LogicalKeyboardKey.space): () =>
                  controller(context).player.playOrPause(),
              const SingleActivator(LogicalKeyboardKey.keyJ): () {
                final rate = controller(context).player.state.position -
                    const Duration(seconds: 10);
                controller(context).player.seek(rate);
              },
              const SingleActivator(LogicalKeyboardKey.keyI): () {
                final rate = controller(context).player.state.position +
                    const Duration(seconds: 10);
                controller(context).player.seek(rate);
              },
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
                final rate = controller(context).player.state.position -
                    const Duration(seconds: 2);
                controller(context).player.seek(rate);
              },
              const SingleActivator(LogicalKeyboardKey.arrowRight): () {
                final rate = controller(context).player.state.position +
                    const Duration(seconds: 2);
                controller(context).player.seek(rate);
              },
              const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                final volume = controller(context).player.state.volume + 5.0;
                controller(context).player.setVolume(volume.clamp(0.0, 100.0));
              },
              const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                final volume = controller(context).player.state.volume - 5.0;
                controller(context).player.setVolume(volume.clamp(0.0, 100.0));
              },
              const SingleActivator(LogicalKeyboardKey.keyF): () =>
                  toggleFullscreen(context),
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  exitFullscreen(context),
            },
        child: Focus(
          autofocus: true,
          child: Material(
            elevation: 0.0,
            borderOnForeground: false,
            animationDuration: Duration.zero,
            color: const Color(0x00000000),
            shadowColor: const Color(0x00000000),
            surfaceTintColor: const Color(0x00000000),
            child: Listener(
              onPointerSignal: _theme(context).modifyVolumeOnScroll
                  ? (e) {
                      if (e is PointerScrollEvent) {
                        if (e.delta.dy > 0) {
                          final volume =
                              controller(context).player.state.volume - 5.0;
                          controller(context)
                              .player
                              .setVolume(volume.clamp(0.0, 100.0));
                        }
                        if (e.delta.dy < 0) {
                          final volume =
                              controller(context).player.state.volume + 5.0;
                          controller(context)
                              .player
                              .setVolume(volume.clamp(0.0, 100.0));
                        }
                      }
                    }
                  : null,
              child: GestureDetector(
                onTapDown: !_theme(context).playAndPauseOnTap
                    ? null
                    : (TapDownDetails details) {
                        final RenderBox box =
                            context.findRenderObject() as RenderBox;
                        final Offset localPosition =
                            box.globalToLocal(details.globalPosition);
                        const double tapPadding = 10.0;
                        if (!mount ||
                            localPosition.dy <
                                box.size.height -
                                    subtitleVerticalShiftOffset -
                                    tapPadding) {
                          // Only play and pause when the bottom seek bar is visible
                          // and when clicking outside of the bottom seek bar region
                          controller(context).player.playOrPause();
                        }
                      },
                onTapUp: !_theme(context).toggleFullscreenOnDoublePress
                    ? null
                    : (e) {
                        final now = DateTime.now();
                        final difference = now.difference(last);
                        last = now;
                        if (difference < const Duration(milliseconds: 400)) {
                          toggleFullscreen(context);
                        }
                      },
                onPanUpdate: _theme(context).modifyVolumeOnScroll
                    ? (e) {
                        if (e.delta.dy > 0) {
                          final volume =
                              controller(context).player.state.volume - 5.0;
                          controller(context)
                              .player
                              .setVolume(volume.clamp(0.0, 100.0));
                        }
                        if (e.delta.dy < 0) {
                          final volume =
                              controller(context).player.state.volume + 5.0;
                          controller(context)
                              .player
                              .setVolume(volume.clamp(0.0, 100.0));
                        }
                      }
                    : null,
                child: MouseRegion(
                  cursor: (_theme(context).hideMouseOnControlsRemoval && !mount)
                      ? SystemMouseCursors.none
                      : SystemMouseCursors.basic,
                  onHover: (_) => onHover(),
                  onEnter: (_) => onEnter(),
                  onExit: (_) => onExit(),
                  child: Stack(
                    children: [
                      AnimatedOpacity(
                        curve: Curves.easeInOut,
                        opacity: visible ? 1.0 : 0.0,
                        duration: _theme(context).controlsTransitionDuration,
                        onEnd: () {
                          if (!visible) {
                            setState(() {
                              mount = false;
                            });
                          }
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.bottomCenter,
                          children: [
                            // Top gradient.
                            if (_theme(context).topButtonBar.isNotEmpty)
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: [
                                      0.0,
                                      0.2,
                                    ],
                                    colors: [
                                      Color(0x61000000),
                                      Color(0x00000000),
                                    ],
                                  ),
                                ),
                              ),
                            // Bottom gradient.
                            if (_theme(context).bottomButtonBar.isNotEmpty)
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: [
                                      0.5,
                                      1.0,
                                    ],
                                    colors: [
                                      Color(0x00000000),
                                      Color(0x61000000),
                                    ],
                                  ),
                                ),
                              ),
                            if (mount)
                              Padding(
                                padding: _theme(context).padding ??
                                    (
                                        // Add padding in fullscreen!
                                        isFullscreen(context)
                                            ? MediaQuery.of(context).padding
                                            : EdgeInsets.zero),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      height: _theme(context).buttonBarHeight,
                                      margin:
                                          _theme(context).topButtonBarMargin,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: _theme(context).topButtonBar,
                                      ),
                                    ),
                                    // Only display [primaryButtonBar] if [buffering] is false.
                                    Expanded(
                                      child: AnimatedOpacity(
                                        curve: Curves.easeInOut,
                                        opacity: buffering ? 0.0 : 1.0,
                                        duration: _theme(context)
                                            .controlsTransitionDuration,
                                        child: Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: _theme(context)
                                                .primaryButtonBar,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_theme(context).displaySeekBar)
                                      Transform.translate(
                                        offset: _theme(context)
                                                .bottomButtonBar
                                                .isNotEmpty
                                            ? const Offset(0.0, 16.0)
                                            : Offset.zero,
                                        child: MaterialDesktopSeekBar(
                                          onSeekStart: () {
                                            _timer?.cancel();
                                          },
                                          onSeekEnd: () {
                                            _timer = Timer(
                                              _theme(context)
                                                  .controlsHoverDuration,
                                              () {
                                                if (mounted) {
                                                  setState(() {
                                                    visible = false;
                                                  });
                                                  unshiftSubtitle();
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    if (_theme(context)
                                        .bottomButtonBar
                                        .isNotEmpty)
                                      Container(
                                        height: _theme(context).buttonBarHeight,
                                        margin: _theme(context)
                                            .bottomButtonBarMargin,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children:
                                              _theme(context).bottomButtonBar,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Buffering Indicator.
                      IgnorePointer(
                        child: Padding(
                          padding: _theme(context).padding ??
                              (
                                  // Add padding in fullscreen!
                                  isFullscreen(context)
                                      ? MediaQuery.of(context).padding
                                      : EdgeInsets.zero),
                          child: Column(
                            children: [
                              Container(
                                height: _theme(context).buttonBarHeight,
                                margin: _theme(context).topButtonBarMargin,
                              ),
                              Expanded(
                                child: Center(
                                  child: Center(
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                        begin: 0.0,
                                        end: buffering ? 1.0 : 0.0,
                                      ),
                                      duration: _theme(context)
                                          .controlsTransitionDuration,
                                      builder: (context, value, child) {
                                        // Only mount the buffering indicator if the opacity is greater than 0.0.
                                        // This has been done to prevent redundant resource usage in [CircularProgressIndicator].
                                        if (value > 0.0) {
                                          return Opacity(
                                            opacity: value,
                                            child: _theme(context)
                                                    .bufferingIndicatorBuilder
                                                    ?.call(context) ??
                                                child!,
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                      child: const CircularProgressIndicator(
                                        color: Color(0xFFFFFFFF),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                height: _theme(context).buttonBarHeight,
                                margin: _theme(context).bottomButtonBarMargin,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// SEEK BAR

/// Material design seek bar.
class MaterialDesktopSeekBar extends StatefulWidget {
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;

  const MaterialDesktopSeekBar({
    Key? key,
    this.onSeekStart,
    this.onSeekEnd,
  }) : super(key: key);

  @override
  MaterialDesktopSeekBarState createState() => MaterialDesktopSeekBarState();
}

class MaterialDesktopSeekBarState extends State<MaterialDesktopSeekBar> {
  bool hover = false;
  bool click = false;
  double slider = 0.0;

  late bool playing = controller(context).player.state.playing;
  late Duration position = controller(context).player.state.position;
  late Duration duration = controller(context).player.state.duration;
  late Duration buffer = controller(context).player.state.buffer;

  final List<StreamSubscription> subscriptions = [];

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (subscriptions.isEmpty) {
      subscriptions.addAll(
        [
          controller(context).player.stream.playing.listen((event) {
            setState(() {
              playing = event;
            });
          }),
          controller(context).player.stream.completed.listen((event) {
            setState(() {
              position = Duration.zero;
            });
          }),
          controller(context).player.stream.position.listen((event) {
            setState(() {
              if (!click) position = event;
            });
          }),
          controller(context).player.stream.duration.listen((event) {
            setState(() {
              duration = event;
            });
          }),
          controller(context).player.stream.buffer.listen((event) {
            setState(() {
              buffer = event;
            });
          }),
        ],
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void onPointerMove(PointerMoveEvent e, BoxConstraints constraints) {
    final percent = e.localPosition.dx / constraints.maxWidth;
    setState(() {
      hover = true;
      slider = percent.clamp(0.0, 1.0);
    });
    controller(context).player.seek(duration * slider);
  }

  void onPointerDown() {
    widget.onSeekStart?.call();
    setState(() {
      click = true;
    });
  }

  void onPointerUp() {
    widget.onSeekEnd?.call();
    setState(() {
      // Explicitly set the position to prevent the slider from jumping.
      click = false;
      position = duration * slider;
    });
    controller(context).player.seek(duration * slider);
  }

  void onHover(PointerHoverEvent e, BoxConstraints constraints) {
    final percent = e.localPosition.dx / constraints.maxWidth;
    setState(() {
      hover = true;
      slider = percent.clamp(0.0, 1.0);
    });
  }

  void onEnter(PointerEnterEvent e, BoxConstraints constraints) {
    final percent = e.localPosition.dx / constraints.maxWidth;
    setState(() {
      hover = true;
      slider = percent.clamp(0.0, 1.0);
    });
  }

  void onExit(PointerExitEvent e, BoxConstraints constraints) {
    setState(() {
      hover = false;
      slider = 0.0;
    });
  }

  /// Returns the current playback position in percentage.
  double get positionPercent {
    if (position == Duration.zero || duration == Duration.zero) {
      return 0.0;
    } else {
      final value = position.inMilliseconds / duration.inMilliseconds;
      return value.clamp(0.0, 1.0);
    }
  }

  /// Returns the current playback buffer position in percentage.
  double get bufferPercent {
    if (buffer == Duration.zero || duration == Duration.zero) {
      return 0.0;
    } else {
      final value = buffer.inMilliseconds / duration.inMilliseconds;
      return value.clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.none,
      margin: _theme(context).seekBarMargin,
      child: LayoutBuilder(
        builder: (context, constraints) => MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: (e) => onHover(e, constraints),
          onEnter: (e) => onEnter(e, constraints),
          onExit: (e) => onExit(e, constraints),
          child: Listener(
            onPointerMove: (e) => onPointerMove(e, constraints),
            onPointerDown: (e) => onPointerDown(),
            onPointerUp: (e) => onPointerUp(),
            child: Container(
              color: const Color(0x00000000),
              width: constraints.maxWidth,
              height: _theme(context).seekBarContainerHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  AnimatedContainer(
                    width: constraints.maxWidth,
                    height: hover
                        ? _theme(context).seekBarHoverHeight
                        : _theme(context).seekBarHeight,
                    alignment: Alignment.centerLeft,
                    duration: _theme(context).seekBarThumbTransitionDuration,
                    color: _theme(context).seekBarColor,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          width: constraints.maxWidth * slider,
                          color: _theme(context).seekBarHoverColor,
                        ),
                        Container(
                          width: constraints.maxWidth * bufferPercent,
                          color: _theme(context).seekBarBufferColor,
                        ),
                        Container(
                          width: click
                              ? constraints.maxWidth * slider
                              : constraints.maxWidth * positionPercent,
                          color: _theme(context).seekBarPositionColor,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: click
                        ? (constraints.maxWidth -
                                _theme(context).seekBarThumbSize / 2) *
                            slider
                        : (constraints.maxWidth -
                                _theme(context).seekBarThumbSize / 2) *
                            positionPercent,
                    child: AnimatedContainer(
                      width: hover || click
                          ? _theme(context).seekBarThumbSize
                          : 0.0,
                      height: hover || click
                          ? _theme(context).seekBarThumbSize
                          : 0.0,
                      duration: _theme(context).seekBarThumbTransitionDuration,
                      decoration: BoxDecoration(
                        color: _theme(context).seekBarThumbColor,
                        borderRadius: BorderRadius.circular(
                          _theme(context).seekBarThumbSize / 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// BUTTON: PLAY/PAUSE

/// A material design play/pause button.
class MaterialDesktopPlayOrPauseButton extends StatefulWidget {
  /// Overriden icon size for [MaterialDesktopSkipPreviousButton].
  final double? iconSize;

  /// Overriden icon color for [MaterialDesktopSkipPreviousButton].
  final Color? iconColor;

  const MaterialDesktopPlayOrPauseButton({
    super.key,
    this.iconSize,
    this.iconColor,
  });

  @override
  MaterialDesktopPlayOrPauseButtonState createState() =>
      MaterialDesktopPlayOrPauseButtonState();
}

class MaterialDesktopPlayOrPauseButtonState
    extends State<MaterialDesktopPlayOrPauseButton>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    value: controller(context).player.state.playing ? 1 : 0,
    duration: const Duration(milliseconds: 200),
  );

  StreamSubscription<bool>? subscription;

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    subscription ??= controller(context).player.stream.playing.listen((event) {
      if (event) {
        animation.forward();
      } else {
        animation.reverse();
      }
    });
  }

  @override
  void dispose() {
    animation.dispose();
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: controller(context).player.playOrPause,
      iconSize: widget.iconSize ?? _theme(context).buttonBarButtonSize,
      color: widget.iconColor ?? _theme(context).buttonBarButtonColor,
      icon: AnimatedIcon(
        progress: animation,
        icon: AnimatedIcons.play_pause,
        size: widget.iconSize ?? _theme(context).buttonBarButtonSize,
        color: widget.iconColor ?? _theme(context).buttonBarButtonColor,
      ),
    );
  }
}

// BUTTON: SKIP NEXT

/// MaterialDesktop design skip next button.
class MaterialDesktopSkipNextButton extends StatelessWidget {
  /// Icon for [MaterialDesktopSkipNextButton].
  final Widget? icon;

  /// Overriden icon size for [MaterialDesktopSkipNextButton].
  final double? iconSize;

  /// Overriden icon color for [MaterialDesktopSkipNextButton].
  final Color? iconColor;

  const MaterialDesktopSkipNextButton({
    Key? key,
    this.icon,
    this.iconSize,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!_theme(context).automaticallyImplySkipNextButton ||
        (controller(context).player.state.playlist.medias.length > 1 &&
            _theme(context).automaticallyImplySkipNextButton)) {
      return IconButton(
        onPressed: controller(context).player.next,
        icon: icon ?? const Icon(Icons.skip_next),
        iconSize: iconSize ?? _theme(context).buttonBarButtonSize,
        color: iconColor ?? _theme(context).buttonBarButtonColor,
      );
    }
    return const SizedBox.shrink();
  }
}

// BUTTON: SKIP PREVIOUS

/// MaterialDesktop design skip previous button.
class MaterialDesktopSkipPreviousButton extends StatelessWidget {
  /// Icon for [MaterialDesktopSkipPreviousButton].
  final Widget? icon;

  /// Overriden icon size for [MaterialDesktopSkipPreviousButton].
  final double? iconSize;

  /// Overriden icon color for [MaterialDesktopSkipPreviousButton].
  final Color? iconColor;

  const MaterialDesktopSkipPreviousButton({
    Key? key,
    this.icon,
    this.iconSize,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!_theme(context).automaticallyImplySkipPreviousButton ||
        (controller(context).player.state.playlist.medias.length > 1 &&
            _theme(context).automaticallyImplySkipPreviousButton)) {
      return IconButton(
        onPressed: controller(context).player.previous,
        icon: icon ?? const Icon(Icons.skip_previous),
        iconSize: iconSize ?? _theme(context).buttonBarButtonSize,
        color: iconColor ?? _theme(context).buttonBarButtonColor,
      );
    }
    return const SizedBox.shrink();
  }
}

// BUTTON: FULL SCREEN

/// MaterialDesktop design fullscreen button.
class MaterialDesktopFullscreenButton extends StatelessWidget {
  /// Icon for [MaterialDesktopFullscreenButton].
  final Widget? icon;

  /// Overriden icon size for [MaterialDesktopFullscreenButton].
  final double? iconSize;

  /// Overriden icon color for [MaterialDesktopFullscreenButton].
  final Color? iconColor;

  const MaterialDesktopFullscreenButton({
    Key? key,
    this.icon,
    this.iconSize,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => toggleFullscreen(context),
      icon: icon ??
          (isFullscreen(context)
              ? const Icon(Icons.fullscreen_exit)
              : const Icon(Icons.fullscreen)),
      iconSize: iconSize ?? _theme(context).buttonBarButtonSize,
      color: iconColor ?? _theme(context).buttonBarButtonColor,
    );
  }
}

// BUTTON: CUSTOM

/// MaterialDesktop design custom button.
class MaterialDesktopCustomButton extends StatelessWidget {
  /// Icon for [MaterialDesktopCustomButton].
  final Widget? icon;

  /// Icon size for [MaterialDesktopCustomButton].
  final double? iconSize;

  /// Icon color for [MaterialDesktopCustomButton].
  final Color? iconColor;

  /// The callback that is called when the button is tapped or otherwise activated.
  final VoidCallback onPressed;

  const MaterialDesktopCustomButton({
    Key? key,
    this.icon,
    this.iconSize,
    this.iconColor,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: icon ?? const Icon(Icons.settings),
      iconSize: iconSize ?? _theme(context).buttonBarButtonSize,
      color: iconColor ?? _theme(context).buttonBarButtonColor,
    );
  }
}

// BUTTON: VOLUME

/// MaterialDesktop design volume button & slider.
class MaterialDesktopVolumeButton extends StatefulWidget {
  /// Icon size for the volume button.
  final double? iconSize;

  /// Icon color for the volume button.
  final Color? iconColor;

  /// Mute icon.
  final Widget? volumeMuteIcon;

  /// Low volume icon.
  final Widget? volumeLowIcon;

  /// High volume icon.
  final Widget? volumeHighIcon;

  /// Width for the volume slider.
  final double? sliderWidth;

  const MaterialDesktopVolumeButton({
    super.key,
    this.iconSize,
    this.iconColor,
    this.volumeMuteIcon,
    this.volumeLowIcon,
    this.volumeHighIcon,
    this.sliderWidth,
  });

  @override
  MaterialDesktopVolumeButtonState createState() =>
      MaterialDesktopVolumeButtonState();
}

class MaterialDesktopVolumeButtonState
    extends State<MaterialDesktopVolumeButton>
    with SingleTickerProviderStateMixin {
  late double volume = controller(context).player.state.volume;

  StreamSubscription<double>? subscription;

  bool hover = false;

  bool mute = false;
  double _volume = 0.0;

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    subscription ??= controller(context).player.stream.volume.listen((event) {
      setState(() {
        volume = event;
      });
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (e) {
        setState(() {
          hover = true;
        });
      },
      onExit: (e) {
        setState(() {
          hover = false;
        });
      },
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            if (event.scrollDelta.dy < 0) {
              controller(context).player.setVolume(
                    (volume + 5.0).clamp(0.0, 100.0),
                  );
            }
            if (event.scrollDelta.dy > 0) {
              controller(context).player.setVolume(
                    (volume - 5.0).clamp(0.0, 100.0),
                  );
            }
          }
        },
        child: Row(
          children: [
            const SizedBox(width: 4.0),
            IconButton(
              onPressed: () async {
                if (mute) {
                  await controller(context).player.setVolume(_volume);
                  mute = !mute;
                }
                // https://github.com/media-kit/media-kit/pull/250#issuecomment-1605588306
                else if (volume == 0.0) {
                  _volume = 100.0;
                  await controller(context).player.setVolume(100.0);
                  mute = false;
                } else {
                  _volume = volume;
                  await controller(context).player.setVolume(0.0);
                  mute = !mute;
                }

                setState(() {});
              },
              iconSize: widget.iconSize ??
                  (_theme(context).buttonBarButtonSize * 0.8),
              color: widget.iconColor ?? _theme(context).buttonBarButtonColor,
              icon: AnimatedSwitcher(
                duration: _theme(context).volumeBarTransitionDuration,
                child: volume == 0.0
                    ? (widget.volumeMuteIcon ??
                        const Icon(
                          Icons.volume_off,
                          key: ValueKey(Icons.volume_off),
                        ))
                    : volume < 50.0
                        ? (widget.volumeLowIcon ??
                            const Icon(
                              Icons.volume_down,
                              key: ValueKey(Icons.volume_down),
                            ))
                        : (widget.volumeHighIcon ??
                            const Icon(
                              Icons.volume_up,
                              key: ValueKey(Icons.volume_up),
                            )),
              ),
            ),
            AnimatedOpacity(
              opacity: hover ? 1.0 : 0.0,
              duration: _theme(context).volumeBarTransitionDuration,
              child: AnimatedContainer(
                width:
                    hover ? (12.0 + (widget.sliderWidth ?? 52.0) + 18.0) : 12.0,
                duration: _theme(context).volumeBarTransitionDuration,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const SizedBox(width: 12.0),
                      SizedBox(
                        width: widget.sliderWidth ?? 52.0,
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 1.2,
                            inactiveTrackColor: _theme(context).volumeBarColor,
                            activeTrackColor:
                                _theme(context).volumeBarActiveColor,
                            thumbColor: _theme(context).volumeBarThumbColor,
                            thumbShape: RoundSliderThumbShape(
                              enabledThumbRadius:
                                  _theme(context).volumeBarThumbSize / 2,
                              elevation: 0.0,
                              pressedElevation: 0.0,
                            ),
                            trackShape: _CustomTrackShape(),
                            overlayColor: const Color(0x00000000),
                          ),
                          child: Slider(
                            value: volume.clamp(0.0, 100.0),
                            min: 0.0,
                            max: 100.0,
                            onChanged: (value) async {
                              await controller(context).player.setVolume(value);
                              mute = false;
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 18.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// POSITION INDICATOR

/// MaterialDesktop design position indicator.
class MaterialDesktopPositionIndicator extends StatefulWidget {
  /// Overriden [TextStyle] for the [MaterialDesktopPositionIndicator].
  final TextStyle? style;
  const MaterialDesktopPositionIndicator({super.key, this.style});

  @override
  MaterialDesktopPositionIndicatorState createState() =>
      MaterialDesktopPositionIndicatorState();
}

class MaterialDesktopPositionIndicatorState
    extends State<MaterialDesktopPositionIndicator> {
  late Duration position = controller(context).player.state.position;
  late Duration duration = controller(context).player.state.duration;

  final List<StreamSubscription> subscriptions = [];

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (subscriptions.isEmpty) {
      subscriptions.addAll(
        [
          controller(context).player.stream.position.listen((event) {
            setState(() {
              position = event;
            });
          }),
          controller(context).player.stream.duration.listen((event) {
            setState(() {
              duration = event;
            });
          }),
        ],
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${position.label(reference: duration)} / ${duration.label(reference: duration)}',
      style: widget.style ??
          TextStyle(
            height: 1.0,
            fontSize: 12.0,
            color: _theme(context).buttonBarButtonColor,
          ),
    );
  }
}

class _CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final height = sliderTheme.trackHeight;
    final left = offset.dx;
    final top = offset.dy + (parentBox.size.height - height!) / 2;
    final width = parentBox.size.width;
    return Rect.fromLTWH(
      left,
      top,
      width,
      height,
    );
  }
}
