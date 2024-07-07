import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(title: const Text('我的')),
      body: Column(
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
    );
  }
}
