import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/proxy_utils.dart';
import 'package:kazumi/webview/captcha/captcha_webview_controller.dart';

class CaptchaWebviewLinuxImpl
    extends CaptchaWebviewController<Webview> {
  VoidCallback? _navigationListener;
  String _currentCaptchaImageXpath = '';
  String _buttonXpath = '';

  @override
  Future<void> init() async {
    final proxyConfig = _getProxyConfiguration();
    webviewController ??= await WebviewWindow.create(
      configuration: CreateConfiguration(
        headless: true,
        proxy: proxyConfig,
      ),
    );
    _initMessageBridge();
    _initNavigationListener();
    initEventController.add(true);
  }

  ProxyConfiguration? _getProxyConfiguration() {
    final setting = GStorage.setting;
    final bool proxyEnable =
        setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
    if (!proxyEnable) return null;

    final String proxyUrl =
        setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
    final parsed = ProxyUtils.parseProxyUrl(proxyUrl);
    if (parsed == null) return null;

    final (host, port) = parsed;
    KazumiLogger().i('[Captcha WebView] 代理设置成功 $host:$port');
    return ProxyConfiguration(host: host, port: port);
  }

  void _initMessageBridge() {
    webviewController?.addOnWebMessageReceivedCallback((message) async {
      final msg = message.toString();
      logEventController.add('[Captcha WebView] WM: $msg');
      if (msg.startsWith('captchaImage:')) {
        final src = msg.replaceFirst('captchaImage:', '');
        if (src.isNotEmpty && !captchaImageFoundController.isClosed) {
          captchaWasFound = true;
          captchaImageFoundController.add(src);
        }
      } else if (msg.startsWith('buttonClicked:')) {
        buttonWasClicked = true;
        logEventController.add('[Captcha WebView] Button clicked flag set');
      } else if (msg.startsWith('captchaGone:')) {
        buttonWasClicked = false;
        if (!captchaDisappearedController.isClosed) {
          captchaDisappearedController.add(null);
        }
      } else if (msg.startsWith('captchaLog:')) {
        logEventController.add(
            '[Captcha WebView JS] ${msg.replaceFirst('captchaLog:', '')}');
      }
    });
  }

  void _initNavigationListener() {
    _navigationListener = () {
      _onNavigationInject();
      _onNavigationCompletion();
    };
    webviewController?.isNavigating.addListener(_navigationListener!);
  }

  Future<void> _onNavigationInject() async {
    if (webviewController?.isNavigating.value == false) {
      logEventController.add('[Captcha WebView] Navigation completed');
      if (_currentCaptchaImageXpath.isNotEmpty) {
        await _injectCaptchaScript();
      } else if (_buttonXpath.isNotEmpty) {
        await _injectButtonClickScript(_buttonXpath);
      }
    }
  }

  Future<void> _onNavigationCompletion() async {
    if (webviewController?.isNavigating.value == false) {
      // Type-1: captcha image was seen; check if it has disappeared.
      if (captchaWasFound) {
        final present = await _isCaptchaPresent();
        if (!present && !captchaDisappearedController.isClosed) {
          logEventController
              .add('[Captcha WebView] Captcha gone after navigation');
          captchaWasFound = false;
          captchaDisappearedController.add(null);
        }
      }
      // Type-2: button was clicked; page navigation confirms verification.
      if (buttonWasClicked && !captchaDisappearedController.isClosed) {
        logEventController.add(
            '[Captcha WebView] Button click and page navigated, verification done');
        buttonWasClicked = false;
        captchaDisappearedController.add(null);
      }
    }
  }

  Future<bool> _isCaptchaPresent() async {
    if (_currentCaptchaImageXpath.isEmpty || webviewController == null) return false;
    final escaped =
        _currentCaptchaImageXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    try {
      final result = await webviewController!.evaluateJavaScript('''
(function() {
  try {
    var r = document.evaluate('$escaped', document, null,
      XPathResult.FIRST_ORDERED_NODE_TYPE, null);
    return r.singleNodeValue ? 'present' : 'absent';
  } catch(e) { return 'absent'; }
})();
''');
      return result?.contains('present') ?? false;
    } catch (e) {
      KazumiLogger().d('[Captcha WebView] _isCaptchaPresent error: $e');
      return false;
    }
  }

  Future<void> _injectCaptchaScript() async {
    if (_currentCaptchaImageXpath.isEmpty) return;
    final escapedXpath =
        _currentCaptchaImageXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

    final script = '''
(function() {
  window.webkit.messageHandlers.msgToNative.postMessage(
    'captchaLog:CaptchaScript injected on ' + window.location.href);

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
        window.webkit.messageHandlers.msgToNative.postMessage('captchaGone:');
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
          window.webkit.messageHandlers.msgToNative.postMessage('captchaImage:' + dataUrl);
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
      await webviewController?.evaluateJavaScript(script);
    } catch (e) {
      KazumiLogger().e('[Captcha WebView] inject script error: $e');
    }
  }

  @override
  Future<void> loadPage(String url, String captchaXpath, {String? inputXpath}) async {
    _currentCaptchaImageXpath = captchaXpath;
    _buttonXpath = '';
    buttonWasClicked = false;
    captchaWasFound = false;
    webviewController?.launch(url);
  }

  @override
  Future<void> loadPageForButtonClick(String url, String buttonXpath) async {
    _currentCaptchaImageXpath = '';
    _buttonXpath = buttonXpath;
    buttonWasClicked = false;
    captchaWasFound = false;
    webviewController?.launch(url);
  }

  Future<void> _injectButtonClickScript(String buttonXpath) async {
    final escaped =
        buttonXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    final script = '''
(function() {
  window.webkit.messageHandlers.msgToNative.postMessage(
    'captchaLog:ButtonClickScript injected on ' + window.location.href);

  var _xpath = '$escaped';
  var _clicked = false;
  var _poller = null;
  var _disappearObserver = null;

  function evalXpath() {
    try {
      var r = document.evaluate(_xpath, document, null,
        XPathResult.FIRST_ORDERED_NODE_TYPE, null);
      return r.singleNodeValue;
    } catch(e) { return null; }
  }

  function startDisappearMonitor() {
    if (_disappearObserver) return;
    _disappearObserver = new MutationObserver(function() {
      if (!evalXpath()) {
        _disappearObserver.disconnect();
        _disappearObserver = null;
        window.webkit.messageHandlers.msgToNative.postMessage('captchaGone:');
      }
    });
    _disappearObserver.observe(document.documentElement,
      { childList: true, subtree: true, attributes: true });
  }

  function checkAndClick() {
    var btn = evalXpath();
    if (btn && !_clicked) {
      _clicked = true;
      btn.click();
      window.webkit.messageHandlers.msgToNative.postMessage('buttonClicked:');
      startDisappearMonitor();
      return true;
    }
    return false;
  }

  if (!checkAndClick()) {
    _poller = setInterval(function() {
      if (checkAndClick()) { clearInterval(_poller); _poller = null; }
    }, 500);
  }
})();
''';
    try {
      await webviewController?.evaluateJavaScript(script);
    } catch (e) {
      KazumiLogger().e('[Captcha WebView] injectButtonClickScript error: $e');
    }
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
    window.webkit.messageHandlers.msgToNative.postMessage('captchaLog:Input filled');
  } else {
    window.webkit.messageHandlers.msgToNative.postMessage('captchaLog:Input element not found');
  }
  var btnEl = evalXpath('$escapedButton');
  if (btnEl) {
    btnEl.click();
    window.webkit.messageHandlers.msgToNative.postMessage('captchaLog:Button clicked');
  } else {
    window.webkit.messageHandlers.msgToNative.postMessage('captchaLog:Button element not found');
  }
})();
''';
    try {
      await webviewController?.evaluateJavaScript(script);
    } catch (e) {
      KazumiLogger().e('[Captcha WebView] submitCaptchaInteract error: $e');
    }
  }

  @override
  Future<String> getCookieString(String pageUrl) async {
    try {
      final cookies = await webviewController?.getAllCookies() ?? [];
      final cookieString =
          cookies.map((c) => '${c.name}=${c.value}').join('; ');
      logEventController
          .add('[Captcha WebView] Cookies: $cookieString');
      return cookieString;
    } catch (e) {
      KazumiLogger().e('[Captcha WebView] getCookieString error: $e');
      return '';
    }
  }

  @override
  Future<void> unloadPage() async {
    webviewController?.launch('about:blank');
  }

  @override
  void dispose() {
    _currentCaptchaImageXpath = '';
    _buttonXpath = '';
    buttonWasClicked = false;
    captchaWasFound = false;
    if (_navigationListener != null) {
      try {
        webviewController?.isNavigating.removeListener(_navigationListener!);
      } catch (_) {}
      _navigationListener = null;
    }
    try {
      captchaImageFoundController.close();
      captchaDisappearedController.close();
      initEventController.close();
      logEventController.close();
    } catch (_) {}
    webviewController?.close();
    webviewController = null;
  }
}
