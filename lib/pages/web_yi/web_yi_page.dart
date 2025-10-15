import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kazumi/pages/web_yi/web_yi_item_impel/web_item.dart';
import 'package:kazumi/pages/web_yi/web_yi_item_impel/web_windows_item.dart';
import '../../bean/appbar/sys_app_bar.dart';

class WebYiPage extends StatefulWidget {
  const WebYiPage({super.key});

  @override
  State<WebYiPage> createState() => _WebYiPageState();
}

class _WebYiPageState extends State<WebYiPage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(title: Text('web')),
      body: webYiUniversal,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

Widget get webYiUniversal {
  if (Platform.isWindows) {
    print('Windows');
    return const WebWindowsItem();
  }
  print('item');
  return const WebItem();
}
