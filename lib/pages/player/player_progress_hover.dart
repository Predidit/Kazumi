import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:kazumi/utils/format.dart';
import 'package:window_manager/window_manager.dart';

Size _labelSize(String text, TextScaler textScaler) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: PlayerProgressHover.labelStyle),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

/// Geometry of the track owned by [PlayerProgressBar].
///
/// It mirrors that adapter's fixed configuration: `thumbRadius` 8,
/// `barHeight` 5, `thumbCanPaintOutsideBar` true, `timeLabelPadding` 0 and
/// total-time labels. Keep these values in sync when the adapter changes.
class PlayerProgressTrackGeometry {
  PlayerProgressTrackGeometry({
    required Size size,
    required Duration progress,
    required Duration total,
    required bool sideLabels,
    required TextScaler textScaler,
  }) {
    double labelWidth(Duration time) {
      final minutes = (time.inMinutes % 60).toString();
      final seconds = (time.inSeconds % 60).toString().padLeft(2, '0');
      final text = time.inHours > 0
          ? '${time.inHours}:${minutes.padLeft(2, '0')}:$seconds'
          : '$minutes:$seconds';
      return _labelSize(text, textScaler).width;
    }

    final before = sideLabels
        ? labelWidth(progress) + PlayerProgressHover.sideLabelPadding
        : 0.0;
    final after = sideLabels
        ? labelWidth(total) + PlayerProgressHover.sideLabelPadding
        : 0.0;
    bounds = Rect.fromLTRB(
      before,
      (size.height - PlayerProgressHover.barExtent) / 2,
      size.width - after,
      (size.height + PlayerProgressHover.barExtent) / 2,
    );
    start = before + PlayerProgressHover.trackCapInset;
    end = size.width - after - PlayerProgressHover.trackCapInset;
  }

  late final Rect bounds;
  late final double start;
  late final double end;

  Duration? timeAt(Offset position, Duration total) {
    if (total <= Duration.zero || end <= start || !bounds.contains(position)) {
      return null;
    }
    final fraction = ((position.dx - start) / (end - start)).clamp(0.0, 1.0);
    return Duration(milliseconds: (total.inMilliseconds * fraction).round());
  }
}

/// Callbacks handed to the bar builder. They are already wrapped with the
/// hover state's pointer-cancel handling, so the bar does not need to know
/// about previews or cancellation.
class PlayerProgressHoverCallbacks {
  const PlayerProgressHoverCallbacks({
    required this.onSeek,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final ValueChanged<Duration> onSeek;
  final void Function(Offset localPosition, Duration timeStamp) onDragStart;
  final void Function(Offset localPosition, Duration timeStamp) onDragUpdate;
  final VoidCallback onDragEnd;
}

typedef PlayerProgressBarBuilder =
    Widget Function(
      BuildContext context,
      PlayerProgressHoverCallbacks callbacks,
    );

/// Adds a mouse time preview to [PlayerProgressBar] without owning rendering,
/// gestures, or seek state. The bar comes from [barBuilder]; geometry comes
/// from [geometryBuilder].
class PlayerProgressHover extends StatefulWidget {
  const PlayerProgressHover({
    super.key,
    required this.progress,
    required this.total,
    required this.enabled,
    required this.mediaIdentity,
    required this.layoutIdentity,
    required this.onSeek,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragCancel,
    required this.geometryBuilder,
    required this.barBuilder,
  });

  final Duration progress;
  final Duration total;
  final bool enabled;
  final Object mediaIdentity;
  final Object layoutIdentity;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onDragStart;
  final ValueChanged<Duration> onDragUpdate;
  final VoidCallback onDragCancel;
  final PlayerProgressTrackGeometry Function(Size size, TextScaler textScaler)
  geometryBuilder;
  final PlayerProgressBarBuilder barBuilder;

  /// Bar configuration shared with [PlayerProgressTrackGeometry].
  static const double thumbRadius = 8;
  static const double thumbGlowRadius = 18;
  static const double barHeight = 5;
  static const double timeLabelPadding = 0;

  /// `thumbRadius + 5` mirrors the package's `_defaultSidePadding`.
  static const double sideLabelPadding = thumbRadius + 5 + timeLabelPadding;
  static const double trackCapInset = barHeight / 2;
  static const double barExtent = 2 * thumbRadius;

  static const labelStyle = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const previewKey = ValueKey('player-progress-hover-preview');

  @override
  State<PlayerProgressHover> createState() => _PlayerProgressHoverState();
}

class _PlayerProgressHoverState extends State<PlayerProgressHover>
    with WidgetsBindingObserver, WindowListener {
  final _portal = OverlayPortalController();
  ({Offset position, Duration time})? _preview;
  final _pointers = <int>{};
  PointerDeviceKind? _pointerKind;
  bool _cancelledPointer = false;
  bool _dragging = false;
  bool _focused = true;
  (Size, TextScaler)? _metrics;
  BoxConstraints? _constraints;

  late final _desktop = switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };

  late final PlayerProgressHoverCallbacks _callbacks =
      PlayerProgressHoverCallbacks(
        onSeek: (time) {
          if (!_cancelledPointer) widget.onSeek(time);
        },
        onDragStart: (position, timeStamp) {
          if (_cancelledPointer) return;
          _dragging = true;
          _updatePreview(position, dragTime: timeStamp);
          widget.onDragStart();
        },
        onDragUpdate: (position, timeStamp) {
          if (_cancelledPointer) return;
          _updatePreview(position, dragTime: timeStamp);
          widget.onDragUpdate(timeStamp);
        },
        onDragEnd: () {
          _dragging = false;
          _hide();
        },
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_desktop) windowManager.addListener(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final metrics = (
      MediaQuery.sizeOf(context),
      MediaQuery.textScalerOf(context),
    );
    if (_metrics != metrics) _cancelPointer();
    _metrics = metrics;
  }

  @override
  void didUpdateWidget(PlayerProgressHover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        widget.mediaIdentity != oldWidget.mediaIdentity ||
        widget.layoutIdentity != oldWidget.layoutIdentity ||
        (_dragging && widget.total != oldWidget.total) ||
        widget.total <= Duration.zero) {
      _cancelPointer();
    } else if (!_dragging &&
        _preview != null &&
        (widget.total != oldWidget.total ||
            widget.progress != oldWidget.progress)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_dragging && _preview != null) {
          _updatePreview(_preview!.position);
        }
      });
    }
  }

  void _hide() {
    _preview = null;
    if (!_portal.isShowing) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _preview == null && _portal.isShowing) {
          _portal.hide();
        }
      });
    } else {
      _portal.hide();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _focused = state == AppLifecycleState.resumed;
    if (!_focused) _cancelPointer();
  }

  @override
  void didChangeMetrics() => _cancelPointer();

  @override
  void onWindowBlur() {
    _focused = false;
    _cancelPointer();
  }

  @override
  void onWindowFocus() => _focused = true;

  void _onHover(PointerEvent event) {
    if (_pointers.isNotEmpty ||
        _dragging ||
        event.kind != PointerDeviceKind.mouse) {
      return;
    }
    _updatePreview(event.localPosition);
  }

  void _updatePreview(Offset position, {Duration? dragTime}) {
    if (!_desktop ||
        !widget.enabled ||
        !_focused ||
        (dragTime != null && _pointerKind != PointerDeviceKind.mouse)) {
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final geometry = widget.geometryBuilder(
      box.size,
      MediaQuery.textScalerOf(context),
    );
    final time = dragTime ?? geometry.timeAt(position, widget.total);
    if (time == null ||
        widget.total <= Duration.zero ||
        geometry.end <= geometry.start) {
      _hide();
      return;
    }
    if (dragTime != null) {
      position = Offset(
        position.dx.clamp(geometry.start, geometry.end),
        box.size.height / 2,
      );
    }
    if (_preview?.position == position &&
        _preview?.time.inSeconds == time.inSeconds) {
      return;
    }
    setState(() => _preview = (position: position, time: time));
    if (!_portal.isShowing) _portal.show();
  }

  void _cancelPointer() {
    final wasDragging = _dragging;
    if (_pointers.isNotEmpty || wasDragging) _cancelledPointer = true;
    _dragging = false;
    _hide();
    if (wasDragging) {
      final cancel = widget.onDragCancel;
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) => cancel());
      } else {
        cancel();
      }
    }
  }

  Widget _buildPreview(BuildContext context, OverlayChildLayoutInfo info) {
    final preview = _preview;
    if (preview == null) return const SizedBox.shrink();
    final text = durationToString(preview.time);
    final textSize = _labelSize(text, MediaQuery.textScalerOf(context));
    final width = textSize.width + 20;
    final height = textSize.height + 12;
    final anchor = MatrixUtils.transformPoint(
      info.childPaintTransform,
      Offset(preview.position.dx, 0),
    );
    var visible = Offset.zero & info.overlaySize;
    // The player's ClipRect supplies the horizontal boundary, while the
    // portal paints above it in the current page's overlay (also in fullscreen).
    final clip = this.context.findAncestorRenderObjectOfType<RenderClipRect>();
    if (clip != null && clip.hasSize) {
      final overlay = Overlay.of(context).context.findRenderObject()!;
      visible = visible.intersect(
        MatrixUtils.transformRect(
          clip.getTransformTo(overlay),
          Offset.zero & clip.size,
        ),
      );
    }
    final minX = visible.left + 4;
    final maxX = math.max(minX, visible.right - width - 4);
    return Positioned(
      left: (anchor.dx - width / 2).clamp(minX, maxX),
      top: math.max(4.0, anchor.dy - height - 8),
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Container(
            key: PlayerProgressHover.previewKey,
            width: width,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(text, style: PlayerProgressHover.labelStyle),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => OverlayPortal.overlayChildLayoutBuilder(
    controller: _portal,
    overlayChildBuilder: _buildPreview,
    child: LayoutBuilder(
      builder: (context, constraints) {
        // Compact time labels can resize the bar as the drag target
        // changes. Keep the drag active; the bar remaps on the next
        // pointer update.
        if (_constraints != null && _constraints != constraints && !_dragging) {
          _cancelPointer();
        }
        _constraints = constraints;
        return MouseRegion(
          onEnter: _onHover,
          onHover: _onHover,
          onExit: (_) {
            if (!_dragging) _hide();
          },
          child: Listener(
            onPointerDown: (event) {
              if (_pointers.isEmpty) {
                _cancelledPointer = false;
                _pointerKind = event.kind;
              } else {
                _pointerKind = null;
              }
              _pointers.add(event.pointer);
              _hide();
            },
            onPointerUp: (event) {
              if (!_pointers.remove(event.pointer)) return;
              if (_pointers.isEmpty) _pointerKind = null;
              _hide();
            },
            onPointerCancel: (event) {
              if (!_pointers.remove(event.pointer)) return;
              _cancelPointer();
              if (_pointers.isEmpty) _pointerKind = null;
            },
            child: widget.barBuilder(context, _callbacks),
          ),
        );
      },
    ),
  );

  @override
  void deactivate() {
    _cancelPointer();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_desktop) windowManager.removeListener(this);
    super.dispose();
  }
}
