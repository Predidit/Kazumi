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
  int? _anchorId;
  double? _anchorY;
  bool _animating = false;

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
  }

  @override
  void didUpdateWidget(covariant SearchResultGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameIds(widget.items, _toItems)) return;
    _startTransition(List<BangumiItem>.of(widget.items));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startTransition(List<BangumiItem> nextItems) {
    _captureAnchor(nextItems);
    _animationController.stop();
    _fromItems = List<BangumiItem>.of(_visibleItems);
    _toItems = nextItems;

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.animate || reduceMotion) {
      setState(() {
        _visibleItems = nextItems;
        _fromItems = nextItems;
        _animating = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreAnchor());
      return;
    }

    setState(() => _animating = true);
    _animationController.forward(from: 0);
  }

  void _captureAnchor(List<BangumiItem> nextItems) {
    if (!widget.scrollController.hasClients || _visibleItems.isEmpty) {
      _anchorId = null;
      _anchorY = null;
      return;
    }
    final offset = widget.scrollController.offset;
    var row = math.max(0, (offset / _rowExtent).floor());
    if (offset - row * _rowExtent >= widget.cardExtent) {
      row++;
    }
    final firstVisibleIndex = math.min(
      row * widget.crossCount,
      _visibleItems.length - 1,
    );
    final nextIds = nextItems.map((item) => item.id).toSet();
    var anchorIndex = -1;

    for (var index = firstVisibleIndex; index < _visibleItems.length; index++) {
      if (nextIds.contains(_visibleItems[index].id)) {
        anchorIndex = index;
        break;
      }
    }
    for (var index = firstVisibleIndex - 1;
        anchorIndex < 0 && index >= 0;
        index--) {
      if (nextIds.contains(_visibleItems[index].id)) {
        anchorIndex = index;
      }
    }
    if (anchorIndex < 0) {
      _anchorId = null;
      _anchorY = null;
      return;
    }

    _anchorId = _visibleItems[anchorIndex].id;
    _anchorY = (anchorIndex ~/ widget.crossCount) * _rowExtent - offset;
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _visibleItems = List<BangumiItem>.of(_toItems);
      _fromItems = _visibleItems;
      _animating = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreAnchor());
  }

  void _restoreAnchor() {
    final anchorId = _anchorId;
    final anchorY = _anchorY;
    if (anchorId == null ||
        anchorY == null ||
        !widget.scrollController.hasClients) {
      return;
    }
    final index = _visibleItems.indexWhere((item) => item.id == anchorId);
    if (index < 0) return;
    final row = index ~/ widget.crossCount;
    final desiredOffset = row * _rowExtent - anchorY;
    final position = widget.scrollController.position;
    final clamped =
        desiredOffset.clamp(0.0, position.maxScrollExtent).toDouble();
    widget.scrollController.jumpTo(clamped);
  }

  bool _sameIds(List<BangumiItem> first, List<BangumiItem> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index].id != second[index].id) return false;
    }
    return true;
  }

  int _indexOf(List<BangumiItem> items, int id) {
    return items.indexWhere((item) => item.id == id);
  }

  Offset _positionFor(int index, double tileWidth) {
    final row = index ~/ widget.crossCount;
    final column = index % widget.crossCount;
    return Offset(
      column * (tileWidth + widget.spacing),
      row * _rowExtent,
    );
  }

  Widget _buildAnimatedCard(
    BuildContext context,
    BangumiItem item,
    double tileWidth,
  ) {
    final progress = Curves.easeInOut.transform(_animationController.value);
    final fromIndex = _indexOf(_fromItems, item.id);
    final toIndex = _indexOf(_toItems, item.id);
    final startIndex = fromIndex >= 0 ? fromIndex : toIndex;
    final endIndex = toIndex >= 0 ? toIndex : fromIndex;
    final start = _positionFor(startIndex, tileWidth);
    final end = _positionFor(endIndex, tileWidth);
    final position = Offset.lerp(start, end, progress) ?? end;

    final removed = toIndex < 0;
    final added = fromIndex < 0;
    final phase = _animationController.value;
    final opacity = removed
        ? 1 - Curves.easeIn.transform((phase / 0.34).clamp(0.0, 1.0))
        : added
            ? Curves.easeOut.transform(((phase - 0.78) / 0.22).clamp(0.0, 1.0))
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
      key: ValueKey(item.id),
      left: position.dx,
      top: position.dy,
      width: tileWidth,
      height: widget.cardExtent,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: widget.itemBuilder(context, item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          0.0,
          constraints.maxWidth - widget.padding.horizontal,
        );
        final tileWidth = widget.crossCount <= 0
            ? width
            : (width - widget.spacing * (widget.crossCount - 1)) /
                widget.crossCount;
        final ids = <int>{
          ..._fromItems.map((item) => item.id),
          ..._toItems.map((item) => item.id),
        };
        final itemById = <int, BangumiItem>{
          for (final item in [..._fromItems, ..._toItems]) item.id: item,
        };
        final maxRows = math.max(
          (_fromItems.length / widget.crossCount).ceil(),
          (_toItems.length / widget.crossCount).ceil(),
        );

        return SingleChildScrollView(
          controller: widget.scrollController,
          physics: _animating
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          padding: widget.padding,
          child: SizedBox(
            width: width,
            height: math.max(0.0, maxRows * _rowExtent - widget.spacing),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final id in ids)
                  _buildAnimatedCard(context, itemById[id]!, tileWidth),
              ],
            ),
          ),
        );
      },
    );
  }
}
