import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/tv_focus_navigation.dart';

/// One visible TV action row. Menus keep their own focus and key handling.
class TvDetailActions extends StatefulWidget {
  const TvDetailActions({
    super.key,
    required this.playFocus,
    required this.onPlay,
    required this.collectionBuilder,
    required this.onReview,
    required this.onUp,
    required this.onDown,
  });

  final FocusNode playFocus;
  final VoidCallback onPlay;
  final Widget Function(FocusNode focusNode) collectionBuilder;
  final VoidCallback onReview;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  State<TvDetailActions> createState() => _TvDetailActionsState();
}

class _TvDetailActionsState extends State<TvDetailActions> {
  final _collectFocus = FocusNode(debugLabel: 'TV detail collect');
  final _reviewFocus = FocusNode(debugLabel: 'TV detail review');

  List<FocusNode> get _nodes => [widget.playFocus, _collectFocus, _reviewFocus];

  @override
  void dispose() {
    _collectFocus.dispose();
    _reviewFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Do not steal arrows from an open collection menu or dialog.
    final index = _nodes.indexWhere((node) => node.hasPrimaryFocus);
    if (index < 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      _nodes[tvWrappedIndex(index, key == LogicalKeyboardKey.arrowLeft ? -1 : 1,
              _nodes.length)]
          .requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      widget.onUp();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.onDown();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _highlight(FocusNode node, Widget child) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            width: 2,
            color: node.hasPrimaryFocus
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      skipTraversal: true,
      canRequestFocus: false,
      onKeyEvent: _onKey,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          _highlight(
            widget.playFocus,
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                autofocus: true,
                focusNode: widget.playFocus,
                onPressed: widget.onPlay,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('开始观看'),
              ),
            ),
          ),
          _highlight(
            _collectFocus,
            SizedBox(
              height: 44,
              child: widget.collectionBuilder(_collectFocus),
            ),
          ),
          _highlight(
            _reviewFocus,
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                focusNode: _reviewFocus,
                onPressed: widget.onReview,
                icon: const Icon(Icons.rate_review_rounded),
                label: const Text('发表吐槽'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
