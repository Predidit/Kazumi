import 'dart:async';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewItemControllerImpel
    extends WebviewItemController<WebViewController> {
  // workaround for webview_flutter lib.
  // webview_flutter lib won't change currentUrl after redirect using window.location.href.
  // which causes multiple redirects to the same url.
  // so we need to store the currentUrl manually
  String currentUrl = '';

  Timer? ifrmaeParserTimer;
  Timer? videoParserTimer;

  @override
  Future<void> init() async {
    webviewController ??= WebViewController();
    initEventController.add(true);
  }

  @override
  Future<void> loadUrl(String url, bool useNativePlayer, bool useLegacyParser,
      {int offset = 0}) async {
    ifrmaeParserTimer?.cancel();
    videoParserTimer?.cancel();
    await unloadPage();
    await setDesktopUserAgent();
    count = 0;
    currentUrl = '';
    this.offset = offset;
    isIframeLoaded = false;
    isVideoSourceLoaded = false;
    videoLoadingEventController.add(true);
    await webviewController!
        .setNavigationDelegate(NavigationDelegate(onUrlChange: (currentUrl) {
      KazumiLogger().i('WebView: current URL: ${currentUrl.url}');
      if (useNativePlayer && !useLegacyParser) {
        addBlobParser();
        addInviewIframeBridge();
      }
      // addFullscreenListener();
    }));
    await webviewController!.setJavaScriptMode(JavaScriptMode.unrestricted);
    await webviewController!.addJavaScriptChannel('JSBridgeDebug',
        onMessageReceived: (JavaScriptMessage message) {
      logEventController.add('Callback received: ${message.message}');
      logEventController.add(
          'If there is audio but no video, please report it to the rule developer.');
      if ((message.message.contains('http') ||
              message.message.startsWith('//')) &&
          !message.message.contains('googleads') &&
          !message.message.contains('googlesyndication.com') &&
          !message.message.contains('prestrain.html') &&
          !message.message.contains('prestrain%2Ehtml') &&
          !message.message.contains('adtrafficquality') &&
          currentUrl != message.message) {
        logEventController.add('Parsing video source ${message.message}');
        currentUrl = Uri.encodeFull(message.message);
        redirctWithReferer(message.message);
        if (Utils.decodeVideoSource(currentUrl) != Uri.encodeFull(currentUrl) &&
            useNativePlayer &&
            useLegacyParser) {
          isIframeLoaded = true;
          isVideoSourceLoaded = true;
          videoLoadingEventController.add(false);
          logEventController.add(
              'Loading video source ${Utils.decodeVideoSource(currentUrl)}');
          unloadPage();
          videoParserEventController
              .add((Utils.decodeVideoSource(currentUrl), offset));
        }
      }
    });
    await webviewController!.addJavaScriptChannel('IframeRedirectBridge',
        onMessageReceived: (JavaScriptMessage message) {
      logEventController.add('Redirect to: ${message.message}');
      if (!useNativePlayer) {
        Future.delayed(const Duration(seconds: 2), () {
          isIframeLoaded = true;
          videoLoadingEventController.add(false);
        });
      }
    });
    if (!useLegacyParser) {
      await webviewController!.addJavaScriptChannel('VideoBridgeDebug',
          onMessageReceived: (JavaScriptMessage message) {
        logEventController.add('Callback received: ${message.message}');
        if (message.message.contains('http') && !isVideoSourceLoaded) {
          logEventController.add('Loading video source: ${message.message}');
          isIframeLoaded = true;
          isVideoSourceLoaded = true;
          videoLoadingEventController.add(false);
          if (useNativePlayer) {
            unloadPage();
            videoParserEventController.add((message.message, offset));
          }
        }
      });
    }
    await webviewController!.loadRequest(Uri.parse(url));

    ifrmaeParserTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isIframeLoaded) {
        timer.cancel();
      } else {
        count++;
        parseIframeUrl();
      }
    });
    if (useNativePlayer) {
      videoParserTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (isVideoSourceLoaded) {
          timer.cancel();
        } else {
          if (count >= 15) {
            timer.cancel();
            isIframeLoaded = true;
            logEventController.add('clear');
            logEventController.add('解析视频资源超时');
            logEventController.add('请切换到其他播放列表或视频源');
            logEventController.add('showDebug');
          } else {
            if (!useLegacyParser) {
              parseVideoSource();
            }
          }
        }
      });
    }
  }

  @override
  Future<void> unloadPage() async {
    await webviewController!
        .removeJavaScriptChannel('JSBridgeDebug')
        .catchError((_) {});
    await webviewController!
        .removeJavaScriptChannel('VideoBridgeDebug')
        .catchError((_) {});
    await webviewController!
        .removeJavaScriptChannel('IframeRedirectBridge')
        .catchError((_) {});
    await webviewController!.loadRequest(Uri.parse('about:blank'));
    await webviewController!.clearCache();
    ifrmaeParserTimer?.cancel();
    videoParserTimer?.cancel();
  }

  @override
  void dispose() {
    unloadPage();
  }

  Future<void> parseIframeUrl() async {
    await webviewController!.runJavaScript('''
      var iframes = document.getElementsByTagName('iframe');
      JSBridgeDebug.postMessage('The number of iframe tags is' + iframes.length);
      for (var i = 0; i < iframes.length; i++) {
          var iframe = iframes[i];
          var src = iframe.getAttribute('src');
          if (src) {
            JSBridgeDebug.postMessage(src);
          }

          if (src && src.trim() !== '' && (src.startsWith('http') || src.startsWith('//')) && !src.includes('googleads') && !src.includes('adtrafficquality') && !src.includes('googlesyndication.com') && !src.includes('google.com') && !src.includes('prestrain.html') && !src.includes('prestrain%2Ehtml')) {
              IframeRedirectBridge.postMessage(src);
              break; 
          }
      }
  ''');
  }

  Future<void> redirctWithReferer(String src) async {
    await webviewController!.runJavaScript('window.location.href = "$src";');
  }

  // 非blob资源
  Future<void> parseVideoSource() async {
    await webviewController!.runJavaScript('''
      var videos = document.querySelectorAll('video');
      VideoBridgeDebug.postMessage('The number of video tags is' + videos.length);
      for (var i = 0; i < videos.length; i++) {
        var src = videos[i].getAttribute('src');
        if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
          VideoBridgeDebug.postMessage(src);
          break;
        } 
      }
      document.querySelectorAll('iframe').forEach((iframe) => {
        try {
          iframe.contentWindow.eval(`
            var videos = document.querySelectorAll('video');
            window.parent.postMessage({ message: 'videoMessage:' + 'The number of video tags is' + videos.length }, "*");
            for (var i = 0; i < videos.length; i++) {
              var src = videos[i].getAttribute('src');
              if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
                window.parent.postMessage({ message: 'videoMessage:' + src }, "*");
              } 
            }
                  `);
        } catch { }
      });
    ''');
  }

  // blob资源
  Future<void> addBlobParser() async {
    await webviewController!.runJavaScript('''
      const _r_text = window.Response.prototype.text;
      window.Response.prototype.text = function () {
          return new Promise((resolve, reject) => {
              _r_text.call(this).then((text) => {
                  resolve(text);
                  if (text.trim().startsWith("#EXTM3U")) {
                      VideoBridgeDebug.postMessage(this.url);
                  }
              }).catch(reject);
          });
      }

      const _open = window.XMLHttpRequest.prototype.open;
      window.XMLHttpRequest.prototype.open = function (...args) {
          this.addEventListener("load", () => {
              try {
                  let content = this.responseText;
                  if (content.trim().startsWith("#EXTM3U") && args[1] !== null && args[1] !== undefined) {
                      VideoBridgeDebug.postMessage(args[1]);
                  };
              } catch { }
          });
          return _open.apply(this, args);
      }
      
      function injectIntoIframe(iframe) {
        try {
          const iframeWindow = iframe.contentWindow;
          if (!iframeWindow) return;
          
          const iframe_r_text = iframeWindow.Response.prototype.text;
          iframeWindow.Response.prototype.text = function () {
            return new Promise((resolve, reject) => {
              iframe_r_text.call(this).then((text) => {
                resolve(text);
                if (text.trim().startsWith("#EXTM3U")) {
                  VideoBridgeDebug.postMessage(this.url);
                }
              }).catch(reject);
            });
          }
          
          const iframe_open = iframeWindow.XMLHttpRequest.prototype.open;
          iframeWindow.XMLHttpRequest.prototype.open = function (...args) {
            this.addEventListener("load", () => {
              try {
                let content = this.responseText;
                if (content.trim().startsWith("#EXTM3U") && args[1] !== null && args[1] !== undefined) {
                  console.log(args[1]);
                  VideoBridgeDebug.postMessage(args[1]);
                };
              } catch { }
            });
            return iframe_open.apply(this, args);
          }
        } catch (e) {
          console.error('iframe inject failed:', e);
        }
      }

      function setupIframeListeners() {
        document.querySelectorAll('iframe').forEach(iframe => {
          if (iframe.contentDocument) {
            injectIntoIframe(iframe);
          }
          iframe.addEventListener('load', () => injectIntoIframe(iframe));
        });
        
        const observer = new MutationObserver(mutations => {
          mutations.forEach(mutation => {
            if (mutation.type === 'childList') {
              mutation.addedNodes.forEach(node => {
                if (node.nodeName === 'IFRAME') {
                  node.addEventListener('load', () => injectIntoIframe(node));
                }
                if (node.querySelectorAll) {
                  node.querySelectorAll('iframe').forEach(iframe => {
                    iframe.addEventListener('load', () => injectIntoIframe(iframe));
                  });
                }
              });
            }
          });
        });
        
        observer.observe(document.body, { childList: true, subtree: true });
      }

      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', setupIframeListeners);
      } else {
        setupIframeListeners();
      } 
    ''');
  }

  Future<void> addInviewIframeBridge() async {
    await webviewController!.runJavaScript('''
      window.addEventListener("message", function(event) {
        if (event.data) {
          if (event.data.message && event.data.message.startsWith('videoMessage:')) {
            const msg = event.data.message.replace(/^videoMessage:/, '');
            if (msg !== null && msg !== undefined && msg !== "") {
                VideoBridgeDebug.postMessage(msg);
            }
          }
        }
      });
    ''');
  }

  // 设定UA
  Future<void> setDesktopUserAgent() async {
    String desktopUserAgent = Utils.getRandomUA();
    await webviewController!.setUserAgent(desktopUserAgent);
  }
}
