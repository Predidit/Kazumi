import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/pages/menu/route_visibility.dart';
import 'package:kazumi/pages/router.dart';
import 'package:kazumi/services/platform/tv_mode.dart';
import 'package:kazumi/services/platform/tv_channel_input.dart';
import 'package:kazumi/bean/widget/tv_focus_navigation.dart';

class ScaffoldMenu extends StatefulWidget {
  const ScaffoldMenu({super.key, required this.location});

  final String location;

  @override
  State<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class _ScaffoldMenu extends State<ScaffoldMenu> with RouteAware {
  final _outletKey = GlobalKey<RouterOutletState>();
  late int _selectedIndex = menu.indexForPath(widget.location);
  final _searchFocusNode = FocusNode(debugLabel: 'TV search entry');
  final _railFocusScope = FocusScopeNode(debugLabel: 'TV navigation rail');
  final _contentFocusScope = FocusScopeNode(debugLabel: 'TV content');
  bool _restoreContentAfterRoute = false;
  DateTime? _lastExitPromptAt;
  bool _didScheduleInitialTvFocus = false;

  /// The shell sits at the bottom of the root stack and stays mounted while
  /// other pages cover it, so it publishes that state for its subtree.
  bool _isCovered = false;

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
    if (!_didScheduleInitialTvFocus) {
      _didScheduleInitialTvFocus = true;
      _requestTvEntryFocus();
    }
  }

  @override
  void dispose() {
    rootRouteObserver.unsubscribe(this);
    _searchFocusNode.dispose();
    _railFocusScope.dispose();
    _contentFocusScope.dispose();
    super.dispose();
  }

  @override
  void didPushNext() => _setCovered(true);

  @override
  void didPopNext() {
    _setCovered(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isCovered || !TvMode.enabled) return;
      if (_restoreContentAfterRoute) {
        _contentFocusScope.requestFocus();
      } else {
        _railFocusScope.requestFocus();
      }
    });
  }

  void _requestTvEntryFocus() {
    if (!TvMode.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isCovered) return;
      _searchFocusNode.requestFocus();
      // The nested outlet installs its initial route after this frame and may
      // focus that route's empty scope. Repair only this startup handoff;
      // never take focus back from a control the user has already reached.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isCovered || !TvMode.enabled) return;
        final current = FocusManager.instance.primaryFocus;
        if (current is FocusScopeNode &&
            current.ancestors.contains(_contentFocusScope)) {
          _searchFocusNode.requestFocus();
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  void _setCovered(bool value) {
    if (!mounted || _isCovered == value) {
      return;
    }
    if (value) {
      _restoreContentAfterRoute = _contentFocusScope.hasFocus;
      tvChannelInputController.cancel();
    }
    setState(() => _isCovered = value);
  }

  void _selectDestination(int index) {
    _lastExitPromptAt = null;
    if (index == _selectedIndex) {
      return;
    }
    if (index != 0) tvChannelInputController.cancel();
    final outlet = _outletKey.currentState;
    if (outlet == null) return;
    outlet.navigate('/tab${menu.getPath(index)}/');
    setState(() => _selectedIndex = index);
  }

  void _handleSystemBack(BuildContext context) {
    if (_outletKey.currentState?.maybePop() ?? false) {
      _lastExitPromptAt = null;
      return;
    }

    if (_selectedIndex == 0 && tvChannelInputController.value != null) {
      tvChannelInputController.cancel();
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

  KeyEventResult _handleTvNumberKey(FocusNode node, KeyEvent event) {
    if (!TvMode.enabled ||
        _isCovered ||
        event is! KeyDownEvent ||
        _selectedIndex != 0) {
      return KeyEventResult.ignored;
    }
    final digit = tvDigitForLogicalKey(event.logicalKey);
    if (digit == null) {
      return KeyEventResult.ignored;
    }
    tvChannelInputController.addDigit(digit);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return RouteVisibility(
      isCovered: _isCovered,
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: _handleTvNumberKey,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _handleSystemBack(context);
            }
          },
          child: OrientationBuilder(
            builder: (context, orientation) {
              return orientation == Orientation.portrait && !TvMode.enabled
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
    if (TvMode.enabled) {
      child = Actions(
        actions: {
          TvFocusRailIntent: CallbackAction<TvFocusRailIntent>(
            onInvoke: (_) {
              _railFocusScope.requestFocus();
              return null;
            },
          ),
        },
        child: FocusScope(
          node: _contentFocusScope,
          onKeyEvent: (_, event) {
            if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
                event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              final current = FocusManager.instance.primaryFocus;
              if (current?.context?.widget is EditableText) {
                return KeyEventResult.ignored;
              }
              if (current != null &&
                  !ReadingOrderTraversalPolicy()
                      .inDirection(current, TraversalDirection.left)) {
                _railFocusScope.requestFocus();
              }
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: child,
        ),
      );
    }
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
            child: FocusScope(
              node: _railFocusScope,
              onKeyEvent: (_, event) {
                if (!TvMode.enabled ||
                    (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
                  return KeyEventResult.ignored;
                }
                final current = FocusManager.instance.primaryFocus;
                if (current == null) return KeyEventResult.ignored;
                final nodes = _railFocusScope.traversalDescendants.toList()
                  ..sort(
                      (a, b) => a.rect.center.dy.compareTo(b.rect.center.dy));
                final index = nodes.indexOf(current);
                if (index >= 0 &&
                    (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                        event.logicalKey == LogicalKeyboardKey.arrowDown)) {
                  nodes[tvWrappedIndex(
                          index,
                          event.logicalKey == LogicalKeyboardKey.arrowUp
                              ? -1
                              : 1,
                          nodes.length)]
                      .requestFocus();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  if (_contentFocusScope.focusedChild != null) {
                    _contentFocusScope.requestFocus();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || _isCovered) return;
                      final focus = FocusManager.instance.primaryFocus;
                      if (focus is! FocusScopeNode ||
                          !focus.ancestors.contains(_contentFocusScope)) {
                        return;
                      }
                      // A newly mounted outlet can remember only an empty
                      // route scope. Explicit RIGHT must enter a real control.
                      final controls = _contentFocusScope.traversalDescendants
                          .where((node) =>
                              node is! FocusScopeNode &&
                              node.canRequestFocus &&
                              node.context != null);
                      if (controls.isNotEmpty) controls.first.requestFocus();
                    });
                    return KeyEventResult.handled;
                  }
                  _railFocusScope.directionalTraversalEdgeBehavior =
                      TraversalEdgeBehavior.parentScope;
                  ReadingOrderTraversalPolicy()
                      .inDirection(current, TraversalDirection.right);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  final candidates = _railFocusScope
                          .enclosingScope?.traversalDescendants
                          .where((node) =>
                              node.context != null &&
                              !node.ancestors.contains(_railFocusScope))
                          .toList() ??
                      <FocusNode>[];
                  candidates.sort((a, b) {
                    final horizontal =
                        b.rect.center.dx.compareTo(a.rect.center.dx);
                    return horizontal != 0
                        ? horizontal
                        : (a.rect.center.dy - current.rect.center.dy)
                            .abs()
                            .compareTo(
                                (b.rect.center.dy - current.rect.center.dy)
                                    .abs());
                  });
                  if (candidates.isNotEmpty) candidates.first.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: NavigationRail(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                groupAlignment: 1,
                leading: FloatingActionButton(
                  elevation: 0,
                  heroTag: null,
                  autofocus: TvMode.enabled,
                  focusNode: _searchFocusNode,
                  onPressed: () => context.pushNamed('/search/'),
                  child: const Icon(Icons.search),
                ),
                labelType: NavigationRailLabelType.selected,
                destinations: <NavigationRailDestination>[
                  const NavigationRailDestination(
                    selectedIcon: Icon(Icons.home),
                    icon: Icon(Icons.home_outlined),
                    label: Text('推荐'),
                  ),
                  if (TvMode.enabled)
                    const NavigationRailDestination(
                      selectedIcon: Icon(Icons.history_rounded),
                      icon: Icon(Icons.history),
                      label: Text('历史'),
                    ),
                  const NavigationRailDestination(
                    selectedIcon: Icon(Icons.timeline),
                    icon: Icon(Icons.timeline_outlined),
                    label: Text('时间表'),
                  ),
                  const NavigationRailDestination(
                    selectedIcon: Icon(Icons.favorite),
                    icon: Icon(Icons.favorite_border),
                    label: Text('追番'),
                  ),
                  const NavigationRailDestination(
                    selectedIcon: Icon(Icons.settings),
                    icon: Icon(Icons.settings_outlined),
                    label: Text('我的'),
                  ),
                  if (TvMode.enabled)
                    const NavigationRailDestination(
                      selectedIcon: Icon(Icons.gamepad_rounded),
                      icon: Icon(Icons.gamepad_outlined),
                      label: Text('遥控器'),
                    ),
                ],
                selectedIndex: selectedIndex,
                onDestinationSelected: _selectDestination,
              ),
            ),
          ),
          Expanded(child: _outlet(context, borderRadius: borderRadius)),
        ],
      ),
    );
  }
}
