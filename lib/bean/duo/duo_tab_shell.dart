import 'package:flutter/material.dart';
import 'package:kazumi/services/platform/duo_navigation.dart';

/// Native tab synchronization stays here, outside the shared router shell.
class DuoTabShell extends StatefulWidget {
  const DuoTabShell({
    super.key,
    required this.index,
    required this.isCovered,
    required this.onSelected,
    required this.nativeBuilder,
    required this.child,
  });

  final int index;
  final bool isCovered;
  final ValueChanged<int> onSelected;
  final WidgetBuilder nativeBuilder;
  final Widget child;

  @override
  State<DuoTabShell> createState() => _DuoTabShellState();
}

class _DuoTabShellState extends State<DuoTabShell> {
  bool _enabled = DuoNavigation.enabled.value;
  bool _visible = false;
  (int, bool, bool)? _published;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await DuoNavigation.initialize();
    if (!mounted || !DuoNavigation.enabled.value) return;
    DuoNavigation.onTabSelected = (index) {
      if (mounted && _visible && index >= 0 && index < 4) {
        widget.onSelected(index);
      }
    };
    setState(() => _enabled = true);
  }

  @override
  void dispose() {
    if (_enabled) {
      DuoNavigation.onTabSelected = null;
      DuoNavigation.setTabs(index: widget.index, visible: false, dark: false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    _visible = !widget.isCovered && (ModalRoute.isCurrentOf(context) ?? true);
    final state = (
      widget.index,
      _visible,
      Theme.of(context).brightness == Brightness.dark,
    );
    if (_published != state) {
      _published = state;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _published == state) {
          DuoNavigation.setTabs(
            index: state.$1,
            visible: state.$2,
            dark: state.$3,
          );
        }
      });
    }
    return widget.nativeBuilder(context);
  }
}
