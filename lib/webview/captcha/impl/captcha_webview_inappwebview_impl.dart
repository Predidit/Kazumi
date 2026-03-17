import 'dart:async';

import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/webview/captcha/captcha_webview_controller.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

class CaptchaWebviewInAppWebviewImpl
    extends CaptchaWebviewController<PlatformInAppWebViewController> {
  PlatformHeadlessInAppWebView? _headlessWebView;
  bool _handlersRegistered = false;
  String _currentCaptchaImageXpath = '';
  String _currentInputXpath = '';

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
          webviewController = controller;
          initEventController.add(true);
        },
        onLoadStart: (controller, url) {
          logEventController.add('[Captcha WebView] Load start: $url');
        },
        onLoadStop: (controller, url) {
          logEventController.add('[Captcha WebView] Load stop: $url');
          if (buttonWasClicked && !captchaDisappearedController.isClosed) {
            KazumiLogger().i('[Captcha WebView] Button click → page navigated, verification done');
            buttonWasClicked = false;
            captchaDisappearedController.add(null);
          }
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

    webviewController?.addJavaScriptHandler(
      handlerName: 'CaptchaImageBridge',
      callback: (args) {
        final src = args.isNotEmpty ? args[0].toString() : '';
        logEventController.add('[Captcha WebView] Captcha image found: $src');
        if (src.isNotEmpty && !captchaImageFoundController.isClosed) {
          captchaWasFound = true;
          captchaImageFoundController.add(src);
        }
      },
    );

    webviewController?.addJavaScriptHandler(
      handlerName: 'CaptchaStatusBridge',
      callback: (args) {
        final status = args.isNotEmpty ? args[0].toString() : '';
        logEventController.add('[Captcha WebView JS] Page captcha status: $status');
        if (status == 'absent' && captchaWasFound &&
            !captchaDisappearedController.isClosed) {
          KazumiLogger().i('[Captcha WebView] Captcha gone after navigation (StatusBridge)');
          captchaWasFound = false;
          captchaDisappearedController.add(null);
        }
      },
    );

    webviewController?.addJavaScriptHandler(
      handlerName: 'CaptchaGoneBridge',
      callback: (args) {
        logEventController.add('[Captcha WebView] Captcha image disappeared');
        buttonWasClicked = false;
        if (!captchaDisappearedController.isClosed) {
          captchaDisappearedController.add(null);
        }
      },
    );

    webviewController?.addJavaScriptHandler(
      handlerName: 'ButtonClickedBridge',
      callback: (args) {
        logEventController.add('[Captcha WebView] Button clicked flag set');
        buttonWasClicked = true;
      },
    );

    webviewController?.addJavaScriptHandler(
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
    if (_currentCaptchaImageXpath.isEmpty) return;

    final escapedXpath =
        _currentCaptchaImageXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    final escapedInputXpath =
        _currentInputXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

    // Remove any previously injected captcha script before adding a fresh one.
    await webviewController?.removeAllUserScripts();

    const String scriptTemplate = """
window.flutter_inappwebview.callHandler('CaptchaLogBridge',
  'CaptchaScript loaded on: ' + window.location.href);

var _captchaXpath = '{XPATH}';
var _inputXpath = '{INPUT_XPATH}';
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

function _triggerInputFocus() {
  if (!_inputXpath) return false;
  try {
    var inputResult = document.evaluate(_inputXpath, document, null,
      XPathResult.FIRST_ORDERED_NODE_TYPE, null);
    var inputEl = inputResult.singleNodeValue;
    if (inputEl) {
      if (typeof \$ !== 'undefined' && \$) {
        \$(inputEl).trigger('focus');
        return true;
      } else if (typeof jQuery !== 'undefined' && jQuery) {
        jQuery(inputEl).trigger('focus');
        return true;
      } else {
        inputEl.focus();
        return true;
      }
    }
  } catch(e) {
    try { window.flutter_inappwebview.callHandler('CaptchaLogBridge',
      'Failed to trigger input focus - ' + e.message); } catch(e2) {}
  }
  return false;
}

// Report captcha status to Dart at DOMContentLoaded so that after a full-page
// navigation Dart can detect that verification succeeded (captcha is gone).
// Also trigger input focus here since DOM is ready at this point.
window.addEventListener('DOMContentLoaded', function() {
  _triggerInputFocus();
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

    final script = scriptTemplate
        .replaceAll('{XPATH}', escapedXpath)
        .replaceAll('{INPUT_XPATH}', escapedInputXpath);
    await webviewController?.addUserScripts(
      userScripts: [
        UserScript(
          source: script,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ],
    );
  }

  @override
  Future<void> loadPage(String url, String captchaXpath, {String? inputXpath}) async {
    _currentCaptchaImageXpath = captchaXpath;
    _currentInputXpath = inputXpath ?? '';
    captchaWasFound = false;
    buttonWasClicked = false;
    _registerHandlers();
    await _addCaptchaUserScript();
    try {
      await PlatformCookieManager(const PlatformCookieManagerCreationParams())
          .deleteAllCookies();
      logEventController.add('[Captcha WebView] Cookies cleared before load');
    } catch (_) {}
    await webviewController
        ?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  @override
  Future<void> loadPageForButtonClick(String url, String buttonXpath) async {
    _currentCaptchaImageXpath = ''; // disable captcha-image script on navigation
    captchaWasFound = false;
    buttonWasClicked = false;
    _registerHandlers();
    await _addButtonClickUserScript(buttonXpath);
    try {
      await PlatformCookieManager(const PlatformCookieManagerCreationParams())
          .deleteAllCookies();
      logEventController.add('[Captcha WebView] Cookies cleared before load');
    } catch (_) {}
    await webviewController
        ?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Future<void> _addButtonClickUserScript(String buttonXpath) async {
    final escapedXpath =
        buttonXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    await webviewController?.removeAllUserScripts();

    const String scriptTemplate = """
try { window.flutter_inappwebview.callHandler('CaptchaLogBridge',
  'ButtonClickScript loaded on: ' + window.location.href); } catch(e) {}

var _btnXpath = '{XPATH}';
var _clicked = false;
var _poller = null;
var _disappearObserver = null;

function _evalBtnXpath() {
  try {
    var result = document.evaluate(
      _btnXpath, document, null,
      XPathResult.FIRST_ORDERED_NODE_TYPE, null);
    return result.singleNodeValue;
  } catch(e) { return null; }
}

function _startDisappearMonitor() {
  if (_disappearObserver) return;
  _disappearObserver = new MutationObserver(function() {
    if (!_evalBtnXpath()) {
      _disappearObserver.disconnect();
      _disappearObserver = null;
      try { window.flutter_inappwebview.callHandler('CaptchaGoneBridge', ''); } catch(e) {}
    }
  });
  _disappearObserver.observe(document.documentElement,
    { childList: true, subtree: true, attributes: true });
}

function _checkAndClick() {
  var btn = _evalBtnXpath();
  if (btn && !_clicked) {
    _clicked = true;
    btn.click();
    try { window.flutter_inappwebview.callHandler('ButtonClickedBridge', ''); } catch(e) {}
    _startDisappearMonitor();
    return true;
  }
  return false;
}

if (!_checkAndClick()) {
  _poller = setInterval(function() {
    if (_checkAndClick()) { clearInterval(_poller); _poller = null; }
  }, 500);
}
""";

    final script = scriptTemplate.replaceAll('{XPATH}', escapedXpath);
    await webviewController?.addUserScripts(
      userScripts: [
        UserScript(
          source: script,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        ),
      ],
    );
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
    await webviewController?.evaluateJavascript(source: script);
  }

  @override
  Future<String> getCookieString(String pageUrl) async {
    try {
      final PlatformCookieManager cookieManager = PlatformCookieManager(
        PlatformCookieManagerCreationParams(),
      );
      final cookies = await cookieManager.getCookies(url: WebUri(pageUrl));
      return cookies.map((c) => '${c.name}=${c.value}').join('; ');
    } catch (e) {
      KazumiLogger().e('[Captcha WebView] getCookieString error: $e');
      return '';
    }
  }

  @override
  Future<void> unloadPage() async {
    try {
      await webviewController
          ?.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')));
    } catch (_) {}
  }

  @override
  void dispose() {
    _currentCaptchaImageXpath = '';
    _currentInputXpath = '';
    captchaWasFound = false;
    buttonWasClicked = false;
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
    webviewController = null;
  }
}
