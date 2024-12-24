import 'dart:async';
import 'package:webview_windows/webview_windows.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';

class WebviewWindowsItemControllerImpel
    extends WebviewItemController<WebviewController> {
  Timer? ifrmaeParserTimer;
  Timer? videoParserTimer;
  bool bridgeInited = false;

  @override
  Future<void> init() async {
    webviewController ??= WebviewController();
    await webviewController!.initialize();
    await webviewController!
        .setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    bridgeInited = false;
    initEventController.add(true);
  }

  Future<void> initBridge(bool useNativePlayer, bool useLegacyParser) async {
    await initJSBridge(useNativePlayer, useLegacyParser);
    if (useNativePlayer && !useLegacyParser) {
      await initBlobParser();
      await initInviewIframeBridge();
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
    await webviewController!.loadUrl(url);

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
    await webviewController!.clearCache();
  }

  @override
  void dispose() {
    bridgeInited = false;
    webviewController!.dispose();
  }

  Future<void> initJSBridge(bool useNativePlayer, bool useLegacyParser) async {
    webviewController!.webMessage.listen((event) async {
      if (event.toString().contains('iframeMessage:')) {
        String messageItem =
            Uri.encodeFull(event.toString().replaceFirst('iframeMessage:', ''));
        logEventController
            .add('Callback received: ${Uri.decodeFull(messageItem)}');
        logEventController.add(
            'If there is audio but no video, please report it to the rule developer.');
        if (messageItem.contains('http') || messageItem.startsWith('//')) {
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
          if (!useNativePlayer) {
            Future.delayed(const Duration(seconds: 2), () {
              isIframeLoaded = true;
              videoLoadingEventController.add(false);
            });
          }
        }
      }
      if (event.toString().contains('videoMessage:')) {
        String messageItem =
            Uri.encodeFull(event.toString().replaceFirst('videoMessage:', ''));
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
    await webviewController!.executeScript('''
      var iframes = document.getElementsByTagName('iframe');
      window.chrome.webview.postMessage('iframeMessage:' + 'The number of iframe tags is' + iframes.length);
      for (var i = 0; i < iframes.length; i++) {
          var iframe = iframes[i];
          var src = iframe.getAttribute('src');

          if (src && src.trim() !== '' && (src.startsWith('http') || src.startsWith('//')) && !src.includes('googleads') && !src.includes('googlesyndication.com') && !src.includes('google.com') && !src.includes('prestrain.html') && !src.includes('prestrain%2Ehtml')) {
              window.chrome.webview.postMessage('iframeMessage:' + src);
              window.location.href = src;
              break; 
          }
      }
  ''');
  }

  // 非blob资源
  Future<void> parseVideoSource() async {
    await webviewController!.executeScript('''
      var videos = document.querySelectorAll('video');
      window.chrome.webview.postMessage('videoMessage:' + 'The number of video tags is' + videos.length);
      for (var i = 0; i < videos.length; i++) {
        var src = videos[i].getAttribute('src');
        if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
          window.chrome.webview.postMessage('videoMessage:' + src);
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
  Future<void> initBlobParser() async {
    await webviewController!.addScriptToExecuteOnDocumentCreated('''
      const _r_text = window.Response.prototype.text;
      window.Response.prototype.text = function () {
          return new Promise((resolve, reject) => {
              _r_text.call(this).then((text) => {
                  resolve(text);
                  if (text.trim().startsWith("#EXTM3U")) {
                      window.chrome.webview.postMessage('videoMessage:' + this.url);
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
                      window.chrome.webview.postMessage('videoMessage:' + args[1]);
                  };
              } catch { }
          });
          return _open.apply(this, args);
      } 
      document.querySelectorAll('iframe').forEach((iframe) => {
        try {
            const _r_text = iframe.contentWindow.Response.prototype.text;
            iframe.contentWindow.Response.prototype.text = function () {
                return new Promise((resolve, reject) => {
                    _r_text.call(this).then((text) => {
                        resolve(text);
                        if (text.trim().startsWith("#EXTM3U")) {
                            iframe.contentWindow.parent.postMessage({ message: 'videoMessage:' + this.url }, "*");
                        }
                    }).catch(reject);
                });
            }
      
            const _open = iframe.contentWindow.XMLHttpRequest.prototype.open;
            iframe.contentWindow.XMLHttpRequest.prototype.open = function (...args) {
                this.addEventListener("load", () => {
                    try {
                        let content = this.responseText;
                        if (content.trim().startsWith("#EXTM3U")) {
                            iframe.contentWindow.parent.postMessage({ message: 'videoMessage:' + args[1] }, "*");
                        };
                    } catch { }
                });
                return _open.apply(this, args);
            } 
        } catch { }
      });
    ''');
  }

  Future<void> initInviewIframeBridge() async {
    await webviewController!.addScriptToExecuteOnDocumentCreated('''
      window.addEventListener("message", function(event) {
        if (event.data) {
          if (event.data.message && event.data.message.startsWith('videoMessage:')) {
            window.chrome.webview.postMessage(event.data.message);
          }
        }
      });
    ''');
  }

  // webview_windows本身无此方法，loadurl方法相当于打开新标签页，会造成内存泄漏
  // 而直接销毁 webview 控制器会导致更换选集时需要重新初始化，webview 重新初始化开销较大
  // 故使用此方法
  Future<void> redirect2Blank() async {
    await webviewController!.executeScript('''
      window.location.href = 'about:blank';
    ''');
  }
}
