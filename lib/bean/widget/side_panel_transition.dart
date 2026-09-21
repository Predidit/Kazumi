import 'package:flutter/material.dart';

class SidePanelTransition extends StatelessWidget {
  const SidePanelTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  static const duration = Duration(milliseconds: 120);

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation.drive(CurveTween(curve: Curves.easeOut))),
        child: child,
      );
}
