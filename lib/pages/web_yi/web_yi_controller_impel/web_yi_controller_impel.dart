import 'dart:async';
import 'package:kazumi/pages/web_yi/web_yi_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebYiControllerImpel extends WebYiController<WebViewController> {
  Timer? htmlParserTimer;
  bool isHtmlLoaded = false;
  int count = 0;
  bool bridgeInited = false;
  bool _isInitialized = false;
  String htmlIdentifier = '';

  late String htmlItem;
  Completer<String>? _htmlCompleter;

  @override
  Future<void> init() async {
    if (!_isInitialized) {
      webviewController = WebViewController();
      _isInitialized = true;
    }
  }

  @override
  Future<String> getCookie(String url) async {
    // webview_flutter 没有直接获取cookie的API
    return '';
  }

  @override
  Future<String> getHtml(String url, String htmlIdentifier) async {
    // 重置状态
    htmlIdentifier = htmlIdentifier;
    isHtmlLoaded = false;
    count = 0;
    _htmlCompleter = Completer<String>();

    // 初始化WebView设置
    await webviewController.setJavaScriptMode(JavaScriptMode.unrestricted);

    // 添加消息通道
    await webviewController.addJavaScriptChannel(
      'HtmlBridge',
      onMessageReceived: (JavaScriptMessage message) {
        if (message.message.startsWith('ParsedHtml:')) {
          htmlItem = message.message.replaceFirst('ParsedHtml:', '');
          if (htmlItem.contains(htmlIdentifier)) {
            isHtmlLoaded = true;
            _htmlCompleter?.complete(htmlItem);
          }
        }
      },
    );

    // 启动轮询
    _startHtmlPolling();

    // 加载URL
    await loadUrl(url);

    // 等待HTML结果
    return await _htmlCompleter!.future;
  }

  @override
  Future<void> loadUrl(String url) async {
    await webviewController.loadRequest(Uri.parse(url));
  }

  void _startHtmlPolling() {
    htmlParserTimer?.cancel();

    htmlParserTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isHtmlLoaded) {
        timer.cancel();
      } else {
        count++;
        parseHtml();

        // 超时处理
        if (count >= 15) {
          timer.cancel();
          _htmlCompleter?.completeError('获取HTML超时');
        }
      }
    });

    // 立即执行第一次解析
    parseHtml();
  }

  @override
  Future<void> unloadPage() async {
    await webviewController
        .removeJavaScriptChannel('HtmlBridge')
        .catchError((_) {});
    await webviewController.loadRequest(Uri.parse('about:blank'));
    await webviewController.clearCache();
    htmlParserTimer?.cancel();
  }


  Future<void> parseHtml() async {
    try {
      await webviewController.runJavaScript('''
        try {
          const htmlContent = document.documentElement.outerHTML;
          
          // 检查HTML是否有效
          if (htmlContent && htmlContent.includes('<html') && 
              htmlContent.includes('<body') && htmlContent.length > 100) {
            HtmlBridge.postMessage('ParsedHtml:' + htmlContent);
          } else {
            console.log('HTML不完整，等待重试...');
          }
        } catch (error) {
          console.error('解析HTML失败:', error);
        }
      ''');
    } catch (e) {
      print('执行解析脚本失败: $e');
    }
  }

// @override
// void dispose() {
//   htmlParserTimer?.cancel();
//   webviewController = null;
//   _isInitialized = false;
//   super.dispose();
// }
}
