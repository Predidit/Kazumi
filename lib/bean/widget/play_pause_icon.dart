import 'package:flutter/material.dart';

class PlayPauseIcon extends StatefulWidget {
  final bool playing;
  final double iconSize;
  final Color? iconColor;

  const PlayPauseIcon(
      {super.key, required this.playing, this.iconSize = 25, this.iconColor});

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
      duration: const Duration(milliseconds: 300),
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
