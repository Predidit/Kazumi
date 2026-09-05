import 'package:flutter/material.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/utils/date_time.dart';

enum _LibrarySort {
  updated('最近收藏'),
  played('最近观看'),
  title('番剧名称');

  const _LibrarySort(this.label);
  final String label;
}

String _title(BangumiItem item) =>
    item.nameCn.trim().isEmpty ? item.name : item.nameCn;

IconData _statusIcon(CollectType type) => switch (type) {
      CollectType.watching => Icons.play_arrow_rounded,
      CollectType.planToWatch => Icons.bookmark_outline_rounded,
      CollectType.onHold => Icons.pause_rounded,
      CollectType.watched => Icons.done_all_rounded,
      CollectType.abandoned => Icons.archive_outlined,
      CollectType.none => Icons.add_rounded,
    };

String _episode(History history) => history.lastWatchEpisodeName.trim().isEmpty
    ? '第 ${history.lastWatchEpisode} 话'
    : history.lastWatchEpisodeName;

String _position(History history) {
  final duration = history.progresses[history.lastWatchEpisode]?.progress;
  if (duration == null || duration <= Duration.zero) return _episode(history);
  final hours = duration.inHours;
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  final time = hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  return '${_episode(history)} · $time';
}

/// A personal library: status and playback context take precedence over posters.
/// Data and actions stay with the page so this view has no storage dependencies.
class CollectLibrary extends StatefulWidget {
  const CollectLibrary({
    super.key,
    required this.collectibles,
    required this.histories,
    required this.showCounts,
    required this.managing,
    required this.onOpen,
    required this.onResume,
    required this.onStatusChanged,
    required this.onDiscover,
    this.busy = false,
  });

  final List<CollectedBangumi> collectibles;
  final List<History> histories;
  final bool showCounts;
  final bool managing;
  final bool busy;
  final ValueChanged<BangumiItem> onOpen;
  final ValueChanged<History> onResume;
  final void Function(BangumiItem, CollectType) onStatusChanged;
  final VoidCallback onDiscover;

  @override
  State<CollectLibrary> createState() => _CollectLibraryState();
}

class _CollectLibraryState extends State<CollectLibrary> {
  static final _types =
      CollectType.values.where((type) => type.isCollected).toList();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  CollectType _selected = CollectType.watching;
  _LibrarySort _sort = _LibrarySort.updated;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _select(CollectType type) {
    setState(() => _selected = type);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final latest = <int, History>{};
    for (final history in widget.histories) {
      final previous = latest[history.bangumiItem.id];
      if (previous == null ||
          history.lastWatchTime.isAfter(previous.lastWatchTime)) {
        latest[history.bangumiItem.id] = history;
      }
    }
    final counts = <CollectType, int>{for (final type in _types) type: 0};
    for (final entry in widget.collectibles) {
      final type = CollectType.fromValue(entry.type);
      if (type.isCollected) counts[type] = counts[type]! + 1;
    }
    final query = _query.trim().toLowerCase();
    final entries = widget.collectibles.where((entry) {
      final item = entry.bangumiItem;
      return entry.type == _selected.value &&
          (query.isEmpty ||
              [item.nameCn, item.name, ...item.alias]
                  .any((name) => name.toLowerCase().contains(query)));
    }).toList();
    entries.sort((a, b) {
      final int order;
      switch (_sort) {
        case _LibrarySort.updated:
          order = b.time.compareTo(a.time);
        case _LibrarySort.played:
          final aTime = latest[a.bangumiItem.id]?.lastWatchTime;
          final bTime = latest[b.bangumiItem.id]?.lastWatchTime;
          order = aTime == null
              ? (bTime == null ? 0 : 1)
              : (bTime == null ? -1 : bTime.compareTo(aTime));
        case _LibrarySort.title:
          order = _title(a.bangumiItem).compareTo(_title(b.bangumiItem));
      }
      return order != 0 ? order : b.time.compareTo(a.time);
    });
    History? resume;
    if (_selected == CollectType.watching &&
        query.isEmpty &&
        !widget.managing) {
      for (final entry in entries) {
        final history = latest[entry.bangumiItem.id];
        if (history != null &&
            (resume == null ||
                history.lastWatchTime.isAfter(resume.lastWatchTime))) {
          resume = history;
        }
      }
    }

    return LayoutBuilder(builder: (context, constraints) {
      final inset = constraints.maxWidth < 600 ? 16.0 : 28.0;
      final contentWidth =
          (constraints.maxWidth - inset * 2).clamp(0.0, 1200.0);
      final side = (constraints.maxWidth - contentWidth) / 2;
      final twoColumns = contentWidth >= 840 &&
          MediaQuery.textScalerOf(context).scale(14) < 22;
      final horizontal = EdgeInsets.symmetric(horizontal: side);
      return CustomScrollView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: horizontal,
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '每个故事，都有自己的进度。',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  _statusSelector(counts, contentWidth),
                  const SizedBox(height: 24),
                  _toolbar(),
                  if (widget.managing) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(children: [
                        Icon(Icons.tune_rounded,
                            color: colors.onSecondaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('点击番剧调整追番状态，或从收藏中移除。',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSecondaryContainer)),
                        ),
                      ]),
                    ),
                  ],
                  if (resume != null) ...[
                    const SizedBox(height: 20),
                    _ResumeCard(
                      history: resume,
                      onResume:
                          widget.busy ? null : () => widget.onResume(resume!),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(children: [
                    Expanded(
                      child: Text(
                        query.isNotEmpty
                            ? '搜索结果'
                            : switch (_selected) {
                                CollectType.watching => '正在追的故事',
                                CollectType.planToWatch => '留给下一次心动',
                                CollectType.onHold => '暂时按下暂停',
                                CollectType.watched => '已经走过的旅程',
                                _ => '归档的故事',
                              },
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (widget.showCounts)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text('${entries.length} 部',
                            style: theme.textTheme.labelLarge
                                ?.copyWith(color: colors.onSurfaceVariant)),
                      ),
                  ]),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (entries.isEmpty)
            SliverPadding(
              padding: horizontal,
              sliver: SliverToBoxAdapter(child: _emptyState(query, counts)),
            )
          else
            SliverPadding(
              padding: horizontal,
              sliver: SliverList.builder(
                itemCount: (entries.length / (twoColumns ? 2 : 1)).ceil(),
                itemBuilder: (context, index) {
                  final first = index * (twoColumns ? 2 : 1);
                  Widget card(int i) => _LibraryCard(
                        key: ValueKey(entries[i].bangumiItem.id),
                        entry: entries[i],
                        history: latest[entries[i].bangumiItem.id],
                        managing: widget.managing,
                        busy: widget.busy,
                        onOpen: () => widget.onOpen(entries[i].bangumiItem),
                        onStatusChanged: (type) => widget.onStatusChanged(
                            entries[i].bangumiItem, type),
                      );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: twoColumns
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: card(first)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: first + 1 < entries.length
                                    ? card(first + 1)
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          )
                        : card(first),
                  );
                },
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      );
    });
  }

  Widget _statusSelector(Map<CollectType, int> counts, double width) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final minWidth = MediaQuery.textScalerOf(context).scale(56) + 8;
    final scrollable = width < minWidth * _types.length;
    final tileWidth = scrollable ? minWidth : (width - 4 * 4) / 5;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final type in _types)
            Padding(
              padding: EdgeInsets.only(right: type == _types.last ? 0 : 4),
              child: Semantics(
                selected: _selected == type,
                button: true,
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeInOutCubicEmphasized,
                  width: tileWidth,
                  decoration: BoxDecoration(
                    color: _selected == type
                        ? colors.primary
                        : colors.surfaceContainerLow,
                    borderRadius:
                        BorderRadius.circular(_selected == type ? 28 : 16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _select(type),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 4),
                        child: Column(
                          children: [
                            if (widget.showCounts) ...[
                              Text('${counts[type]}',
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _selected == type
                                        ? colors.onPrimary
                                        : colors.onSurface,
                                  )),
                              const SizedBox(height: 4),
                            ] else ...[
                              Icon(_statusIcon(type),
                                  color: _selected == type
                                      ? colors.onPrimary
                                      : colors.onSurfaceVariant),
                              const SizedBox(height: 6),
                            ],
                            Text(type.label,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: _selected == type
                                      ? colors.onPrimary
                                      : colors.onSurfaceVariant,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    final colors = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            hintText: '搜索${_selected.label}的番剧',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: '清除搜索',
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close_rounded)),
            filled: true,
            fillColor: colors.surfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      PopupMenuButton<_LibrarySort>(
        tooltip: '排序：${_sort.label}',
        initialValue: _sort,
        onSelected: (value) => setState(() => _sort = value),
        itemBuilder: (_) => [
          for (final sort in _LibrarySort.values)
            PopupMenuItem(
              value: sort,
              child: Row(children: [
                Icon(_sort == sort ? Icons.check_rounded : Icons.sort_rounded,
                    size: 20),
                const SizedBox(width: 12),
                Text(sort.label),
              ]),
            ),
        ],
        icon: const Icon(Icons.sort_rounded),
      ),
    ]);
  }

  Widget _emptyState(String query, Map<CollectType, int> counts) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasSearch = query.isNotEmpty;
    final isEmpty = widget.collectibles.isEmpty;
    final otherType = _types.where((type) => counts[type]! > 0).firstOrNull;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
              hasSearch ? Icons.search_off_rounded : _statusIcon(_selected),
              size: 32,
              color: colors.onSecondaryContainer),
        ),
        const SizedBox(height: 20),
        Text(
          hasSearch
              ? '没有找到匹配的番剧'
              : isEmpty
                  ? '从第一部心动的番剧开始'
                  : '还没有${_selected.label}的番剧',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          hasSearch
              ? '试试其他名称，或切换追番状态查找。'
              : isEmpty
                  ? '在番剧详情中添加收藏，在这里慢慢看。'
                  : '可以在番剧的状态菜单中调整分类。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        FilledButton.tonalIcon(
          onPressed: hasSearch
              ? _clearSearch
              : otherType != null
                  ? () => _select(otherType)
                  : widget.onDiscover,
          icon: Icon(hasSearch ? Icons.close_rounded : Icons.arrow_forward),
          label: Text(hasSearch
              ? '清除搜索'
              : otherType != null
                  ? '查看${otherType.label}'
                  : '发现番剧'),
        ),
      ]),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.history, required this.onResume});

  final History history;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onResume,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('继续上次的故事',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: colors.onPrimaryContainer)),
                  const SizedBox(height: 8),
                  Text(_title(history.bangumiItem),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onPrimaryContainer)),
                  const SizedBox(height: 8),
                  Text(_position(history),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colors.onPrimaryContainer)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            IconButton.filled(
              tooltip: '继续观看',
              onPressed: onResume,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 32),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    super.key,
    required this.entry,
    required this.history,
    required this.managing,
    required this.busy,
    required this.onOpen,
    required this.onStatusChanged,
  });

  final CollectedBangumi entry;
  final History? history;
  final bool managing;
  final bool busy;
  final VoidCallback onOpen;
  final ValueChanged<CollectType> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final item = entry.bangumiItem;
    final type = CollectType.fromValue(entry.type);
    final statusColor = managing ? colors.primary : colors.onSurfaceVariant;
    return MenuAnchor(
      consumeOutsideTap: true,
      menuChildren: [
        for (final status in CollectType.values.where((t) => t.isCollected))
          MenuItemButton(
            leadingIcon: Icon(_statusIcon(status)),
            trailingIcon: status == type
                ? const Icon(Icons.check_rounded, size: 18)
                : null,
            onPressed:
                busy || status == type ? null : () => onStatusChanged(status),
            child: Text(status.label),
          ),
        const Divider(),
        MenuItemButton(
          leadingIcon: Icon(Icons.delete_outline_rounded, color: colors.error),
          onPressed: busy ? null : () => onStatusChanged(CollectType.none),
          child: Text('移除收藏', style: TextStyle(color: colors.error)),
        ),
      ],
      builder: (context, menu, _) {
        void toggleMenu() => menu.isOpen ? menu.close() : menu.open();
        return Material(
          color: colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: managing
                ? BorderSide(color: colors.outlineVariant)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy ? null : (managing ? toggleMenu : onOpen),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: NetworkImgLayer(
                      src: item.images['large'] ?? '',
                      width: 72,
                      height: 104,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(_title(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface)),
                        const SizedBox(height: 8),
                        Text(
                          history != null
                              ? '上次看到 ${_position(history!)}'
                              : type == CollectType.watched
                                  ? '已标记看过'
                                  : type == CollectType.planToWatch
                                      ? '还没开始，留待下次观看'
                                      : '暂无本地观看记录',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          history != null
                              ? '${formatTimestampToRelativeTime(history!.lastWatchTime.millisecondsSinceEpoch ~/ 1000)}观看'
                              : '${entry.time.year}.${entry.time.month.toString().padLeft(2, '0')}.${entry.time.day.toString().padLeft(2, '0')} 收藏',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: '修改${_title(item)}的追番状态',
                    onPressed: busy ? null : toggleMenu,
                    icon: Icon(
                        managing
                            ? Icons.tune_rounded
                            : Icons.more_horiz_rounded,
                        color: statusColor),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
