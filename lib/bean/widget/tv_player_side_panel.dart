import 'package:flutter/material.dart';

/// A single translucent background. Children must not repaint canvasColor.
class TvPlayerSidePanel extends StatelessWidget {
  const TvPlayerSidePanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Theme.of(context).canvasColor.withValues(alpha: 0.64),
        child: child,
      );
}
