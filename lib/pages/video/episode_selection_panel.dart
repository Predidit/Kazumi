import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/split_list_row.dart';
import 'package:kazumi/bean/widget/split_list_selector.dart';
import 'package:kazumi/bean/widget/tonal_card.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/pages/video/episode_range_strip.dart';
import 'package:kazumi/pages/video/episode_road_picker.dart';
import 'package:kazumi/pages/video/player_panel_layout.dart';

enum _EpisodeViewMode { grid, list }

class EpisodeSelectionPanel extends StatefulWidget {
  const EpisodeSelectionPanel({
    super.key,
    required this.title,
    required this.roads,
    required this.selectedRoad,
    required this.selectedEpisode,
    required this.onEpisodeSelected,
    required this.downloads,
    this.onDownload,
    this.isOffline = false,
  });

  final String title;
  final List<Road> roads;
  final int selectedRoad;
  final int selectedEpisode;
  final void Function(int episode, int road) onEpisodeSelected;
  final ValueChanged<int>? onDownload;
  final Map<String, DownloadEpisode> downloads;
  final bool isOffline;

  @override
  EpisodeSelectionPanelState createState() => EpisodeSelectionPanelState();
}

class EpisodeSelectionPanelState extends State<EpisodeSelectionPanel>
    with KazumiDialogOwner {
  final _scrollController = ScrollController();
  final _rangeStripKey = GlobalKey<EpisodeRangeStripState>();
  late final _observerController =
      SliverObserverController(controller: _scrollController)
        ..cacheJumpIndexOffset = false;
  BuildContext? _episodeSliverContext;

  late int _visibleRoad = _clampedRoad(widget.selectedRoad);
  _EpisodeViewMode? _userViewMode;
  int _selectedRangeIndex = 0;

  int _clampedRoad(int road) {
    if (widget.roads.isEmpty) return 0;
    return road.clamp(0, widget.roads.length - 1);
  }

  Road? get _currentVisibleRoad =>
      _visibleRoad >= 0 && _visibleRoad < widget.roads.length
          ? widget.roads[_visibleRoad]
          : null;

  bool get _canLocate =>
      widget.selectedRoad >= 0 &&
      widget.selectedRoad < widget.roads.length &&
      widget.selectedEpisode > 0 &&
      widget.selectedEpisode <= widget.roads[widget.selectedRoad].data.length;

  String _roadName(int index) {
    if (index < 0 || index >= widget.roads.length) return '暂无线路';
    final trimmed = widget.roads[index].name.trim();
    return trimmed.isEmpty ? '线路 ${index + 1}' : trimmed;
  }

  String _episodeLabel(Road road, int episode) {
    final index = episode - 1;
    if (index >= 0 && index < road.identifier.length) {
      final trimmed = road.identifier[index].trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '第$episode集';
  }

  double _visualTextUnits(String text) {
    var units = 0.0;
    for (final rune in text.runes) {
      units += rune >= 0x2E80 ? 1.6 : 1.0;
    }
    return units;
  }

  double _typicalLabelUnits(Road? road) {
    if (road == null || road.data.isEmpty) return 6;
    final sampleCount = road.data.length.clamp(0, 60);
    final lengths = <double>[
      for (var i = 0; i < sampleCount; i++)
        _visualTextUnits(_episodeLabel(road, i + 1)),
    ]..sort();
    return lengths[(lengths.length * 0.75).floor().clamp(0, lengths.length - 1)];
  }

  _EpisodeViewMode _effectiveViewMode(double typicalUnits) {
    if (_userViewMode != null) return _userViewMode!;
    return typicalUnits <= 10.5
        ? _EpisodeViewMode.grid
        : _EpisodeViewMode.list;
  }

  double _toolbarHeight(BuildContext context) =>
      (MediaQuery.textScalerOf(context).scale(20) + 36)
          .clamp(56.0, double.infinity);

  double _rangeStripHeight(BuildContext context) =>
      (MediaQuery.textScalerOf(context).scale(16) + 20)
          .clamp(36.0, double.infinity);

  double _pinnedHeaderHeight(BuildContext context, {required bool hasRanges}) =>
      _toolbarHeight(context) +
      (hasRanges ? _rangeStripHeight(context) + 10 : 0);

  @override
  void initState() {
    super.initState();
    _syncRangeToCurrentEpisode();
  }

  @override
  void didUpdateWidget(covariant EpisodeSelectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.roads.isEmpty) {
      _visibleRoad = 0;
      _selectedRangeIndex = 0;
      return;
    }
    if (_visibleRoad >= widget.roads.length) {
      _visibleRoad = _clampedRoad(widget.selectedRoad);
      _syncRangeToCurrentEpisode();
    } else if ((widget.selectedRoad != oldWidget.selectedRoad ||
            widget.selectedEpisode != oldWidget.selectedEpisode) &&
        _visibleRoad == oldWidget.selectedRoad) {
      _visibleRoad = _clampedRoad(widget.selectedRoad);
      _syncRangeToCurrentEpisode();
    }
    final ranges = EpisodeRanges(_currentVisibleRoad?.data.length ?? 0);
    if (!ranges.hasRanges) {
      _selectedRangeIndex = 0;
    } else if (_selectedRangeIndex >= ranges.rangeCount) {
      _selectedRangeIndex = ranges.rangeCount - 1;
    }
  }

  void _syncRangeToCurrentEpisode() {
    if (!_canLocate || _visibleRoad != widget.selectedRoad) {
      _selectedRangeIndex = 0;
      return;
    }
    final count = widget.roads[widget.selectedRoad].data.length;
    _selectedRangeIndex = EpisodeRanges(count).indexOf(widget.selectedEpisode);
  }

  void _selectRoad(int road) {
    if (_visibleRoad == road) return;
    setState(() {
      _visibleRoad = road;
      _syncRangeToCurrentEpisode();
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _showRoadPicker() async {
    if (dialogs.isRunning || widget.roads.length <= 1) return;
    await dialogs.run((task) async {
      final selected = await task.showSheet<int>(
        maxHeightFactor: 0.72,
        builder: (context) => EpisodeRoadPickerSheet(
          roads: widget.roads,
          roadName: _roadName,
          visibleRoad: _visibleRoad,
        ),
      );
      _selectRoad(selected);
    });
  }

  void _selectRange(int index) {
    if (_selectedRangeIndex == index) return;
    setState(() => _selectedRangeIndex = index);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _setViewMode(_EpisodeViewMode mode) {
    if (_effectiveViewMode(_typicalLabelUnits(_currentVisibleRoad)) == mode) {
      return;
    }
    setState(() => _userViewMode = mode);
  }

  Future<void> revealCurrentEpisode() async {
    if (!_canLocate) return;
    final targetRoad = widget.selectedRoad;
    final ranges = EpisodeRanges(widget.roads[targetRoad].data.length);
    final targetRange = ranges.indexOf(widget.selectedEpisode);
    final needsRebuild =
        _visibleRoad != targetRoad || _selectedRangeIndex != targetRange;
    if (needsRebuild) {
      setState(() {
        _visibleRoad = targetRoad;
        _selectedRangeIndex = targetRange;
      });
      await WidgetsBinding.instance.endOfFrame;
    } else {
      unawaited(_rangeStripKey.currentState?.revealSelected(animate: true));
    }
    if (!mounted ||
        !_scrollController.hasClients ||
        !_canLocate ||
        _visibleRoad != targetRoad) {
      return;
    }

    final bounds = ranges.boundsOf(_selectedRangeIndex);
    if (widget.selectedEpisode < bounds.start ||
        widget.selectedEpisode > bounds.end) {
      return;
    }
    final visualIndex = widget.selectedEpisode - bounds.start;

    final sliverContext = _episodeSliverContext;
    if (sliverContext == null || !sliverContext.mounted) return;

    final pinnedHeight = _pinnedHeaderHeight(
      context,
      hasRanges: ranges.hasRanges,
    );
    final item = _observerController.findChildInfo(
      index: visualIndex,
      sliverContext: sliverContext,
    );
    if (item != null) {
      final top = item.renderObject
          .localToGlobal(Offset.zero, ancestor: item.viewport)
          .dy;
      if (top >= pinnedHeight &&
          top + item.renderObject.size.height <= item.viewport.size.height) {
        return;
      }
    }

    final isGrid = _effectiveViewMode(_typicalLabelUnits(_currentVisibleRoad)) ==
        _EpisodeViewMode.grid;
    await _observerController.jumpTo(
      index: visualIndex,
      sliverContext: sliverContext,
      isFixedHeight: isGrid,
      offset: (_) => pinnedHeight + 8,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final road = _currentVisibleRoad;
    final count = road?.data.length ?? 0;
    final ranges = EpisodeRanges(count);
    final bounds = ranges.boundsOf(_selectedRangeIndex);
    final typicalUnits = _typicalLabelUnits(road);
    final viewMode = _effectiveViewMode(typicalUnits);

    return ColoredBox(
      color: colors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = playerPanelGutter(constraints.maxWidth);
          final contentWidth =
              (constraints.maxWidth - gutter * 2).clamp(0.0, double.infinity);
          final toolbarHeight = _toolbarHeight(context);
          final pinnedHeight =
              _pinnedHeaderHeight(context, hasRanges: ranges.hasRanges);
          final rangeStripHeight = _rangeStripHeight(context);

          return SliverViewObserver(
            controller: _observerController,
            sliverContexts: () => [
              if (_episodeSliverContext != null &&
                  _episodeSliverContext!.mounted)
                _episodeSliverContext!,
            ],
            child: Scrollbar(
              controller: _scrollController,
              child: CustomScrollView(
                controller: _scrollController,
                scrollBehavior: playerPanelScrollBehavior(context),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 4),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              widget.title.trim().isEmpty
                                  ? '剧集列表'
                                  : widget.title.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (widget.roads.length > 1) ...[
                            const SizedBox(height: 12),
                            SplitListSelectorCard(
                              leading: const Icon(Icons.alt_route_rounded),
                              title: _roadName(_visibleRoad),
                              titleMaxLines: 1,
                              subtitle: '播放线路 · 共 ${widget.roads.length} 条',
                              semanticsLabel:
                                  '切换播放线路，当前 ${_roadName(_visibleRoad)}，共 ${widget.roads.length} 条线路',
                              onTap: _showRoadPicker,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _PinnedToolbarDelegate(
                      height: pinnedHeight,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: toolbarHeight,
                            child: _EpisodeUtilityBar(
                              gutter: gutter,
                              availableWidth: contentWidth,
                              count: count,
                              isOffline: widget.isOffline,
                              viewMode: viewMode,
                              onLocate:
                                  _canLocate ? revealCurrentEpisode : null,
                              onViewModeChanged:
                                  count > 0 ? _setViewMode : null,
                              onDownload: !widget.isOffline &&
                                      count > 0 &&
                                      widget.onDownload != null
                                  ? () => widget.onDownload!(_visibleRoad)
                                  : null,
                            ),
                          ),
                          if (ranges.hasRanges)
                            Padding(
                              padding:
                                  EdgeInsets.fromLTRB(gutter, 0, gutter, 10),
                              child: EpisodeRangeStrip(
                                key: _rangeStripKey,
                                height: rangeStripHeight,
                                ranges: ranges,
                                selectedIndex: _selectedRangeIndex,
                                activeRangeIndex: _canLocate &&
                                        _visibleRoad == widget.selectedRoad
                                    ? ranges.indexOf(widget.selectedEpisode)
                                    : null,
                                onSelected: _selectRange,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (count == 0)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: GeneralEmptyState(
                        compact: true,
                        icon: Icons.video_library_outlined,
                        title: '这条线路暂无剧集',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        4,
                        gutter,
                        20 + MediaQuery.paddingOf(context).bottom,
                      ),
                      sliver: viewMode == _EpisodeViewMode.grid
                          ? _buildEpisodeGrid(
                              context,
                              road: road!,
                              bounds: bounds,
                              typicalUnits: typicalUnits,
                            )
                          : _buildEpisodeList(
                              road: road!,
                              bounds: bounds,
                            ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEpisodeGrid(
    BuildContext context, {
    required Road road,
    required EpisodeRange bounds,
    required double typicalUnits,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textScale = (textScaler.scale(14) / 14).clamp(1.0, double.infinity);
    final baseMaxExtent = typicalUnits > 7.5 ? 136.0 : 108.0;
    final maxCrossAxisExtent = (baseMaxExtent * textScale).clamp(108.0, 220.0);
    final tileHeight =
        (textScaler.scale(14) * 2.5 + 16).clamp(52.0, double.infinity);
    final itemCount = bounds.end - bounds.start + 1;

    return SliverGrid(
      key: ValueKey('grid-$_visibleRoad-$_selectedRangeIndex'),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: tileHeight,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          _episodeSliverContext = context;
          final episode = bounds.start + index;
          final name = _episodeLabel(road, episode);
          final selected = _visibleRoad == widget.selectedRoad &&
              episode == widget.selectedEpisode;
          return _EpisodeGridTile(
            key: ValueKey('grid-ep-$_visibleRoad-$episode'),
            name: name,
            height: tileHeight,
            selected: selected,
            isOffline: widget.isOffline,
            download: widget.downloads[road.data[episode - 1]],
            onTap: () => widget.onEpisodeSelected(episode, _visibleRoad),
          );
        },
        childCount: itemCount,
      ),
    );
  }

  Widget _buildEpisodeList({
    required Road road,
    required EpisodeRange bounds,
  }) {
    final itemCount = bounds.end - bounds.start + 1;
    return SliverList.builder(
      key: ValueKey('list-$_visibleRoad-$_selectedRangeIndex'),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        _episodeSliverContext = context;
        final episode = bounds.start + index;
        final name = _episodeLabel(road, episode);
        final selected = _visibleRoad == widget.selectedRoad &&
            episode == widget.selectedEpisode;
        final download =
            widget.isOffline ? null : widget.downloads[road.data[episode - 1]];
        final status = download?.status;
        final downloadLabel = _downloadStatusLabel(status, download);

        final last = index == itemCount - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: last ? 0 : splitListRowGap),
          child: SplitListOptionRow(
            key: ValueKey('list-ep-$_visibleRoad-$episode'),
            badge: episode.toString().padLeft(2, '0'),
            title: name,
            subtitle: downloadLabel,
            subtitleColor: status == DownloadStatus.failed
                ? Theme.of(context).colorScheme.error
                : null,
            semanticsLabel:
                downloadLabel == null ? name : '$name，$downloadLabel',
            first: index == 0,
            last: last,
            selected: selected,
            trailing: status == null
                ? null
                : _EpisodeDownloadTrailing(status: status, download: download),
            onTap: () => widget.onEpisodeSelected(episode, _visibleRoad),
          ),
        );
      },
    );
  }
}

class _PinnedToolbarDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedToolbarDelegate({
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: overlapsContent
              ? Border(
                  bottom: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.45),
                  ),
                )
              : null,
        ),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedToolbarDelegate oldDelegate) => true;
}

class _EpisodeUtilityBar extends StatelessWidget {
  const _EpisodeUtilityBar({
    required this.gutter,
    required this.availableWidth,
    required this.count,
    required this.isOffline,
    required this.viewMode,
    required this.onLocate,
    required this.onViewModeChanged,
    required this.onDownload,
  });

  final double gutter;
  final double availableWidth;
  final int count;
  final bool isOffline;
  final _EpisodeViewMode viewMode;
  final VoidCallback? onLocate;
  final ValueChanged<_EpisodeViewMode>? onViewModeChanged;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compact = availableWidth < 324 || textScale > 1.3;

    final countLabel = compact
        ? '$count 集'
        : isOffline
            ? '已缓存 · $count 集'
            : '共 $count 集';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              countLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: '定位当前集',
            onPressed: onLocate,
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              backgroundColor: colors.surfaceContainer,
              foregroundColor: colors.onSurfaceVariant,
            ),
            icon: const Icon(Icons.my_location_rounded, size: 20),
          ),
          if (onViewModeChanged != null) ...[
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: viewMode == _EpisodeViewMode.grid
                  ? '切换为列表视图'
                  : '切换为网格视图',
              onPressed: () => onViewModeChanged!(
                viewMode == _EpisodeViewMode.grid
                    ? _EpisodeViewMode.list
                    : _EpisodeViewMode.grid,
              ),
              style: IconButton.styleFrom(
                minimumSize: const Size(40, 40),
                backgroundColor: colors.surfaceContainer,
                foregroundColor: colors.onSurfaceVariant,
              ),
              icon: Icon(
                viewMode == _EpisodeViewMode.grid
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
                size: 20,
              ),
            ),
          ],
          if (onDownload != null) ...[
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: '缓存剧集',
              onPressed: onDownload,
              style: IconButton.styleFrom(
                minimumSize: const Size(40, 40),
                backgroundColor: colors.surfaceContainer,
                foregroundColor: colors.onSurfaceVariant,
              ),
              icon: const Icon(Icons.download_rounded, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}

class _EpisodeGridTile extends StatelessWidget {
  const _EpisodeGridTile({
    super.key,
    required this.name,
    required this.height,
    required this.selected,
    required this.isOffline,
    required this.onTap,
    this.download,
  });

  final String name;
  final double height;
  final bool selected;
  final bool isOffline;
  final VoidCallback onTap;
  final DownloadEpisode? download;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = isOffline ? null : download?.status;
    final downloadLabel = _downloadStatusLabel(status, download);
    final bg = selected ? colors.primary : colors.surfaceContainerLow;
    final fg = selected ? colors.onPrimary : colors.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: downloadLabel == null ? name : '$name，$downloadLabel',
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: downloadLabel == null ? name : '$name · $downloadLabel',
        excludeFromSemantics: true,
        child: TextButton(
          onPressed: onTap,
          clipBehavior: Clip.antiAlias,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.zero),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.standard,
            backgroundColor: WidgetStatePropertyAll(bg),
            foregroundColor: WidgetStatePropertyAll(fg),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed) ||
                  states.contains(WidgetState.focused)) {
                return fg.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return fg.withValues(alpha: 0.08);
              }
              return null;
            }),
            shape: WidgetStateProperty.resolveWith((states) {
              final radius = states.contains(WidgetState.pressed)
                  ? 8.0
                  : selected
                      ? height / 2
                      : states.contains(WidgetState.hovered)
                          ? 12.0
                          : tonalCardRadius;
              return RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              );
            }),
            animationDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
          ),
          child: SizedBox.expand(
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        height: 1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                if (status != null && status != DownloadStatus.downloading)
                  Positioned(
                    top: 6,
                    right: selected ? 11 : 7,
                    child: _buildCornerIcon(status, colors),
                  ),
                if (status == DownloadStatus.downloading)
                  Positioned(
                    left: selected ? 16 : 12,
                    right: selected ? 16 : 12,
                    bottom: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        height: 3,
                        color: fg.withValues(alpha: 0.16),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor:
                              (download?.progressPercent ?? 0).clamp(0.05, 1.0),
                          child: ColoredBox(
                            color: selected ? colors.onPrimary : colors.primary,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCornerIcon(int status, ColorScheme colors) {
    final (icon, color) = _downloadStatusIcon(status, colors);
    return Icon(icon, size: 12, color: selected ? colors.onPrimary : color);
  }
}

class _EpisodeDownloadTrailing extends StatelessWidget {
  const _EpisodeDownloadTrailing({
    required this.status,
    required this.download,
  });

  final int status;
  final DownloadEpisode? download;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (status == DownloadStatus.downloading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${_downloadPercent(download)}%',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onPrimaryContainer,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }
    final (icon, color) = _downloadStatusIcon(status, colors);
    return Icon(icon, size: 18, color: SplitListRow.contentColorOf(context, color));
  }
}

int _downloadPercent(DownloadEpisode? download) =>
    ((download?.progressPercent ?? 0).clamp(0, 1) * 100).round();

(IconData, Color) _downloadStatusIcon(int status, ColorScheme colors) {
  return switch (status) {
    DownloadStatus.completed => (
        Icons.download_done_rounded,
        colors.primary,
      ),
    DownloadStatus.failed => (
        Icons.error_outline_rounded,
        colors.error,
      ),
    DownloadStatus.paused => (
        Icons.pause_circle_outline_rounded,
        colors.onSurfaceVariant,
      ),
    _ => (
        Icons.schedule_rounded,
        colors.onSurfaceVariant,
      ),
  };
}

String? _downloadStatusLabel(int? status, DownloadEpisode? download) {
  return switch (status) {
    DownloadStatus.completed => '已缓存',
    DownloadStatus.downloading => '缓存 ${_downloadPercent(download)}%',
    DownloadStatus.failed => '缓存失败',
    DownloadStatus.paused => '缓存已暂停',
    DownloadStatus.pending => '等待缓存',
    DownloadStatus.resolving => '正在解析',
    _ => null,
  };
}
