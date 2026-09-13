import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/tv_focus_navigation.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/services/platform/tv_mode.dart';
import 'package:kazumi/services/platform/tv_navigation.dart';

/// Applies TV-only focus behavior while preserving the normal mobile theme.
class TvAppShell extends StatefulWidget {
  const TvAppShell({super.key, required this.child});

  final Widget child;

  @override
  State<TvAppShell> createState() => _TvAppShellState();
}

class _TvAppShellState extends State<TvAppShell> {
  static const _channel = MethodChannel('com.predidit.kazumi/tv_navigation');

  @override
  void initState() {
    super.initState();
    if (TvMode.enabled) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'home') TvNavigation.goHome();
        if (call.method == 'back') {
          await rootNavigatorKey.currentState?.maybePop();
        }
      });
      _channel.invokeMethod<void>('setActive', true);
    }
  }

  @override
  void dispose() {
    if (TvMode.enabled) {
      _channel.setMethodCallHandler(null);
      _channel.invokeMethod<void>('setActive', false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!TvMode.enabled) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        focusColor: colorScheme.primary.withValues(alpha: 0.24),
        hoverColor: colorScheme.primary.withValues(alpha: 0.12),
        visualDensity: VisualDensity.comfortable,
      ),
      child: FocusTraversalGroup(
        policy: TvLoopTraversalPolicy(),
        child: widget.child,
      ),
    );
  }
}
