import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/web_yi/web_yi_controller.dart';
import 'package:webview_windows/webview_windows.dart';

class WebYiWindowsControllerImpel extends WebYiController<WebviewController> {
  bool bridgeInited = false;
  bool _isInitialized = false; // 添加初始化标志
  Timer? htmlParserTimer;
  bool isHtmlLoaded = false;
  int count = 0;
  String htmlIdentifier = '';

  String htmlItem = ''; // 确保有默认值

  @override
  Future<void> init() async {
    if (!_isInitialized) {
      webviewController = WebviewController();
      await webviewController.initialize();
      _isInitialized = true;
    }
  }

  @override
  Future<String> getCookie(String url) async {
    return await webviewController.getCookies(url) ?? '';
  }

  @override
  Future<String> getHtml(String url, String htmlIdentifier) async {
    htmlIdentifier = htmlIdentifier;
    if (!bridgeInited) {
      await initJSBridge();
    }
    bridgeInited = true;
    isHtmlLoaded = false;
    count = 0;
    final completer = Completer<String>(); // 创建异步完成器

    htmlParserTimer?.cancel();
    await loadUrl(url);
    htmlParserTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      print(htmlItem);
      if (isHtmlLoaded) {
        timer.cancel();
        completer.complete(htmlItem); // 完成异步任务
      } else {
        count++;

        if (count >= 20) {
          timer.cancel();
          completer.completeError('Timeout loading HTML'); // 超时处理
        } else {
          parseHtml();
        }
      }
    });
    return completer.future; // 返回 Future，等待结果
  }

  @override
  Future<void> loadUrl(String url) async {
    await unloadPage();
    await webviewController.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    await webviewController.loadUrl(url);
  }


  @override
  Future<void> unloadPage() async {
    await redirect2Blank();
    await webviewController!.clearCache();
  }

  Future<void> initJSBridge() async {
    webviewController.webMessage.listen((event) async {
      final message = event.toString();
      if (message.startsWith('ParsedHtml:')) {
        htmlItem = message.replaceFirst('ParsedHtml:', '');
        if (htmlItem.contains(htmlIdentifier)) {
          isHtmlLoaded = true; // 标记完成
        }
      }
    });
  }

  Future<void> parseHtml() async {
    await webviewController.executeScript('''
       window.chrome.webview.postMessage("ParsedHtml:" + document.documentElement.outerHTML)
  ''');
  }

  Future<void> redirect2Blank() async {
    await webviewController.executeScript('''
      window.location.href = 'about:blank';
    ''');
  }



// @override
// void dispose() {
//   webviewController.dispose();
//   _isInitialized = false; // 重置状态
//   super.dispose();
// }
}
