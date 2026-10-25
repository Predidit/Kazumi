import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/utils/format.dart';

// Metrics follow the defaults of the former audio_video_progress_bar.
const double _thumbRadius = 8;
const double _thumbGlowRadius = 18;
const double _barHeight = 5;
const double _labelGap = _thumbRadius + 5;
const double _semanticStep = 0.05;
const _labelStyle = TextStyle(
  color: Colors.white,
  fontSize: 12,
  fontFeatures: [FontFeature.tabularFigures()],
);

/// Every [onDragStart] is followed by exactly one [onDragEnd], also when the
/// bar is removed mid-drag.
class PlayerProgressBar extends StatefulWidget {
  const PlayerProgressBar({
    super.key,
    required this.progress,
    required this.buffered,
    required this.total,
    required this.sideLabels,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onSeek,
  });

  final Duration progress;
  final Duration buffered;
  final Duration total;
  final bool sideLabels;
  final VoidCallback onDragStart;
  final ValueChanged<Duration> onDragUpdate;
  final void Function(bool cancelled) onDragEnd;

  /// Seeks from accessibility actions, outside of any drag.
  final ValueChanged<Duration> onSeek;

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  final _preview = OverlayPortalController();
  double? _dragFraction;
  bool _mouseDrag = false;
  double? _hoverFraction;

  bool get _seekable => widget.total > Duration.zero;

  double? get _previewFraction {
    if (_dragFraction == null) return _hoverFraction;
    return _mouseDrag ? _dragFraction : null;
  }

  double _fractionOf(Duration value) => _seekable
      ? (value.inMilliseconds / widget.total.inMilliseconds).clamp(0.0, 1.0)
      : 0;

  Duration _timeAt(double fraction) => Duration(
      milliseconds:
          (widget.total.inMilliseconds * fraction.clamp(0.0, 1.0)).round());

  @override
  void dispose() {
    // The recognizer goes away without reporting an end, and disposal runs
    // inside a frame, so the drag is closed right after it.
    if (_dragFraction != null) {
      final onDragEnd = widget.onDragEnd;
      scheduleMicrotask(() => onDragEnd(true));
    }
    super.dispose();
  }

  void _syncPreview() {
    final visible = _previewFraction != null;
    if (visible == _preview.isShowing) return;
    if (visible) {
      _preview.show();
    } else {
      _preview.hide();
    }
  }

  void _handleHover(PointerEvent event, _Track track) {
    if (event.kind != PointerDeviceKind.mouse || _dragFraction != null) return;
    final dx = event.localPosition.dx;
    _setHover(_seekable && track.covers(dx) ? track.fractionAt(dx) : null);
  }

  void _setHover(double? fraction) {
    if (fraction == _hoverFraction) return;
    setState(() => _hoverFraction = fraction);
    _syncPreview();
  }

  void _handleDragStart(DragStartDetails details, _Track track) {
    if (!_seekable || track.isEmpty) return;
    final fraction = track.fractionAt(details.localPosition.dx);
    setState(() {
      _dragFraction = fraction;
      _mouseDrag = details.kind == PointerDeviceKind.mouse;
      _hoverFraction = null;
    });
    _syncPreview();
    widget.onDragStart();
    widget.onDragUpdate(_timeAt(fraction));
  }

  void _handleDragUpdate(DragUpdateDetails details, _Track track) {
    if (_dragFraction == null) return;
    final fraction = track.fractionAt(details.localPosition.dx);
    setState(() => _dragFraction = fraction);
    widget.onDragUpdate(_timeAt(fraction));
  }

  void _handleDragEnd({required bool cancelled}) {
    if (_dragFraction == null) return;
    setState(() => _dragFraction = null);
    _syncPreview();
    widget.onDragEnd(cancelled || !_seekable);
  }

  static String _percent(double fraction) =>
      '${(fraction.clamp(0.0, 1.0) * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final color = Theme.of(context).colorScheme.primary;
    // Both labels take the width of the total time, the longest one, so the
    // track stays put while the position label changes.
    final labelSize = widget.sideLabels
        ? _measureLabel(durationToString(widget.total), textScaler)
        : null;
    final inset = labelSize == null ? 0.0 : labelSize.width + _labelGap;
    final height = math.max(2 * _thumbRadius, labelSize?.height ?? 0);
    final dragFraction = _dragFraction;
    final current = dragFraction ?? _fractionOf(widget.progress);
    final position =
        dragFraction == null ? widget.progress : _timeAt(dragFraction);
    return LayoutBuilder(builder: (context, constraints) {
      final track = _Track(width: constraints.maxWidth, inset: inset);
      return OverlayPortal.overlayChildLayoutBuilder(
        controller: _preview,
        overlayChildBuilder: (context, info) =>
            _buildPreview(context, info, track),
        child: Semantics(
          slider: true,
          label: '播放进度',
          value: _percent(current),
          increasedValue: _percent(current + _semanticStep),
          decreasedValue: _percent(current - _semanticStep),
          onIncrease: _seekable
              ? () => widget.onSeek(_timeAt(current + _semanticStep))
              : null,
          onDecrease: _seekable
              ? () => widget.onSeek(_timeAt(current - _semanticStep))
              : null,
          child: MouseRegion(
            onEnter: (event) => _handleHover(event, track),
            onHover: (event) => _handleHover(event, track),
            onExit: (_) => _setHover(null),
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                _ProgressDragRecognizer: GestureRecognizerFactoryWithHandlers<
                        _ProgressDragRecognizer>(_ProgressDragRecognizer.new,
                    (recognizer) {
                  recognizer.onStart =
                      (details) => _handleDragStart(details, track);
                  recognizer.onUpdate =
                      (details) => _handleDragUpdate(details, track);
                  recognizer.onEnd =
                      (_) => _handleDragEnd(cancelled: recognizer.cancelled);
                }),
              },
              child: SizedBox(
                width: track.width,
                height: height,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ProgressPainter(
                      inset: inset,
                      current: current,
                      buffered: _fractionOf(widget.buffered),
                      dragging: dragFraction != null,
                      color: color,
                      textScaler: textScaler,
                      labels: labelSize == null
                          ? null
                          : (
                              position: durationToString(position),
                              total: durationToString(widget.total),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPreview(
      BuildContext context, OverlayChildLayoutInfo info, _Track track) {
    final fraction = _previewFraction;
    if (fraction == null || !_seekable || track.isEmpty) {
      return const SizedBox.shrink();
    }
    final text = durationToString(_timeAt(fraction));
    final textSize = _measureLabel(text, MediaQuery.textScalerOf(context));
    final width = textSize.width + 20;
    final height = textSize.height + 12;
    Offset toOverlay(double x) =>
        MatrixUtils.transformPoint(info.childPaintTransform, Offset(x, 0));
    final anchor = toOverlay(track.xAt(fraction));
    final minLeft = toOverlay(0).dx;
    final maxLeft = math.max(minLeft, toOverlay(track.width).dx - width);
    return Positioned(
      left: (anchor.dx - width / 2).clamp(minLeft, maxLeft),
      top: math.max(4.0, anchor.dy - height - 8),
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Container(
            width: width,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(text, style: _labelStyle),
          ),
        ),
      ),
    );
  }
}

TextPainter _layoutLabel(String text, TextScaler textScaler) => TextPainter(
      text: TextSpan(text: text, style: _labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();

Size _measureLabel(String text, TextScaler textScaler) {
  final painter = _layoutLabel(text, textScaler);
  final size = painter.size;
  painter.dispose();
  return size;
}

class _Track {
  const _Track({required this.width, required this.inset});

  final double width;
  final double inset;

  // A round cap reaches half the bar height past each end of the line.
  double get start => inset + _barHeight / 2;
  double get end => width - inset - _barHeight / 2;
  bool get isEmpty => end <= start;

  double xAt(double fraction) => start + (end - start) * fraction;

  double fractionAt(double dx) =>
      isEmpty ? 0 : ((dx - start) / (end - start)).clamp(0.0, 1.0);

  bool covers(double dx) => !isEmpty && dx >= inset && dx <= width - inset;
}

// Accepts on contact so a press seeks at once. A cancelled pointer still ends
// in onEnd, so the flag tells the two apart.
class _ProgressDragRecognizer extends HorizontalDragGestureRecognizer {
  bool cancelled = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    cancelled = false;
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerCancelEvent) cancelled = true;
    super.handleEvent(event);
  }

  @override
  String get debugDescription => 'progress drag';
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({
    required this.inset,
    required this.current,
    required this.buffered,
    required this.dragging,
    required this.color,
    required this.textScaler,
    required this.labels,
  });

  final double inset;
  final double current;
  final double buffered;
  final bool dragging;
  final Color color;
  final TextScaler textScaler;
  final ({String position, String total})? labels;

  @override
  void paint(Canvas canvas, Size size) {
    final track = _Track(width: size.width, inset: inset);
    final centerY = size.height / 2;
    if (!track.isEmpty) {
      final bar = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = _barHeight;
      void drawBar(double fraction, Color barColor) => canvas.drawLine(
          Offset(track.start, centerY),
          Offset(track.xAt(fraction), centerY),
          bar..color = barColor);
      final faded = color.withValues(alpha: 0.24);
      drawBar(1, faded);
      drawBar(buffered, faded);
      drawBar(current, color);
      final thumb = Offset(track.xAt(current), centerY);
      if (dragging) {
        canvas.drawCircle(thumb, _thumbGlowRadius,
            Paint()..color = color.withValues(alpha: 80 / 255));
      }
      canvas.drawCircle(thumb, _thumbRadius, Paint()..color = color);
    }
    final labels = this.labels;
    if (labels != null) {
      _paintLabel(canvas, labels.position, 0, centerY);
      _paintLabel(canvas, labels.total, size.width, centerY, alignEnd: true);
    }
  }

  void _paintLabel(Canvas canvas, String text, double x, double centerY,
      {bool alignEnd = false}) {
    final painter = _layoutLabel(text, textScaler);
    painter.paint(canvas,
        Offset(alignEnd ? x - painter.width : x, centerY - painter.height / 2));
    painter.dispose();
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) =>
      oldDelegate.inset != inset ||
      oldDelegate.current != current ||
      oldDelegate.buffered != buffered ||
      oldDelegate.dragging != dragging ||
      oldDelegate.color != color ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.labels != labels;
}
