import 'dart:async';

import 'package:webview_windows/webview_windows.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/proxy_utils.dart';
import 'package:kazumi/webview/captcha/captcha_webview_controller.dart';

class CaptchaWebviewWindowsImpl
    extends CaptchaWebviewController<WebviewController> {
  HeadlessWebview? _headlessWebview;
  final List<StreamSubscription> _subscriptions = [];
  String _currentCaptchaImageXpath = '';
  String _currentInputXpath = '';
  String _currentPageUrl = '';
  String _buttonXpath = '';

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

    // Inject captcha or button-click script when navigation completes
    _subscriptions.add(
      _headlessWebview!.loadingState.listen((state) async {
        if (state == LoadingState.navigationCompleted) {
          logEventController
              .add('[Captcha WebView] Navigation completed: $_currentPageUrl');
          if (_currentCaptchaImageXpath.isNotEmpty) {
            await _injectCaptchaScript();
          } else if (_buttonXpath.isNotEmpty) {
            await _injectButtonClickScript(_buttonXpath);
          }
        }
      }),
    );

    // After a navigation, detect verification completion for both type-1
    // (captcha image gone) and type-2 (button was clicked, page navigated).
    _subscriptions.add(
      _headlessWebview!.loadingState.listen((state) async {
        if (state == LoadingState.navigationCompleted) {
          if (captchaWasFound) {
            final present = await _isCaptchaPresent();
            if (!present && !captchaDisappearedController.isClosed) {
              logEventController
                  .add('[Captcha WebView] Captcha gone after navigation');
              captchaWasFound = false;
              captchaDisappearedController.add(null);
            }
          }
          if (buttonWasClicked && !captchaDisappearedController.isClosed) {
            logEventController
                .add('[Captcha WebView] Button click → page navigated, verification done');
            buttonWasClicked = false;
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
      logEventController.add('[Captcha WebView JS] ${msg.replaceFirst('captchaLog:', '')}');
    }
  }

  Future<bool> _isCaptchaPresent() async {
    if (_currentCaptchaImageXpath.isEmpty || _headlessWebview == null) return false;
    final escaped =
        _currentCaptchaImageXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
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
    if (_currentCaptchaImageXpath.isEmpty) return;
    final escapedXpath =
        _currentCaptchaImageXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    final escapedInputXpath =
        _currentInputXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

    final script = '''
(function() {
  window.chrome.webview.postMessage('captchaLog:CaptchaScript injected on ' + window.location.href);

  var _captchaXpath = '$escapedXpath';
  var _inputXpath = '$escapedInputXpath';
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

  function _triggerInputFocus() {
    if (!_inputXpath) {
      return false;
    }
    
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
      window.chrome.webview.postMessage('captchaLog:Failed to trigger input focus - ' + e.message);
    }
    return false;
  }

  // If inputXpath is provided, trigger focus to load captcha (some sites require this)
  _triggerInputFocus();
  
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
  Future<void> loadPage(String url, String captchaXpath, {String? inputXpath}) async {
    _currentCaptchaImageXpath = captchaXpath;
    _currentInputXpath = inputXpath ?? '';
    _buttonXpath = '';
    buttonWasClicked = false;
    _currentPageUrl = url;
    captchaWasFound = false;
    await _headlessWebview?.loadUrl(url);
  }

  @override
  Future<void> loadPageForButtonClick(String url, String buttonXpath) async {
    _currentCaptchaImageXpath = '';
    _buttonXpath = buttonXpath;
    buttonWasClicked = false;
    _currentPageUrl = url;
    captchaWasFound = false;
    await _headlessWebview?.loadUrl(url);
  }

  Future<void> _injectButtonClickScript(String buttonXpath) async {
    final escaped =
        buttonXpath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    final script = '''
(function() {
  window.chrome.webview.postMessage('captchaLog:ButtonClickScript injected on ' + window.location.href);

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
        window.chrome.webview.postMessage('captchaGone:');
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
      window.chrome.webview.postMessage('buttonClicked:');
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
      await _headlessWebview?.executeScript(script);
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
      final result = await _headlessWebview?.getCookies(pageUrl);
      return result ?? '';
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
    _currentCaptchaImageXpath = '';
    _currentInputXpath = '';
    _buttonXpath = '';
    buttonWasClicked = false;
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
