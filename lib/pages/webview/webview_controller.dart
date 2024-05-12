import 'package:webview_flutter/webview_flutter.dart';

class WebviewItemController {
  WebViewController webviewController = WebViewController();

  loadUrl(String url) async {
    await webviewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await webviewController.loadRequest(Uri.parse(url));
  }

  Future<String> parseVideoUrl() async {
    String htmlString = '';
    await webviewController.runJavaScriptReturningResult('''
          function getAllIframesContent() {
            var fullHtml = document.documentElement.outerHTML;
            var iframes = document.getElementsByTagName('iframe');
            for (var i = 0; i < iframes.length; i++) {
              try {
                var iframeContent = iframes[i].contentDocument.documentElement.outerHTML;
                fullHtml += iframeContent;
              } catch (e) {
                console.error('无法获取某个 iframe 的内容，可能是由于跨域限制。', e);
                return '无法获取某个 iframe 的内容，可能是由于跨域限制。';
              }
            }
  
             return fullHtml;
            }
          var completeHtml = getAllIframesContent();
          console.log(completeHtml);
          return completeHtml;
        ''').then((html) {
          htmlString = html.toString();
        });
    return htmlString;
  }
}
