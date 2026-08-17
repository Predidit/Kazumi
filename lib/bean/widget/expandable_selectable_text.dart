import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Selectable text that only offers expansion when its collapsed rendering
/// actually exceeds [maxLines].
///
/// Overflow is read from the paragraph that Flutter already laid out for
/// display. This avoids a second, manual [TextPainter] layout pass.
class ExpandableSelectableText extends StatefulWidget {
  const ExpandableSelectableText({
    super.key,
    required this.text,
    this.maxLines = 7,
    this.expandLabel = '加载更多',
    this.collapseLabel = '加载更少',
  }) : assert(maxLines > 0);

  final String text;
  final int maxLines;
  final String expandLabel;
  final String collapseLabel;

  @override
  State<ExpandableSelectableText> createState() =>
      _ExpandableSelectableTextState();
}

class _ExpandableSelectableTextState extends State<ExpandableSelectableText> {
  final GlobalKey _textKey = GlobalKey();
  bool _expanded = false;
  bool _canExpand = false;
  bool _overflowCheckScheduled = false;

  @override
  void didUpdateWidget(ExpandableSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.maxLines != widget.maxLines) {
      _expanded = false;
      _canExpand = false;
    }
  }

  void _scheduleOverflowCheck() {
    if (_expanded || _overflowCheckScheduled) return;
    _overflowCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overflowCheckScheduled = false;
      if (!mounted || _expanded) return;

      final renderObject = _textKey.currentContext?.findRenderObject();
      final paragraph = _findParagraph(renderObject);
      if (paragraph == null) return;

      final canExpand = paragraph.didExceedMaxLines;
      if (canExpand != _canExpand) {
        setState(() {
          _canExpand = canExpand;
        });
      }
    });
  }

  RenderParagraph? _findParagraph(RenderObject? renderObject) {
    if (renderObject is RenderParagraph) return renderObject;
    RenderParagraph? paragraph;
    renderObject?.visitChildren((child) {
      paragraph ??= _findParagraph(child);
    });
    return paragraph;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, _) {
        _scheduleOverflowCheck();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectionArea(
              child: Text(
                widget.text,
                key: _textKey,
                maxLines: _expanded ? null : widget.maxLines,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.clip,
                textAlign: TextAlign.start,
              ),
            ),
            if (_canExpand)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _expanded = !_expanded;
                    });
                  },
                  child: Text(
                    _expanded ? widget.collapseLabel : widget.expandLabel,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
