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
            onTap: () async {
              Modular.to.pushNamed('/tab/my/plugin');
            },
            dense: false,
            title: const Text('规则管理'),
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
