import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/platform/tv_mode.dart';

/// Adds a ten-foot-UI focus treatment without changing the mobile surface.
class TvFocusableSurface extends StatefulWidget {
  const TvFocusableSurface({
    super.key,
    required this.child,
    required this.onPressed,
    this.enabled,
    this.autofocus = false,
    this.focusNode,
    this.borderRadius = 16,
    this.highlighted = false,
    this.onFocusChange,
    this.onKeyEvent,
    this.focusScale = 1.035,
    this.ensureVisibleOnFocus = true,
  });

  final Widget child;
  final VoidCallback onPressed;
  final bool? enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final double borderRadius;
  final bool highlighted;
  final ValueChanged<bool>? onFocusChange;
  final FocusOnKeyEventCallback? onKeyEvent;

  /// Compact grids can keep the frame inside their scroll viewport.
  final double focusScale;

  /// Virtualized grids may own visibility by item geometry, not render bounds.
  final bool ensureVisibleOnFocus;

  @override
  State<TvFocusableSurface> createState() => _TvFocusableSurfaceState();
}

class _TvFocusableSurfaceState extends State<TvFocusableSurface> {
  bool _focused = false;

  bool get _enabled => widget.enabled ?? TvMode.enabled;

  void _handleFocusChange(bool focused) {
    if (_focused != focused) {
      setState(() => _focused = focused);
    }
    if (focused && widget.ensureVisibleOnFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_focused || widget.focusNode?.hasFocus == false) {
          return;
        }
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      });
    }
    widget.onFocusChange?.call(focused);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final customResult = widget.onKeyEvent?.call(node, event);
    if (customResult != null && customResult != KeyEventResult.ignored) {
      return customResult;
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      widget.onPressed();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) {
      return widget.child;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final visuallyHighlighted = _focused || widget.highlighted;
    return Semantics(
      button: true,
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        // The wrapper is the single remote-control target. Cards often contain
        // an InkWell/Button for pointer input; allowing that child to join TV
        // traversal creates an invisible extra stop inside the same card.
        descendantsAreFocusable: false,
        descendantsAreTraversable: false,
        onFocusChange: _handleFocusChange,
        onKeyEvent: _handleKeyEvent,
        child: AnimatedScale(
          scale: visuallyHighlighted ? widget.focusScale : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius + 2),
              border: Border.all(
                color: visuallyHighlighted
                    ? colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: visuallyHighlighted
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.28),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
