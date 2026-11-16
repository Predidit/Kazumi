import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:kazumi/bean/widget/expressive_motion.dart';
import 'package:kazumi/bean/widget/tonal_card.dart';

// Compose Material 3 segmented list item tokens.
const double splitListRowGap = 2;
const double _outerRadius = tonalCardRadius;
const double _innerRadius = 4;
const double _hoveredRadius = 12;

/// Resting shape of a row, for surfaces that cannot be a [SplitListRow].
BorderRadius splitListRowRadius({required bool first, required bool last}) {
  return BorderRadius.vertical(
    top: Radius.circular(first ? _outerRadius : _innerRadius),
    bottom: Radius.circular(last ? _outerRadius : _innerRadius),
  );
}

class SplitListRow extends StatefulWidget {
  const SplitListRow({
    super.key,
    required this.child,
    this.first = false,
    this.last = false,
    this.selected = false,
    this.color,
    this.onTap,
  });

  final Widget child;
  final bool first;
  final bool last;
  final bool selected;
  final Color? color;
  final VoidCallback? onTap;

  /// Pass to a child InkWell so its interactions shape the row.
  static WidgetStatesController? statesOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_SplitRowScope>()?.states;
  }

  @override
  State<SplitListRow> createState() => _SplitListRowState();
}

class _SplitListRowState extends State<SplitListRow> {
  final _states = WidgetStatesController();
  double? _interactionRadius;

  @override
  void initState() {
    super.initState();
    _states.addListener(_handleStates);
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  void _handleStates() => runOutsideBuild(() {
        if (!mounted) return;
        final states = _states.value;
        final radius = states.contains(WidgetState.disabled)
            ? null
            : states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.focused)
                ? _outerRadius
                : states.contains(WidgetState.hovered)
                    ? _hoveredRadius
                    : null;
        if (radius != _interactionRadius) {
          setState(() => _interactionRadius = radius);
        }
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final radius = widget.selected ? _outerRadius : _interactionRadius;
    final child = ListTileTheme(
      data: theme.listTileTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle:
            theme.textTheme.bodyLarge?.copyWith(color: colors.onSurface),
        subtitleTextStyle: theme.textTheme.bodyMedium
            ?.copyWith(color: colors.onSurfaceVariant),
      ),
      child: _SplitRowScope(
        states: _states,
        child: widget.onTap == null
            ? widget.child
            : InkWell(
                onTap: widget.onTap,
                statesController: _states,
                child: widget.child,
              ),
      ),
    );
    return SpringBuilder(
      value: radius ?? (widget.first ? _outerRadius : _innerRadius),
      spring: ExpressiveMotion.fastSpatial,
      child: child,
      builder: (context, top, child) => SpringBuilder(
        value: radius ?? (widget.last ? _outerRadius : _innerRadius),
        spring: ExpressiveMotion.fastSpatial,
        child: child,
        builder: (context, bottom, child) => SpringBuilder(
          value: widget.selected ? 1 : 0,
          spring: ExpressiveMotion.defaultEffects,
          child: child,
          builder: (context, selection, child) => Material(
            animationDuration: Duration.zero,
            color: Color.lerp(
              widget.color ?? colors.surfaceContainerLow,
              colors.secondaryContainer,
              selection.clamp(0, 1),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(math.max(top, 0)),
                bottom: Radius.circular(math.max(bottom, 0)),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SplitRowScope extends InheritedWidget {
  const _SplitRowScope({required this.states, required super.child});

  final WidgetStatesController states;

  @override
  bool updateShouldNotify(_SplitRowScope oldWidget) =>
      oldWidget.states != states;
}

class SplitListGroup extends StatelessWidget {
  const SplitListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: splitListRowGap),
          SplitListRow(
            first: i == 0,
            last: i == children.length - 1,
            child: children[i],
          ),
        ],
      ],
    );
  }
}
