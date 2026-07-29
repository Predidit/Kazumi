import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

typedef SearchResultItemBuilder = Widget Function(
  BuildContext context,
  BangumiItem item,
);

/// A fixed-format search grid that animates cards between two ordered views.
class SearchResultGrid extends StatefulWidget {
  const SearchResultGrid({
    super.key,
    required this.items,
    required this.crossCount,
    required this.cardExtent,
    required this.itemBuilder,
    required this.scrollController,
    this.spacing = 8,
    this.padding = const EdgeInsets.fromLTRB(8, 0, 8, 0),
    this.animate = true,
  });

  final List<BangumiItem> items;
  final int crossCount;
  final double cardExtent;
  final SearchResultItemBuilder itemBuilder;
  final ScrollController scrollController;
  final double spacing;
  final EdgeInsets padding;
  final bool animate;

  @override
  State<SearchResultGrid> createState() => _SearchResultGridState();
}

class _SearchResultGridState extends State<SearchResultGrid>
    with SingleTickerProviderStateMixin {
  late List<BangumiItem> _visibleItems;
  List<BangumiItem> _fromItems = const [];
  List<BangumiItem> _toItems = const [];
  late final AnimationController _animationController;
  bool _animating = false;
  bool _reversingToStart = false;

  double get _rowExtent => widget.cardExtent + widget.spacing;

  @override
  void initState() {
    super.initState();
    _visibleItems = List<BangumiItem>.of(widget.items);
    _fromItems = _visibleItems;
    _toItems = _visibleItems;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addStatusListener(_handleAnimationStatus);
    widget.scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant SearchResultGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_handleScroll);
      widget.scrollController.addListener(_handleScroll);
    }
    if (_sameIds(widget.items, _toItems)) {
      final refreshedItems = List<BangumiItem>.of(widget.items);
      _toItems = refreshedItems;
      if (_animating && _reversingToStart) {
        _reversingToStart = false;
        _animationController.forward();
      } else if (!_animating) {
        _visibleItems = refreshedItems;
        _fromItems = refreshedItems;
      }
      return;
    }
    _startTransition(List<BangumiItem>.of(widget.items));
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_handleScroll);
    _animationController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (mounted && _animating) {
      setState(() {});
    }
  }

  void _startTransition(List<BangumiItem> nextItems) {
    if (_animating && _sameIds(nextItems, _fromItems)) {
      _fromItems = nextItems;
      _reversingToStart = true;
      _animationController.reverse();
      return;
    }

    _animationController.stop();
    _fromItems = List<BangumiItem>.of(_visibleItems);
    _toItems = nextItems;
    _reversingToStart = false;

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.animate || reduceMotion) {
      setState(() {
        _visibleItems = nextItems;
        _fromItems = nextItems;
        _animating = false;
      });
      return;
    }

    setState(() => _animating = true);
    _animationController.forward(from: 0);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (!mounted ||
        (status != AnimationStatus.completed &&
            (status != AnimationStatus.dismissed || !_reversingToStart))) {
      return;
    }
    final settledItems =
        status == AnimationStatus.completed ? _toItems : _fromItems;
    setState(() {
      _visibleItems = List<BangumiItem>.of(settledItems);
      _fromItems = _visibleItems;
      _toItems = _visibleItems;
      _animating = false;
      _reversingToStart = false;
    });
  }

  bool _sameIds(List<BangumiItem> first, List<BangumiItem> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index].id != second[index].id) return false;
    }
    return true;
  }

  Offset _positionFor(int index, double tileWidth, int crossCount) {
    final row = index ~/ crossCount;
    final column = index % crossCount;
    return Offset(
      column * (tileWidth + widget.spacing),
      row * _rowExtent,
    );
  }

  Widget _buildAnimatedCard(
    BuildContext context,
    BangumiItem item,
    double tileWidth,
    int crossCount,
    int fromIndex,
    int toIndex,
  ) {
    final startIndex = fromIndex >= 0 ? fromIndex : toIndex;
    final endIndex = toIndex >= 0 ? toIndex : fromIndex;
    final start = _positionFor(startIndex, tileWidth, crossCount);
    final end = _positionFor(endIndex, tileWidth, crossCount);
    final removed = toIndex < 0;
    final added = fromIndex < 0;
    return AnimatedBuilder(
      key: ValueKey(item.id),
      animation: _animationController,
      child: widget.itemBuilder(context, item),
      builder: (context, child) {
        final phase = _animationController.value;
        final progress = Curves.easeInOut.transform(phase);
        final position = Offset.lerp(start, end, progress) ?? end;
        final opacity = removed
            ? 1 - Curves.easeIn.transform((phase / 0.34).clamp(0.0, 1.0))
            : added
                ? Curves.easeOut
                    .transform(((phase - 0.78) / 0.22).clamp(0.0, 1.0))
                : 1.0;
        final scale = removed
            ? 1 - 0.08 * Curves.easeIn.transform((phase / 0.34).clamp(0.0, 1.0))
            : added
                ? 0.92 +
                    0.08 *
                        Curves.easeOut
                            .transform(((phase - 0.78) / 0.22).clamp(0.0, 1.0))
                : 1.0;

        return Positioned(
          left: position.dx,
          top: position.dy,
          width: tileWidth,
          height: widget.cardExtent,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = math.max(1, widget.crossCount);
        final width = math.max(
          0.0,
          constraints.maxWidth - widget.padding.horizontal,
        );
        if (!_animating) {
          return CustomScrollView(
            controller: widget.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: widget.padding,
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisSpacing: widget.spacing,
                    crossAxisSpacing: widget.spacing,
                    mainAxisExtent: widget.cardExtent,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        widget.itemBuilder(context, _visibleItems[index]),
                    childCount: _visibleItems.length,
                  ),
                ),
              ),
            ],
          );
        }

        final tileWidth = math.max(
          0.0,
          (width - widget.spacing * (crossCount - 1)) / crossCount,
        );
        final fromIndexes = <int, int>{
          for (var index = 0; index < _fromItems.length; index++)
            _fromItems[index].id: index,
        };
        final toIndexes = <int, int>{
          for (var index = 0; index < _toItems.length; index++)
            _toItems[index].id: index,
        };
        final ids = <int>{
          ...fromIndexes.keys,
          ...toIndexes.keys,
        };
        final itemById = <int, BangumiItem>{
          for (final item in [..._fromItems, ..._toItems]) item.id: item,
        };
        final maxRows = math.max(
          (_fromItems.length / crossCount).ceil(),
          (_toItems.length / crossCount).ceil(),
        );
        final viewportHeight = widget.scrollController.hasClients
            ? widget.scrollController.position.viewportDimension
            : constraints.hasBoundedHeight
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
        final viewportTop = widget.scrollController.hasClients
            ? widget.scrollController.offset
            : 0.0;
        final visibleTop = math.max(0.0, viewportTop - 2 * _rowExtent);
        final visibleBottom = viewportTop + viewportHeight + 2 * _rowExtent;

        bool isNearViewport(int id) {
          final fromIndex = fromIndexes[id] ?? -1;
          final toIndex = toIndexes[id] ?? -1;
          final startIndex = fromIndex >= 0 ? fromIndex : toIndex;
          final endIndex = toIndex >= 0 ? toIndex : fromIndex;
          final start = _positionFor(startIndex, tileWidth, crossCount);
          final end = _positionFor(endIndex, tileWidth, crossCount);
          final top = math.min(start.dy, end.dy);
          final bottom = math.max(start.dy, end.dy) + widget.cardExtent;
          return bottom >= visibleTop && top <= visibleBottom;
        }

        return CustomScrollView(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: widget.padding,
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  width: width,
                  height: math.max(0.0, maxRows * _rowExtent - widget.spacing),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final id in ids.where(isNearViewport))
                        _buildAnimatedCard(
                          context,
                          itemById[id]!,
                          tileWidth,
                          crossCount,
                          fromIndexes[id] ?? -1,
                          toIndexes[id] ?? -1,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
