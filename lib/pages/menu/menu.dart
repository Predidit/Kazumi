import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/pages/menu/route_visibility.dart';
import 'package:kazumi/pages/router.dart';
import 'package:kazumi/bean/widget/gamepad_navigation.dart';

class ScaffoldMenu extends StatefulWidget {
  const ScaffoldMenu({super.key, required this.location});

  final String location;

  @override
  State<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class _ScaffoldMenu extends State<ScaffoldMenu> with RouteAware {
  final _outletKey = GlobalKey<RouterOutletState>();
  late int _selectedIndex = menu.indexForPath(widget.location);
  DateTime? _lastExitPromptAt;

  /// The shell sits at the bottom of the root stack and stays mounted while
  /// other pages cover it, so it publishes that state for its subtree.
  bool _isCovered = false;

  @override
  void initState() {
    super.initState();
    GamepadNavigationScope.onSectionFallback = _handleGlobalSectionSwitch;
  }

  @override
  void didUpdateWidget(covariant ScaffoldMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _selectedIndex = menu.indexForPath(widget.location);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      rootRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    GamepadNavigationScope.onSectionFallback = null;
    rootRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() => _setCovered(true);

  @override
  void didPopNext() => _setCovered(false);

  void _setCovered(bool value) {
    if (!mounted || _isCovered == value) {
      return;
    }
    setState(() => _isCovered = value);
  }

  void _selectDestination(int index) {
    _lastExitPromptAt = null;
    if (index == _selectedIndex) {
      return;
    }
    final outlet = _outletKey.currentState;
    if (outlet == null) return;
    outlet.navigate('/tab${menu.getPath(index)}/');
    setState(() => _selectedIndex = index);
  }

  // The shell owns its selection even while another page covers it.
  void _handleGlobalSectionSwitch(int offset) {
    _selectDestination((_selectedIndex + offset) % menu.menuList.length);
  }

  void _handleSystemBack(BuildContext context) {
    if (_outletKey.currentState?.maybePop() ?? false) {
      _lastExitPromptAt = null;
      return;
    }

    if (_selectedIndex != 0) {
      _selectDestination(0);
      return;
    }

    final now = DateTime.now();
    final lastPromptAt = _lastExitPromptAt;
    if (lastPromptAt == null ||
        now.difference(lastPromptAt) > const Duration(seconds: 2)) {
      _lastExitPromptAt = now;
      KazumiDialog.showToast(message: '再按一次退出应用', context: context);
      return;
    }

    _lastExitPromptAt = null;
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        GamepadBackIntent: CallbackAction<GamepadBackIntent>(
          onInvoke: (_) {
            _handleSystemBack(context);
            return null;
          },
        ),
        GamepadPreviousSectionIntent:
            CallbackAction<GamepadPreviousSectionIntent>(
          onInvoke: (_) {
            _handleGlobalSectionSwitch(-1);
            return null;
          },
        ),
        GamepadNextSectionIntent: CallbackAction<GamepadNextSectionIntent>(
          onInvoke: (_) {
            _handleGlobalSectionSwitch(1);
            return null;
          },
        ),
        GamepadContextActionIntent: CallbackAction<GamepadContextActionIntent>(
          onInvoke: (_) {
            // The search page owns Y while its input is focused. The shell's
            // action is still in the ancestor tree, so inspect both the
            // focused route and the root route state before opening another
            // search route. This also covers nested tab paths such as
            // /tab/my/search, which are not equal to /search.
            final focusedContext = FocusManager.instance.primaryFocus?.context;
            final navigationContext = rootNavigatorKey.currentContext;
            final paths = <String>[];
            for (final candidate in [
              focusedContext,
              navigationContext,
              context
            ]) {
              if (candidate == null) continue;
              try {
                paths.add(candidate.routeState(listen: false).uri.path);
              } catch (_) {
                // A focused platform view can sit outside Modular's route
                // scope; the other candidates still provide the route.
              }
            }
            bool isSearchPath(String path) =>
                path == '/search' ||
                path.endsWith('/search') ||
                path.contains('/search/');
            if (paths.any(isSearchPath)) {
              return null;
            }
            context.pushNamed('/search/');
            return null;
          },
        ),
        GamepadMenuIntent: CallbackAction<GamepadMenuIntent>(
          onInvoke: (_) {
            context.pushNamed('/settings/');
            return null;
          },
        ),
      },
      child: RouteVisibility(
        isCovered: _isCovered,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _handleSystemBack(context);
            }
          },
          child: OrientationBuilder(
            builder: (context, orientation) {
              return orientation == Orientation.portrait
                  ? _bottomMenu(context, _selectedIndex)
                  : _sideMenu(context, _selectedIndex);
            },
          ),
        ),
      ),
    );
  }

  Widget _outlet(BuildContext context, {BorderRadius? borderRadius}) {
    Widget child = NotificationListener<NavigationNotification>(
      // A non-poppable outlet must not override the shell's PopScope state.
      onNotification: (notification) => !notification.canHandlePop,
      child: RouterOutlet(key: _outletKey),
    );
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius, child: child);
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }

  Widget _bottomMenu(BuildContext context, int selectedIndex) {
    return Scaffold(
      body: _outlet(context),
      bottomNavigationBar: NavigationBar(
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: '推荐',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.timeline),
            icon: Icon(Icons.timeline_outlined),
            label: '时间表',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.favorite),
            icon: Icon(Icons.favorite_outlined),
            label: '追番',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.settings),
            icon: Icon(Icons.settings),
            label: '我的',
          ),
        ],
        selectedIndex: selectedIndex,
        onDestinationSelected: _selectDestination,
      ),
    );
  }

  Widget _sideMenu(BuildContext context, int selectedIndex) {
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(16),
      bottomLeft: Radius.circular(16),
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Row(
        children: [
          EmbeddedNativeControlArea(
            child: NavigationRail(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              groupAlignment: 1,
              leading: FloatingActionButton(
                elevation: 0,
                heroTag: null,
                onPressed: () => context.pushNamed('/search/'),
                child: const Icon(Icons.search),
              ),
              labelType: NavigationRailLabelType.selected,
              destinations: const <NavigationRailDestination>[
                NavigationRailDestination(
                  selectedIcon: Icon(Icons.home),
                  icon: Icon(Icons.home_outlined),
                  label: Text('推荐'),
                ),
                NavigationRailDestination(
                  selectedIcon: Icon(Icons.timeline),
                  icon: Icon(Icons.timeline_outlined),
                  label: Text('时间表'),
                ),
                NavigationRailDestination(
                  selectedIcon: Icon(Icons.favorite),
                  icon: Icon(Icons.favorite_border),
                  label: Text('追番'),
                ),
                NavigationRailDestination(
                  selectedIcon: Icon(Icons.settings),
                  icon: Icon(Icons.settings_outlined),
                  label: Text('我的'),
                ),
              ],
              selectedIndex: selectedIndex,
              onDestinationSelected: _selectDestination,
            ),
          ),
          Expanded(child: _outlet(context, borderRadius: borderRadius)),
        ],
      ),
    );
  }
}
