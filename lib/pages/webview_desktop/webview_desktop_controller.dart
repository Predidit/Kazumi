import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:webview_windows/webview_windows.dart';

class WebviewDesktopItemController {
  bool isIframeLoaded = false;
  WebviewController webviewController = WebviewController();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();

  loadUrl(String url) async {
    await unloadPage();
    await webviewController.loadUrl(url);

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isIframeLoaded) {
        timer.cancel();
      } else {
        parseIframeUrl();
      }
    });
  }

  initJSBridge() async {
    webviewController.webMessage.listen((event) async {
      debugPrint('由JS桥收到的消息为 ${event.toString()}');
      if (event.toString().startsWith('https://')) {
        debugPrint('开始加载 iframe');
        isIframeLoaded = true;
      }
    });
  }

  unloadPage() async {
    await webviewController.loadUrl('about:blank');
    await webviewController.clearCache();
    isIframeLoaded = false;
  }

  parseIframeUrl() async {
    await webviewController.executeScript('''
      var iframes = document.getElementsByTagName('iframe');
      for (var i = 0; i < iframes.length; i++) {
          var iframe = iframes[i];
          var src = iframe.getAttribute('src');

          if (src && src.trim() !== '' && src.trim().startsWith('https://')) {
              window.chrome.webview.postMessage(src);
              window.location.href = src;
              break; 
          }
      }
  ''');
  }
}
