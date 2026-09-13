import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/tv_focus_navigation.dart';
import 'package:kazumi/services/platform/tv_mode.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/bean/card/bangumi_history_card.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/utils/constants.dart';

/// Remote grid; the parent retains the shared persistence and editing guards.
class TvHistoryGrid extends StatefulWidget {
  const TvHistoryGrid(
      {super.key,
      required this.entries,
      required this.editing,
      required this.onDelete});
  final List<History> entries;
  final bool editing;
  final Future<void> Function(History) onDelete;
  @override
  State<TvHistoryGrid> createState() => _TvHistoryGridState();
}

class _TvHistoryGridState extends State<TvHistoryGrid> {
  final _focusNodes = <String, FocusNode>{};
  final _emptyFocus = FocusNode(debugLabel: 'TV empty history back');
  final _scrollController = ScrollController();
  int _focusRequest = 0;

  void _cancelFocusRequest() {
    _focusRequest++;
    // Cancel the old viewport motion too: otherwise a newer More focus can
    // remain logically selected while its card is scrolled off screen.
    if (_scrollController.hasClients &&
        _scrollController.position.isScrollingNotifier.value) {
      _scrollController.jumpTo(_scrollController.offset);
    }
  }

  Future<void> _focusHistory(int index, int columns) async {
    final node = _focusFor(widget.entries[index]);
    final origin = FocusManager.instance.primaryFocus;
    final originScope = origin?.enclosingScope;
    final request = ++_focusRequest;
    final rowTop = index ~/ columns * 152.0 + 4;
    if (_scrollController.hasClients &&
        (node.context == null ||
            rowTop < _scrollController.offset ||
            rowTop + 150 >
                _scrollController.offset +
                    _scrollController.position.viewportDimension)) {
      await _scrollController.animateTo(
          (index ~/ columns * 152.0)
              .clamp(0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (mounted &&
        node.context != null &&
        request == _focusRequest &&
        // A viewport eviction may detach the old node and choose a fallback.
        // An attached origin losing focus to another control is not that case.
        (FocusManager.instance.primaryFocus == origin ||
            origin?.parent == null) &&
        originScope?.hasFocus == true) {
      node.requestFocus();
    }
  }

  FocusNode _focusFor(History history) => _focusNodes.putIfAbsent(
      history.key, () => FocusNode(debugLabel: 'TV history ${history.key}'));

  @override
  void dispose() {
    _focusRequest++;
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _emptyFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _deleteHistory(History history, int index) async {
    await widget.onDelete(history);
    if (!mounted || !TvMode.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final items = widget.entries;
      if (items.isEmpty) {
        _emptyFocus.requestFocus();
      } else {
        _focusFor(items[index.clamp(0, items.length - 1)]).requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) => renderBody;
  Widget get renderBody {
    if (widget.entries.isNotEmpty) {
      return contentGrid;
    } else {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const GeneralEmptyState(
            icon: Icons.history_rounded,
            title: '暂无历史记录',
          ),
          if (TvMode.enabled)
            TextButton.icon(
                autofocus: true,
                focusNode: _emptyFocus,
                onPressed: () {
                  if (Actions.maybeFind<TvFocusRailIntent>(context) != null) {
                    Actions.invoke(context, const TvFocusRailIntent());
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回')),
        ]),
      );
    }
  }

  Widget get contentGrid {
    int crossCount = 1;
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.compact['width']!) {
      crossCount = 2;
    }
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.medium['width']!) {
      crossCount = 3;
    }

    final double screenWidth = MediaQuery.sizeOf(context).width;
    if (TvMode.enabled) {
      // Reserve the rail and enough room for poster, text and a separate More
      // target. The old three-column phone density truncates even short titles.
      crossCount = ((screenWidth - 80) / 380).floor().clamp(1, 3);
    }
    final double maxContentWidth = 1000;
    final double horizontalPadding =
        screenWidth > maxContentWidth ? (screenWidth - maxContentWidth) / 2 : 0;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 4)),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              mainAxisSpacing: 2,
              crossAxisSpacing: StyleString.cardSpace,
              crossAxisCount: crossCount,
              // TV adds a 10 px focus inset around the unchanged 140 px card.
              mainAxisExtent: TvMode.enabled ? 150 : 140,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final history = widget.entries[index];
                return BangumiHistoryCardV(
                  key: ValueKey(history.key),
                  historyItem: history,
                  focusNode: TvMode.enabled ? _focusFor(history) : null,
                  onNavigationInput:
                      TvMode.enabled ? _cancelFocusRequest : null,
                  onKeyEvent: (_, event) {
                    if (!TvMode.enabled ||
                        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
                      return KeyEventResult.ignored;
                    }
                    if (event.logicalKey != LogicalKeyboardKey.arrowDown) {
                      _focusRequest++;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                        index % crossCount == 0) {
                      Actions.maybeInvoke(context, const TvFocusRailIntent());
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      final target = tvGridTarget(index, widget.entries.length,
                          crossCount, TraversalDirection.down);
                      _focusHistory(target, crossCount);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  showDelete: widget.editing,
                  onDeleted: () => _deleteHistory(history, index),
                );
              },
              childCount: widget.entries.length,
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }
}
