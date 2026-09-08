import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'package:kazumi/bean/appbar/drag_to_move_bar.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/pages/player/player_panel_hold.dart';
import 'package:kazumi/utils/format.dart';

/// Video controls always use a dark tonal surface, derived from the app accent.
/// Opaque containers keep controls legible even over a white video frame.
ThemeData playerControlsTheme(ThemeData appTheme) {
  final colors = ColorScheme.fromSeed(
    seedColor: appTheme.colorScheme.primary,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    platform: appTheme.platform,
    fontFamily: appTheme.textTheme.bodyMedium?.fontFamily,
    colorScheme: colors,
    textTheme: appTheme.textTheme.apply(
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    ),
    iconTheme: IconThemeData(color: colors.onSurface),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        )),
        side: const WidgetStatePropertyAll(BorderSide.none),
        elevation: const WidgetStatePropertyAll(3),
        shadowColor: const WidgetStatePropertyAll(Colors.black26),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surfaceContainerHigh,
      selectedColor: colors.secondaryContainer,
      labelStyle:
          appTheme.textTheme.labelLarge?.copyWith(color: colors.onSurface),
      side: BorderSide.none,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 8,
      trackGap: 6,
      trackShape: const GappedSliderTrackShape(),
      thumbShape: const HandleThumbShape(),
      thumbSize: WidgetStateProperty.resolveWith(
          (states) => Size(states.contains(WidgetState.pressed) ? 2 : 4, 32)),
      activeTrackColor: colors.primary,
      inactiveTrackColor: colors.surfaceContainerHighest,
      secondaryActiveTrackColor: colors.secondary.withValues(alpha: 0.4),
      thumbColor: colors.primary,
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
  );
}

/// One control vocabulary for desktop, landscape, embedded video and PiP.
/// The slots keep the high-frequency position/volume observers out of the chrome.
class PlayerControlsView extends StatelessWidget {
  const PlayerControlsView({
    super.key,
    required this.title,
    required this.episode,
    required this.playing,
    required this.fullscreen,
    required this.isPip,
    required this.danmakuOn,
    required this.danmakuLoading,
    required this.speed,
    required this.skipSeconds,
    required this.timeline,
    required this.superResolutionBuilder,
    required this.onBack,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onSkip,
    required this.onSkipSettings,
    required this.onSpeed,
    required this.onDanmaku,
    required this.onEpisodes,
    required this.onFullscreen,
    required this.onSettings,
    required this.onSyncPlay,
    this.visibility = const AlwaysStoppedAnimation(1),
    this.onLock,
    this.volume,
    this.collection,
    this.wrapControls,
    this.disableAnimations = false,
  });

  final String title;
  final String episode;
  final bool playing;
  final bool fullscreen;
  final bool isPip;
  final bool danmakuOn;
  final bool danmakuLoading;
  final double speed;
  final int skipSeconds;
  final Widget timeline;
  final Widget Function(bool showLabel) superResolutionBuilder;
  final Animation<double> visibility;
  final Widget? volume;
  final Widget? collection;
  final Widget Function(Widget child)? wrapControls;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onSkip;
  final VoidCallback onSkipSettings;
  final VoidCallback onSpeed;
  final VoidCallback onDanmaku;
  final VoidCallback onEpisodes;
  final VoidCallback onFullscreen;
  final VoidCallback onSettings;
  final VoidCallback onSyncPlay;
  final VoidCallback? onLock;
  final bool disableAnimations;

  Widget _wrap(Widget child) => wrapControls?.call(child) ?? child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final compact =
          isPip || constraints.maxWidth < 560 || constraints.maxHeight < 300;
      final wide = !compact && constraints.maxWidth >= 1000;
      final spacious = wide && constraints.maxHeight >= 500;
      final labels = constraints.maxWidth >= 1360 &&
          MediaQuery.textScalerOf(context).scale(14) <= 20;
      final margin = compact ? 8.0 : (wide ? 24.0 : 12.0);
      final resolutionLabel = !compact &&
          (constraints.maxWidth >= 700 ||
              MediaQuery.textScalerOf(context).scale(14) <= 20);
      final play = PlayerControlButton(
        key: const ValueKey('player-play-pause'),
        icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        tooltip: playing ? '暂停' : '播放',
        onPressed: onPlayPause,
        prominent: true,
        selected: playing,
        width: compact ? 56 : (wide ? 96 : 80),
        height: spacious ? 64 : 48,
        iconSize: compact ? 32 : 38,
        disableAnimations: disableAnimations,
      );
      final expand = PlayerControlButton(
        icon: isPip
            ? Icons.picture_in_picture_alt_rounded
            : (fullscreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded),
        tooltip: isPip ? '退出画中画' : (fullscreen ? '退出全屏' : '全屏'),
        onPressed: onFullscreen,
        disableAnimations: disableAnimations,
      );
      final header = Row(
        children: [
          PlayerControlButton(
            icon: Icons.arrow_back_rounded,
            tooltip: '返回',
            onPressed: onBack,
            disableAnimations: disableAnimations,
          ),
          SizedBox(width: compact ? 10 : 16),
          Expanded(
            child: DragToMoveArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (compact
                            ? Theme.of(context).textTheme.titleSmall
                            : Theme.of(context).textTheme.titleLarge)
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text(
                      episode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (wide) ...[
            PlayerControlButton(
              icon: Icons.group_outlined,
              label: labels ? '一起看' : null,
              tooltip: '一起看',
              onPressed: onSyncPlay,
              disableAnimations: disableAnimations,
            ),
            const SizedBox(width: 6),
          ],
          if (collection != null && !compact) ...[
            Material(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
              child: SizedBox.square(dimension: 48, child: collection),
            ),
            const SizedBox(width: 6),
          ],
          if (compact) ...[
            superResolutionBuilder(false),
            const SizedBox(width: 6),
          ],
          PlayerControlButton(
            key: const ValueKey('player-settings'),
            icon: Icons.tune_rounded,
            tooltip: '播放设置',
            onPressed: onSettings,
            disableAnimations: disableAnimations,
          ),
        ],
      );

      final dock = Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(compact ? 28 : 32),
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : (spacious ? 16 : 12)),
          child: compact
              ? Row(
                  children: [
                    play,
                    const SizedBox(width: 12),
                    Expanded(child: timeline),
                    const SizedBox(width: 8),
                    expand,
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    timeline,
                    SizedBox(height: spacious ? 8 : 4),
                    Row(
                      children: [
                        if (wide) ...[
                          PlayerControlButton(
                            icon: Icons.skip_previous_rounded,
                            tooltip: '上一集',
                            onPressed: onPrevious,
                            height: spacious ? 64 : 48,
                            width: 56,
                            groupStart: true,
                            disableAnimations: disableAnimations,
                          ),
                          const SizedBox(width: 4),
                        ],
                        play,
                        const SizedBox(width: 4),
                        PlayerControlButton(
                          icon: Icons.skip_next_rounded,
                          tooltip: '下一集',
                          onPressed: onNext,
                          height: spacious ? 64 : 48,
                          width: 56,
                          groupEnd: true,
                          disableAnimations: disableAnimations,
                        ),
                        const Spacer(),
                        if (wide) ...[
                          PlayerControlButton(
                            icon: Icons.fast_forward_rounded,
                            label: labels ? '跳过 $skipSeconds 秒' : null,
                            tooltip: '跳过 $skipSeconds 秒，长按设置',
                            onPressed: onSkip,
                            onLongPress: onSkipSettings,
                            disableAnimations: disableAnimations,
                          ),
                          const SizedBox(width: 6),
                        ],
                        superResolutionBuilder(resolutionLabel),
                        const SizedBox(width: 6),
                        PlayerControlButton(
                          icon: Icons.speed_rounded,
                          label: labels ? '${speed}x' : null,
                          tooltip: '播放速度 ${speed}x',
                          onPressed: onSpeed,
                          selected: speed != 1,
                          disableAnimations: disableAnimations,
                        ),
                        const SizedBox(width: 6),
                        PlayerControlButton(
                          icon: Icons.subtitles_outlined,
                          label: labels ? '弹幕' : null,
                          tooltip: danmakuLoading
                              ? '弹幕加载中'
                              : (danmakuOn ? '关闭弹幕' : '打开弹幕'),
                          selected: danmakuOn,
                          loading: danmakuLoading,
                          onPressed: danmakuLoading ? null : onDanmaku,
                          disableAnimations: disableAnimations,
                        ),
                        const SizedBox(width: 6),
                        PlayerControlButton(
                          icon: Icons.video_library_outlined,
                          label: labels ? '选集' : null,
                          tooltip: '选集',
                          onPressed: onEpisodes,
                          disableAnimations: disableAnimations,
                        ),
                        const SizedBox(width: 6),
                        if (wide && volume != null) ...[
                          SizedBox(width: 116, child: volume),
                          const SizedBox(width: 6),
                        ],
                        expand,
                      ],
                    ),
                  ],
                ),
        ),
      );

      return Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: ValueKey('player-controls-scrim'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.3, 0.65, 1],
                    colors: [
                      Color(0xB3000000),
                      Colors.transparent,
                      Colors.transparent,
                      Color(0x80000000),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: margin,
            left: margin,
            right: margin,
            child: _edgeTransition(
              offset: const Offset(0, -12),
              child: _wrap(header),
            ),
          ),
          if (onLock != null && !compact)
            Positioned(
              right: margin,
              top: constraints.maxHeight / 2 - 24,
              child: _wrap(PlayerControlButton(
                icon: Icons.lock_open_rounded,
                tooltip: '锁定面板',
                onPressed: onLock,
                disableAnimations: disableAnimations,
              )),
            ),
          Positioned(
            bottom: margin,
            left: margin,
            right: margin,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: _edgeTransition(
                  offset: const Offset(0, 16),
                  child: _wrap(dock),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _edgeTransition({required Offset offset, required Widget child}) =>
      AnimatedBuilder(
        animation: visibility,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: disableAnimations || MediaQuery.disableAnimationsOf(context)
              ? Offset.zero
              : offset * (1 - Curves.easeOutCubic.transform(visibility.value)),
          child: child,
        ),
      );
}

/// Fade the full viewport in place. Only the header and dock translate, inside
/// PlayerControlsView, so the scrim can never detach from the video edges.
class PlayerControlsVisibility extends StatelessWidget {
  const PlayerControlsVisibility({
    super.key,
    required this.visible,
    required this.animation,
    required this.child,
    this.disableAnimations = false,
  });

  final bool visible;
  final Animation<double> animation;
  final Widget child;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        ignoring: !visible,
        child: ExcludeFocus(
          excluding: !visible,
          child: ExcludeSemantics(
            excluding: !visible,
            child: disableAnimations || MediaQuery.disableAnimationsOf(context)
                ? Visibility(visible: visible, child: child)
                : FadeTransition(opacity: animation, child: child),
          ),
        ),
      );
}

class PlayerSuperResolutionButton extends StatelessWidget {
  const PlayerSuperResolutionButton({
    super.key,
    required this.mode,
    required this.onSelected,
    required this.acquirePlayerPanelHold,
    required this.onMenuVisibilityChanged,
    this.showLabel = true,
    this.disableAnimations = false,
  });

  final SuperResolutionMode mode;
  final ValueChanged<SuperResolutionMode> onSelected;
  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final ValueChanged<bool> onMenuVisibilityChanged;
  final bool showLabel;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) => PlayerPanelHoldMenuAnchor(
        acquirePlayerPanelHold: acquirePlayerPanelHold,
        onVisibilityChanged: onMenuVisibilityChanged,
        consumeOutsideTap: true,
        builder: (context, controller, _) => PlayerControlButton(
          key: const ValueKey('player-super-resolution'),
          icon: Icons.auto_awesome_rounded,
          label: showLabel ? '超分辨率' : null,
          tooltip: '超分辨率：${mode.label}',
          selected: mode != SuperResolutionMode.off,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          disableAnimations: disableAnimations,
        ),
        menuChildren: [
          for (final option in SuperResolutionMode.values)
            MenuItemButton(
              onPressed: () => onSelected(option),
              leadingIcon: Icon(switch (option) {
                SuperResolutionMode.off => Icons.block_rounded,
                SuperResolutionMode.efficiency => Icons.bolt_rounded,
                SuperResolutionMode.quality => Icons.auto_awesome_rounded,
              }),
              trailingIcon:
                  option == mode ? const Icon(Icons.check_rounded) : null,
              child: Text(option.label),
            ),
        ],
      );
}

/// Filled buttons use a spring for press/release and a contrasting active shape.
/// Material's focus, hover, ink and semantic behavior remain available.
class PlayerControlButton extends StatefulWidget {
  const PlayerControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
    this.onLongPress,
    this.prominent = false,
    this.selected = false,
    this.loading = false,
    this.groupStart = false,
    this.groupEnd = false,
    this.width,
    this.height = 48,
    this.iconSize = 24,
    this.disableAnimations = false,
  });

  final IconData icon;
  final String tooltip;
  final String? label;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool prominent;
  final bool selected;
  final bool loading;
  final bool groupStart;
  final bool groupEnd;
  final double? width;
  final double height;
  final double iconSize;
  final bool disableAnimations;

  @override
  State<PlayerControlButton> createState() => _PlayerControlButtonState();
}

class _PlayerControlButtonState extends State<PlayerControlButton>
    with SingleTickerProviderStateMixin {
  late final _press = AnimationController.unbounded(vsync: this);

  void _setPressed(bool pressed) {
    if (widget.disableAnimations || MediaQuery.disableAnimationsOf(context)) {
      _press.value = pressed ? 1 : 0;
      return;
    }
    _press.animateWith(SpringSimulation(
      SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: 500,
        ratio: 0.72,
      ),
      _press.value,
      pressed ? 1 : 0,
      _press.velocity,
    ));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = widget.selected;
    final background = widget.prominent
        ? colors.primary
        : (active ? colors.secondaryContainer : colors.surfaceContainerHigh);
    final foreground = widget.prominent
        ? colors.onPrimary
        : (active ? colors.onSecondaryContainer : colors.onSurface);
    final enabled = widget.onPressed != null;
    return Tooltip(
      message: widget.tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        label: widget.tooltip,
        button: true,
        enabled: enabled,
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            final restRadius = active ? 18.0 : widget.height / 2;
            final radius = (restRadius + (12 - restRadius) * _press.value)
                .clamp(8.0, widget.height / 2);
            final shape = RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(widget.groupEnd ? 12 : radius),
                right: Radius.circular(widget.groupStart ? 12 : radius),
              ),
            );
            return Material(
              color: background,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: shape,
                onTap: widget.onPressed,
                onLongPress: widget.onLongPress,
                onHighlightChanged: _setPressed,
                child: SizedBox(
                  width: widget.width ?? (widget.label == null ? 48 : null),
                  height: widget.height,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: widget.label == null ? 0 : 16),
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.loading)
                            SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: foreground,
                              ),
                            )
                          else
                            Icon(widget.icon,
                                size: widget.iconSize,
                                color: enabled
                                    ? foreground
                                    : foreground.withValues(alpha: 0.38)),
                          if (widget.label != null) ...[
                            const SizedBox(width: 8),
                            Text(widget.label!,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: foreground,
                                      fontWeight: FontWeight.w700,
                                    )),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PlayerTimeline extends StatelessWidget {
  const PlayerTimeline({
    super.key,
    required this.position,
    required this.buffered,
    required this.duration,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final Duration position;
  final Duration buffered;
  final Duration duration;
  final VoidCallback onStart;
  final ValueChanged<Duration> onUpdate;
  final ValueChanged<Duration> onEnd;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds.clamp(0, 1 << 53).toDouble();
    final value = position.inMilliseconds.toDouble().clamp(0.0, total);
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colors.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(durationToString(position),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style?.copyWith(
                      color: colors.primary, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: Text(durationToString(duration),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style),
            ),
          ],
        ),
        Semantics(
          label: '播放进度',
          child: SizedBox(
            height: 48,
            child: Slider(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              value: value,
              max: total > 0 ? total : 1,
              secondaryTrackValue:
                  buffered.inMilliseconds.toDouble().clamp(value, total),
              label: durationToString(position),
              semanticFormatterCallback: (value) =>
                  '${durationToString(Duration(milliseconds: value.round()))}，'
                  '共 ${durationToString(duration)}',
              onChangeStart: total > 0 ? (_) => onStart() : null,
              onChanged: total > 0
                  ? (value) => onUpdate(Duration(milliseconds: value.round()))
                  : null,
              onChangeEnd: total > 0
                  ? (value) => onEnd(Duration(milliseconds: value.round()))
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
