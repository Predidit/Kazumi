import 'dart:async';

import 'package:kazumi/services/plugin/plugin_cookie_manager.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/webview/captcha/captcha_webview_controller.dart';

/// 验证码验证服务
///
/// 支持三种独立的验证流程：
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
///   4. 按钮消失或页面跳转时，获取页面 Cookie 并保存到 [PluginCookieManager]
///   5. 通过 [onVerified] 回调通知 UI 发起重新检索
///
/// **类型3：自定义 JS 验证**（[loadForCustomScript]）
///   1. 初始化 WebView
///   2. 加载搜索页面，注入规则中配置的 JS 验证脚本
///   3. 脚本调用 KazumiCaptcha.clicked/done 或返回 true 后完成验证
///   4. 获取页面 Cookie 并保存到 [PluginCookieManager]
class CaptchaVerificationService {
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
    KazumiLogger().i('[CaptchaVerificationService] WebView initialized');
  }

  /// 加载指定页面并开始监听验证码图片
  ///
  /// [url] 要加载的页面地址
  /// [captchaXpath] 验证码图片元素的 XPath
  /// [inputXpath] 可选，验证码输入框的 XPath。如果提供，会在检测验证码前先触发输入框的 focus 事件
  Future<void> loadForCaptcha(String url, String captchaXpath,
      {String? inputXpath}) async {
    _pageUrl = url;
    await _ensureInitialized();
    if (_disposed || _controller == null) return;

    _imageFoundSub?.cancel();
    _imageFoundSub = _controller!.onCaptchaImageFound.listen((src) {
      KazumiLogger()
          .i('[CaptchaVerificationService] Captcha image found: $src');
      if (!_captchaImageStreamController.isClosed) {
        _captchaImageStreamController.add(src);
      }
    });

    await _controller!.loadPage(url, captchaXpath, inputXpath: inputXpath);
    KazumiLogger().i('[CaptchaVerificationService] Page loading: $url');
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
      KazumiLogger()
          .w('[CaptchaVerificationService] submitCaptcha called before init');
      return;
    }

    KazumiLogger()
        .i('[CaptchaVerificationService] Submitting captcha code via interact');

    bool handled = false;

    Future<void> onDisappeared() async {
      if (handled) return;
      handled = true;
      _disappearedSub?.cancel();
      final controller = _controller;
      if (controller == null) return;
      await _saveCookiesAndUnload(controller, pluginName);
      onVerified();
    }

    _disappearedSub?.cancel();
    _disappearedSub = _controller!.onCaptchaDisappeared.listen((_) {
      onDisappeared();
    });
    await _controller!
        .submitCaptchaInteract(captchaCode, inputXpath, buttonXpath);
  }

  /// 加载页面并自动点击验证按钮
  ///
  /// [url] 要加载的页面地址
  /// [buttonXpath] 验证按钮元素的 XPath，检测到后自动点击
  /// [pluginName] 规则名（用于保存 Cookie）
  /// [onVerified] 验证通过后的回调
  Future<void> loadForButtonClick({
    required String url,
    required String buttonXpath,
    required String pluginName,
    required void Function() onVerified,
  }) async {
    _pageUrl = url;
    await _ensureInitialized();
    if (_disposed || _controller == null) return;

    bool handled = false;

    Future<void> onDisappeared() async {
      if (handled) return;
      handled = true;
      _disappearedSub?.cancel();
      final controller = _controller;
      if (controller == null) return;
      await _saveCookiesAndUnload(controller, pluginName,
          logPrefix: '(type2) ');
      onVerified();
    }

    _disappearedSub?.cancel();
    _disappearedSub = _controller!.onCaptchaDisappeared.listen((_) {
      onDisappeared();
    });

    await _controller!.loadPageForButtonClick(url, buttonXpath);
    KazumiLogger().i(
        '[CaptchaVerificationService] (type2) Page loading for button click: $url');
  }

  Future<void> loadForCustomScript({
    required String url,
    required String script,
    required String pluginName,
    required void Function() onVerified,
  }) async {
    _pageUrl = url;
    await _ensureInitialized();
    if (_disposed || _controller == null) return;

    bool handled = false;

    Future<void> onDisappeared() async {
      if (handled) return;
      handled = true;
      _disappearedSub?.cancel();
      final controller = _controller;
      if (controller == null) return;
      await _saveCookiesAndUnload(controller, pluginName,
          logPrefix: '(type3) ');
      onVerified();
    }

    _disappearedSub?.cancel();
    _disappearedSub = _controller!.onCaptchaDisappeared.listen((_) {
      onDisappeared();
    });

    await _controller!.loadPageForCustomScript(url, script);
    KazumiLogger().i(
        '[CaptchaVerificationService] (type3) Page loading for custom script: $url');
  }

  Future<void> saveAndUnload(String pluginName) async {
    _disappearedSub?.cancel();
    _disappearedSub = null;
    // Capture locally before any await so dispose() nulling _controller
    // between two awaits cannot cause a force-unwrap crash.
    final controller = _controller;
    if (controller == null || _pageUrl.isEmpty) return;
    await _saveCookiesAndUnload(
      controller,
      pluginName,
      logPrefix: 'on cancel ',
    );
  }

  Future<void> _saveCookiesAndUnload(
    CaptchaWebviewController controller,
    String pluginName, {
    String logPrefix = '',
  }) async {
    final cookieString = await controller.getCookieString(_pageUrl);
    KazumiLogger().i(
        '[CaptchaVerificationService] ${logPrefix}Captured cookies: $cookieString');
    if (cookieString.isNotEmpty) {
      await PluginCookieManager.instance
          .saveFromWebView(pluginName, _pageUrl, cookieString);
      KazumiLogger().i(
          '[CaptchaVerificationService] ${logPrefix}Cookies saved for plugin: $pluginName');
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
    KazumiLogger().i('[CaptchaVerificationService] Disposed');
  }
}
