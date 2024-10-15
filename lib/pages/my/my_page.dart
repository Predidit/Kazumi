import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/menu/side_menu.dart';
import 'package:kazumi/utils/utils.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  dynamic navigationBarState;

  void onBackPressed(BuildContext context) {
    navigationBarState.updateSelectedIndex(0);
    Modular.to.navigate('/tab/popular/');
  }

  @override
  void initState() {
    super.initState();
    if (Utils.isCompact()) {
      navigationBarState =
          Provider.of<NavigationBarState>(context, listen: false);
    } else {
      navigationBarState =
          Provider.of<SideNavigationBarState>(context, listen: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('我的')),
        body: ListView(
          children: [
            ListTile(
              onTap: () {
                Modular.to.pushNamed('/tab/my/history');
              },
              dense: false,
              title: const Text('历史记录'),
            ),
            ListTile(
              onTap: () async {
                Modular.to.pushNamed('/tab/my/plugin');
              },
              dense: false,
              title: const Text('规则管理'),
            ),
            ListTile(
              onTap: () async {
                Modular.to.pushNamed('/tab/my/player');
              },
              dense: false,
              title: const Text('播放设置'),
            ),
            ListTile(
              onTap: () async {
                Modular.to.pushNamed('/tab/my/danmaku');
              },
              dense: false,
              title: const Text('弹幕设置'),
            ),
            ListTile(
              onTap: () async {
                Modular.to.pushNamed('/tab/my/theme');
              },
              dense: false,
              title: const Text('外观设置'),
              // trailing: const Icon(Icons.navigate_next),
            ),
            ListTile(
              onTap: () async {
                Modular.to.pushNamed('/tab/my/webdav');
              },
              dense: false,
              title: const Text('同步设置'),
            ),
            ListTile(
              onTap: () async {
                Modular.to.pushNamed('/tab/my/other');
              },
              dense: false,
              title: const Text('其他设置'),
            ),
            ListTile(
              onTap: () {
                Modular.to.pushNamed('/tab/my/about');
              },
              dense: false,
              title: const Text('关于'),
            ),
          ],
        ),
      ),
    );
  }
}
