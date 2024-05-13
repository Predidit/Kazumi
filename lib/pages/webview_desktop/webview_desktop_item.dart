import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/pages/webview_desktop/webview_desktop_controller.dart';

class WebviewDesktopItem extends StatefulWidget {
  const WebviewDesktopItem({super.key});

  @override
  State<WebviewDesktopItem> createState() => _WebviewDesktopItemState();
}

class _WebviewDesktopItemState extends State<WebviewDesktopItem> {
  // final _controller = WebviewController();
  final List<StreamSubscription> _subscriptions = [];
  final WebviewDesktopItemController webviewDesktopItemController =
      Modular.get<WebviewDesktopItemController>();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    await webviewDesktopItemController.webviewController.initialize();
    // 接受全屏事件
    _subscriptions
        .add(webviewDesktopItemController.webviewController.containsFullScreenElementChanged.listen((flag) {
      debugPrint('包括可全屏元素: $flag');
      windowManager.setFullScreen(flag);
    }));
    // 初始化JS监听器
    webviewDesktopItemController.initJSBridge();
    if (!mounted) return;

    setState(() {});
  }

  Widget get compositeView {
    if (!webviewDesktopItemController.webviewController.value.isInitialized) {
      return const Text(
        'Not Initialized',
        style: TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Card(
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Stack(
            children: [
              Webview(webviewDesktopItemController.webviewController),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return compositeView;
  }
}
