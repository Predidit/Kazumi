import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kazumi/utils/format.dart';

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

  Color _accent(ColorScheme colorScheme) {
    return switch (_displayType) {
      PlayerAdjustmentHudType.brightness => colorScheme.tertiaryContainer,
      PlayerAdjustmentHudType.volume => colorScheme.primaryContainer,
    };
  }

  Color _container(ColorScheme colorScheme) {
    return switch (_displayType) {
      PlayerAdjustmentHudType.brightness => colorScheme.tertiary,
      PlayerAdjustmentHudType.volume => colorScheme.primary,
    };
  }

  Color _onContainer(ColorScheme colorScheme) {
    return switch (_displayType) {
      PlayerAdjustmentHudType.brightness => colorScheme.onTertiary,
      PlayerAdjustmentHudType.volume => colorScheme.onPrimary,
    };
  }

  Color _activeTraker(ColorScheme colorScheme) {
    return switch (_displayType) {
      PlayerAdjustmentHudType.brightness => colorScheme.tertiary,
      PlayerAdjustmentHudType.volume => colorScheme.primary,
    };
  }

  Color _inactiveTraker(ColorScheme colorScheme) {
    return switch (_displayType) {
      PlayerAdjustmentHudType.brightness => colorScheme.tertiaryContainer,
      PlayerAdjustmentHudType.volume => colorScheme.secondaryContainer,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = _accent(colorScheme);
    final container = _container(colorScheme);
    final onContainer = _onContainer(colorScheme);
    final surface = colorScheme.surfaceContainerHighest.withValues(alpha: 0.74);
    final border = colorScheme.outlineVariant.withValues(alpha: 0.34);
    final duration = widget.disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 200);
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
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  width: 142,
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: border),
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
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: container.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
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
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 24,
                            activeTrackColor: _activeTraker(colorScheme),
                            inactiveTrackColor: _inactiveTraker(colorScheme),
                            thumbColor: _activeTraker(colorScheme),
                            overlayShape: SliderComponentShape.noOverlay,
                            trackShape: const _HudSliderTrackShape(
                              outerRadius: 9,
                              innerRadius: 2,
                              thumbGap: 12,
                              edgeInset: 6,
                            ),
                            thumbShape: const _HudSliderThumbShape(
                              width: 4,
                              height: 32,
                              cornerRadius: 2,
                            ),
                            tickMarkShape: SliderTickMarkShape.noTickMark,
                            padding: EdgeInsets.zero,
                          ),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: _progress),
                            duration: widget.disableAnimations || snapProgress
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            builder: (context, animatedProgress, child) {
                              return Slider(
                                value: animatedProgress,
                                onChanged: (_) {},
                              );
                            },
                          ),
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

class _HudSliderTrackShape extends SliderTrackShape {
  const _HudSliderTrackShape({
    required this.outerRadius,
    required this.innerRadius,
    this.thumbGap = 10,
    this.edgeInset = 6,
  });

  final double outerRadius;
  final double innerRadius;
  final double thumbGap;
  final double edgeInset;

  Rect _baseTrackRect({
    required RenderBox parentBox,
    required Offset offset,
    required SliderThemeData sliderTheme,
    required bool isEnabled,
    required bool isDiscrete,
  }) {
    final thumbWidth =
        sliderTheme.thumbShape?.getPreferredSize(isEnabled, isDiscrete).width ??
            0;
    final trackHeight = sliderTheme.trackHeight ?? 0;
    final trackLeft = offset.dx + thumbWidth / 2;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width - thumbWidth;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final baseTrackRect = _baseTrackRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final safeInset = edgeInset.clamp(0.0, baseTrackRect.width / 2).toDouble();
    return Rect.fromLTRB(
      baseTrackRect.left + safeInset,
      baseTrackRect.top,
      baseTrackRect.right - safeInset,
      baseTrackRect.bottom,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final canvas = context.canvas;
    final baseTrackRect = _baseTrackRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final effectiveTrackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final activeColor = ColorTween(
          begin: sliderTheme.disabledActiveTrackColor,
          end: sliderTheme.activeTrackColor,
        ).evaluate(enableAnimation) ??
        Colors.transparent;
    final inactiveColor = ColorTween(
          begin: sliderTheme.disabledInactiveTrackColor,
          end: sliderTheme.inactiveTrackColor,
        ).evaluate(enableAnimation) ??
        Colors.transparent;

    final thumbX = thumbCenter.dx.clamp(
      effectiveTrackRect.left,
      effectiveTrackRect.right,
    );
    var halfGap = thumbGap / 2;
    final leftRoom = thumbX - baseTrackRect.left;
    final rightRoom = baseTrackRect.right - thumbX;
    if (halfGap > leftRoom) {
      halfGap = leftRoom;
    }
    if (halfGap > rightRoom) {
      halfGap = rightRoom;
    }

    final leftEnd = (thumbX - halfGap).clamp(
      baseTrackRect.left,
      baseTrackRect.right,
    );
    final rightStart = (thumbX + halfGap).clamp(
      baseTrackRect.left,
      baseTrackRect.right,
    );

    final leftRect = Rect.fromLTRB(
      baseTrackRect.left,
      baseTrackRect.top,
      leftEnd,
      baseTrackRect.bottom,
    );
    final rightRect = Rect.fromLTRB(
      rightStart,
      baseTrackRect.top,
      baseTrackRect.right,
      baseTrackRect.bottom,
    );

    final leftColor =
        textDirection == TextDirection.ltr ? activeColor : inactiveColor;
    final rightColor =
        textDirection == TextDirection.ltr ? inactiveColor : activeColor;
    final hasLeftSegment = leftRect.width > 0;
    final hasRightSegment = rightRect.width > 0;

    if (hasLeftSegment) {
      _paintSegment(
        canvas: canvas,
        segmentRect: leftRect,
        color: leftColor,
        startRadius: outerRadius,
        endRadius: innerRadius,
        anchorToStart: true,
      );
    }

    if (hasRightSegment) {
      _paintSegment(
        canvas: canvas,
        segmentRect: rightRect,
        color: rightColor,
        startRadius: innerRadius,
        endRadius: outerRadius,
        anchorToStart: false,
      );
    }
  }

  void _paintSegment({
    required Canvas canvas,
    required Rect segmentRect,
    required Color color,
    required double startRadius,
    required double endRadius,
    required bool anchorToStart,
  }) {
    if (segmentRect.width <= 0) {
      return;
    }

    final minTemplateWidth = startRadius + endRadius;
    final templateWidth = segmentRect.width < minTemplateWidth
        ? minTemplateWidth
        : segmentRect.width;
    final templateRect = anchorToStart
        ? Rect.fromLTWH(
            segmentRect.left,
            segmentRect.top,
            templateWidth,
            segmentRect.height,
          )
        : Rect.fromLTWH(
            segmentRect.right - templateWidth,
            segmentRect.top,
            templateWidth,
            segmentRect.height,
          );

    canvas.save();
    canvas.clipRect(segmentRect);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        templateRect,
        topLeft: Radius.circular(startRadius),
        bottomLeft: Radius.circular(startRadius),
        topRight: Radius.circular(endRadius),
        bottomRight: Radius.circular(endRadius),
      ),
      Paint()..color = color,
    );
    canvas.restore();
  }
}

class _HudSliderThumbShape extends SliderComponentShape {
  const _HudSliderThumbShape({
    required this.width,
    required this.height,
    required this.cornerRadius,
  });

  final double width;
  final double height;
  final double cornerRadius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(width, height);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final thumbColor = ColorTween(
          begin: sliderTheme.disabledThumbColor,
          end: sliderTheme.thumbColor,
        ).evaluate(enableAnimation) ??
        Colors.transparent;
    final canvas = context.canvas;

    final thumbRect = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        thumbRect,
        Radius.circular(cornerRadius),
      ),
      Paint()..color = thumbColor,
    );
  }
}

class PlayerSeekHud extends StatefulWidget {
  const PlayerSeekHud({
    super.key,
    required this.visible,
    required this.currentPosition,
    required this.playerPosition,
    required this.duration,
    required this.direction,
    this.disableAnimations = false,
  });

  final bool visible;
  final Duration currentPosition;
  final Duration playerPosition;
  final Duration duration;
  final int direction;
  final bool disableAnimations;

  @override
  State<PlayerSeekHud> createState() => _PlayerSeekHudState();
}

class _PlayerSeekHudState extends State<PlayerSeekHud> {
  late Duration _displayCurrentPosition;
  late Duration _displayPlayerPosition;
  late Duration _displayDuration;
  late int _displayDirection;
  bool _snapProgressOnNextBuild = false;

  @override
  void initState() {
    super.initState();
    _displayCurrentPosition = widget.currentPosition;
    _displayPlayerPosition = widget.playerPosition;
    _displayDuration = widget.duration;
    _displayDirection = widget.direction;
  }

  @override
  void didUpdateWidget(covariant PlayerSeekHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible) {
      _displayCurrentPosition = widget.currentPosition;
      _displayPlayerPosition = widget.playerPosition;
      _displayDuration = widget.duration;
      _displayDirection = widget.direction;
      if (!oldWidget.visible) {
        _snapProgressOnNextBuild = true;
      }
    }
  }

  int get _effectiveDirection {
    final positionDirection =
        _displayCurrentPosition.compareTo(_displayPlayerPosition);
    if (positionDirection != 0) {
      return positionDirection;
    }
    return _displayDirection;
  }

  bool get _isForward => _effectiveDirection >= 0;

  String get _offsetText {
    final offsetMs = (_displayCurrentPosition.inMilliseconds -
            _displayPlayerPosition.inMilliseconds)
        .abs();
    final sign = _isForward ? '+' : '-';
    return '$sign${durationToString(Duration(milliseconds: offsetMs))}';
  }

  double get _progress {
    final durationMs = _displayDuration.inMilliseconds;
    if (durationMs <= 0) {
      return 0;
    }
    return (_displayCurrentPosition.inMilliseconds / durationMs)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.secondaryContainer;
    final container = colorScheme.secondary;
    final onContainer = colorScheme.onSecondary;
    final progressFill = colorScheme.secondaryContainer.withValues(alpha: 0.46);
    final surface = colorScheme.surfaceContainerHighest.withValues(alpha: 0.74);
    final border = colorScheme.outlineVariant.withValues(alpha: 0.34);
    final duration = widget.disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final snapProgress = _snapProgressOnNextBuild;
    final icon =
        _isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded;

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
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  // width: 248,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: border),
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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: _progress),
                          duration: widget.disableAnimations || snapProgress
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          builder: (context, animatedProgress, child) {
                            return _SeekProgressBackground(
                              progress: animatedProgress,
                              color: progressFill,
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: duration,
                              curve: Curves.easeOutCubic,
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: container.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(20),
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
                                  icon,
                                  key: ValueKey(icon),
                                  color: onContainer,
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _offsetText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${durationToString(_displayCurrentPosition)} / ${durationToString(_displayDuration)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
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

class _SeekProgressBackground extends StatelessWidget {
  const _SeekProgressBackground({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * progress.clamp(0.0, 1.0);
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: width,
            color: color,
          ),
        );
      },
    );
  }
}

class PlayerSpeedHud extends StatefulWidget {
  const PlayerSpeedHud({
    super.key,
    required this.visible,
    required this.speed,
    this.disableAnimations = false,
  });

  final bool visible;
  final double speed;
  final bool disableAnimations;

  @override
  State<PlayerSpeedHud> createState() => _PlayerSpeedHudState();
}

class _PlayerSpeedHudState extends State<PlayerSpeedHud> {
  late double _displaySpeed;

  @override
  void initState() {
    super.initState();
    _displaySpeed = widget.speed;
  }

  @override
  void didUpdateWidget(covariant PlayerSpeedHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible) {
      _displaySpeed = widget.speed;
    }
  }

  String get _speedText => '${_displaySpeed.toStringAsFixed(1)}x';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final container = colorScheme.inverseSurface;
    final onContainer = colorScheme.onInverseSurface;
    final surface = colorScheme.surfaceContainerHighest.withValues(alpha: 0.56);
    final border = colorScheme.outlineVariant.withValues(alpha: 0.22);
    final duration = widget.disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 160);

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: widget.visible ? Offset.zero : const Offset(0, -0.12),
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: widget.visible ? 1 : 0.96,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: container.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.speed_rounded,
                          color: onContainer,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _speedText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
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
