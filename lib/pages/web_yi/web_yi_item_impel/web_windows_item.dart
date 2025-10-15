import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:webview_windows/webview_windows.dart';

import '../web_yi_controller.dart';

class WebWindowsItem extends StatefulWidget {
  const WebWindowsItem({super.key});

  @override
  State<WebWindowsItem> createState() => _WebWindowsItemState();
}

class _WebWindowsItemState extends State<WebWindowsItem> {
  final webYiWindowsItemController = Modular.get<WebYiController>();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    webYiWindowsItemController.dispose();
    super.dispose();
  }

  Future<void> initPlatformState() async {
    if (webYiWindowsItemController.webviewController == null) {
      await webYiWindowsItemController.init();
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Webview(webYiWindowsItemController.webviewController));
  }
}
