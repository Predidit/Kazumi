import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';

class WebviewLinuxItemImpel extends StatefulWidget {
  const WebviewLinuxItemImpel({super.key});

  @override
  State<WebviewLinuxItemImpel> createState() => _WebviewLinuxItemImpelState();
}

class _WebviewLinuxItemImpelState extends State<WebviewLinuxItemImpel> {
  final webviewLinuxItemController = Modular.get<WebviewItemController>();

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
