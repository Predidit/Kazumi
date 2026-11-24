import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

import 'package:kazumi/pages/video/player_panel_layout.dart';

typedef EpisodeRange = ({int start, int end});

/// Splits long episode lists into 50- or 100-episode chunks.
class EpisodeRanges {
  const EpisodeRanges(this.count);

  static const int _threshold = 50;
  static const int _smallChunkSize = 50;
  static const int _largeChunkSize = 100;
  static const int _largeChunkThreshold = 300;

  final int count;

  int get chunkSize =>
      count > _largeChunkThreshold ? _largeChunkSize : _smallChunkSize;

  int get rangeCount => count <= _threshold ? 0 : (count / chunkSize).ceil();

  bool get hasRanges => rangeCount > 0;

  int indexOf(int episode) {
    if (!hasRanges) return 0;
    return ((episode - 1).clamp(0, count - 1)) ~/ chunkSize;
  }

  EpisodeRange boundsOf(int rangeIndex) {
    if (count <= 0) return (start: 1, end: 0);
    if (!hasRanges) return (start: 1, end: count);
    final safeIndex = rangeIndex.clamp(0, rangeCount - 1);
    final start = safeIndex * chunkSize + 1;
    final end = ((safeIndex + 1) * chunkSize).clamp(0, count);
    return (start: start, end: end);
  }
}

class EpisodeRangeStrip extends StatefulWidget {
  const EpisodeRangeStrip({
    super.key,
    required this.height,
    required this.ranges,
    required this.selectedIndex,
    required this.activeRangeIndex,
    required this.onSelected,
  });

  final double height;
  final EpisodeRanges ranges;
  final int selectedIndex;
  final int? activeRangeIndex;
  final ValueChanged<int> onSelected;

  @override
  State<EpisodeRangeStrip> createState() => EpisodeRangeStripState();
}

class EpisodeRangeStripState extends State<EpisodeRangeStrip> {
  final _scrollController = ScrollController();
  late final _observerController =
      ListObserverController(controller: _scrollController)
        ..cacheJumpIndexOffset = false
        ..initialIndexModelBlock = _initialIndexModel;

  double _leadingOffset(double _) => _scrollController.hasClients
      ? _scrollController.position.viewportDimension * 0.25
      : 0;

  ObserverIndexPositionModel _initialIndexModel() {
    final rangeCount = widget.ranges.rangeCount;
    if (rangeCount <= 0) {
      return ObserverIndexPositionModel(index: 0);
    }
    return ObserverIndexPositionModel(
      index: widget.selectedIndex.clamp(0, rangeCount - 1),
      offset: _leadingOffset,
    );
  }

  @override
  void didUpdateWidget(covariant EpisodeRangeStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex ||
        widget.ranges.rangeCount != oldWidget.ranges.rangeCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(revealSelected(animate: true));
      });
    }
  }

  Future<void> revealSelected({required bool animate}) async {
    final rangeCount = widget.ranges.rangeCount;
    if (!mounted || !_scrollController.hasClients || rangeCount <= 0) {
      return;
    }
    final index = widget.selectedIndex.clamp(0, rangeCount - 1);
    final item = _observerController.findChildInfo(index: index);
    if (item != null) {
      final left = item.renderObject
          .localToGlobal(Offset.zero, ancestor: item.viewport)
          .dx;
      if (left >= 0 &&
          left + item.renderObject.size.width <= item.viewport.size.width) {
        return;
      }
    }
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      await _observerController.jumpTo(
        index: index,
        offset: _leadingOffset,
      );
    } else {
      await _observerController.animateTo(
        index: index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        offset: _leadingOffset,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rangeCount = widget.ranges.rangeCount;
    return SizedBox(
      height: widget.height,
      child: ScrollConfiguration(
        behavior: playerPanelScrollBehavior(context, scrollbars: false),
        child: ListViewObserver(
          controller: _observerController,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: rangeCount,
            itemBuilder: (context, index) {
              final bounds = widget.ranges.boundsOf(index);
              return Padding(
                padding: EdgeInsets.only(
                  right: index == rangeCount - 1 ? 0 : 6,
                ),
                child: _RangePill(
                  key: ValueKey('range-pill-$index'),
                  label: '${bounds.start}–${bounds.end}',
                  selected: index == widget.selectedIndex,
                  showDot: index == widget.activeRangeIndex &&
                      index != widget.selectedIndex,
                  onTap: () => widget.onSelected(index),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    super.key,
    required this.label,
    required this.selected,
    required this.showDot,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool showDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: ChoiceChip(
        showCheckmark: false,
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide.none,
        backgroundColor: colors.surfaceContainer,
        selectedColor: colors.secondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelPadding: EdgeInsets.zero,
        shape: selected
            ? const StadiumBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: theme.textTheme.labelMedium?.copyWith(
          color: selected
              ? colors.onSecondaryContainer
              : colors.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}
