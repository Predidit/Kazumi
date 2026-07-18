import 'package:flutter/material.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';

class PlayPauseIcon extends StatefulWidget {
  final bool playing;
  final double iconSize;
  final Color? iconColor;
  final bool disableAnimations;

  const PlayPauseIcon({
    super.key,
    required this.playing,
    this.iconSize = 25,
    this.iconColor,
    this.disableAnimations = false,
  });

  @override
  State<PlayPauseIcon> createState() => _PlayPauseIconState();
}

class _PlayPauseIconState extends State<PlayPauseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.disableAnimations
          ? Duration.zero
          : KazumiDesignTokens.motionStandard,
      value: widget.playing ? 1.0 : 0.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlayPauseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.disableAnimations != widget.disableAnimations) {
      _controller.duration = widget.disableAnimations
          ? Duration.zero
          : KazumiDesignTokens.motionStandard;
      if (widget.disableAnimations) {
        _controller.value = widget.playing ? 1 : 0;
      }
    }

    if (oldWidget.playing != widget.playing) {
      if (widget.playing) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedIcon(
      color: widget.iconColor,
      size: widget.iconSize,
      icon: AnimatedIcons.play_pause,
      progress: _controller,
    );
  }
}
