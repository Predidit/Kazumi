import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';
import 'package:kazumi/design_system/kazumi_surfaces.dart';
import 'package:kazumi/pages/router.dart';
import 'package:kazumi/utils/device.dart';

class ScaffoldMenu extends StatefulWidget {
  const ScaffoldMenu({super.key});

  @override
  State<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class _ScaffoldMenu extends State<ScaffoldMenu> {
  final _outletKey = GlobalKey<RouterOutletState>();
  DateTime? _lastExitPromptAt;

  void _selectDestination(int index) {
    _lastExitPromptAt = null;
    final currentIndex =
        menu.indexForPath(context.routeState(listen: false).uri.path);
    if (index == currentIndex) return;
    _outletKey.currentState?.navigate('/tab${menu.getPath(index)}/');
  }

  void _handleSystemBack(BuildContext context) {
    if (_outletKey.currentState?.maybePop() ?? false) {
      _lastExitPromptAt = null;
      return;
    }

    final currentIndex =
        menu.indexForPath(context.routeState(listen: false).uri.path);
    if (currentIndex != 0) {
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
    final selectedIndex = menu.indexForPath(context.routeState().uri.path);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack(context);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useSideNavigation = isDesktop()
              ? constraints.maxWidth >= KazumiDesignTokens.shellBreakpoint
              : MediaQuery.orientationOf(context) == Orientation.landscape;
          return useSideNavigation
              ? _sideMenu(context, selectedIndex)
              : _bottomMenu(context, selectedIndex);
        },
      ),
    );
  }

  Widget _outlet(BuildContext context, {BorderRadius? borderRadius}) {
    Widget child = NotificationListener<NavigationNotification>(
      onNotification: (notification) => !notification.canHandlePop,
      child: RouterOutlet(key: _outletKey),
    );
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius, child: child);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }

  Widget _bottomMenu(BuildContext context, int selectedIndex) {
    final tokens = context.design;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _outlet(context),
      floatingActionButton: isDesktop()
          ? FloatingActionButton.small(
              heroTag: null,
              tooltip: '搜索',
              onPressed: () => context.pushNamed('/search/'),
              child: const Icon(Icons.search_rounded),
            )
          : null,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: KazumiGlassSurface(
          borderRadius: BorderRadius.circular(tokens.radiusSurface),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            destinations: const <Widget>[
              NavigationDestination(
                selectedIcon: Icon(Icons.home_rounded),
                icon: Icon(Icons.home_outlined),
                label: '推荐',
              ),
              NavigationDestination(
                selectedIcon: Icon(Icons.timeline_rounded),
                icon: Icon(Icons.timeline_outlined),
                label: '时间表',
              ),
              NavigationDestination(
                selectedIcon: Icon(Icons.favorite_rounded),
                icon: Icon(Icons.favorite_border_rounded),
                label: '追番',
              ),
              NavigationDestination(
                selectedIcon: Icon(Icons.settings_rounded),
                icon: Icon(Icons.settings_outlined),
                label: '我的',
              ),
            ],
            selectedIndex: selectedIndex,
            onDestinationSelected: _selectDestination,
          ),
        ),
      ),
    );
  }

  Widget _sideMenu(BuildContext context, int selectedIndex) {
    final tokens = context.design;
    final borderRadius = BorderRadius.circular(tokens.radiusSurface);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            EmbeddedNativeControlArea(
              child: KazumiGlassSurface(
                borderRadius: borderRadius,
                shadow: false,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: NavigationRail(
                  groupAlignment: 0.35,
                  scrollable: true,
                  leading: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label: 'Kazumi',
                          image: true,
                          child: ClipRSuperellipse(
                            borderRadius: BorderRadius.circular(
                              tokens.radiusControl,
                            ),
                            child: Image.asset(
                              'assets/images/logo/logo_rounded.png',
                              width: 42,
                              height: 42,
                              cacheWidth: 96,
                              cacheHeight: 96,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FloatingActionButton.small(
                          heroTag: null,
                          tooltip: '搜索',
                          onPressed: () => context.pushNamed('/search/'),
                          child: const Icon(Icons.search_rounded),
                        ),
                      ],
                    ),
                  ),
                  labelType: NavigationRailLabelType.selected,
                  destinations: const <NavigationRailDestination>[
                    NavigationRailDestination(
                      selectedIcon: Icon(Icons.home_rounded),
                      icon: Icon(Icons.home_outlined),
                      label: Text('推荐'),
                    ),
                    NavigationRailDestination(
                      selectedIcon: Icon(Icons.timeline_rounded),
                      icon: Icon(Icons.timeline_outlined),
                      label: Text('时间表'),
                    ),
                    NavigationRailDestination(
                      selectedIcon: Icon(Icons.favorite_rounded),
                      icon: Icon(Icons.favorite_border_rounded),
                      label: Text('追番'),
                    ),
                    NavigationRailDestination(
                      selectedIcon: Icon(Icons.settings_rounded),
                      icon: Icon(Icons.settings_outlined),
                      label: Text('我的'),
                    ),
                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: _selectDestination,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _outlet(context, borderRadius: borderRadius)),
          ],
        ),
      ),
    );
  }
}
