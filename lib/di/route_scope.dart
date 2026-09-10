import 'package:auto_injector/auto_injector.dart';
import 'package:flutter/widgets.dart';

/// Disposes local bindings after unmount; never attach the root injector here.
class RouteScope extends StatefulWidget {
  const RouteScope({
    super.key,
    required this.create,
    required this.builder,
  });

  final AutoInjector Function() create;
  final Widget Function(BuildContext context, AutoInjector injector) builder;

  static T read<T>(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ScopeProvider>();
    assert(scope != null, 'No RouteScope found above this context.');
    return scope!.injector.get<T>();
  }

  @override
  State<RouteScope> createState() => _RouteScopeState();
}

class _RouteScopeState extends State<RouteScope> {
  late final AutoInjector _injector = widget.create();

  @override
  void initState() {
    super.initState();
    _injector.commit();
  }

  @override
  void dispose() {
    _injector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ScopeProvider(
        injector: _injector,
        child:
            Builder(builder: (context) => widget.builder(context, _injector)),
      );
}

class _ScopeProvider extends InheritedWidget {
  const _ScopeProvider({required this.injector, required super.child});

  final AutoInjector injector;

  @override
  bool updateShouldNotify(_ScopeProvider oldWidget) =>
      injector != oldWidget.injector;
}
