import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

/// Material 3 Expressive loading indicator, ported from Compose Material3.
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
  /// Seconds the indicator has been running.
  late final _elapsed = AnimationController.unbounded(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _elapsed.stop();
    } else if (!_elapsed.isAnimating) {
      _elapsed.animateWith(_Clock(_elapsed.value));
    }
  }

  @override
  void dispose() {
    _elapsed.dispose();
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
              elapsed: _elapsed,
              color: widget.color ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Clock extends Simulation {
  _Clock(this.start);

  final double start;

  @override
  double x(double time) => start + time;

  @override
  double dx(double time) => 1;

  @override
  bool isDone(double time) => false;
}

class _LoadingShapePainter extends CustomPainter {
  _LoadingShapePainter({required this.elapsed, required this.color})
      : super(repaint: elapsed);

  static const _morphInterval = 0.65;
  static const _rotationPeriod = 4.666;
  static final _morphProgress = SpringSimulation(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 200, ratio: 0.6),
    0,
    1,
    0,
  );
  static final _shapes = [
    MaterialShapes.softBurst,
    MaterialShapes.cookie9Sided,
    MaterialShapes.pentagon,
    MaterialShapes.pill,
    MaterialShapes.sunny,
    MaterialShapes.cookie4Sided,
    MaterialShapes.oval,
  ];
  // Share expensive morph matching across indicator instances.
  static final _morphs = List.generate(
    _shapes.length,
    (index) => Morph(_shapes[index], _shapes[(index + 1) % _shapes.length]),
  );
  // A 38dp indicator in a 48dp container, shrunk further so that no shape
  // leaves it while rotating.
  static final _scale = 38 / 48 * _shapes.map(_rotationFit).reduce(math.min);

  static double _rotationFit(RoundedPolygon shape) {
    final bounds = shape.calculateBounds();
    final maxBounds = shape.calculateMaxBounds();
    return math.max(
      (bounds[2] - bounds[0]) / (maxBounds[2] - maxBounds[0]),
      (bounds[3] - bounds[1]) / (maxBounds[3] - maxBounds[1]),
    );
  }

  final Animation<double> elapsed;
  final Color color;
  final Path _path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final time = elapsed.value;
    final step = (time / _morphInterval).floor();
    final progress = _morphProgress.x(time - step * _morphInterval);
    final path = _morphs[step % _morphs.length].toPath(
      progress: progress,
      path: _path,
    );
    // Every morph adds a quarter turn to the steady rotation.
    final turns = (step + 1 + progress) / 4 + time / _rotationPeriod;
    final center = path.getBounds().center;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(turns * math.pi * 2);
    canvas.scale(size.width * _scale, size.height * _scale);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LoadingShapePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.elapsed != elapsed;
}
