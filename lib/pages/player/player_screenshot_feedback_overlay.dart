import 'package:flutter/material.dart';

class PlayerScreenshotFeedbackOverlay extends StatelessWidget {
  const PlayerScreenshotFeedbackOverlay({
    super.key,
    required this.animation,
  });

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final value = animation.value;
          if (value == 0.0) {
            return const SizedBox.shrink();
          }

          final dimOpacity =
              0.12 * _pulse(value, begin: 0.0, peak: 0.18, end: 0.62);
          final frameOpacity = 0.90 *
              _interval(value, begin: 0.0, end: 0.14, curve: Curves.easeOut) *
              (1 -
                  _interval(
                    value,
                    begin: 0.58,
                    end: 1.0,
                    curve: Curves.easeOutCubic,
                  ));
          final frameProgress = _interval(
            value,
            begin: 0.0,
            end: 0.68,
            curve: Curves.easeOutCubic,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black.withValues(alpha: dimOpacity),
              ),
              CustomPaint(
                painter: _ScreenshotFramePainter(
                  opacity: frameOpacity,
                  progress: frameProgress,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static double _interval(
    double value, {
    required double begin,
    required double end,
    required Curve curve,
  }) {
    if (value <= begin) {
      return 0.0;
    }
    if (value >= end) {
      return 1.0;
    }
    return curve.transform((value - begin) / (end - begin));
  }

  static double _pulse(
    double value, {
    required double begin,
    required double peak,
    required double end,
  }) {
    if (value <= begin || value >= end) {
      return 0.0;
    }
    if (value <= peak) {
      return _interval(
        value,
        begin: begin,
        end: peak,
        curve: Curves.easeOutCubic,
      );
    }
    return 1 -
        _interval(
          value,
          begin: peak,
          end: end,
          curve: Curves.easeOutCubic,
        );
  }
}

class _ScreenshotFramePainter extends CustomPainter {
  const _ScreenshotFramePainter({
    required this.opacity,
    required this.progress,
  });

  final double opacity;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.0 || size.isEmpty) {
      return;
    }

    final horizontalInset = size.width * (0.055 + 0.025 * progress);
    final verticalInset = size.height * (0.075 + 0.030 * progress);
    final rect = Rect.fromLTRB(
      horizontalInset,
      verticalInset,
      size.width - horizontalInset,
      size.height - verticalInset,
    );

    final cornerLength =
        (rect.shortestSide * 0.12).clamp(22.0, 54.0).toDouble();
    final strokeWidth = (1.4 + 0.8 * (1 - progress)).clamp(1.4, 2.2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final path = Path()
      ..moveTo(rect.left, rect.top + cornerLength)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.left + cornerLength, rect.top)
      ..moveTo(rect.right - cornerLength, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.top + cornerLength)
      ..moveTo(rect.right, rect.bottom - cornerLength)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.right - cornerLength, rect.bottom)
      ..moveTo(rect.left + cornerLength, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.bottom - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ScreenshotFramePainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.progress != progress;
  }
}
