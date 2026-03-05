import 'dart:async';

import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/webview/captcha_webview_controller.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

/// 基于 flutter_inappwebview 的验证码 WebView 实现（Android / iOS / macOS）
class CaptchaInAppWebviewImpel extends CaptchaWebviewController {
  PlatformHeadlessInAppWebView? _headlessWebView;
  PlatformInAppWebViewController? _webviewController;
  bool _handlersRegistered = false;
  String _currentXpath = '';
  /// whether a captcha image has been detected, used to determine if verification is successful after page navigation
  bool _captchaWasFound = false;

  @override
  Future<void> init() async {
    _headlessWebView ??= PlatformHeadlessInAppWebView(
      PlatformHeadlessInAppWebViewCreationParams(
        initialSettings: InAppWebViewSettings(
          userAgent: Utils.getRandomUA(),
          mediaPlaybackRequiresUserGesture: true,
          cacheEnabled: true,
          blockNetworkImage: false,
          loadsImagesAutomatically: true,
          upgradeKnownHostsToHTTPS: false,
          safeBrowsingEnabled: false,
        ),
        onWebViewCreated: (controller) {
          logEventController.add('[Captcha WebView] Created');
          _webviewController = controller;
          initEventController.add(true);
        },
        onLoadStart: (controller, url) {
          logEventController.add('[Captcha WebView] Load start: $url');
        },
        onLoadStop: (controller, url) {
          logEventController.add('[Captcha WebView] Load stop: $url');
        },
        onReceivedError: (controller, request, error) {
          logEventController
              .add('[Captcha WebView] Error: ${error.description}');
        },
      ),
    );
    await _headlessWebView!.run();
  }

  void _registerHandlers() {
    if (_handlersRegistered) return;

    _webviewController?.addJavaScriptHandler(
      handlerName: 'CaptchaImageBridge',
      callback: (args) {
        final src = args.isNotEmpty ? args[0].toString() : '';
        logEventController.add('[Captcha WebView] Captcha image found: $src');
        if (src.isNotEmpty && !captchaImageFoundController.isClosed) {
          _captchaWasFound = true;
          captchaImageFoundController.add(src);
        }
      },
    );

    _webviewController?.addJavaScriptHandler(
      handlerName: 'CaptchaStatusBridge',
      callback: (args) {
        final status = args.isNotEmpty ? args[0].toString() : '';
        logEventController.add('[Captcha WebView JS] Page captcha status: $status');
        if (status == 'absent' && _captchaWasFound &&
            !captchaDisappearedController.isClosed) {
          KazumiLogger().i('[Captcha WebView] Captcha gone after navigation (StatusBridge)');
          _captchaWasFound = false;
          captchaDisappearedController.add(null);
        }
      },
    );

    _webviewController?.addJavaScriptHandler(
      handlerName: 'CaptchaGoneBridge',
      callback: (args) {
        logEventController.add('[Captcha WebView] Captcha image disappeared');
        if (!captchaDisappearedController.isClosed) {
          captchaDisappearedController.add(null);
        }
      },
    );

    _webviewController?.addJavaScriptHandler(
      handlerName: 'CaptchaLogBridge',
      callback: (args) {
        if (args.isNotEmpty) {
          logEventController.add('[Captcha WebView JS] ${args[0]}');
        }
      },
    );

    _handlersRegistered = true;
    logEventController.add('[Captcha WebView] JS handlers registered');
  }

  Future<void> _addCaptchaUserScript() async {
    if (_currentXpath.isEmpty) return;

    final escapedXpath =
        _currentXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

    // Remove any previously injected captcha script before adding a fresh one.
    await _webviewController?.removeAllUserScripts();

    const String scriptTemplate = """
window.flutter_inappwebview.callHandler('CaptchaLogBridge',
  'CaptchaScript loaded on: ' + window.location.href);

var _captchaXpath = '{XPATH}';
var _captchaPoller = null;
var _disappearObserver = null;

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
    var node = _evalXpath();
    if (!node) {
      _disappearObserver.disconnect();
      _disappearObserver = null;
      try {
        window.flutter_inappwebview.callHandler('CaptchaGoneBridge', '');
      } catch(e) {}
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
        try {
          window.flutter_inappwebview.callHandler('CaptchaImageBridge', dataUrl);
        } catch(e) {}
      }
    });
    _startDisappearMonitor();
    return true;
  }
  return false;
}

// Report captcha status to Dart at DOMContentLoaded so that after a full-page
// navigation Dart can detect that verification succeeded (captcha is gone).
window.addEventListener('DOMContentLoaded', function() {
  var node = _evalXpath();
  try {
    window.flutter_inappwebview.callHandler('CaptchaStatusBridge', node ? 'present' : 'absent');
  } catch(e) {}
});

if (!_checkForCaptcha()) {
  _captchaPoller = setInterval(function() {
    if (_checkForCaptcha()) {
      clearInterval(_captchaPoller);
      _captchaPoller = null;
    }
  }, 500);
}
""";

    final script = scriptTemplate.replaceAll('{XPATH}', escapedXpath);
    await _webviewController?.addUserScripts(
      userScripts: [
        UserScript(
          source: script,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ],
    );
  }

  @override
  Future<void> loadPage(String url, String captchaXpath) async {
    _currentXpath = captchaXpath;
    _captchaWasFound = false;
    _registerHandlers();
    await _addCaptchaUserScript();
    try {
      await PlatformCookieManager(const PlatformCookieManagerCreationParams())
          .deleteAllCookies();
      logEventController.add('[Captcha WebView] Cookies cleared before load');
    } catch (_) {}
    await _webviewController
        ?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
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
    try { window.flutter_inappwebview.callHandler('CaptchaLogBridge', 'Input filled'); } catch(e) {}
  } else {
    try { window.flutter_inappwebview.callHandler('CaptchaLogBridge', 'Input element not found'); } catch(e) {}
  }
  var btnEl = evalXpath('$escapedButton');
  if (btnEl) {
    btnEl.click();
    try { window.flutter_inappwebview.callHandler('CaptchaLogBridge', 'Button clicked'); } catch(e) {}
  } else {
    try { window.flutter_inappwebview.callHandler('CaptchaLogBridge', 'Button element not found'); } catch(e) {}
  }
})();
''';
    await _webviewController?.evaluateJavascript(source: script);
  }

  @override
  Future<String> getCookieString(String pageUrl) async {
    try {
      // Use JS to read document.cookie (non-HttpOnly cookies).
      // HttpOnly cookies are not accessible via JS by design, but session
      // cookies set by anti-crawler checks are typically not HttpOnly.
      final jsResult = await _webviewController
          ?.evaluateJavascript(source: 'document.cookie');
      return jsResult?.toString().replaceAll('"', '') ?? '';
    } catch (e) {
      KazumiLogger().e('[Captcha WebView] getCookieString error: $e');
      return '';
    }
  }

  @override
  Future<void> unloadPage() async {
    try {
      await _webviewController
          ?.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')));
    } catch (_) {}
  }

  @override
  void dispose() {
    _currentXpath = '';
    _captchaWasFound = false;
    _handlersRegistered = false;
    try {
      PlatformCookieManager(const PlatformCookieManagerCreationParams())
          .deleteAllCookies();
    } catch (_) {}
    try {
      captchaImageFoundController.close();
      captchaDisappearedController.close();
      initEventController.close();
      logEventController.close();
    } catch (_) {}
    _headlessWebView?.dispose();
    _headlessWebView = null;
    _webviewController = null;
  }
}
