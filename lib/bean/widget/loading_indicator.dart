import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

class LoadingIndicator extends StatefulWidget {
  const LoadingIndicator({
    super.key,
    this.size = 48,
    this.color,
    this.semanticsLabel = '加载中',
  });

  final double size;
  final Color? color;
  final String semanticsLabel;

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with SingleTickerProviderStateMixin {
  static final _shapes = [
    MaterialShapes.softBurst,
    MaterialShapes.cookie9Sided,
    MaterialShapes.pill,
    MaterialShapes.sunny,
    MaterialShapes.cookie4Sided,
    MaterialShapes.oval,
    MaterialShapes.cookie7Sided,
  ];
  // Share expensive morph matching across indicator instances.
  static final _morphs = List.generate(
    _shapes.length,
    (index) => Morph(_shapes[index], _shapes[(index + 1) % _shapes.length]),
  );

  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 650 * _shapes.length),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: _LoadingShapePainter(
              animation: _controller,
              morphs: _morphs,
              color: widget.color ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingShapePainter extends CustomPainter {
  _LoadingShapePainter({
    required this.animation,
    required this.morphs,
    required this.color,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<Morph> morphs;
  final Color color;
  final Path _path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final position = animation.value * morphs.length;
    final index = position.floor() % morphs.length;
    final progress = Curves.easeInOutCubicEmphasized.transform(position % 1);
    final path = morphs[index].toPath(progress: progress, path: _path);
    // Fit the diagonal so rotation stays inside small indicator slots.
    final scale = size.shortestSide / math.sqrt2;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(animation.value * math.pi * 2);
    canvas.scale(scale);
    canvas.translate(-0.5, -0.5);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LoadingShapePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.animation != animation ||
      oldDelegate.morphs != morphs;
}
