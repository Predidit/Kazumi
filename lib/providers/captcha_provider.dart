import 'dart:async';

import 'package:kazumi/webview/captcha_webview_controller.dart';
import 'package:kazumi/plugins/plugin_cookie_manager.dart';
import 'package:kazumi/utils/logger.dart';

/// 验证码解决 Provider
///
/// 独立的验证码解决流程：
///   1. 初始化 WebView
///   2. 加载搜索页面，注入 JS 脚本监听验证码图片
///   3. 通过 [onCaptchaImageUrl] 流将验证码图片 URL 暴露给 UI
///   4. UI 将用户输入的验证码传给 [submitCaptcha]
///   5. 页面通过 AJAX 提交验证码
///   6. 验证码图片消失 + 1 秒后，获取页面 Cookie 并保存到 [PluginCookieManager]
///   7. UI 发起重新检索
class CaptchaProvider {
  CaptchaWebviewController? _controller;

  final StreamController<String?> _captchaImageStreamController =
      StreamController<String?>.broadcast();

  Stream<String?> get onCaptchaImageUrl => _captchaImageStreamController.stream;

  StreamSubscription? _imageFoundSub;
  StreamSubscription? _disappearedSub;

  bool _isInitialized = false;
  String _pageUrl = '';

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    _controller = CaptchaWebviewControllerFactory.getController();
    final initializedFuture = _controller!.onInitialized.first
        .timeout(const Duration(seconds: 10), onTimeout: () => false);

    await _controller!.init();
    await initializedFuture;

    _isInitialized = true;
    KazumiLogger().i('[CaptchaProvider] WebView initialized');
  }

  /// 加载指定页面并开始监听验证码图片
  ///
  /// [url] 要加载的页面地址（通常为搜索 URL）
  /// [captchaXpath] 验证码图片元素的 XPath
  Future<void> loadForCaptcha(String url, String captchaXpath) async {
    await _ensureInitialized();
    _pageUrl = url;

    _imageFoundSub?.cancel();
    _imageFoundSub = _controller!.onCaptchaImageFound.listen((src) {
      KazumiLogger().i('[CaptchaProvider] Captcha image found: $src');
      if (!_captchaImageStreamController.isClosed) {
        _captchaImageStreamController.add(src);
      }
    });

    await _controller!.loadPage(url, captchaXpath);
    KazumiLogger().i('[CaptchaProvider] Page loading: $url');
  }

  /// 提交验证码
  ///
  /// [captchaCode] 用户输入的验证码文本
  /// [inputXpath]  验证码输入框元素的 XPath
  /// [buttonXpath] 验证提交按钮元素的 XPath
  /// [pluginName] 规则名（用于保存 Cookie）
  /// [onVerified] 验证成功后的回调
  Future<void> submitCaptcha({
    required String captchaCode,
    required String inputXpath,
    required String buttonXpath,
    required String pluginName,
    required void Function() onVerified,
  }) async {
    if (_controller == null) {
      KazumiLogger().w('[CaptchaProvider] submitCaptcha called before init');
      return;
    }

    KazumiLogger().i('[CaptchaProvider] Submitting captcha code via interact');

    bool _handled = false;

    Future<void> onDisappeared() async {
      if (_handled) return;
      _handled = true;
      _disappearedSub?.cancel();
      KazumiLogger().i('[CaptchaProvider] Captcha disappeared, waiting 1s...');
      await Future.delayed(const Duration(seconds: 1));
      final cookieString = await _controller!.getCookieString(_pageUrl);
      KazumiLogger().i('[CaptchaProvider] Captured cookies: $cookieString');
      if (cookieString.isNotEmpty) {
        await PluginCookieManager.instance
            .saveFromWebView(pluginName, _pageUrl, cookieString);
        KazumiLogger()
            .i('[CaptchaProvider] Cookies saved for plugin: $pluginName');
      }
      await _controller!.unloadPage();
      onVerified();
    }
    _disappearedSub?.cancel();
    _disappearedSub = _controller!.onCaptchaDisappeared.listen((_) {
      onDisappeared();
    });
    await _controller!.submitCaptchaInteract(captchaCode, inputXpath, buttonXpath);
  }

  Stream<String>? get onLog => _controller?.onLog;

  void dispose() {
    _imageFoundSub?.cancel();
    _disappearedSub?.cancel();
    if (!_captchaImageStreamController.isClosed) {
      _captchaImageStreamController.close();
    }
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    KazumiLogger().i('[CaptchaProvider] Disposed');
  }
}
