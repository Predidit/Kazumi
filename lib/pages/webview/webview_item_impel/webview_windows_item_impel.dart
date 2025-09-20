import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';

class WebviewWindowsItemImpel extends StatefulWidget {
  const WebviewWindowsItemImpel({super.key});

  @override
  State<WebviewWindowsItemImpel> createState() =>
      _WebviewWindowsItemImpelState();
}

class _WebviewWindowsItemImpelState extends State<WebviewWindowsItemImpel> {
  final webviewDesktopItemController = Modular.get<WebviewItemController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();

  @override
  void initState() {
    super.initState();
    webviewDesktopItemController.init();
  }

  @override
  void dispose() {
    webviewDesktopItemController.dispose();
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
