import 'package:flutter/material.dart';
import 'package:kazumi/services/platform/duo_icon.dart';

/// Explicit native representation of an existing Flutter action. Callbacks and
/// enabled/selection state belong to the control that creates this value.
class DuoAction {
  const DuoAction({
    required this.label,
    this.icon,
    this.onPressed,
    this.menu,
    this.selected = false,
    this.destructive = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final List<DuoAction>? menu;
  final bool selected;
  final bool destructive;

  Map<String, Object?> encode(
    Map<String, VoidCallback> callbacks, {
    TextDirection direction = TextDirection.ltr,
  }) {
    final id = '${callbacks.length}';
    // Menu containers also need a unique id, even without a callback.
    callbacks[id] = onPressed ?? () {};
    return {
      'id': id,
      'label': label,
      if (icon != null) 'icon': duoIcon(icon!, direction: direction),
      'enabled': menu != null ? menu!.isNotEmpty : onPressed != null,
      'selected': selected,
      'destructive': destructive,
      if (menu != null)
        'menu': [
          for (final item in menu!)
            item.encode(callbacks, direction: direction),
        ],
    };
  }
}

/// Internal collection scope for a native header. No widget-tree inspection:
/// only controls with an explicit [DuoActionBinding] are exported.
class DuoActionScope extends InheritedWidget {
  const DuoActionScope({
    super.key,
    required this.actions,
    required super.child,
  });

  final Map<Object, DuoAction> actions;

  @override
  bool updateShouldNotify(DuoActionScope oldWidget) =>
      actions != oldWidget.actions;
}

/// Uses the original Flutter control everywhere except inside a Duo header.
/// Stateful controls build the same binding again when their action changes.
class DuoActionBinding extends StatefulWidget {
  const DuoActionBinding({
    super.key,
    required this.action,
    required this.child,
  });

  final DuoAction action;
  final Widget child;

  @override
  State<DuoActionBinding> createState() => _DuoActionBindingState();
}

class _DuoActionBindingState extends State<DuoActionBinding> {
  DuoActionScope? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope?.actions.remove(this);
    _scope = context.dependOnInheritedWidgetOfExactType<DuoActionScope>();
    _scope?.actions[this] = widget.action;
  }

  @override
  void didUpdateWidget(DuoActionBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scope?.actions[this] = widget.action;
  }

  @override
  void dispose() {
    _scope?.actions.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _scope == null ? widget.child : const SizedBox.shrink();
}
