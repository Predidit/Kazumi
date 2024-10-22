import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';

class WebviewWindowsItemControllerImpel extends WebviewItemController<WebviewController> {
  Timer? ifrmaeParserTimer;
  Timer? videoParserTimer;

  @override
  init() async {
    webviewController ??= WebviewController();
    await webviewController!.initialize();
    await webviewController!.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    await initJSBridge();
    if (videoPageController.currentPlugin.useNativePlayer &&
        !videoPageController.currentPlugin.useLegacyParser) {
      await initBlobParser();
      await initInviewIframeBridge();
    }
    videoPageController.changeEpisode(videoPageController.currentEspisode,
        currentRoad: videoPageController.currentRoad,
        offset: videoPageController.historyOffset);
  }

  @override
  loadUrl(String url, {int offset = 0}) async {
    ifrmaeParserTimer?.cancel();
    videoParserTimer?.cancel();
    await unloadPage();
    count = 0;
    this.offset = offset;
    isIframeLoaded = false;
    isVideoSourceLoaded = false;
    videoPageController.loading = true;
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
    if (videoPageController.currentPlugin.useNativePlayer) {
      videoParserTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (isVideoSourceLoaded) {
          timer.cancel();
        } else {
          if (count >= 15) {
            timer.cancel();
            isIframeLoaded = true;
            videoPageController.logLines.clear();
            videoPageController.logLines.add('解析视频资源超时');
            videoPageController.logLines.add('请切换到其他播放列表或视频源');
            videoPageController.showDebugLog = true;
          } else {
            if (!videoPageController.currentPlugin.useLegacyParser) {
              parseVideoSource();
            }
          }
        }
      });
    }
  }

  @override
  unloadPage() async {
    await redirect2Blank();
    await webviewController!.clearCache();
  }

  @override
  dispose() {
    webviewController!.dispose();
  }

  initJSBridge() async {
    webviewController!.webMessage.listen((event) async {
      if (event.toString().contains('iframeMessage:')) {
        String messageItem =
            Uri.encodeFull(event.toString().replaceFirst('iframeMessage:', ''));
        debugPrint('JS Bridge: $messageItem');
        videoPageController.logLines
            .add('Callback received: ${Uri.decodeFull(messageItem)}');
        videoPageController.logLines.add(
            'If there is audio but no video, please report it to the rule developer.');
        if (messageItem.contains('http') || messageItem.startsWith('//')) {
          videoPageController.logLines.add('Parsing video source $messageItem');
          if (Utils.decodeVideoSource(messageItem) !=
                  Uri.encodeFull(messageItem) &&
              videoPageController.currentPlugin.useNativePlayer &&
              videoPageController.currentPlugin.useLegacyParser) {
            isIframeLoaded = true;
            isVideoSourceLoaded = true;
            videoPageController.loading = false;
            videoPageController.logLines.add(
                'Loading video source ${Utils.decodeVideoSource(messageItem)}');
            debugPrint(
                'Loading video source from ifame src ${Utils.decodeVideoSource(messageItem)}');
            unloadPage();
            playerController.videoUrl = Utils.decodeVideoSource(messageItem);
            playerController.init(offset: offset);
          }
          if (!videoPageController.currentPlugin.useNativePlayer) {
            Future.delayed(const Duration(seconds: 2), () {
              isIframeLoaded = true;
              videoPageController.loading = false;
            });
          }
        }
      }
      if (event.toString().contains('videoMessage:')) {
        String messageItem =
            Uri.encodeFull(event.toString().replaceFirst('videoMessage:', ''));
        debugPrint('VideoJS Bridge: $messageItem');
        videoPageController.logLines
            .add('Callback received: ${Uri.decodeFull(messageItem)}');
        if (messageItem.contains('http') && !isVideoSourceLoaded) {
          String videoUrl = Uri.decodeFull(messageItem);
          debugPrint('Loading video source $videoUrl');
          videoPageController.logLines.add('Loading video source $videoUrl');
          isIframeLoaded = true;
          isVideoSourceLoaded = true;
          videoPageController.loading = false;
          if (videoPageController.currentPlugin.useNativePlayer) {
            unloadPage();
            playerController.videoUrl = videoUrl;
            playerController.init(offset: offset);
          }
        }
      }
    });
  }

  parseIframeUrl() async {
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
  parseVideoSource() async {
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
  initBlobParser() async {
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

  initInviewIframeBridge() async {
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
  redirect2Blank() async {
    await webviewController!.executeScript('''
      window.location.href = 'about:blank';
    ''');
  }
}
