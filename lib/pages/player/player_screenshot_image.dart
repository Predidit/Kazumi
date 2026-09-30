import 'dart:typed_data';

import 'package:flutter/material.dart';

class PlayerScreenshotImage extends StatelessWidget {
  const PlayerScreenshotImage({
    super.key,
    required this.bytes,
    this.fit = BoxFit.contain,
    this.cacheWidth,
    this.semanticLabel,
  });

  final Uint8List bytes;
  final BoxFit fit;
  final int? cacheWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Image.memory(
    bytes,
    fit: fit,
    width: double.infinity,
    height: double.infinity,
    cacheWidth: cacheWidth,
    gaplessPlayback: true,
    semanticLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
    frameBuilder: (context, child, frame, synchronouslyLoaded) {
      if (synchronouslyLoaded || MediaQuery.disableAnimationsOf(context)) {
        return child;
      }
      return AnimatedOpacity(
        opacity: frame == null ? 0 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: child,
      );
    },
    errorBuilder: (context, error, stack) => Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
