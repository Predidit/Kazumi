import 'dart:async';

import 'package:kazumi/webview/captcha/captcha_webview_controller.dart';
import 'package:kazumi/plugins/plugin_cookie_manager.dart';
import 'package:kazumi/utils/logger.dart';

/// 验证码解决 Provider
///
/// 支持两种独立的验证流程：
///
/// **类型1：图片验证码**（[loadForCaptcha] + [submitCaptcha]）
///   1. 初始化 WebView
///   2. 加载搜索页面，注入 JS 脚本监听验证码图片
///   3. 通过 [onCaptchaImageUrl] 流将验证码图片 URL 暴露给 UI
///   4. UI 将用户输入的验证码传给 [submitCaptcha]
///   5. 页面通过 AJAX 提交验证码
///   6. 验证码图片消失后，获取页面 Cookie 并保存到 [PluginCookieManager]
///   7. UI 发起重新检索
///
/// **类型2：自动点击验证按钮**（[loadForButtonClick]）
///   1. 初始化 WebView
///   2. 加载搜索页面，注入 JS 脚本轮询验证按钮
///   3. 检测到按钮后自动模拟点击
///   4. 按钮消失时，获取页面 Cookie 并保存到 [PluginCookieManager]
///   5. 通过 [onVerified] 回调通知 UI 发起重新检索
class CaptchaProvider {
  CaptchaWebviewController? _controller;

  final StreamController<String?> _captchaImageStreamController =
      StreamController<String?>.broadcast();

  Stream<String?> get onCaptchaImageUrl => _captchaImageStreamController.stream;

  StreamSubscription? _imageFoundSub;
  StreamSubscription? _disappearedSub;
  StreamSubscription? _logSub;

  bool _isInitialized = false;
  bool _disposed = false;
  String _pageUrl = '';

  Future<void> _ensureInitialized() async {
    if (_isInitialized || _disposed) return;
    _controller = CaptchaWebviewControllerFactory.getController();
    final initializedFuture = _controller!.onInitialized.first
        .timeout(const Duration(seconds: 10), onTimeout: () => false);

    await _controller!.init();
    if (_disposed) return;
    await initializedFuture;
    if (_disposed) return;

    _logSub?.cancel();
    _logSub = _controller!.onLog.listen((msg) => KazumiLogger().d(msg));

    _isInitialized = true;
    KazumiLogger().i('[CaptchaProvider] WebView initialized');
  }

  /// 加载指定页面并开始监听验证码图片
  ///
  /// [url] 要加载的页面地址
  /// [captchaXpath] 验证码图片元素的 XPath
  /// [inputXpath] 可选，验证码输入框的 XPath。如果提供，会在检测验证码前先触发输入框的 focus 事件
  Future<void> loadForCaptcha(String url, String captchaXpath, {String? inputXpath}) async {
    _pageUrl = url;
    await _ensureInitialized();
    if (_disposed || _controller == null) return;

    _imageFoundSub?.cancel();
    _imageFoundSub = _controller!.onCaptchaImageFound.listen((src) {
      KazumiLogger().i('[CaptchaProvider] Captcha image found: $src');
      if (!_captchaImageStreamController.isClosed) {
        _captchaImageStreamController.add(src);
      }
    });

    await _controller!.loadPage(url, captchaXpath, inputXpath: inputXpath);
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

  /// 加载页面并自动点击验证按钮
  ///
  /// [url] 要加载的页面地址
  /// [buttonXpath] 验证按钮元素的 XPath，检测到后自动点击
  /// [pluginName] 规则名（用于保存 Cookie）
  /// [onVerified] 按钮消失（验证通过）后的回调
  Future<void> loadForButtonClick({
    required String url,
    required String buttonXpath,
    required String pluginName,
    required void Function() onVerified,
  }) async {
    _pageUrl = url;
    await _ensureInitialized();
    if (_disposed || _controller == null) return;

    bool _handled = false;

    Future<void> onDisappeared() async {
      if (_handled) return;
      _handled = true;
      _disappearedSub?.cancel();
      final cookieString = await _controller!.getCookieString(_pageUrl);
      KazumiLogger().i('[CaptchaProvider] (type2) Captured cookies: $cookieString');
      if (cookieString.isNotEmpty) {
        await PluginCookieManager.instance
            .saveFromWebView(pluginName, _pageUrl, cookieString);
        KazumiLogger()
            .i('[CaptchaProvider] (type2) Cookies saved for plugin: $pluginName');
      }
      await _controller!.unloadPage();
      onVerified();
    }

    _disappearedSub?.cancel();
    _disappearedSub = _controller!.onCaptchaDisappeared.listen((_) {
      onDisappeared();
    });

    await _controller!.loadPageForButtonClick(url, buttonXpath);
    KazumiLogger().i('[CaptchaProvider] (type2) Page loading for button click: $url');
  }

  Future<void> saveAndUnload(String pluginName) async {
    _disappearedSub?.cancel();
    _disappearedSub = null;
    // Capture locally before any await so dispose() nulling _controller
    // between two awaits cannot cause a force-unwrap crash.
    final controller = _controller;
    if (controller == null || _pageUrl.isEmpty) return;
    final cookieString = await controller.getCookieString(_pageUrl);
    KazumiLogger()
        .i('[CaptchaProvider] Captured cookies on cancel: $cookieString');
    if (cookieString.isNotEmpty) {
      await PluginCookieManager.instance
          .saveFromWebView(pluginName, _pageUrl, cookieString);
      KazumiLogger()
          .i('[CaptchaProvider] Cookies saved on cancel for plugin: $pluginName');
    }
    await controller.unloadPage();
  }

  Stream<String>? get onLog => _controller?.onLog;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _imageFoundSub?.cancel();
    _disappearedSub?.cancel();
    _logSub?.cancel();
    if (!_captchaImageStreamController.isClosed) {
      _captchaImageStreamController.close();
    }
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    KazumiLogger().i('[CaptchaProvider] Disposed');
  }
}
