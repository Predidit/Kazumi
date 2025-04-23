import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';

class WebviewLinuxItemControllerImpel extends WebviewItemController<Webview> {
  Timer? ifrmaeParserTimer;
  Timer? videoParserTimer;
  bool bridgeInited = false;

  @override
  Future<void> init() async {
    webviewController ??= await WebviewWindow.create(
      configuration: const CreateConfiguration(),
    );
    bridgeInited = false;
    initEventController.add(true);
  }

  Future<void> initBridge(bool useNativePlayer, bool useLegacyParser) async {
    await initJSBridge(useNativePlayer, useLegacyParser);
    if (useNativePlayer && !useLegacyParser) {
      await initBlobParserAndiframeBridge();
    }
    bridgeInited = true;
  }

  @override
  Future<void> loadUrl(String url, bool useNativePlayer, bool useLegacyParser,
      {int offset = 0}) async {
    ifrmaeParserTimer?.cancel();
    videoParserTimer?.cancel();
    await unloadPage();
    if (!bridgeInited) {
      await initBridge(useNativePlayer, useLegacyParser);
    }
    count = 0;
    this.offset = offset;
    isIframeLoaded = false;
    isVideoSourceLoaded = false;
    videoLoadingEventController.add(true);
    webviewController!.launch(url);

    ifrmaeParserTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isIframeLoaded) {
        timer.cancel();
      } else {
        count++;
        parseIframeUrl();
      }
      // parseIframeUrl();
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
    await redirect2Blank();
  }

  @override
  void dispose() {
    webviewController!.close();
    bridgeInited = false;
  }

  Future<void> initJSBridge(bool useNativePlayer, bool useLegacyParser) async {
    webviewController!.addOnWebMessageReceivedCallback((message) async {
      if (message.contains('iframeMessage:')) {
        String messageItem =
            Uri.encodeFull(message.replaceFirst('iframeMessage:', ''));
        logEventController
            .add('Callback received: ${Uri.decodeFull(messageItem)}');
        logEventController.add(
            'If there is audio but no video, please report it to the rule developer.');
        if ((messageItem.contains('http') || messageItem.startsWith('//')) &&
            !messageItem.contains('googleads') &&
            !messageItem.contains('googlesyndication.com') &&
            !messageItem.contains('prestrain.html') &&
            !messageItem.contains('prestrain%2Ehtml') &&
            !messageItem.contains('adtrafficquality')) {
          logEventController.add('Parsing video source $messageItem');
          if (Utils.decodeVideoSource(messageItem) !=
                  Uri.encodeFull(messageItem) &&
              useNativePlayer &&
              useLegacyParser) {
            isIframeLoaded = true;
            isVideoSourceLoaded = true;
            videoLoadingEventController.add(false);
            logEventController.add(
                'Loading video source ${Utils.decodeVideoSource(messageItem)}');
            unloadPage();
            videoParserEventController
                .add((Utils.decodeVideoSource(messageItem), offset));
          }
        }
      }
      if (message.contains('iframeRedirectMessage:')) {
        String messageItem =
            Uri.encodeFull(message.replaceFirst('iframeRedirectMessage:', ''));
        logEventController
            .add('Redirect to ${Utils.decodeVideoSource(messageItem)}');
        if (!useNativePlayer) {
          Future.delayed(const Duration(seconds: 2), () {
            isIframeLoaded = true;
            videoLoadingEventController.add(false);
          });
        }
      }
      if (message.contains('videoMessage:')) {
        String messageItem =
            Uri.encodeFull(message.replaceFirst('videoMessage:', ''));
        logEventController
            .add('Callback received: ${Uri.decodeFull(messageItem)}');
        if (messageItem.contains('http') && !isVideoSourceLoaded) {
          String videoUrl = Uri.decodeFull(messageItem);
          logEventController.add('Loading video source $videoUrl');
          isIframeLoaded = true;
          isVideoSourceLoaded = true;
          videoLoadingEventController.add(false);
          if (useNativePlayer) {
            unloadPage();
            videoParserEventController.add((videoUrl, offset));
          }
        }
      }
    });
  }

  Future<void> parseIframeUrl() async {
    await webviewController!.evaluateJavaScript('''
      var iframes = document.getElementsByTagName('iframe');
      window.webkit.messageHandlers.msgToNative.postMessage('iframeMessage:' + 'The number of iframe tags is' + iframes.length);
      for (var i = 0; i < iframes.length; i++) {
          var iframe = iframes[i];
          var src = iframe.getAttribute('src');
          window.webkit.messageHandlers.msgToNative.postMessage('iframeMessage:' + src);

          if (src && src.trim() !== '' && (src.startsWith('http') || src.startsWith('//')) && !src.includes('googleads') && !src.includes('adtrafficquality') && !src.includes('googlesyndication.com') && !src.includes('google.com') && !src.includes('prestrain.html') && !src.includes('prestrain%2Ehtml')) {
              window.webkit.messageHandlers.msgToNative.postMessage('iframeRedirectMessage:' + src);
              window.location.href = src;
              break; 
          }
      }
  ''');
  }

  // 非blob资源
  Future<void> parseVideoSource() async {
    await webviewController!.evaluateJavaScript('''
      var videos = document.querySelectorAll('video');
      window.webkit.messageHandlers.msgToNative.postMessage('videoMessage:' + 'The number of video tags is' + videos.length);
      for (var i = 0; i < videos.length; i++) {
        var src = videos[i].getAttribute('src');
        if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
          window.webkit.messageHandlers.msgToNative.postMessage('videoMessage:' + src);
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

  // blob资源/iframe桥
  Future<void> initBlobParserAndiframeBridge() async {
    webviewController!.setOnUrlRequestCallback((url) {
      debugPrint('Current URL: $url');
      return true;
    });
    webviewController!.addScriptToExecuteOnDocumentCreated('''
      const _r_text = window.Response.prototype.text;
      window.Response.prototype.text = function () {
          return new Promise((resolve, reject) => {
              _r_text.call(this).then((text) => {
                  resolve(text);
                  if (text.trim().startsWith("#EXTM3U")) {
                      window.webkit.messageHandlers.msgToNative.postMessage('videoMessage:' + this.url);
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
                      window.webkit.messageHandlers.msgToNative.postMessage('videoMessage:' + args[1]);
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
                  console.log(this.url);
                  window.webkit.messageHandlers.msgToNative.postMessage('videoMessage:' + this.url);
                }
              }).catch(reject);
            });
          }
          
          const iframe_open = iframeWindow.XMLHttpRequest.prototype.open;
          iframeWindow.XMLHttpRequest.prototype.open = function (...args) {
            this.addEventListener("load", () => {
              try {
                let content = this.responseText;
                if (content.trim().startsWith("#EXTM3U")) {
                  console.log(args[1]);
                  window.webkit.messageHandlers.msgToNative.postMessage('videoMessage:' + args[1]);
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

  // webview_windows本身无此方法，loadurl方法相当于打开新标签页，会造成内存泄漏
  // 而直接销毁 webview 控制器会导致更换选集时需要重新初始化，webview 重新初始化开销较大
  // 故使用此方法
  Future<void> redirect2Blank() async {
    await webviewController!.evaluateJavaScript('''
      window.location.href = 'about:blank';
    ''');
  }
}
