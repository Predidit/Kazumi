import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewItemController {
  WebViewController webviewController = WebViewController();

  loadUrl(String url) async {
    await webviewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await webviewController.loadRequest(Uri.parse(url));
    await webviewController.addJavaScriptChannel('JSBridgeDebug',
        onMessageReceived: (JavaScriptMessage message) {
      debugPrint('由JS桥收到的消息为 ${message.message}');
    });
    debugPrint('JS桥初始化完成');
  }

  // Future<String> parseVideoUrl() async {
  //   String htmlString = '';
  //   await webviewController.runJavaScriptReturningResult('''
  //         function getAllIframesContent() {
  //           return '123456';
  //           var fullHtml = document.documentElement.outerHTML;
  //           var iframes = document.getElementsByTagName('iframe');
  //           for (var i = 0; i < iframes.length; i++) {
  //             try {
  //               var iframeContent = iframes[i].contentDocument.documentElement.outerHTML;
  //               fullHtml += iframeContent;
  //             } catch (e) {
  //               console.error('无法获取某个 iframe 的内容，可能是由于跨域限制。', e);
  //               return '无法获取某个 iframe 的内容，可能是由于跨域限制。';
  //             }
  //           }

  //            return fullHtml;
  //           }
  //         var completeHtml = getAllIframesContent();
  //         console.log(completeHtml);
  //         return completeHtml;
  //       ''').then((html) {
  //         htmlString = html.toString();
  //         return htmlString;
  //       });
  //   return '';
  // }

  parseVideoUrl() async {
    await webviewController.runJavaScript('''
      function getAllIframesContent() {
        var fullHtml = document.documentElement.outerHTML;
        var iframes = document.getElementsByTagName('iframe');
        for (var i = 0; i < iframes.length; i++) {
          try {
            var iframeContent = iframes[i].contentDocument.documentElement.outerHTML;
            fullHtml += iframeContent;
          } catch (e) {
            console.error('无法获取某个 iframe 的内容，可能是由于跨域限制。', e);
          }
        }

          return fullHtml;
        }
      var completeHtml = getAllIframesContent();
      JSBridgeDebug.postMessage(completeHtml);
  ''');
  }
}
