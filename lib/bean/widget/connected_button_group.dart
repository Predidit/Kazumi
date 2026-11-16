import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:kazumi/bean/widget/expressive_motion.dart';

// Compose Material 3 connected button group tokens, small size.
const double _height = 40;
const double _gap = 2;
const double _innerCorner = 8;
const double _pressedInnerCorner = 4;

/// Single-choice Material 3 Expressive connected button group.
class ConnectedButtonGroup<T> extends StatelessWidget {
  const ConnectedButtonGroup({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.expanded = true,
    this.emphasized = false,
    this.color,
  });

  final List<ButtonSegment<T>> segments;
  final T? selected;

  /// Null disables the group.
  final ValueChanged<T>? onSelected;
  final bool expanded;

  /// Selects with primary instead of secondaryContainer.
  final bool emphasized;

  /// Container of the unselected segments.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final onSelected = this.onSelected;
    return Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      spacing: _gap,
      children: [
        for (final (index, segment) in segments.indexed)
          Flexible(
            flex: expanded ? 1 : 0,
            fit: expanded ? FlexFit.tight : FlexFit.loose,
            child: _ConnectedButton(
              segment: segment,
              expanded: expanded,
              emphasized: emphasized,
              color: color,
              selected: segment.value == selected,
              leading: index == 0,
              trailing: index == segments.length - 1,
              onPressed: onSelected == null || !segment.enabled
                  ? null
                  : () => onSelected(segment.value),
            ),
          ),
      ],
    );
  }
}

class _ConnectedButton extends StatefulWidget {
  const _ConnectedButton({
    required this.segment,
    required this.expanded,
    required this.emphasized,
    required this.color,
    required this.selected,
    required this.leading,
    required this.trailing,
    required this.onPressed,
  });

  final ButtonSegment<Object?> segment;
  final bool expanded;
  final bool emphasized;
  final Color? color;
  final bool selected;
  final bool leading;
  final bool trailing;
  final VoidCallback? onPressed;

  @override
  State<_ConnectedButton> createState() => _ConnectedButtonState();
}

class _ConnectedButtonState extends State<_ConnectedButton> {
  final _states = WidgetStatesController();
  bool _pressed = false;

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
        final pressed = _states.value.contains(WidgetState.pressed);
        if (pressed != _pressed) setState(() => _pressed = pressed);
      });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final segment = widget.segment;
    final height = math.max(
      _height,
      MediaQuery.textScalerOf(context).scale(20) + 20,
    );
    final (background, foreground) = !widget.selected
        ? (widget.color ?? colors.surfaceContainer, colors.onSurfaceVariant)
        : widget.emphasized
            ? (colors.primary, colors.onPrimary)
            : (colors.secondaryContainer, colors.onSecondaryContainer);

    final button = SpringBuilder(
      value: _pressed
          ? _pressedInnerCorner
          : widget.selected
              ? height / 2
              : _innerCorner,
      spring: ExpressiveMotion.fastSpatial,
      builder: (context, corner, child) {
        final outer = Radius.circular(height / 2);
        final inner = Radius.circular(corner.clamp(0, height / 2));
        return TextButton(
          onPressed: widget.onPressed,
          statesController: _states,
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, height)),
            // A stretched segment centers its content and only needs an inset.
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(
                horizontal: widget.expanded
                    ? 8
                    : segment.label == null
                        ? 12
                        : 16,
              ),
            ),
            visualDensity: VisualDensity.standard,
            animationDuration: Duration.zero,
            iconSize: const WidgetStatePropertyAll(20),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? colors.onSurface.withValues(alpha: 0.1)
                  : background,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? colors.onSurface.withValues(alpha: 0.38)
                  : foreground,
            ),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed) ||
                  states.contains(WidgetState.focused)) {
                return foreground.withValues(alpha: 0.1);
              }
              if (states.contains(WidgetState.hovered)) {
                return foreground.withValues(alpha: 0.08);
              }
              return null;
            }),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadiusDirectional.horizontal(
                  start: widget.leading ? outer : inner,
                  end: widget.trailing ? outer : inner,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
      child: Semantics(
        selected: widget.selected,
        inMutuallyExclusiveGroup: true,
        child: DefaultTextStyle.merge(
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              if (segment.icon != null) segment.icon!,
              if (segment.label != null) Flexible(child: segment.label!),
            ],
          ),
        ),
      ),
    );

    final tooltip = segment.tooltip;
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
