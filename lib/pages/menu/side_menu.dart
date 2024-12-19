import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/router.dart';
import 'package:provider/provider.dart';

class SideMenu extends StatefulWidget {
  //const SideMenu({Key? key}) : super(key: key);
  const SideMenu({super.key});

  @override
  State<SideMenu> createState() => _SideMenu();
}

class SideNavigationBarState extends ChangeNotifier {
  int _selectedIndex = 0;
  bool _isRailVisible = true;

  int get selectedIndex => _selectedIndex;

  bool get isRailVisible => _isRailVisible;

  void updateSelectedIndex(int pageIndex) {
    _selectedIndex = pageIndex;
    notifyListeners();
  }

  void hideNavigate() {
    _isRailVisible = false;
    notifyListeners();
  }

  void showNavigate() {
    _isRailVisible = true;
    notifyListeners();
  }
}

class _SideMenu extends State<SideMenu> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SideNavigationBarState(),
      child: Scaffold(
        body: Row(
          children: [
            Consumer<SideNavigationBarState>(builder: (context, state, child) {
              return SafeArea(
                child: Visibility(
                  visible: state.isRailVisible,
                  child: NavigationRail(
                    groupAlignment: 1.0,
                    labelType: NavigationRailLabelType.selected,
                    leading: SizedBox(
                        width: 50,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ClipOval(
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                Modular.to.pushNamed('/settings/history');
                              },
                              child: Image.asset(
                              'assets/images/logo/logo_android.png',
                            ),
                          ),
                        ))),
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
                    selectedIndex: state.selectedIndex,
                    onDestinationSelected: (int index) {
                      state.updateSelectedIndex(index);
                      Modular.to.navigate("/tab${menu.getPath(index)}/");
                    },
                  ),
                ),
              );
            }),
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: PageView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: menu.size,
                  onPageChanged: (i) =>
                      Modular.to.navigate("/tab${menu.getPath(i)}/"),
                  itemBuilder: (_, __) => const RouterOutlet(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
