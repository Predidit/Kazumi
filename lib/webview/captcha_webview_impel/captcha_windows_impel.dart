import 'dart:async';

import 'package:webview_windows/webview_windows.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/proxy_utils.dart';
import 'package:kazumi/webview/captcha_webview_controller.dart';

/// 基于 webview_windows 的验证码 WebView 实现（Windows）
class CaptchaWindowsImpel extends CaptchaWebviewController {
  HeadlessWebview? _headlessWebview;
  final List<StreamSubscription> _subscriptions = [];
  String _currentXpath = '';
  String _currentPageUrl = '';
  /// 是否已检测到验证码图片，用于在页面跳转后判断验证是否通过
  bool _captchaWasFound = false;

  @override
  Future<void> init() async {
    await _setupProxy();
    _headlessWebview ??= HeadlessWebview();
    await _headlessWebview!.run();
    await _headlessWebview!.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

    // Listen for messages from JavaScript via window.chrome.webview.postMessage
    _subscriptions.add(
      _headlessWebview!.webMessage.listen(_onWebMessage),
    );

    // Inject captcha script when navigation completes
    _subscriptions.add(
      _headlessWebview!.loadingState.listen((state) async {
        if (state == LoadingState.navigationCompleted) {
          logEventController
              .add('[Captcha WebView] Navigation completed: $_currentPageUrl');
          if (_currentXpath.isNotEmpty) {
            await _injectCaptchaScript();
          }
        }
      }),
    );

    // After a navigation, if we already found a captcha once and it is now
    // absent from DOM, consider the verification successful.
    _subscriptions.add(
      _headlessWebview!.loadingState.listen((state) async {
        if (state == LoadingState.navigationCompleted && _captchaWasFound) {
          final present = await _isCaptchaPresent();
          if (!present && !captchaDisappearedController.isClosed) {
            logEventController
                .add('[Captcha WebView] Captcha gone after navigation');
            _captchaWasFound = false;
            captchaDisappearedController.add(null);
          }
        }
      }),
    );

    initEventController.add(true);
  }

  void _onWebMessage(dynamic message) {
    final msg = message.toString();
    logEventController.add('[Captcha WebView] WM: $msg');
    if (msg.startsWith('captchaImage:')) {
      final src = msg.replaceFirst('captchaImage:', '');
      if (src.isNotEmpty && !captchaImageFoundController.isClosed) {
        _captchaWasFound = true;
        captchaImageFoundController.add(src);
      }
    } else if (msg.startsWith('captchaGone:')) {
      if (!captchaDisappearedController.isClosed) {
        captchaDisappearedController.add(null);
      }
    } else if (msg.startsWith('captchaLog:')) {
      logEventController
          .add('[Captcha WebView JS] ${msg.replaceFirst('captchaLog:', '')}');
    }
  }

  Future<bool> _isCaptchaPresent() async {
    if (_currentXpath.isEmpty || _headlessWebview == null) return false;
    final escaped =
        _currentXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    try {
      final result = await _headlessWebview!.executeScript('''
(function() {
  try {
    var r = document.evaluate('$escaped', document, null,
      XPathResult.FIRST_ORDERED_NODE_TYPE, null);
    return r.singleNodeValue ? 'present' : 'absent';
  } catch(e) { return 'absent'; }
})();
''');
      return result?.toString().contains('present') ?? false;
    } catch (e) {
      KazumiLogger().d('[Captcha WebView] _isCaptchaPresent error: $e');
      return false;
    }
  }

  Future<void> _injectCaptchaScript() async {
    if (_currentXpath.isEmpty) return;
    final escapedXpath =
        _currentXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

    final script = '''
(function() {
  window.chrome.webview.postMessage('captchaLog:CaptchaScript injected on ' + window.location.href);

  var _captchaXpath = '$escapedXpath';
  var _captchaPoller = null;
  var _disappearObserver = null;

  function _resolveSrc(node) {
    return node.getAttribute('src') || node.getAttribute('data-src') ||
           node.src || '';
  }

  function _evalXpath() {
    try {
      var result = document.evaluate(
        _captchaXpath, document, null,
        XPathResult.FIRST_ORDERED_NODE_TYPE, null);
      return result.singleNodeValue;
    } catch(e) { return null; }
  }

  function _startDisappearMonitor() {
    if (_disappearObserver) return;
    _disappearObserver = new MutationObserver(function() {
      if (!_evalXpath()) {
        _disappearObserver.disconnect();
        _disappearObserver = null;
        window.chrome.webview.postMessage('captchaGone:');
      }
    });
    _disappearObserver.observe(document.documentElement,
      { childList: true, subtree: true, attributes: true });
  }

  function _captureAsBase64(imgNode, callback) {
    function doCapture() {
      try {
        var canvas = document.createElement('canvas');
        canvas.width = imgNode.naturalWidth || imgNode.width || 100;
        canvas.height = imgNode.naturalHeight || imgNode.height || 40;
        var ctx = canvas.getContext('2d');
        ctx.drawImage(imgNode, 0, 0);
        callback(canvas.toDataURL('image/png'));
      } catch(e) { callback(null); }
    }
    if (imgNode.complete && imgNode.naturalWidth > 0) {
      doCapture();
    } else {
      imgNode.addEventListener('load', doCapture);
      imgNode.addEventListener('error', function() { callback(null); });
    }
  }

  function _checkForCaptcha() {
    var node = _evalXpath();
    if (node) {
      _captureAsBase64(node, function(dataUrl) {
        if (dataUrl) {
          window.chrome.webview.postMessage('captchaImage:' + dataUrl);
        }
      });
      _startDisappearMonitor();
      return true;
    }
    return false;
  }

  if (!_checkForCaptcha()) {
    _captchaPoller = setInterval(function() {
      if (_checkForCaptcha()) {
        clearInterval(_captchaPoller);
        _captchaPoller = null;
      }
    }, 500);
  }
})();
''';

    try {
      await _headlessWebview?.executeScript(script);
    } catch (e) {
      KazumiLogger().e('[Captcha WebView] inject script error: $e');
    }
  }

  @override
  Future<void> loadPage(String url, String captchaXpath) async {
    _currentXpath = captchaXpath;
    _currentPageUrl = url;
    _captchaWasFound = false;
    await _headlessWebview?.loadUrl(url);
  }

  @override
  Future<void> submitCaptchaInteract(
      String captchaCode, String inputXpath, String buttonXpath) async {
    logEventController
        .add('[Captcha WebView] Filling input and clicking button');
    final escapedCode =
        captchaCode.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    final escapedInput =
        inputXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    final escapedButton =
        buttonXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    final script = '''
(function() {
  function evalXpath(xpath) {
    try {
      var r = document.evaluate(xpath, document, null,
        XPathResult.FIRST_ORDERED_NODE_TYPE, null);
      return r.singleNodeValue;
    } catch(e) { return null; }
  }
  var inputEl = evalXpath('$escapedInput');
  if (inputEl) {
    inputEl.focus();
    var nativeInput = Object.getOwnPropertyDescriptor(
      window.HTMLInputElement.prototype, 'value');
    nativeInput.set.call(inputEl, '$escapedCode');
    inputEl.dispatchEvent(new Event('input', { bubbles: true }));
    inputEl.dispatchEvent(new Event('change', { bubbles: true }));
    window.chrome.webview.postMessage('captchaLog:Input filled');
  } else {
    window.chrome.webview.postMessage('captchaLog:Input element not found');
  }
  var btnEl = evalXpath('$escapedButton');
  if (btnEl) {
    btnEl.click();
    window.chrome.webview.postMessage('captchaLog:Button clicked');
  } else {
    window.chrome.webview.postMessage('captchaLog:Button element not found');
  }
})();
''';
    try {
      await _headlessWebview?.executeScript(script);
    } catch (e) {
      KazumiLogger().e('[Captcha WebView] submitCaptchaInteract error: $e');
    }
  }

  @override
  Future<String> getCookieString(String pageUrl) async {
    try {
      // webview_windows only exposes document.cookie (non-HttpOnly cookies)
      final result = await _headlessWebview?.executeScript('document.cookie');
      return result?.toString().replaceAll('"', '') ?? '';
    } catch (e) {
      KazumiLogger().e('[Captcha WebView] getCookieString error: $e');
      return '';
    }
  }

  @override
  Future<void> unloadPage() async {
    try {
      await _headlessWebview?.executeScript(
          "window.location.href = 'about:blank';");
    } catch (e) {
      KazumiLogger().d('[Captcha WebView] unloadPage skipped: $e');
    }
  }

  @override
  void dispose() {
    _currentXpath = '';
    _currentPageUrl = '';
    for (final s in _subscriptions) {
      try {
        s.cancel();
      } catch (_) {}
    }
    _subscriptions.clear();
    try {
      captchaImageFoundController.close();
      captchaDisappearedController.close();
      initEventController.close();
      logEventController.close();
    } catch (_) {}
    _headlessWebview?.dispose();
    _headlessWebview = null;
  }

  Future<void> _setupProxy() async {
    final setting = GStorage.setting;
    final bool proxyEnable =
        setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
    if (!proxyEnable) return;

    final String proxyUrl =
        setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
    final formattedProxy = ProxyUtils.getFormattedProxyUrl(proxyUrl);
    if (formattedProxy == null) return;

    try {
      await WebviewController.initializeEnvironment(
        additionalArguments: '--proxy-server=$formattedProxy',
      );
      KazumiLogger().i('[Captcha WebView] 代理设置成功 $formattedProxy');
    } catch (e) {
      KazumiLogger().e('[Captcha WebView] 设置代理失败 $e');
    }
  }
}
