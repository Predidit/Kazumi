import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/web_yi/web_yi_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebItem extends StatefulWidget {
  const WebItem({super.key});

  @override
  State<WebItem> createState() => _WebItemState();
}

class _WebItemState extends State<WebItem> {
  final webYiItemController = Modular.get<WebYiController>();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    webYiItemController.dispose();
    super.dispose();
  }

  Future<void> initPlatformState() async {
    // 初始化Webview
    if (webYiItemController.webviewController == null) {
      await webYiItemController.init();
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body:WebViewWidget(controller: webYiItemController.webviewController)
    );
  }
}
