import 'package:flutter/material.dart';
import 'package:kazumi/modules/my/watch_stats.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

enum MyDestination {
  theme,
  player,
  danmaku,
  rules,
  history,
  downloads,
  sync,
  storage,
  about,
}

const _tileRadius = BorderRadius.all(Radius.circular(28));

class MySpaceView extends StatelessWidget {
  const MySpaceView({
    super.key,
    required this.stats,
    required this.onOpen,
  });

  final WatchStats stats;
  final ValueChanged<MyDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final inset = constraints.maxWidth < 600 ? 16.0 : 32.0;
      final width = (constraints.maxWidth - inset * 2).clamp(0.0, 1120.0);
      final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
      final wide = width >= 840 && !largeText;
      final columnWidth = wide ? (width - 12) / 2 : width;
      final stackTools = columnWidth < 300 || largeText;
      return SingleChildScrollView(
        key: const PageStorageKey('my-space'),
        padding: EdgeInsets.fromLTRB(inset, 12, inset, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdaptivePair(
                  stack: !wide,
                  gap: 20,
                  first: const _SpaceHeading(),
                  second: _WatchStatsPanel(
                    bangumiCount: stats.watchedBangumiCount,
                    episodeCount: stats.watchedEpisodeCount,
                  ),
                ),
                const SizedBox(height: 28),
                _AdaptivePair(
                  stack: !wide,
                  gap: 12,
                  first: _RulesTile(onTap: () => onOpen(MyDestination.rules)),
                  second: _AdaptivePair(
                    stack: stackTools,
                    gap: 12,
                    first: _ToolTile(
                      icon: Icons.history_rounded,
                      title: '历史记录',
                      caption:
                          stats.watchedBangumiCount == 0 ? '暂无观看记录' : '查看观看记录',
                      color: colors.secondaryContainer,
                      foreground: colors.onSecondaryContainer,
                      onTap: () => onOpen(MyDestination.history),
                    ),
                    second: _ToolTile(
                      icon: Icons.download_rounded,
                      title: '离线下载',
                      caption: stats.downloadTaskCount == 0
                          ? '管理离线内容'
                          : '${stats.downloadTaskCount} 集下载任务',
                      color: colors.tertiaryContainer,
                      foreground: colors.onTertiaryContainer,
                      onTap: () => onOpen(MyDestination.downloads),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _AdaptivePair(
                  stack: !wide,
                  gap: 12,
                  first: _PreferencesPanel(
                    onOpen: onOpen,
                    stack: columnWidth < 280 || largeText,
                  ),
                  second: _AdaptivePair(
                    stack: stackTools,
                    gap: 12,
                    first: _ToolTile(
                      icon: Icons.cloud_sync_rounded,
                      title: '同步备份',
                      caption: '跨设备同步数据',
                      color: colors.surfaceContainer,
                      foreground: colors.onSurface,
                      onTap: () => onOpen(MyDestination.sync),
                    ),
                    second: _ToolTile(
                      icon: Icons.cleaning_services_rounded,
                      title: '存储管理',
                      caption: '缓存与日志',
                      color: colors.surfaceContainer,
                      foreground: colors.onSurface,
                      onTap: () => onOpen(MyDestination.storage),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.center,
                  child: _ExpressiveAction(
                    color: colors.surfaceContainerLow,
                    foreground: colors.onSurfaceVariant,
                    onTap: () => onOpen(MyDestination.about),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 20),
                          SizedBox(width: 8),
                          Flexible(child: Text('关于 Kazumi')),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _WatchStatsPanel extends StatelessWidget {
  const _WatchStatsPanel({
    required this.bangumiCount,
    required this.episodeCount,
  });

  final int bangumiCount;
  final int episodeCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('观看统计',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _StatCount(value: bangumiCount, label: '看过番剧')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.auto_awesome_rounded,
                      color: colors.primary, size: 20),
                ),
                Expanded(child: _StatCount(value: episodeCount, label: '观看集数')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCount extends StatelessWidget {
  const _StatCount({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Scale large totals without shrinking their labels.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('$value',
              style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _SpaceHeading extends StatelessWidget {
  const _SpaceHeading();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            '个人中心',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                  height: 1.2,
                ),
          ),
        ),
        const SizedBox(width: 12),
        _ShapeIcon(
          shape: _SpaceShape.sun,
          icon: Icons.sentiment_satisfied_alt_rounded,
          size: 64,
          color: colors.tertiaryContainer,
          foreground: colors.onTertiaryContainer,
        ),
      ],
    );
  }
}

class _RulesTile extends StatelessWidget {
  const _RulesTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _ExpressiveAction(
      color: colors.primary,
      foreground: colors.onPrimary,
      radius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(64),
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('规则设置',
                      style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onPrimary)),
                  const SizedBox(height: 6),
                  Text('管理番剧来源',
                      style:
                          text.bodyMedium?.copyWith(color: colors.onPrimary)),
                  const SizedBox(height: 20),
                  _ArrowCue(
                      color: colors.onPrimary, foreground: colors.primary),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _ShapeIcon(
              shape: _SpaceShape.clover,
              icon: Icons.extension_rounded,
              size: 80,
              color: colors.primaryContainer,
              foreground: colors.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.caption,
    required this.color,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Color color;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _ExpressiveAction(
      color: color,
      foreground: foreground,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 30),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
            const SizedBox(height: 26),
            Text(title,
                style: text.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700, color: foreground)),
            const SizedBox(height: 6),
            Text(caption,
                style:
                    text.bodySmall?.copyWith(color: foreground, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _PreferencesPanel extends StatelessWidget {
  const _PreferencesPanel({required this.onOpen, required this.stack});

  final ValueChanged<MyDestination> onOpen;
  final bool stack;

  static const _entries = [
    ('外观', Icons.palette_rounded, MyDestination.theme),
    ('播放', Icons.play_circle_rounded, MyDestination.player),
    ('弹幕', Icons.subtitles_rounded, MyDestination.danmaku),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final buttons = Flex(
      direction: stack ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _entries.length; i++) ...[
          if (i > 0) const SizedBox(width: 4, height: 4),
          if (stack) _button(i) else Expanded(child: _button(i)),
        ],
      ],
    );
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: _tileRadius,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('偏好设置',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: colors.onSurface)),
            ),
            const SizedBox(height: 16),
            if (stack) buttons else IntrinsicHeight(child: buttons),
          ],
        ),
      ),
    );
  }

  Widget _button(int index) {
    final (label, icon, destination) = _entries[index];
    return _PreferenceAction(
      icon: icon,
      label: label,
      stack: stack,
      first: index == 0,
      last: index == _entries.length - 1,
      onTap: () => onOpen(destination),
    );
  }
}

class _PreferenceAction extends StatelessWidget {
  const _PreferenceAction({
    required this.icon,
    required this.label,
    required this.stack,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool stack;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = stack
        ? BorderRadius.vertical(
            top: Radius.circular(first ? 24 : 8),
            bottom: Radius.circular(last ? 24 : 8))
        : BorderRadius.horizontal(
            left: Radius.circular(first ? 24 : 8),
            right: Radius.circular(last ? 24 : 8));
    return _ExpressiveAction(
      color: colors.secondaryContainer,
      foreground: colors.onSecondaryContainer,
      radius: radius,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 10),
            Text(label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSecondaryContainer)),
          ],
        ),
      ),
    );
  }
}

class MySettingsButton extends StatelessWidget {
  const MySettingsButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: '全部设置',
      child: _ExpressiveAction(
        color: colors.surfaceContainerHigh,
        foreground: colors.onSurface,
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 20),
              SizedBox(width: 8),
              Text('设置'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowCue extends StatelessWidget {
  const _ArrowCue({required this.color, required this.foreground});

  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: 52,
          height: 32,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.arrow_forward_rounded, color: foreground, size: 20),
        ),
      );
}

enum _SpaceShape { sun, clover }

class _ShapeIcon extends StatelessWidget {
  const _ShapeIcon({
    required this.shape,
    required this.icon,
    required this.size,
    required this.color,
    required this.foreground,
  });

  final _SpaceShape shape;
  final IconData icon;
  final double size;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: ClipPath(
          clipper: _SpaceShapeClipper(shape),
          child: ColoredBox(
            color: color,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, color: foreground, size: size * .44),
            ),
          ),
        ),
      );
}

class _SpaceShapeClipper extends CustomClipper<Path> {
  const _SpaceShapeClipper(this.shape);

  final _SpaceShape shape;
  static final _paths = {
    _SpaceShape.sun: MaterialShapes.sunny.toPath(),
    _SpaceShape.clover: MaterialShapes.clover4Leaf.toPath(),
  };

  @override
  Path getClip(Size size) => _paths[shape]!
      .transform(Matrix4.diagonal3Values(size.width, size.height, 1).storage);

  @override
  bool shouldReclip(_SpaceShapeClipper oldClipper) => oldClipper.shape != shape;
}

class _ExpressiveAction extends StatefulWidget {
  const _ExpressiveAction({
    required this.color,
    required this.foreground,
    required this.onTap,
    required this.child,
    this.radius = _tileRadius,
  });

  final Color color;
  final Color foreground;
  final VoidCallback onTap;
  final Widget child;
  final BorderRadius radius;

  @override
  State<_ExpressiveAction> createState() => _ExpressiveActionState();
}

class _ExpressiveActionState extends State<_ExpressiveAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : Duration(milliseconds: _pressed ? 150 : 300);
    return Semantics(
      button: true,
      child: AnimatedScale(
        scale: _pressed && !reducedMotion ? .97 : 1,
        duration: duration,
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: _pressed ? BorderRadius.circular(16) : widget.radius,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (value) => setState(() => _pressed = value),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return widget.foreground.withValues(alpha: .10);
                }
                if (states.contains(WidgetState.focused)) {
                  return widget.foreground.withValues(alpha: .12);
                }
                if (states.contains(WidgetState.hovered)) {
                  return widget.foreground.withValues(alpha: .08);
                }
                return null;
              }),
              child: IconTheme.merge(
                data: IconThemeData(color: widget.foreground),
                child: DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: widget.foreground,
                      ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdaptivePair extends StatelessWidget {
  const _AdaptivePair({
    required this.first,
    required this.second,
    required this.stack,
    required this.gap,
  });

  final Widget first;
  final Widget second;
  final bool stack;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [first, SizedBox(height: gap), second],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: first),
          SizedBox(width: gap),
          Expanded(child: second),
        ],
      ),
    );
  }
}
