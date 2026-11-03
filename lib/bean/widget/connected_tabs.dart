import 'package:flutter/material.dart';

// Material 3 connected-button small tokens.

const double _connectedGroupHeight = 40;
const double _connectedGroupGap = 2;
const double _connectedInnerCorner = 8;
const double _connectedPressedInnerCorner = 4;

class ConnectedTabs extends StatelessWidget {
  const ConnectedTabs({
    super.key,
    required this.labels,
    this.controller,
    this.padding = EdgeInsets.zero,
  });

  final List<String> labels;

  final TabController? controller;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tabController = controller ?? DefaultTabController.of(context);
    assert(labels.isNotEmpty && labels.length == tabController.length);

    return Padding(
      padding: padding,
      child: SizedBox(
        height: _connectedGroupHeight,
        child: AnimatedBuilder(
          animation: tabController.animation!,
          builder: (context, _) {
            final position = tabController.animation!.value;
            return Row(
              children: [
                for (var index = 0; index < labels.length; index++) ...[
                  if (index != 0) const SizedBox(width: _connectedGroupGap),
                  Expanded(
                    child: _ConnectedSegment(
                      label: labels[index],
                      selection: (1 - (position - index).abs()).clamp(0.0, 1.0),
                      isLeading: index == 0,
                      isTrailing: index == labels.length - 1,
                      onTap: () => tabController.animateTo(index),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConnectedSegment extends StatefulWidget {
  const _ConnectedSegment({
    required this.label,
    required this.selection,
    required this.isLeading,
    required this.isTrailing,
    required this.onTap,
  });

  final String label;
  final double selection;
  final bool isLeading;
  final bool isTrailing;
  final VoidCallback onTap;

  @override
  State<_ConnectedSegment> createState() => _ConnectedSegmentState();
}

class _ConnectedSegmentState extends State<_ConnectedSegment> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selection = widget.selection;
    const outerCorner = _connectedGroupHeight / 2;
    const outerRadius = Radius.circular(outerCorner);

    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selection > 0.5,
      // Selection already follows the tab animation; tween only the press.
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _pressed ? 1 : 0),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (context, press, child) {
          var inner = _connectedInnerCorner +
              (outerCorner - _connectedInnerCorner) * selection;
          inner +=
              (_connectedPressedInnerCorner - inner) * press * (1 - selection);
          final animated = Radius.circular(inner);
          return Material(
            color: Color.lerp(
              colorScheme.surfaceContainer,
              colorScheme.secondaryContainer,
              selection,
            ),
            borderRadius: BorderRadiusDirectional.only(
              topStart: widget.isLeading ? outerRadius : animated,
              bottomStart: widget.isLeading ? outerRadius : animated,
              topEnd: widget.isTrailing ? outerRadius : animated,
              bottomEnd: widget.isTrailing ? outerRadius : animated,
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          );
        },
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Center(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Color.lerp(
                  colorScheme.onSurfaceVariant,
                  colorScheme.onSecondaryContainer,
                  selection,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
