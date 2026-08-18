import 'package:flutter/material.dart';

/// The M3 Expressive split-list vocabulary: large corners at a group's ends,
/// small ones between rows, and a gap in place of a divider.
const double splitListOuterRadius = 24;
const double splitListInnerRadius = 4;
const double splitListRowGap = 4;

const Duration splitListMotionDuration = Duration(milliseconds: 250);
const Curve splitListMotionCurve = Curves.easeInOutCubic;

/// One row of a split list, morphing to [pressedRadius] while held.
///
/// The press is driven by [onTap] here, or, when the row's content owns its
/// own [InkWell], by handing [pressReporterOf] to that
/// [InkWell.onHighlightChanged].
class SplitListRow extends StatefulWidget {
  const SplitListRow({
    super.key,
    required this.child,
    this.color,
    this.topRadius = splitListInnerRadius,
    this.bottomRadius = splitListInnerRadius,
    this.pressedRadius = splitListOuterRadius,
    this.onTap,
  });

  final Widget child;

  /// Defaults to `surfaceContainerLow`.
  final Color? color;

  final double topRadius;
  final double bottomRadius;
  final double pressedRadius;
  final VoidCallback? onTap;

  /// Null outside a row, which leaves that row's shape static.
  static ValueChanged<bool>? pressReporterOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SplitRowScope>()
        ?.onPressChanged;
  }

  @override
  State<SplitListRow> createState() => _SplitListRowState();
}

class _SplitListRowState extends State<SplitListRow> {
  bool _pressed = false;

  void _reportPress(bool pressed) => setState(() => _pressed = pressed);

  @override
  Widget build(BuildContext context) {
    final child = widget.onTap == null
        ? widget.child
        : InkWell(
            onTap: widget.onTap,
            onHighlightChanged: _reportPress,
            child: widget.child,
          );
    // An AnimatedContainer rather than Material's implicit animation:
    // Material tweens its shape but snaps its colour.
    return AnimatedContainer(
      duration: splitListMotionDuration,
      curve: splitListMotionCurve,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color:
            widget.color ?? Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
              _pressed ? widget.pressedRadius : widget.topRadius),
          bottom: Radius.circular(
              _pressed ? widget.pressedRadius : widget.bottomRadius),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: _SplitRowScope(onPressChanged: _reportPress, child: child),
      ),
    );
  }
}

class _SplitRowScope extends InheritedWidget {
  const _SplitRowScope({required this.onPressChanged, required super.child});

  final ValueChanged<bool> onPressChanged;

  // The callback always reaches the same state, so a rebuilt scope never
  // obsoletes the one a row already holds.
  @override
  bool updateShouldNotify(_SplitRowScope oldWidget) => false;
}
