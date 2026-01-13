import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart';
import 'package:kazumi/pages/router.dart';
import 'package:provider/provider.dart';

class ScaffoldMenu extends StatefulWidget {
  const ScaffoldMenu({super.key});

  @override
  State<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class NavigationBarState extends ChangeNotifier {
  int _selectedIndex = 0;
  bool _isHide = false;
  bool _isBottom = false;

  int get selectedIndex => _selectedIndex;

  bool get isHide => _isHide;

  bool get isBottom => _isBottom;

  void updateSelectedIndex(int pageIndex) {
    _selectedIndex = pageIndex;
    notifyListeners();
  }

  void hideNavigate() {
    _isHide = true;
    notifyListeners();
  }

  void showNavigate() {
    _isHide = false;
    notifyListeners();
  }
}

// 通用导航项
class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem(this.icon, this.selectedIcon, this.label);
}

class _ScaffoldMenu extends State<ScaffoldMenu> {
  final PageController _page = PageController();
  final GlobalKey _pageViewKey = GlobalKey();
  
  // 通用导航内容
  static const List<_NavItem> _navItems = <_NavItem>[
    _NavItem(Icons.home_outlined, Icons.home, '推荐'),
    _NavItem(Icons.timeline_outlined, Icons.timeline, '时间表'),
    _NavItem(Icons.favorite_border, Icons.favorite, '追番'),
    _NavItem(Icons.settings_outlined, Icons.settings, '我的'),
  ];
  static List<NavigationDestination> get _bottomDestinations => _navItems
      .map((e) => NavigationDestination(selectedIcon: Icon(e.selectedIcon), icon: Icon(e.icon), label: e.label))
      .toList();
  static List<NavigationRailDestination> get _sideDestinations => _navItems
      .map((e) => NavigationRailDestination(selectedIcon: Icon(e.selectedIcon), icon: Icon(e.icon), label: Text(e.label)))
      .toList();

  Widget _buildPageView() {
    return PageView.builder(
      key: _pageViewKey,
      physics: const NeverScrollableScrollPhysics(),
      controller: _page,
      itemCount: menu.size,
      itemBuilder: (_, __) => const RouterOutlet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (context) => NavigationBarState(),
        child: Consumer<NavigationBarState>(builder: (context, state, _) {
          return OrientationBuilder(builder: (context, orientation) {
            state._isBottom = orientation == Orientation.portrait;
            return orientation != Orientation.portrait
                ? sideMenuWidget(context, state)
                : bottomMenuWidget(context, state);
          });
        }));
  }

  Widget bottomMenuWidget(BuildContext context, NavigationBarState state) {
    return Scaffold(
        body: Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: _buildPageView(),
        ),
        bottomNavigationBar: state.isHide
            ? const SizedBox(height: 0)
            : NavigationBar(
                destinations: _bottomDestinations,
                selectedIndex: state.selectedIndex,
                onDestinationSelected: (int index) {
                  state.updateSelectedIndex(index);
                  Modular.to.navigate("/tab${menu.getPath(index)}/");
                },
              ));
  }

  Widget sideMenuWidget(BuildContext context, NavigationBarState state) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Row(
        children: [
          EmbeddedNativeControlArea(
            child: Visibility(
              visible: !state.isHide,
              child: DragToMoveArea(
                child: NavigationRail(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                  groupAlignment: 1.0,
                  leading: FloatingActionButton(
                    elevation: 0,
                    heroTag: null,
                    onPressed: () {
                      Modular.to.pushNamed('/search/');
                    },
                    child: const Icon(Icons.search),
                  ),
                  labelType: NavigationRailLabelType.selected,
                  destinations: _sideDestinations,
                  selectedIndex: state.selectedIndex,
                  onDestinationSelected: (int index) {
                    state.updateSelectedIndex(index);
                    Modular.to.navigate("/tab${menu.getPath(index)}/");
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  bottomLeft: Radius.circular(16.0),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  bottomLeft: Radius.circular(16.0),
                ),
                child: _buildPageView(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
