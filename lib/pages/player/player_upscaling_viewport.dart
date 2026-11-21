import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kazumi/services/enhancement/upscaling_output.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Supplies the pixel-size viewport to libmpv. Scaling only the Flutter
/// texture would bypass mpv's neural upscalers entirely.
class PlayerUpscalingViewport extends StatefulWidget {
  const PlayerUpscalingViewport({
    super.key,
    required this.controller,
    required this.enabled,
    required this.fit,
    required this.maximumEdge,
    required this.child,
  });

  final VideoController controller;
  final bool enabled;
  final BoxFit fit;
  final int maximumEdge;
  final Widget child;

  @override
  State<PlayerUpscalingViewport> createState() =>
      _PlayerUpscalingViewportState();
}

typedef _OutputSize = ({int width, int height});

class _PlayerUpscalingViewportState extends State<PlayerUpscalingViewport> {
  _OutputSize? _requested;
  _OutputSize? _applied;
  Timer? _settle;
  bool _resizing = false;

  void _request(_OutputSize? size) {
    if (_requested == size) return;
    _requested = size;
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 300), () {
      _settle = null;
      unawaited(_applyPending());
    });
  }

  Future<void> _applyPending() async {
    if (!mounted || _resizing || _applied == _requested) return;
    final size = _requested;
    _resizing = true;
    try {
      await widget.controller.setSize(width: size?.width, height: size?.height);
      _applied = size;
    } catch (error) {
      if (mounted) KazumiLogger().w('Video output resize failed', error: error);
    } finally {
      _resizing = false;
      if (mounted && _settle == null && size != _requested) {
        unawaited(_applyPending());
      }
    }
  }

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final density = MediaQuery.devicePixelRatioOf(context);
    final player = widget.controller.player;
    return LayoutBuilder(
      builder: (context, constraints) {
        return StreamBuilder<VideoParams>(
          stream: player.stream.videoParams,
          initialData: player.state.videoParams,
          builder: (_, snapshot) {
            final source = snapshot.data;
            final quarterTurn = source?.rotate == 90 || source?.rotate == 270;
            _request(
              upscalingOutputSize(
                sourceWidth: (quarterTurn ? source?.dh : source?.dw) ?? 0,
                sourceHeight: (quarterTurn ? source?.dw : source?.dh) ?? 0,
                viewportWidth: constraints.maxWidth * density,
                viewportHeight: constraints.maxHeight * density,
                enabled: widget.enabled,
                maximumEdge: widget.maximumEdge,
                fill: widget.fit == BoxFit.cover || widget.fit == BoxFit.fill,
              ),
            );
            return widget.child;
          },
        );
      },
    );
  }
}
