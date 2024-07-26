import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/webview_linux/webview_linux_controller.dart';

class WebviewLinuxItem extends StatefulWidget {
  const WebviewLinuxItem({super.key});

  @override
  State<WebviewLinuxItem> createState() => _WebviewLinuxItemState();
}

class _WebviewLinuxItemState extends State<WebviewLinuxItem> {
  final WebviewLinuxItemController webviewLinuxItemController =
      Modular.get<WebviewLinuxItemController>();

  @override
  void initState() {
    super.initState();
    webviewLinuxItemController.init();
  }

  @override
  void dispose() {
    webviewLinuxItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        height: MediaQuery.of(context).size.width * 9.0 / (16.0),
        width: MediaQuery.of(context).size.width,
        color: Colors.black,
        child: const Center(child: Text('此平台不支持Webview规则')));
  }
}
