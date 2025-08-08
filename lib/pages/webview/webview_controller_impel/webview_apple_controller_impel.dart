import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

class WebviewAppleItemControllerImpel
    extends WebviewItemController<PlatformInAppWebViewController> {
  Timer? loadingMonitorTimer;
  bool hasInjectedScripts = false;

  @override
  Future<void> init() async {
    initEventController.add(true);
  }

  @override
  Future<void> loadUrl(String url, bool useNativePlayer, bool useLegacyParser,
      {int offset = 0}) async {
    await unloadPage();
    if (!hasInjectedScripts) {
      addJavaScriptHandlers(useNativePlayer, useLegacyParser);
      await addUserScripts(useNativePlayer, useLegacyParser);
      hasInjectedScripts = true;
    }
    count = 0;
    this.offset = offset;
    isIframeLoaded = false;
    isVideoSourceLoaded = false;
    videoLoadingEventController.add(true);

    await webviewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));

    loadingMonitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isVideoSourceLoaded || isIframeLoaded) {
        timer.cancel();
      } else {
        count++;
        if (count >= 15) {
          timer.cancel();

          logEventController.add('clear');
          logEventController.add('解析视频资源超时');
          logEventController.add('请切换到其他播放列表或视频源');
          logEventController.add('showDebug');
        }
      }
    });
  }

  void addJavaScriptHandlers(bool useNativePlayer, bool useLegacyParser) {
    if (!useNativePlayer) {
      debugPrint('[WebView] Adding IframeRedirectBridge handler');
      webviewController?.addJavaScriptHandler(
          handlerName: 'IframeRedirectBridge',
          callback: (args) {
            String message = args[0].toString();
            logEventController.add('Redirect to: $message');
            Future.delayed(const Duration(seconds: 2), () {
              isIframeLoaded = true;
              videoLoadingEventController.add(false);
            });
          });
    } else if (useLegacyParser) {
      debugPrint('[WebView] Adding JSBridgeDebug handler');
      webviewController?.addJavaScriptHandler(
          handlerName: 'JSBridgeDebug',
          callback: (args) {
            String message = args[0].toString();
            logEventController.add('Callback received: $message');
            logEventController.add(
                'If there is audio but no video, please report it to the rule developer.');
            if ((message.contains('http') || message.startsWith('//')) &&
                !message.contains('googleads') &&
                !message.contains('googlesyndication.com') &&
                !message.contains('prestrain.html') &&
                !message.contains('prestrain%2Ehtml') &&
                !message.contains('adtrafficquality')) {
              logEventController.add('Parsing video source $message');
              String encodedUrl = Uri.encodeFull(message);
              if (Utils.decodeVideoSource(encodedUrl) != encodedUrl) {
                isIframeLoaded = true;
                isVideoSourceLoaded = true;
                videoLoadingEventController.add(false);
                logEventController.add(
                    'Loading video source ${Utils.decodeVideoSource(encodedUrl)}');
                unloadPage();
                videoParserEventController
                    .add((Utils.decodeVideoSource(encodedUrl), offset));
              }
            }
          });
    } else {
      debugPrint('[WebView] Adding VideoBridgeDebug handler');
      webviewController?.addJavaScriptHandler(
          handlerName: 'VideoBridgeDebug',
          callback: (args) {
            String message = args[0].toString();
            logEventController.add('Callback received: $message');
            if (message.contains('http') && !isVideoSourceLoaded) {
              logEventController.add('Loading video source: $message');
              isIframeLoaded = true;
              isVideoSourceLoaded = true;
              videoLoadingEventController.add(false);
              unloadPage();
              videoParserEventController.add((message, offset));
            }
          });
    }
  }

  Future<void> addUserScripts(
      bool useNativePlayer, bool useLegacyParser) async {
    final List<UserScript> scripts = [];

    if (!useNativePlayer) {
      debugPrint('[WebView] Adding IframeRedirectBridge user script');
      const String iframeRedirectScript = """
        var iframes = document.getElementsByTagName('iframe');
        for (var i = 0; i < iframes.length; i++) {
              var iframe = iframes[i];
              var src = iframe.getAttribute('src');
              if (src && src.trim() !== '' && (src.startsWith('http') || src.startsWith('//')) && !src.includes('googleads') && !src.includes('adtrafficquality') && !src.includes('googlesyndication.com') && !src.includes('google.com') && !src.includes('prestrain.html') && !src.includes('prestrain%2Ehtml')) {
                  window.flutter_inappwebview.callHandler('IframeRedirectBridge', src);
                  window.location.href = src;
                  break; 
              }
          }
      """;
      scripts.add(UserScript(
        source: iframeRedirectScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        forMainFrameOnly: true,
      ));
    } else if (useLegacyParser) {
      debugPrint('[WebView] Adding JSBridgeDebug user script');
      const String jsBridgeDebugScript = """
        var iframes = document.getElementsByTagName('iframe');
        window.flutter_inappwebview.callHandler('JSBridgeDebug', 'The number of iframe tags is' + iframes.length);
        for (var i = 0; i < iframes.length; i++) {
            var iframe = iframes[i];
            var src = iframe.getAttribute('src');
            if (src) {
              window.flutter_inappwebview.callHandler('JSBridgeDebug', src);
            }
        }
      """;
      scripts.add(UserScript(
        source: jsBridgeDebugScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        forMainFrameOnly: false,
      ));
    } else {
      debugPrint('[WebView] Adding VideoBridgeDebug user script');
      const String blobParserScript = """
        const _r_text = window.Response.prototype.text;
        window.Response.prototype.text = function () {
            return new Promise((resolve, reject) => {
                _r_text.call(this).then((text) => {
                    resolve(text);
                    if (text.trim().startsWith("#EXTM3U")) {
                        console.log('M3U8 source found:', this.url);
                        window.flutter_inappwebview.callHandler('VideoBridgeDebug', this.url);
                    }
                }).catch(reject);
            });
        }

        const _open = window.XMLHttpRequest.prototype.open;
        window.XMLHttpRequest.prototype.open = function (...args) {
            this.addEventListener("load", () => {
                try {
                    let content = this.responseText;
                    if (content.trim().startsWith("#EXTM3U")) {
                        console.log('M3U8 source found:', args[1]);
                        window.flutter_inappwebview.callHandler('VideoBridgeDebug', args[1]);
                    };
                } catch {}
            });
            return _open.apply(this, args);
        };
      """;

      const String videoTagParserScript = """
        function processVideoElement(video) {
          window.flutter_inappwebview.callHandler('VideoBridgeDebug', 'Scanning video tag for source URL');
          let src = video.getAttribute('src');
          if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
            console.log('VIDEO source found:', src);
            window.flutter_inappwebview.callHandler('VideoBridgeDebug', src);
            return;
          }
          const sources = video.getElementsByTagName('source');
          for (let source of sources) {
            src = source.getAttribute('src');
            if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
              console.log('VIDEO source found (source tag):', src);
              window.flutter_inappwebview.callHandler('VideoBridgeDebug', src);
              return;
            }
          }
        }

        document.querySelectorAll('video').forEach(processVideoElement);

        const _observer = new MutationObserver((mutations) => {
          mutations.forEach(mutation => {
            if (mutation.type === 'attributes' && mutation.target.nodeName === 'VIDEO') {
              processVideoElement(mutation.target);
            }
            mutation.addedNodes.forEach(node => {
              if (node.nodeName === 'VIDEO') processVideoElement(node);
              if (node.querySelectorAll) {
                node.querySelectorAll('video').forEach(processVideoElement);
              }
            });
          });  
        });

        _observer.observe(document.body, {
          childList: true,
          subtree: true,
          attributes: true,
          attributeFilter: ['src']
        });
    """;
      scripts.add(UserScript(
        source: blobParserScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: false,
      ));
      scripts.add(UserScript(
        source: videoTagParserScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        forMainFrameOnly: false,
      ));
    }

    await webviewController?.addUserScripts(
      userScripts: scripts,
    );
  }

  @override
  Future<void> unloadPage() async {
    loadingMonitorTimer?.cancel();
    await webviewController!.clearAllCache();
    await webviewController!
        .loadUrl(urlRequest: URLRequest(url: WebUri("about:blank")));
  }

  @override
  void dispose() {
    loadingMonitorTimer?.cancel();
  }
}
