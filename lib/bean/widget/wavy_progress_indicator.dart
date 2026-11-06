import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

/// A flowing wavy progress indicator. A null value indicates ongoing work.
class WavyProgressIndicator extends StatefulWidget {
  const WavyProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.trackColor,
    this.height = 10,
    this.semanticsLabel = '加载中',
  }) : assert(height >= 4);

  final double? value;
  final Color? color;
  final Color? trackColor;

  /// Total height of the wave, including its stroke; 10 is the Material default.
  final double height;
  final String semanticsLabel;

  @override
  State<WavyProgressIndicator> createState() => _WavyProgressIndicatorState();
}

class _WavyProgressIndicatorState extends State<WavyProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
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
    final colors = Theme.of(context).colorScheme;
    final progress = widget.value?.clamp(0.0, 1.0);
    return Semantics(
      label: widget.semanticsLabel,
      value: progress == null ? null : '${(progress * 100).round()}%',
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(
          painter: _WavyProgressPainter(
            animation: _controller,
            value: progress,
            color: widget.color ?? colors.primary,
            trackColor: widget.trackColor ?? colors.surfaceContainerHighest,
            textDirection: Directionality.of(context),
            reducedMotion: MediaQuery.disableAnimationsOf(context),
          ),
        ),
      ),
    );
  }
}

class _WavyProgressPainter extends CustomPainter {
  _WavyProgressPainter({
    required this.animation,
    required this.value,
    required this.color,
    required this.trackColor,
    required this.textDirection,
    required this.reducedMotion,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final double? value;
  final Color color;
  final Color trackColor;
  final TextDirection textDirection;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final scale = size.height / 10;
    final strokeWidth = math.min(4.0 * scale, size.width);
    final start = strokeWidth / 2;
    final width = size.width - strokeWidth;
    final center = size.height / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    if (textDirection == TextDirection.rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    // Two expanding and contracting segments convey indeterminate progress.
    final double cycle = (animation.value * 2) % 1;
    double transition(double begin, double end) => Curves.fastOutSlowIn
        .transform(((cycle - begin) / (end - begin)).clamp(0.0, 1.0));
    final List<(double, double)> segments = value != null
        ? [(0.0, value!)]
        : reducedMotion
        ? [(0.25, 0.75)]
        : [
            (transition(0.18, 0.75), transition(0, 0.55)),
            (transition(0.60, 1.0), transition(0.42, 0.90)),
          ];
    segments.sort((a, b) => a.$1.compareTo(b.$1));
    final gap = 4.0 * scale;
    void drawTrack(double a, double b) {
      if (b <= a) return;
      canvas.drawLine(
        Offset(start + a, center),
        Offset(start + b, center),
        paint..color = trackColor,
      );
    }

    double trackStart = 0;
    for (final (from, to) in segments) {
      if (to <= from) continue;
      final left = from * width;
      final right = to * width;
      drawTrack(trackStart, math.max(trackStart, left - gap - strokeWidth));
      trackStart = math.max(trackStart, right + gap + strokeWidth);
      final path = Path();
      final amplitude = value != null && (value! <= 0.1 || value! >= 0.95)
          ? 0.0
          : math.max(0.0, (size.height - strokeWidth) / 2);
      final wavelength = (value == null ? 20.0 : 40.0) * scale;
      final phase = animation.value * 4 * 2 * math.pi;
      final length = right - left;
      final steps = math.max(1, length.ceil());
      for (var i = 0; i <= steps; i++) {
        final px = left + length * i / steps;
        final edge = math.min(
          1.0,
          math.min((px - left) / (8 * scale), (right - px) / (8 * scale)),
        );
        final y =
            center +
            amplitude * edge * math.sin(px * 2 * math.pi / wavelength - phase);
        if (i == 0) {
          path.moveTo(start + px, y);
        } else {
          path.lineTo(start + px, y);
        }
      }
      canvas.drawPath(path, paint..color = color);
    }
    drawTrack(math.min(width, trackStart), width);
    if (value != null && value! < 1) {
      canvas.drawCircle(
        Offset(start + width, center),
        strokeWidth / 2,
        paint
          ..style = PaintingStyle.fill
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_WavyProgressPainter oldDelegate) =>
      value != oldDelegate.value ||
      color != oldDelegate.color ||
      trackColor != oldDelegate.trackColor ||
      textDirection != oldDelegate.textDirection ||
      animation != oldDelegate.animation ||
      reducedMotion != oldDelegate.reducedMotion;
}

@Preview(name: '波浪加载进度条', size: Size(360, 180))
Widget wavyProgressPreview() => MaterialApp(
  theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
  home: const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('正在加载'),
            SizedBox(height: 12),
            WavyProgressIndicator(),
            SizedBox(height: 20),
            WavyProgressIndicator(value: 0.65, semanticsLabel: '下载进度'),
          ],
        ),
      ),
    ),
  ),
);
