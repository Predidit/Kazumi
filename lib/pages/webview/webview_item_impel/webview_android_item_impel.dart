import 'package:flutter/material.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/webview/webview_controller_impel/webview_android_controller_impel.dart';

class WebviewAndroidItemImpel extends StatefulWidget {
  const WebviewAndroidItemImpel({super.key});

  @override
  State<WebviewAndroidItemImpel> createState() =>
      _WebviewAndroidItemImpelState();
}

class _WebviewAndroidItemImpelState extends State<WebviewAndroidItemImpel> {
  final webviewAndroidItemController =
      Modular.get<WebviewItemController>() as WebviewAndroidItemControllerImpel;

  @override
  void initState() {
    super.initState();
    webviewAndroidItemController.init();
  }

  @override
  void dispose() {
    webviewAndroidItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        height: MediaQuery.of(context).size.width * 9.0 / (16.0),
        width: MediaQuery.of(context).size.width,
        color: Colors.black,
        child: const Center(child: Text('此平台不支持Webview规则', style: TextStyle(color: Colors.white))));
  }
}
