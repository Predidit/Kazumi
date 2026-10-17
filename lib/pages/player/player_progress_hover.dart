import 'dart:math' as math;

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:kazumi/utils/format.dart';
import 'package:window_manager/window_manager.dart';

/// Geometry of audio_video_progress_bar 2.0.3's _updateThumbPosition and
/// _drawProgressBarWithLabelsOnSides. Its seek endpoints use barHeight / 2,
/// not thumbRadius; thumbGlowRadius affects painting only. Labels stay LTR
/// even in RTL layouts and use MediaQuery's TextScaler, just like the package.
class PlayerProgressTrackGeometry {
  PlayerProgressTrackGeometry({
    required Size size,
    required Duration progress,
    required Duration total,
    required TimeLabelLocation timeLabelLocation,
    required TextStyle labelStyle,
    required TextScaler textScaler,
  }) {
    double labelWidth(Duration time) {
      final minutes = (time.inMinutes % 60).toString();
      final seconds = (time.inSeconds % 60).toString().padLeft(2, '0');
      final text = time.inHours > 0
          ? '${time.inHours}:${minutes.padLeft(2, '0')}:$seconds'
          : '$minutes:$seconds';
      final painter = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final sides = timeLabelLocation == TimeLabelLocation.sides;
    // The widget below explicitly fixes thumbRadius=8, barHeight=5,
    // thumbCanPaintOutsideBar=true, timeLabelPadding=0, totalTime labels.
    final before = sides ? labelWidth(progress) + 8 + 5 : 0.0;
    final after = sides ? labelWidth(total) + 8 + 5 : 0.0;
    bounds = Rect.fromLTRB(
      before,
      (size.height - 16) / 2,
      size.width - after,
      (size.height + 16) / 2,
    );
    start = before + 2.5;
    end = size.width - after - 2.5;
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

/// A mouse-only preview around the existing progress bar. It observes pointer
/// events without joining the gesture arena and never changes playback state.
class PlayerProgressHover extends StatefulWidget {
  const PlayerProgressHover({
    super.key,
    required this.progress,
    required this.buffered,
    required this.total,
    required this.timeLabelLocation,
    required this.mediaIdentity,
    required this.layoutIdentity,
    required this.enabled,
    required this.onSeek,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragCancel,
  }) : assert(
         timeLabelLocation == TimeLabelLocation.none ||
             timeLabelLocation == TimeLabelLocation.sides,
       );

  final Duration progress;
  final Duration buffered;
  final Duration total;
  final TimeLabelLocation timeLabelLocation;
  final Object mediaIdentity;
  final Object layoutIdentity;
  final bool enabled;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onDragStart;
  final ValueChanged<ThumbDragDetails> onDragUpdate;
  final VoidCallback onDragCancel;

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
  final _link = LayerLink();
  final _barKey = GlobalKey();
  Offset? _position;
  Duration? _preview;
  final _pointers = <int>{};
  PointerDeviceKind? _pointerKind;
  bool _cancelledPointer = false;
  bool _dragging = false;
  bool _focused = true;
  bool _listeningToWindow = false;
  Size? _viewport;
  BoxConstraints? _constraints;
  TextScaler? _textScaler;
  int _generation = 0;

  bool get _desktop => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_desktop) {
      windowManager.addListener(this);
      _listeningToWindow = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewport = MediaQuery.sizeOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    if (_viewport != viewport || _textScaler != textScaler) _cancelPointer();
    _viewport = viewport;
    _textScaler = textScaler;
  }

  @override
  void didUpdateWidget(PlayerProgressHover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        widget.mediaIdentity != oldWidget.mediaIdentity ||
        widget.layoutIdentity != oldWidget.layoutIdentity ||
        widget.timeLabelLocation != oldWidget.timeLabelLocation ||
        (_dragging && widget.total != oldWidget.total) ||
        widget.total <= Duration.zero) {
      _cancelPointer();
    } else if (!_dragging &&
        _position != null &&
        (widget.total != oldWidget.total ||
            (widget.timeLabelLocation == TimeLabelLocation.sides &&
                widget.progress != oldWidget.progress))) {
      final generation = _generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            generation == _generation &&
            !_dragging &&
            _position != null) {
          _updatePreview(_position!);
        }
      });
    }
  }

  void _hide() {
    _generation++;
    _position = null;
    _preview = null;
    if (!_portal.isShowing) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      final generation = _generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _generation && _portal.isShowing) {
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
    if (!_desktop ||
        !widget.enabled ||
        !_focused ||
        _pointers.isNotEmpty ||
        _dragging ||
        event.kind != PointerDeviceKind.mouse) {
      return;
    }
    _updatePreview(event.localPosition);
  }

  void _updatePreview(Offset position) {
    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final geometry = PlayerProgressTrackGeometry(
      size: box.size,
      progress: widget.progress,
      total: widget.total,
      timeLabelLocation: widget.timeLabelLocation,
      labelStyle: PlayerProgressHover.labelStyle,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final preview = geometry.timeAt(position, widget.total);
    if (preview == null) {
      _hide();
      return;
    }
    if (_position == position && _preview?.inSeconds == preview.inSeconds) {
      return;
    }
    setState(() {
      _position = position;
      _preview = preview;
    });
    if (!_portal.isShowing) _portal.show();
  }

  void _updateDragPreview(ThumbDragDetails details) {
    if (!_desktop ||
        _pointerKind != PointerDeviceKind.mouse ||
        !widget.enabled ||
        !_focused ||
        _cancelledPointer ||
        widget.total <= Duration.zero) {
      return;
    }
    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final geometry = PlayerProgressTrackGeometry(
      size: box.size,
      progress: widget.progress,
      total: widget.total,
      timeLabelLocation: widget.timeLabelLocation,
      labelStyle: PlayerProgressHover.labelStyle,
      textScaler: MediaQuery.textScalerOf(context),
    );
    if (geometry.end <= geometry.start) return;
    setState(() {
      _position = Offset(
        details.localPosition.dx.clamp(geometry.start, geometry.end),
        box.size.height / 2,
      );
      // The package owns drag mapping, including its cached side-label widths.
      // Recomputing this from hover geometry can disagree during playback ticks.
      _preview = details.timeStamp;
    });
    if (!_portal.isShowing) _portal.show();
  }

  void _cancelPointer() {
    final wasDragging = _dragging;
    if (_pointers.isNotEmpty || wasDragging) _cancelledPointer = true;
    _dragging = false;
    _hide();
    // 2.0.3 has no public drag-cancel callback. The listener observes native
    // cancellation while leaving its recognizer's normal callbacks intact.
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

  Widget _buildPreview(BuildContext context) {
    final position = _position;
    final preview = _preview;
    if (position == null || preview == null) return const SizedBox.shrink();
    final box = _barKey.currentContext!.findRenderObject()! as RenderBox;
    final text = durationToString(preview);
    final painter = TextPainter(
      text: TextSpan(text: text, style: PlayerProgressHover.labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width + 20;
    final height = painter.height + 12;
    painter.dispose();
    final origin = box.localToGlobal(Offset.zero);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    var visible = overlay.localToGlobal(Offset.zero) & overlay.size;
    // The player's ClipRect supplies the horizontal boundary, while the
    // portal paints above it in the current page's overlay (also in fullscreen).
    final clip = this.context.findAncestorRenderObjectOfType<RenderClipRect>();
    if (clip != null && clip.hasSize) {
      visible = visible.intersect(clip.localToGlobal(Offset.zero) & clip.size);
    }
    final minX = visible.left + 4;
    final maxX = math.max(minX, visible.right - width - 4);
    final x = (origin.dx + position.dx - width / 2).clamp(minX, maxX);
    final y = math.max(4.0, origin.dy - height - 8);
    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: Offset(x - origin.dx, y - origin.dy),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: _buildPreview,
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (_constraints != null && _constraints != constraints) {
          _cancelPointer();
        }
        _constraints = constraints;
        return CompositedTransformTarget(
          link: _link,
          child: MouseRegion(
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
              child: ProgressBar(
                key: _barKey,
                thumbRadius: 8,
                thumbGlowRadius: 18,
                timeLabelLocation: widget.timeLabelLocation,
                timeLabelTextStyle: PlayerProgressHover.labelStyle,
                progress: widget.progress,
                buffered: widget.buffered,
                total: widget.total,
                onSeek: (time) {
                  // A cancelled accepted horizontal drag also calls onEnd
                  // in Flutter. Do not commit the package's resulting seek.
                  if (!_cancelledPointer) widget.onSeek(time);
                },
                onDragStart: (details) {
                  if (_cancelledPointer) return;
                  _dragging = true;
                  _updateDragPreview(details);
                  widget.onDragStart();
                },
                onDragUpdate: (details) {
                  if (_cancelledPointer) return;
                  _updateDragPreview(details);
                  widget.onDragUpdate(details);
                },
                onDragEnd: () {
                  _dragging = false;
                  _hide();
                },
              ),
            ),
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
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    if (_listeningToWindow) windowManager.removeListener(this);
    super.dispose();
  }
}
