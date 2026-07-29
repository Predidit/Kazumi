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
      const SizedBox(height: 12),
      _entryGroup(stats),
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
        Expanded(flex: 2, child: _entryGroup(stats)),
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
    final tiles = <Widget>[
      _StatTile(
        value: '${stats.watchedBangumiCount}',
        unit: '部',
        label: '看过番剧',
      ),
      _StatTile(
        value: '${stats.watchedEpisodeCount}',
        unit: '集',
        label: '观看集数',
      ),
      _StatTile(
        value: '${stats.downloadTaskCount}',
        unit: '集',
        label: '离线缓存',
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

  /// Peer entries share one surface: the tonal accent belongs on the icon
  /// badge, not on the card, so the page keeps a single point of emphasis.
  /// Grouped corners (round outside, tight inside) tie them into one block.
  Widget _entryGroup(WatchStats stats) {
    final entries = <_EntryData>[
      _EntryData(
        icon: Icons.history_rounded,
        title: '历史记录',
        subtitle: stats.lastWatchName != null
            ? '最近看到 ${stats.lastWatchName}'
            : '还没有观看记录',
        onTap: () => context.pushNamed('/settings/history/'),
      ),
      _EntryData(
        icon: Icons.download_rounded,
        title: '离线下载',
        subtitle: '缓存任务与本地文件',
        onTap: () => context.pushNamed('/settings/download/'),
      ),
      _EntryData(
        icon: Icons.settings_rounded,
        title: '设置',
        subtitle: '播放、弹幕、外观与规则',
        onTap: () => context.pushNamed('/settings/'),
      ),
    ];
    const outer = Radius.circular(16);
    const inner = Radius.circular(4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          _EntryTile(
            data: entries[i],
            borderRadius: BorderRadius.vertical(
              top: i == 0 ? outer : inner,
              bottom: i == entries.length - 1 ? outer : inner,
            ),
          ),
        ],
      ],
    );
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
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

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
        ],
      ),
    );
  }
}

class _EntryData {
  const _EntryData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.data, required this.borderRadius});

  final _EntryData data;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  data.icon,
                  size: 18,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
