import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/pages/player/player_progress_hover.dart';
import 'package:kazumi/pages/player/player_transport_bar.dart';
import 'package:kazumi/utils/format.dart';

/// Project-owned progress bar used by the player.
///
/// It exposes only project types. The hover preview and the track geometry
/// live in `player_progress_hover.dart`, so this file owns rendering, labels,
/// colors, gestures, and seek callbacks.
///
/// The visual defaults mirror `audio_video_progress_bar` 2.0.3 (MIT), which
/// this widget replaces.
class PlayerProgressBar extends StatelessWidget {
  const PlayerProgressBar({
    super.key,
    required this.progress,
    required this.buffered,
    required this.total,
    required this.timeLabelLocation,
    required this.enabled,
    required this.mediaIdentity,
    required this.layoutIdentity,
    required this.onSeek,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragCancel,
  });

  final Duration progress;
  final Duration buffered;
  final Duration total;
  final PlayerTimeLabelLocation timeLabelLocation;
  final bool enabled;
  final Object mediaIdentity;
  final Object layoutIdentity;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onDragStart;
  final ValueChanged<Duration> onDragUpdate;
  final VoidCallback onDragCancel;

  @override
  Widget build(BuildContext context) {
    final sideLabels = timeLabelLocation == PlayerTimeLabelLocation.sides;
    return PlayerProgressHover(
      progress: progress,
      total: total,
      enabled: enabled,
      mediaIdentity: mediaIdentity,
      layoutIdentity: layoutIdentity,
      onSeek: onSeek,
      onDragStart: onDragStart,
      onDragUpdate: onDragUpdate,
      onDragCancel: onDragCancel,
      geometryBuilder: (size, textScaler) => PlayerProgressTrackGeometry(
        size: size,
        progress: progress,
        total: total,
        sideLabels: sideLabels,
        textScaler: textScaler,
      ),
      barBuilder: (context, callbacks) => _PlayerProgressTrack(
        progress: progress,
        buffered: buffered,
        total: total,
        sideLabels: sideLabels,
        callbacks: callbacks,
      ),
    );
  }
}

/// Eagerly wins the gesture arena so a press on the bar seeks immediately,
/// matching the previous package behavior instead of waiting for a drag slop.
class _EagerHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  String get debugDescription => '_EagerHorizontalDragGestureRecognizer';
}

class _PlayerProgressTrack extends StatefulWidget {
  const _PlayerProgressTrack({
    required this.progress,
    required this.buffered,
    required this.total,
    required this.sideLabels,
    required this.callbacks,
  });

  final Duration progress;
  final Duration buffered;
  final Duration total;
  final bool sideLabels;
  final PlayerProgressHoverCallbacks callbacks;

  @override
  State<_PlayerProgressTrack> createState() => _PlayerProgressTrackState();
}

class _PlayerProgressTrackState extends State<_PlayerProgressTrack> {
  double? _dragValue;

  @override
  void didUpdateWidget(_PlayerProgressTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.total != oldWidget.total) _dragValue = null;
  }

  double _fractionOf(Duration value) {
    final total = widget.total.inMilliseconds;
    if (total <= 0) return 0;
    return (value.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration _durationAt(double fraction) => Duration(
    milliseconds: (widget.total.inMilliseconds * fraction.clamp(0.0, 1.0))
        .round(),
  );

  double _fractionAt(Offset position, PlayerProgressTrackGeometry geometry) {
    final width = geometry.end - geometry.start;
    if (width <= 0) return 0;
    return ((position.dx - geometry.start) / width).clamp(0.0, 1.0);
  }

  void _startDrag(Offset position, PlayerProgressTrackGeometry geometry) {
    final fraction = _fractionAt(position, geometry);
    setState(() => _dragValue = fraction);
    widget.callbacks.onDragStart(position, _durationAt(fraction));
  }

  void _updateDrag(Offset position, PlayerProgressTrackGeometry geometry) {
    final fraction = _fractionAt(position, geometry);
    setState(() => _dragValue = fraction);
    widget.callbacks.onDragUpdate(position, _durationAt(fraction));
  }

  void _endDrag() {
    final fraction = _dragValue ?? _fractionOf(widget.progress);
    setState(() => _dragValue = null);
    widget.callbacks.onDragEnd();
    widget.callbacks.onSeek(_durationAt(fraction));
  }

  void _cancelDrag() {
    if (_dragValue != null) setState(() => _dragValue = null);
  }

  void _semanticSeek(double fraction) {
    widget.callbacks.onSeek(_durationAt(fraction));
  }

  double _textHeight(TextScaler textScaler) {
    final painter = TextPainter(
      text: TextSpan(text: '0:00', style: PlayerProgressHover.labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final height = painter.size.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final height = widget.sideLabels
        ? math.max(PlayerProgressHover.barExtent, _textHeight(textScaler))
        : PlayerProgressHover.barExtent;
    final primary = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, height);
        final geometry = PlayerProgressTrackGeometry(
          size: size,
          progress: widget.progress,
          total: widget.total,
          sideLabels: widget.sideLabels,
          textScaler: textScaler,
        );
        final current = _dragValue ?? _fractionOf(widget.progress);
        return Semantics(
          slider: true,
          textDirection: TextDirection.ltr,
          label: 'Progress bar',
          value: '${(current * 100).round()}%',
          increasedValue:
              '${((current + 0.05).clamp(0.0, 1.0) * 100).round()}%',
          decreasedValue:
              '${((current - 0.05).clamp(0.0, 1.0) * 100).round()}%',
          onIncrease: () => _semanticSeek(current + 0.05),
          onDecrease: () => _semanticSeek(current - 0.05),
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              _EagerHorizontalDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    _EagerHorizontalDragGestureRecognizer
                  >(_EagerHorizontalDragGestureRecognizer.new, (recognizer) {
                    recognizer
                      ..onStart = (details) {
                        _startDrag(details.localPosition, geometry);
                      }
                      ..onUpdate = (details) {
                        _updateDrag(details.localPosition, geometry);
                      }
                      ..onEnd = (_) {
                        _endDrag();
                      }
                      ..onCancel = _cancelDrag;
                  }),
            },
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: CustomPaint(
                painter: _PlayerProgressBarPainter(
                  start: geometry.start,
                  end: geometry.end,
                  currentFraction: current,
                  bufferedFraction: _fractionOf(widget.buffered),
                  dragging: _dragValue != null,
                  leftLabel: widget.sideLabels
                      ? durationToString(widget.progress)
                      : null,
                  rightLabel: widget.sideLabels
                      ? durationToString(widget.total)
                      : null,
                  labelStyle: PlayerProgressHover.labelStyle,
                  textScaler: textScaler,
                  baseColor: primary.withValues(alpha: 0.24),
                  bufferedColor: primary.withValues(alpha: 0.24),
                  progressColor: primary,
                  thumbColor: primary,
                  thumbGlowColor: primary.withValues(alpha: 80 / 255),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayerProgressBarPainter extends CustomPainter {
  const _PlayerProgressBarPainter({
    required this.start,
    required this.end,
    required this.currentFraction,
    required this.bufferedFraction,
    required this.dragging,
    required this.leftLabel,
    required this.rightLabel,
    required this.labelStyle,
    required this.textScaler,
    required this.baseColor,
    required this.bufferedColor,
    required this.progressColor,
    required this.thumbColor,
    required this.thumbGlowColor,
  });

  final double start;
  final double end;
  final double currentFraction;
  final double bufferedFraction;
  final bool dragging;
  final String? leftLabel;
  final String? rightLabel;
  final TextStyle labelStyle;
  final TextScaler textScaler;
  final Color baseColor;
  final Color bufferedColor;
  final Color progressColor;
  final Color thumbColor;
  final Color thumbGlowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final barPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = PlayerProgressHover.barHeight;

    barPaint.color = baseColor;
    canvas.drawLine(Offset(start, centerY), Offset(end, centerY), barPaint);

    barPaint.color = bufferedColor;
    canvas.drawLine(
      Offset(start, centerY),
      Offset(start + (end - start) * bufferedFraction, centerY),
      barPaint,
    );

    barPaint.color = progressColor;
    canvas.drawLine(
      Offset(start, centerY),
      Offset(start + (end - start) * currentFraction, centerY),
      barPaint,
    );

    final thumbCenter = Offset(
      start + (end - start) * currentFraction,
      centerY,
    );
    if (dragging) {
      canvas.drawCircle(
        thumbCenter,
        PlayerProgressHover.thumbGlowRadius,
        Paint()..color = thumbGlowColor,
      );
    }
    canvas.drawCircle(
      thumbCenter,
      PlayerProgressHover.thumbRadius,
      Paint()..color = thumbColor,
    );

    if (leftLabel != null) {
      _paintLabel(
        canvas,
        leftLabel!,
        Offset(0, centerY - _textHeight(leftLabel!) / 2),
      );
    }
    if (rightLabel != null) {
      final width = _textWidth(rightLabel!);
      _paintLabel(
        canvas,
        rightLabel!,
        Offset(size.width - width, centerY - _textHeight(rightLabel!) / 2),
      );
    }
  }

  TextPainter _labelPainter(String text) => TextPainter(
    text: TextSpan(text: text, style: labelStyle),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();

  double _textHeight(String text) {
    final painter = _labelPainter(text);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  double _textWidth(String text) {
    final painter = _labelPainter(text);
    final width = painter.width;
    painter.dispose();
    return width;
  }

  void _paintLabel(Canvas canvas, String text, Offset offset) {
    final painter = _labelPainter(text);
    painter.paint(canvas, offset);
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _PlayerProgressBarPainter oldDelegate) =>
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.currentFraction != currentFraction ||
      oldDelegate.bufferedFraction != bufferedFraction ||
      oldDelegate.dragging != dragging ||
      oldDelegate.leftLabel != leftLabel ||
      oldDelegate.rightLabel != rightLabel ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.baseColor != baseColor ||
      oldDelegate.bufferedColor != bufferedColor ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.thumbColor != thumbColor ||
      oldDelegate.thumbGlowColor != thumbGlowColor;
}
