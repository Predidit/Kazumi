import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
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
    final surface = colorScheme.surfaceContainerHighest;
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
              // Avoid BackdropFilter/ImageFilter.blur: it can trigger Impeller
              // native aborts when HUD saveLayers are drawn over video output.
              // See flutter/flutter#185506.
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: container,
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
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: _progress),
                        duration: widget.disableAnimations || snapProgress
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedProgress, child) {
                          return M3ESlider(
                            value: animatedProgress,
                            decoration: M3ESliderDecoration(
                              colors:
                                  M3ESliderDefaults.colors(context).copyWith(
                                activeTrackColor: _activeTraker(colorScheme),
                                inactiveTrackColor:
                                    _inactiveTraker(colorScheme),
                                thumbColor: _activeTraker(colorScheme),
                              ),
                            ),
                            onChanged: (_) {},
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
    final progressFill = colorScheme.secondaryContainer;
    final surface = colorScheme.surfaceContainerHighest;
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
              // Avoid BackdropFilter/ImageFilter.blur: it can trigger Impeller
              // native aborts when HUD saveLayers are drawn over video output.
              // See flutter/flutter#185506.
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                width: 248,
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
                        vertical: 8,
                        horizontal: 10,
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: duration,
                            curve: Curves.easeOutCubic,
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: container,
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
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _offsetText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
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
    final surface = colorScheme.surfaceContainerHighest;
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
              // Avoid BackdropFilter/ImageFilter.blur: it can trigger Impeller
              // native aborts when HUD saveLayers are drawn over video output.
              // See flutter/flutter#185506.
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                width: 94,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                        color: container,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.speed_rounded,
                        color: onContainer,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _speedText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
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
    );
  }
}
