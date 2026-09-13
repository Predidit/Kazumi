import 'package:kazumi/services/platform/tv_mode.dart';

class MenuRouteItem {
  const MenuRouteItem({required this.path});

  final String path;
}

class MenuRoute {
  const MenuRoute(this.menuList);

  final List<MenuRouteItem> menuList;

  String getPath(int index) => menuList[index].path;

  int indexForPath(String path) {
    final index = menuList.indexWhere(
      (item) =>
          path == '/tab${item.path}' ||
          path == '/tab${item.path}/' ||
          path.startsWith('/tab${item.path}/'),
    );
    return index < 0 ? 0 : index;
  }
}

MenuRoute get menu => TvMode.enabled ? tvMenu : mobileMenu;

const MenuRoute mobileMenu = MenuRoute([
  MenuRouteItem(path: '/popular'),
  MenuRouteItem(path: '/timeline'),
  MenuRouteItem(path: '/collect'),
  MenuRouteItem(path: '/my'),
]);

const MenuRoute tvMenu = MenuRoute([
  MenuRouteItem(path: '/popular'),
  MenuRouteItem(path: '/history'),
  MenuRouteItem(path: '/timeline'),
  MenuRouteItem(path: '/collect'),
  MenuRouteItem(path: '/my'),
  MenuRouteItem(path: '/remote-help'),
]);
