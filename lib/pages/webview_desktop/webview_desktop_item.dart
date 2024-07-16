import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/pages/video/video_controller.dart';
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
  final VideoPageController videoPageController = Modular.get<VideoPageController>();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    _subscriptions.forEach((s) => s.cancel());
    webviewDesktopItemController.dispose();
    super.dispose();
  }

  Future<void> initPlatformState() async {
    // 初始化Webview
    if (!webviewDesktopItemController.webviewController.value.isInitialized) {
      await webviewDesktopItemController.init();
    }
    // 接受全屏事件
    _subscriptions.add(webviewDesktopItemController
        .webviewController.containsFullScreenElementChanged
        .listen((flag) {
      debugPrint('包括可全屏元素: $flag');
      videoPageController.androidFullscreen = flag;
      windowManager.setFullScreen(flag);
    }));
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
      return Webview(webviewDesktopItemController.webviewController);
    }
  }

  @override
  Widget build(BuildContext context) {
    return compositeView;
  }
}
