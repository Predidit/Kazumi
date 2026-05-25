import 'dart:ui';

import 'package:flutter/material.dart';

enum PlayerAdjustmentHudType {
  brightness,
  volume,
}

class PlayerAdjustmentHud extends StatefulWidget {
  const PlayerAdjustmentHud({
    super.key,
    required this.visible,
    required this.type,
    required this.value,
    this.disableAnimations = false,
  });

  final bool visible;
  final PlayerAdjustmentHudType type;
  final double value;
  final bool disableAnimations;

  @override
  State<PlayerAdjustmentHud> createState() => _PlayerAdjustmentHudState();
}

class _PlayerAdjustmentHudState extends State<PlayerAdjustmentHud> {
  late PlayerAdjustmentHudType _displayType;
  late double _displayValue;
  bool _snapProgressOnNextBuild = false;

  @override
  void initState() {
    super.initState();
    _displayType = widget.type;
    _displayValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant PlayerAdjustmentHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible) {
      _displayType = widget.type;
      _displayValue = widget.value;
      if (!oldWidget.visible) {
        _snapProgressOnNextBuild = true;
      }
    }
  }

  double get _progress {
    return switch (_displayType) {
      PlayerAdjustmentHudType.brightness =>
        _displayValue.clamp(0.0, 1.0).toDouble(),
      PlayerAdjustmentHudType.volume =>
        (_displayValue / 100).clamp(0.0, 1.0).toDouble(),
    };
  }

  int get _percent => (_progress * 100).round();

  IconData get _icon {
    if (_displayType == PlayerAdjustmentHudType.brightness) {
      if (_percent <= 8) {
        return Icons.brightness_low_rounded;
      }
      if (_percent < 55) {
        return Icons.brightness_medium_rounded;
      }
      return Icons.brightness_high_rounded;
    }
    if (_percent <= 0) {
      return Icons.volume_off_rounded;
    }
    if (_percent < 45) {
      return Icons.volume_down_rounded;
    }
    return Icons.volume_up_rounded;
  }

  String get _label {
    return switch (_displayType) {
      PlayerAdjustmentHudType.brightness => '亮度',
      PlayerAdjustmentHudType.volume => '音量',
    };
  }

  Color _accent(ColorScheme colorScheme) {
    return switch (_displayType) {
      PlayerAdjustmentHudType.brightness => colorScheme.tertiary,
      PlayerAdjustmentHudType.volume => colorScheme.primary,
    };
  }

  Color _container(ColorScheme colorScheme) {
    return switch (_displayType) {
      PlayerAdjustmentHudType.brightness => colorScheme.tertiaryContainer,
      PlayerAdjustmentHudType.volume => colorScheme.primaryContainer,
    };
  }

  Color _onContainer(ColorScheme colorScheme) {
    return switch (_displayType) {
      PlayerAdjustmentHudType.brightness => colorScheme.onTertiaryContainer,
      PlayerAdjustmentHudType.volume => colorScheme.onPrimaryContainer,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = _accent(colorScheme);
    final container = _container(colorScheme);
    final onContainer = _onContainer(colorScheme);
    final frostedBackground = colorScheme.surface.withValues(alpha: 0.38);
    final frostedBorder = colorScheme.onSurface.withValues(alpha: 0.12);
    final duration = widget.disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 280);
    final snapProgress = _snapProgressOnNextBuild;
    if (snapProgress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _snapProgressOnNextBuild = false;
        });
      });
    }

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: widget.visible ? Offset.zero : const Offset(0, -0.18),
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: widget.visible ? 1 : 0.92,
            duration: duration,
            curve: Curves.easeOutBack,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  width: 236,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: frostedBackground,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: frostedBorder,
                      width: 0.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(
                          alpha: widget.visible ? 0.24 : 0,
                        ),
                        blurRadius: 32,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: container.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: AnimatedSwitcher(
                          duration: duration,
                          switchInCurve: Curves.easeOutBack,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Icon(
                            _icon,
                            key: ValueKey(_icon),
                            color: onContainer,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.88),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$_percent%',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 13,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                end: _progress,
                              ),
                              duration: widget.disableAnimations || snapProgress
                                  ? Duration.zero
                                  : const Duration(milliseconds: 360),
                              curve: Curves.easeOutCubic,
                              builder: (context, animatedProgress, _) {
                                return SizedBox(
                                  width: double.infinity,
                                  height: 16,
                                  child: CustomPaint(
                                    painter: _AdjustmentTrackPainter(
                                      progress: animatedProgress,
                                      accent: accent,
                                      trackColor: colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.86),
                                      tickColor: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.18),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdjustmentTrackPainter extends CustomPainter {
  const _AdjustmentTrackPainter({
    required this.progress,
    required this.accent,
    required this.trackColor,
    required this.tickColor,
  });

  final double progress;
  final Color accent;
  final Color trackColor;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    const trackHeight = 12.0;
    const fillEndRadius = 2.0;
    final rect = Offset(0, (size.height - trackHeight) / 2) &
        Size(size.width, trackHeight);
    final radius = Radius.circular(trackHeight / 2);
    final track = RRect.fromRectAndRadius(rect, radius);

    canvas.drawRRect(track, Paint()..color = trackColor);

    final fillWidth = (size.width * progress).clamp(0.0, size.width).toDouble();
    if (fillWidth > 0) {
      canvas.save();
      canvas.clipRRect(track);
      final fillRect = Rect.fromLTWH(rect.left, rect.top, fillWidth, rect.height);
      final fillEnd = Radius.circular(fillEndRadius);
      final isFull = fillWidth >= rect.width;
      canvas.drawRRect(
        isFull
            ? RRect.fromRectAndRadius(fillRect, radius)
            : RRect.fromRectAndCorners(
                fillRect,
                topRight: fillEnd,
                bottomRight: fillEnd,
              ),
        Paint()..color = accent,
      );
      canvas.restore();
    }

    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < 6; i++) {
      final x = rect.left + rect.width * i / 6;
      canvas.drawLine(
        Offset(x, rect.top + 3),
        Offset(x, rect.bottom - 3),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AdjustmentTrackPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.tickColor != tickColor;
  }
}
