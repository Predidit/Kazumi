import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewItemController {
  bool isIframeLoaded = false;
  WebViewController webviewController = WebViewController();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();

  loadUrl(String url) async {
    await unloadPage();
    await webviewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await webviewController.addJavaScriptChannel('JSBridgeDebug',
        onMessageReceived: (JavaScriptMessage message) {
      debugPrint('由JS桥收到的消息为 ${message.message}');
      if (message.message.startsWith('https://')) {
        debugPrint('开始加载 iframe');
        loadIframe(message.message);
        isIframeLoaded = true;
      }
    });
    await webviewController.loadRequest(Uri.parse(url));

    Timer.periodic(Duration(seconds: 1), (timer) {
      if (isIframeLoaded) {
        timer.cancel();
      } else {
        parseIframeUrl();
      }
    });
  }

  unloadPage() async {
    await webviewController.removeJavaScriptChannel('JSBridgeDebug').catchError((_) {});
    await webviewController.loadRequest(Uri.parse('about:blank'));
    await webviewController.clearCache();
    isIframeLoaded = false;
  }

  loadIframe(String url) async {
    await webviewController.loadRequest(Uri.parse(url),
        headers: {'Referer': videoPageController.currentPlugin.baseUrl + '/'});
  }

  parseIframeUrl() async {
    await webviewController.runJavaScript('''
      JSBridgeDebug.postMessage('开始检索iframe标签');
      var iframes = document.getElementsByTagName('iframe');
      JSBridgeDebug.postMessage('iframe 标签数量为');
      JSBridgeDebug.postMessage(iframes.length);
      for (var i = 0; i < iframes.length; i++) {
          var iframe = iframes[i];
          var src = iframe.getAttribute('src');

          if (src && src.trim() !== '' && src.trim().startsWith('https://')) {
              JSBridgeDebug.postMessage(src);
              break; 
          }
      }
  ''');
  }
}
