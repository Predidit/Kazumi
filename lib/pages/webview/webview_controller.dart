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
    await webviewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await webviewController.loadRequest(Uri.parse(url));
    await webviewController.addJavaScriptChannel('JSBridgeDebug',
        onMessageReceived: (JavaScriptMessage message) {
      debugPrint('由JS桥收到的消息为 ${message.message}');
      if (message.message.startsWith('https://')) {
        debugPrint('开始加载 iframe');
        loadIframe(message.message);
        isIframeLoaded = true;
      }
    });

    Timer.periodic(Duration(seconds: 1), (timer) {
      if (isIframeLoaded) {
        timer.cancel();
      } else {
        parseIframeUrl();
      }
    });
  }

  loadIframe(String url) async {
    await webviewController.loadRequest(Uri.parse(url),
        headers: {'Referer': videoPageController.currentPlugin.baseUrl + '/'});
  }

//  parseIframeUrl() async {
//     await webviewController.runJavaScript('''
//       function getAllIframesContent() {
//         var fullHtml = document.documentElement.outerHTML;
//         var iframes = document.getElementsByTagName('iframe');
//         for (var i = 0; i < iframes.length; i++) {
//           try {
//             var iframeContent = iframes[i].contentDocument.documentElement.outerHTML;
//             fullHtml += iframeContent;
//           } catch (e) {
//             console.error('无法获取某个 iframe 的内容，可能是由于跨域限制。', e);
//           }
//         }

//           return fullHtml;
//         }
//       var completeHtml = getAllIframesContent();
//       JSBridgeDebug.postMessage(completeHtml);
//   ''');
//   }

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
