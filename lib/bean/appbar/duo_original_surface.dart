import 'package:flutter/widgets.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/services/platform/duo_navigation.dart';

/// Gives the original player its whole window and sole ownership of controls.
/// A popup keeps this policy; pushing another page releases it until returning.
class DuoOriginalSurface extends StatefulWidget {
  const DuoOriginalSurface({super.key, required this.child});

  final Widget child;

  @override
  State<DuoOriginalSurface> createState() => _DuoOriginalSurfaceState();
}

class _DuoOriginalSurfaceState extends State<DuoOriginalSurface>
    with RouteAware {
  PageRoute<void>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!DuoNavigation.enabled.value) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute<void> && !identical(route, _route)) {
      rootRouteObserver.unsubscribe(this);
      _route = route;
      rootRouteObserver.subscribe(this, route);
      _setActive(route.isCurrent);
    }
  }

  void _setActive(bool active) =>
      DuoNavigation.setOriginalSurface(this, active);

  @override
  void didPush() => _setActive(true);

  @override
  void didPushNext() => _setActive(false);

  @override
  void didPopNext() => _setActive(true);

  @override
  void didPop() => _setActive(false);

  @override
  void dispose() {
    rootRouteObserver.unsubscribe(this);
    _setActive(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
