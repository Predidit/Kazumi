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
    final surface = colorScheme.surfaceContainerHighest.withValues(alpha: 0.74);
    final border = colorScheme.outlineVariant.withValues(alpha: 0.34);
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
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  width: 224,
                  padding:
                      const EdgeInsets.all(8),
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
                        width: 40,
                        height: 40,
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
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 32,
                            activeTrackColor: colorScheme.primary,
                            inactiveTrackColor:
                                colorScheme.secondaryContainer,
                            thumbColor: colorScheme.primary,
                            overlayShape: SliderComponentShape.noOverlay,
                            trackShape: const _HudSliderTrackShape(
                              outerRadius: 12,
                              innerRadius: 2,
                              thumbGap: 12,
                              edgeInset: 6,
                            ),
                            thumbShape: const _HudSliderThumbShape(
                              width: 4,
                              height: 40,
                              cornerRadius: 2,
                            ),
                            tickMarkShape: SliderTickMarkShape.noTickMark,
                            padding: EdgeInsets.zero,
                          ),
                          child: Slider(
                            value: _progress,
                            onChanged: (_) {},
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
