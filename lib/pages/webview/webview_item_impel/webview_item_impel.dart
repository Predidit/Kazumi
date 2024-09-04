import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';

class WebviewItemImpel extends StatefulWidget {
  const WebviewItemImpel({super.key});

  @override
  State<WebviewItemImpel> createState() => _WebviewItemImpelState();
}

class _WebviewItemImpelState extends State<WebviewItemImpel> {
  final webviewItemController = Modular.get<WebviewItemController>();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    webviewItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return compositeView;
  }

  Future<void> initPlatformState() async {
    // 初始化Webview
    if (webviewItemController.webviewController == null) {
      await webviewItemController.init();
    }
    if (!mounted) return;
    setState(() {});
  }

  Widget get compositeView {
    if (webviewItemController.webviewController == null) {
      return const Text(
        'Not Initialized',
        style: TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return WebViewWidget(controller: webviewItemController.webviewController);
    }
  }
}
