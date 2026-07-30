import 'dart:async';

import 'package:kazumi/services/plugin/plugin_cookie_manager.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/async_single_flight.dart';
import 'package:kazumi/webview/captcha/captcha_webview_controller.dart';

/// 验证码验证服务
///
/// 三种验证流程各自加载搜索页并等待验证通过：
///
/// - **类型1：图片验证码**（[loadForCaptcha] + [submitCaptcha]）
///   监听验证码图片并经 [onCaptchaImageUrl] 交给 UI，UI 回传用户输入后
///   在页面内填写并提交，验证码图片消失即视为通过。
/// - **类型2：自动点击验证按钮**（[loadForButtonClick]）
///   检测到按钮后自动点击，按钮消失或页面跳转即视为通过。
/// - **类型3：自定义 JavaScript 验证**（[loadForCustomScript]）
///   注入规则提供的脚本，脚本调用 KazumiCaptcha.done 或返回 true 即通过。
///
/// 验证通过后统一收尾：收割验证后页面的 HTML，保存 Cookie 与 User-Agent 到
/// [PluginCookieManager]，再将 HTML 交给 onVerified。UI 能解析该 HTML 时直接
/// 展示结果，否则回落到重新检索。
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

  /// 共享收尾任务。收割页面需要数秒，期间用户仍可取消，两条路径便会同时
  /// 对同一个 WebView 卸载页面和读取内容。汇合到同一次收尾以避免并发访问，
  /// 也使 [cancelAndSave] 的 await 覆盖住调用方随后的 dispose。
  final AsyncSingleFlight<String> _finalize = AsyncSingleFlight<String>();

  bool _outcomeClaimed = false;

  /// 认领向 UI 提交结果的权利。
  ///
  /// 收尾任务的归属与结果的归属可以不同：成功路径先启动收尾，用户随后取消，
  /// 此时应由取消提交结果。故在共享收尾之外单独仲裁——取消在 [cancelAndSave]
  /// 入口同步认领，成功路径在收尾结束后认领，后到者放弃提交。
  bool _claimOutcome() {
    if (_outcomeClaimed) return false;
    _outcomeClaimed = true;
    return true;
  }

  /// 订阅验证通过事件：收尾后把收割到的 HTML 交给 [onVerified]。
  ///
  /// [onFinalizing] 在观察到验证通过、开始收尾之前触发。收尾需要数秒，
  /// 调用方若对验证设有超时，必须以此为准而非 [onVerified]，
  /// 否则超时会在收尾途中把已经成功的验证判成失败。
  void _listenForVerification(
    String pluginName,
    void Function(String pageHtml) onVerified, {
    String logPrefix = '',
    void Function()? onFinalizing,
  }) {
    final controller = _controller;
    if (controller == null) return;

    Future<void> onDisappeared() async {
      _disappearedSub?.cancel();
      // 重新读取：订阅到事件之间可能已被 dispose 置空。
      final current = _controller;
      if (current == null) return;
      onFinalizing?.call();
      final pageHtml = await _finalize.run(() =>
          _saveCookiesAndUnload(current, pluginName, logPrefix: logPrefix));
      if (_disposed || !_claimOutcome()) return;
      onVerified(pageHtml);
    }

    _disappearedSub?.cancel();
    _disappearedSub = controller.onCaptchaDisappeared.listen((_) {
      onDisappeared();
    });
  }

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

  /// 在页面中填写 [captchaCode] 并点击 [buttonXpath] 提交
  ///
  /// [onFinalizing] 在验证通过、开始收尾时触发，早于 [onVerified] 数秒。
  Future<void> submitCaptcha({
    required String captchaCode,
    required String inputXpath,
    required String buttonXpath,
    required String pluginName,
    required void Function(String pageHtml) onVerified,
    void Function()? onFinalizing,
  }) async {
    if (_controller == null) {
      KazumiLogger()
          .w('[CaptchaVerificationService] submitCaptcha called before init');
      return;
    }

    KazumiLogger()
        .i('[CaptchaVerificationService] Submitting captcha code via interact');

    _listenForVerification(pluginName, onVerified, onFinalizing: onFinalizing);
    await _controller!
        .submitCaptchaInteract(captchaCode, inputXpath, buttonXpath);
  }

  /// 加载 [url] 并在检测到 [buttonXpath] 后自动点击
  Future<void> loadForButtonClick({
    required String url,
    required String buttonXpath,
    required String pluginName,
    required void Function(String pageHtml) onVerified,
  }) async {
    _pageUrl = url;
    await _ensureInitialized();
    if (_disposed || _controller == null) return;

    _listenForVerification(pluginName, onVerified, logPrefix: '(type2) ');
    await _controller!.loadPageForButtonClick(url, buttonXpath);
    KazumiLogger().i(
        '[CaptchaVerificationService] (type2) Page loading for button click: $url');
  }

  /// 加载 [url] 并注入规则提供的验证脚本 [script]
  Future<void> loadForCustomScript({
    required String url,
    required String script,
    required String pluginName,
    required void Function(String pageHtml) onVerified,
  }) async {
    _pageUrl = url;
    await _ensureInitialized();
    if (_disposed || _controller == null) return;

    _listenForVerification(pluginName, onVerified, logPrefix: '(type3) ');
    await _controller!.loadPageForCustomScript(url, script);
    KazumiLogger().i(
        '[CaptchaVerificationService] (type3) Page loading for custom script: $url');
  }

  /// 用户取消验证：认领结果提交权并保存已有 Cookie。
  ///
  /// 认领必须发生在任何 await 之前，这样即使验证恰好在此刻通过，
  /// 其 onVerified 也不会再提交结果，由调用方按取消语义收尾。
  Future<void> cancelAndSave(String pluginName) async {
    _claimOutcome();
    _disappearedSub?.cancel();
    _disappearedSub = null;
    // 先取到本地：dispose 可能在两次 await 之间把 _controller 置空。
    final controller = _controller;
    if (controller == null || _pageUrl.isEmpty) return;
    // 若验证成功路径已在收尾，这里会汇合到那一次并等它把 Cookie 存完。
    await _finalize.run(() => _saveCookiesAndUnload(
          controller,
          pluginName,
          logPrefix: 'on cancel ',
          harvestHtml: false,
        ));
  }

  /// 保存 Cookie 与 User-Agent 并卸载页面。
  ///
  /// [harvestHtml] 为 true 时先收割验证后页面的 HTML 并返回，
  /// 供上层直接解析检索结果；取消路径不收割。
  ///
  /// 按契约不抛异常：成功与取消两条路径共享这一个 Future，任何异常都会同时
  /// 打断两边——成功路径的 onVerified 不再触发，取消路径 onDismiss 里的
  /// dispose 与回落检索也会被跳过。故内部兜住异常，尽力返回已取到的内容。
  Future<String> _saveCookiesAndUnload(
    CaptchaWebviewController controller,
    String pluginName, {
    String logPrefix = '',
    bool harvestHtml = true,
  }) async {
    String pageHtml = '';
    try {
      // 先收割：等待结果页稳定的同时，也让 JS 写入的 Cookie 落地后再读取。
      if (harvestHtml) {
        pageHtml = await _waitForPageHtml(controller);
        KazumiLogger().i(
            '[CaptchaVerificationService] ${logPrefix}Harvested page html length: ${pageHtml.length}');
      }
      final cookieString = await controller.getCookieString(_pageUrl);
      final userAgent = await controller.getUserAgent();
      KazumiLogger().i(
          '[CaptchaVerificationService] ${logPrefix}Captured cookies: $cookieString');
      if (cookieString.isNotEmpty) {
        await PluginCookieManager.instance.saveFromWebView(
            pluginName, _pageUrl, cookieString,
            userAgent: userAgent);
        KazumiLogger().i(
            '[CaptchaVerificationService] ${logPrefix}Cookies saved for plugin: $pluginName');
      }
      await controller.unloadPage();
    } catch (error, stackTrace) {
      KazumiLogger().w(
        '[CaptchaVerificationService] ${logPrefix}Finalize failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return pageHtml;
  }

  /// 等待验证后的页面加载完成并返回其 HTML。
  /// 验证消失事件可能早于结果页加载完成，因此短暂轮询；
  /// 超时返回空字符串，由上层回落到重新检索。
  Future<String> _waitForPageHtml(CaptchaWebviewController controller) async {
    const maxAttempts = 10;
    const interval = Duration(milliseconds: 300);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (_disposed) return '';
      final html = await controller.getPageHtml();
      if (html.trim().isNotEmpty) return html;
      await Future.delayed(interval);
    }
    return '';
  }

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
