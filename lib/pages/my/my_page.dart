import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/my/watch_stats.dart';
import 'package:kazumi/pages/menu/route_visibility.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/my/recent_watch_card.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/date_time.dart';
import 'package:kazumi/utils/format.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key, required this.controller});

  final MyController controller;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  MyController get myController => widget.controller;

  bool _attached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This page stays mounted under the player, which rewrites history every
    // second. Drop the subscription while covered, re-derive on the way back.
    _setAttached(!RouteVisibility.isCoveredOf(context));
  }

  @override
  void dispose() {
    _setAttached(false);
    super.dispose();
  }

  void _setAttached(bool value) {
    if (_attached == value) {
      return;
    }
    _attached = value;
    if (value) {
      myController.attach();
    } else {
      myController.detach();
    }
  }

  int _recentCrossCount() {
    final width = MediaQuery.sizeOf(context).width;
    if (width > LayoutBreakpoint.medium['width']!) {
      return 3;
    }
    if (width > LayoutBreakpoint.compact['width']!) {
      return 2;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final bool wide =
        MediaQuery.sizeOf(context).width > LayoutBreakpoint.compact['width']!;
    return Scaffold(
      appBar: const SysAppBar(title: Text('我的'), needTopOffset: false),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Observer(
          builder: (context) {
            final stats = myController.watchStats;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 1400 : 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide) _wideHeader(stats) else ..._narrowHeader(stats),
                      ..._recentSection(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _narrowHeader(WatchStats stats) {
    return [
      _CollectHero(stats: stats),
      const SizedBox(height: 12),
      _statTiles(stats),
      const SizedBox(height: 24),
      _sectionLabel('快捷入口'),
      const SizedBox(height: 12),
      ..._entryCards(stats),
    ];
  }

  Widget _wideHeader(WatchStats stats) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CollectHero(stats: stats),
              const SizedBox(height: 12),
              _statTiles(stats),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionLabel('快捷入口'),
              const SizedBox(height: 12),
              ..._entryCards(stats),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _recentSection() {
    final crossCount = _recentCrossCount();
    final int maxCount = crossCount == 1 ? 3 : crossCount * 2;
    final int count = myController.recentWatches.length < maxCount
        ? myController.recentWatches.length
        : maxCount;
    if (count == 0) {
      return const [];
    }
    return [
      const SizedBox(height: 24),
      _sectionLabel('继续观看'),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          crossAxisSpacing: StyleString.cardSpace,
          mainAxisSpacing: StyleString.cardSpace,
          mainAxisExtent: 128,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          final item = myController.recentWatches[index];
          return RecentWatchCard(key: ValueKey(item.id), item: item);
        },
      ),
    ];
  }

  Widget _sectionLabel(String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _statTiles(WatchStats stats) {
    final colorScheme = Theme.of(context).colorScheme;
    final tiles = <Widget>[
      _StatTile(
        icon: Icons.smart_display_rounded,
        iconColor: colorScheme.primary,
        value: '${stats.watchedBangumiCount}',
        unit: '部',
        label: '看过番剧',
      ),
      _StatTile(
        icon: Icons.playlist_play_rounded,
        iconColor: colorScheme.secondary,
        value: '${stats.watchedEpisodeCount}',
        unit: '集',
        label: '观看集数',
      ),
      _StatTile(
        icon: Icons.sd_storage_rounded,
        iconColor: colorScheme.tertiary,
        value: '${stats.downloadTaskCount}',
        unit: '集',
        label: '离线缓存',
        caption: stats.downloadedBytes > 0
            ? formatBytes(stats.downloadedBytes)
            : null,
      ),
    ];
    // Tiles hold different amounts of text; stretch keeps them level.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }

  List<Widget> _entryCards(WatchStats stats) {
    final colorScheme = Theme.of(context).colorScheme;
    return [
      _EntryCard(
        icon: Icons.history_rounded,
        title: '历史记录',
        subtitle: stats.lastWatchName != null
            ? '最近看到 ${stats.lastWatchName}'
            : '还没有观看记录',
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
        onTap: () => context.pushNamed('/settings/history/'),
      ),
      const SizedBox(height: 12),
      _EntryCard(
        icon: Icons.download_rounded,
        title: '离线下载',
        subtitle: stats.downloadBangumiCount > 0
            ? '${stats.downloadBangumiCount} 部番剧已缓存'
            : '还没有缓存内容',
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
        onTap: () => context.pushNamed('/settings/download/'),
      ),
      const SizedBox(height: 12),
      _EntryCard(
        icon: Icons.settings_rounded,
        title: '设置',
        subtitle: '播放、弹幕、外观与规则',
        background: colorScheme.surfaceContainerLow,
        foreground: colorScheme.onSurface,
        onTap: () => context.pushNamed('/settings/'),
      ),
    ];
  }
}

class _CollectHero extends StatelessWidget {
  const _CollectHero({required this.stats});

  final WatchStats stats;

  static const List<CollectType> _order = [
    CollectType.watching,
    CollectType.planToWatch,
    CollectType.onHold,
    CollectType.watched,
    CollectType.abandoned,
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final lastWatchTime = stats.lastWatchTime;
    final String caption = lastWatchTime == null
        ? '收藏番剧后会在这里汇总'
        : '最近观看 ${formatTimestampToRelativeTime(lastWatchTime.millisecondsSinceEpoch ~/ 1000)}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '我的追番',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${stats.collectedCount}',
                  style: textTheme.displaySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: ' 部',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (stats.collectedCount > 0)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in _order)
                  if ((stats.collectCounts[type] ?? 0) > 0)
                    _CollectChip(
                      label: type.label,
                      count: stats.collectCounts[type]!,
                    ),
              ],
            ),
          if (stats.collectedCount > 0) const SizedBox(height: 12),
          Text(
            caption,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectChip extends StatelessWidget {
  const _CollectChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $count',
        style: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.unit,
    required this.label,
    this.caption,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String unit;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null)
            Text(
              caption!,
              style: textTheme.bodySmall?.copyWith(color: iconColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: foreground),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(color: foreground),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.75),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: foreground.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
