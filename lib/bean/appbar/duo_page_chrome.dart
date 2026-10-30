import 'package:flutter/material.dart';
import 'package:kazumi/services/platform/duo_navigation.dart';
import 'duo_action.dart';

export 'duo_action.dart' show DuoAction, DuoActionBinding;

/// A route-aware native header. Ordinary content remains in [child]; only
/// explicitly bound actions are moved to UIKit. [actionOwners] is for custom pages
/// whose action controls live outside the visible Flutter header.
class DuoPageChrome extends StatefulWidget {
  const DuoPageChrome({
    super.key,
    this.leading,
    this.actionOwners = const [],
    this.hidden = false,
    this.immersive = false,
    this.dark,
    this.child = const SizedBox.shrink(),
  }) : _adaptChild = false;

  /// Adapt only a header subtree, never a page body or its inline controls.
  const DuoPageChrome.header({
    super.key,
    this.leading,
    this.hidden = false,
    this.immersive = false,
    this.dark,
    required this.child,
  }) : _adaptChild = true,
       actionOwners = const [];

  final bool _adaptChild;
  final DuoAction? leading;
  final List<Widget> actionOwners;
  final bool hidden;
  final bool immersive;
  final bool? dark;
  final Widget child;

  @override
  State<DuoPageChrome> createState() => _DuoPageChromeState();
}

class _DuoPageChromeState extends State<DuoPageChrome> {
  static int _nextId = 0;
  final int _id = ++_nextId;
  final _actions = <Object, DuoAction>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routes = <ModalRoute<dynamic>>[];
    var route = ModalRoute.of(context);
    while (route != null && !routes.contains(route)) {
      routes.add(route);
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of(navigator.context);
    }
    var depth = 0;
    context.visitAncestorElements((_) {
      depth++;
      return true;
    });
    DuoNavigation.register(
      this,
      DuoHeaderRegistration(
        id: _id,
        depth: depth,
        routes: routes,
        snapshot: _snapshot,
      ),
    );
  }

  @override
  void dispose() {
    DuoNavigation.unregister(this);
    super.dispose();
  }

  DuoChrome _snapshot() {
    final callbacks = <String, VoidCallback>{};
    final leading = widget.leading?.encode(callbacks);
    final actions = [
      for (final action in _actions.values) action.encode(callbacks),
    ];
    return DuoChrome(
      dark: widget.dark ?? Theme.of(context).brightness == Brightness.dark,
      hidden:
          widget.hidden ||
          widget.immersive ||
          (leading == null && actions.isEmpty),
      immersive: widget.immersive,
      leading: leading,
      actions: actions,
      callbacks: callbacks,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!DuoNavigation.enabled.value) return widget.child;
    Widget scope(Widget child) =>
        DuoActionScope(actions: _actions, child: child);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Custom header controls keep their own state. Their bindings publish
        // descriptors without mounting hidden Flutter buttons or menus.
        if (widget.actionOwners.isNotEmpty)
          SizedBox(
            width: 0,
            height: 0,
            child: Offstage(
              child: scope(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.actionOwners,
                ),
              ),
            ),
          ),
        widget._adaptChild ? scope(widget.child) : widget.child,
      ],
    );
  }
}

/// Insets foreground content on Duo while its parent's background can paint
/// beneath the native sidebar. Other devices keep their existing layout.
class DuoContentSafeArea extends StatelessWidget {
  const DuoContentSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DuoNavigation.enabled.value
      ? SafeArea(top: false, bottom: false, child: child)
      : child;
}
