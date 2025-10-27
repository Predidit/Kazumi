import 'package:flutter/material.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';

class WebviewAppleItemImpel extends StatefulWidget {
  const WebviewAppleItemImpel({super.key});

  @override
  State<WebviewAppleItemImpel> createState() => _WebviewAppleItemImpelState();
}

class _WebviewAppleItemImpelState extends State<WebviewAppleItemImpel> {
  final webviewAppleItemController = Modular.get<WebviewItemController>();

  @override
  void initState() {
    super.initState();
    webviewAppleItemController.init();
  }

  @override
  void dispose() {
    webviewAppleItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.width * 9.0 / (16.0),
      width: MediaQuery.of(context).size.width,
      color: Colors.black,
      child: const Center(
        child: Text(
          '此平台不支持Webview规则',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
