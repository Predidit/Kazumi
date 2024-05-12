import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';

class WebviewItem extends StatefulWidget {
  const WebviewItem({
    super.key
  });

  @override
  State<WebviewItem> createState() => _WebviewItemState();
}

class _WebviewItemState extends State<WebviewItem> {
  final WebviewItemController webviewItemController = Modular.get<WebviewItemController>();

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: webviewItemController.webviewController);
  }
}

