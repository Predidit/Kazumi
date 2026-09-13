import 'package:flutter/material.dart';
import 'package:kazumi/services/platform/tv_mode.dart';

/// Leaves the non-TV focus tree intact while adding a TV pane boundary.
class TvFocusScope extends StatelessWidget {
  const TvFocusScope(
      {super.key, required this.child, this.node, this.onKeyEvent});
  final Widget child;
  final FocusScopeNode? node;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  Widget build(BuildContext context) => TvMode.enabled
      ? FocusScope(node: node, onKeyEvent: onKeyEvent, child: child)
      : child;
}
