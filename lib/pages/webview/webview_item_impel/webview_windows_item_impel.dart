import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';

class WebviewWindowsItemImpel extends StatefulWidget {
  const WebviewWindowsItemImpel({super.key});

  @override
  State<WebviewWindowsItemImpel> createState() =>
      _WebviewWindowsItemImpelState();
}

class _WebviewWindowsItemImpelState extends State<WebviewWindowsItemImpel> {
  final List<StreamSubscription> _subscriptions = [];
  final webviewDesktopItemController = Modular.get<WebviewItemController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    for (var s in _subscriptions) {
      try {
        s.cancel();
      } catch (_) {}
    }
    webviewDesktopItemController.dispose();
    super.dispose();
  }

  Future<void> initPlatformState() async {
    // 初始化Webview
    if (webviewDesktopItemController.webviewController == null) {
      await webviewDesktopItemController.init();
    }
    // 接受全屏事件
    _subscriptions.add(webviewDesktopItemController
        .webviewController.containsFullScreenElementChanged
        .listen((flag) {
      videoPageController.isFullscreen = flag;
      windowManager.setFullScreen(flag);
    }));
    if (!mounted) return;

    setState(() {});
  }

  Widget get compositeView {
    if (webviewDesktopItemController.webviewController == null) {
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
