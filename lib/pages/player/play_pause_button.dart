import 'package:flutter/material.dart';

class PlayPauseButton extends StatefulWidget {
  final bool playing;
  final VoidCallback onPressed;
  final double iconSize;
  final Color? iconColor;
  final String? tooltip;

  const PlayPauseButton({super.key,
    required this.playing,
    required this.onPressed,
    this.iconSize = 25,
    this.tooltip, this.iconColor});

  @override
  State<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton>
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
  void didUpdateWidget(covariant PlayPauseButton oldWidget) {
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
    return IconButton(
      onPressed: widget.onPressed,
      iconSize: widget.iconSize,
      tooltip: widget.tooltip,
      color: widget.iconColor,
      icon: AnimatedIcon(
        icon: AnimatedIcons.play_pause,
        progress: _controller,
      ),
    );
  }
}
