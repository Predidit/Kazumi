import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewItemController {
  // 重试次数
  int count = 0;
  // 上次观看位置
  int offset = 0;
  bool isIframeLoaded = false;
  bool isVideoSourceLoaded = false;
  WebViewController webviewController = WebViewController();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PlayerController playerController = Modular.get<PlayerController>();

  loadUrl(String url, {int offset = 0}) async {
    await unloadPage();
    await setDesktopUserAgent();
    count = 0;
    this.offset = offset;
    isIframeLoaded = false;
    isVideoSourceLoaded = false;
    videoPageController.loading = true;
    await webviewController
        .setNavigationDelegate(NavigationDelegate(onUrlChange: (currentUrl) {
      debugPrint('Current URL: ${currentUrl.url}');
      if (videoPageController.currentPlugin.useNativePlayer) {
        addBlobParser();
        addInviewIframeBridge();
      }
      addFullscreenListener();
    }));
    await webviewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await webviewController.addJavaScriptChannel('JSBridgeDebug',
        onMessageReceived: (JavaScriptMessage message) {
      debugPrint('JS Bridge: ${message.message}');
      videoPageController.logLines.add('Callback received: ${message.message}');
      videoPageController.logLines.add(
          'If there is audio but no video, please report it to the rule developer.');
      if (message.message.contains('http')) {
        videoPageController.logLines
            .add('Parsing video source ${message.message}');
        if (!videoPageController.currentPlugin.useNativePlayer) {
          Future.delayed(const Duration(seconds: 2), () {
            isIframeLoaded = true;
            videoPageController.loading = false;
          });
        }
      }
    });
    await webviewController.addJavaScriptChannel('VideoBridgeDebug',
        onMessageReceived: (JavaScriptMessage message) {
      debugPrint('VideoJS Bridge: ${message.message}');
      videoPageController.logLines.add('Callback received: ${message.message}');
      count++;
      if (message.message.contains('http') && !isVideoSourceLoaded) {
        debugPrint('Loading video source: ${message.message}');
        videoPageController.logLines
            .add('Loading video source: ${message.message}');
        isIframeLoaded = true;
        isVideoSourceLoaded = true;
        videoPageController.loading = false;
        if (videoPageController.currentPlugin.useNativePlayer) {
          unloadPage();
          playerController.videoUrl = message.message;
          playerController.init(offset: offset);
        }
      }
    });
    await webviewController.addJavaScriptChannel('FullscreenBridgeDebug',
        onMessageReceived: (JavaScriptMessage message) {
      debugPrint('FullscreenJS桥收到的消息为 ${message.message}');
      if (message.message == 'enteredFullscreen') {
        videoPageController.androidFullscreen = true;
        videoPageController.enterFullScreen();
      }
      if (message.message == 'exitedFullscreen') {
        videoPageController.androidFullscreen = false;
        videoPageController.exitFullScreen();
      }
    });
    await webviewController.loadRequest(Uri.parse(url));

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isIframeLoaded) {
        timer.cancel();
      } else {
        parseIframeUrl();
      }
    });
    if (videoPageController.currentPlugin.useNativePlayer) {
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (isVideoSourceLoaded) {
          timer.cancel();
        } else {
          if (count >= 15) {
            timer.cancel();
            isIframeLoaded = true;
            videoPageController.logLines.clear();
            videoPageController.logLines.add('解析视频资源超时');
            videoPageController.logLines.add('请切换到其他播放列表或视频源');
          } else {
            parseVideoSource();
          }
        }
      });
    }
  }

  unloadPage() async {
    await webviewController
        .removeJavaScriptChannel('JSBridgeDebug')
        .catchError((_) {});
    await webviewController
        .removeJavaScriptChannel('VideoBridgeDebug')
        .catchError((_) {});
    await webviewController
        .removeJavaScriptChannel('FullscreenBridgeDebug')
        .catchError((_) {});
    await webviewController.loadRequest(Uri.parse('about:blank'));
    await webviewController.clearCache();
  }

  parseIframeUrl() async {
    await webviewController.runJavaScript('''
      var iframes = document.getElementsByTagName('iframe');
      JSBridgeDebug.postMessage('The number of iframe tags is' + iframes.length);
      for (var i = 0; i < iframes.length; i++) {
          var iframe = iframes[i];
          var src = iframe.getAttribute('src');

          if (src && src.trim() !== '' && src.includes('http') && !src.includes('googleads') && !src.includes('prestrain.html') && !src.includes('prestrain%2Ehtml')) {
              window.location.href = src;
              JSBridgeDebug.postMessage(src);
              break; 
          }
      }
  ''');
  }

  // 非blob资源
  parseVideoSource() async {
    await webviewController.runJavaScript('''
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
  addBlobParser() async {
    await webviewController.runJavaScript('''
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
                  if (content.trim().startsWith("#EXTM3U")) {
                      VideoBridgeDebug.postMessage(args[1]);
                  };
              } catch { }
          });
          return _open.apply(this, args);
      }     
    ''');
  }

  addInviewIframeBridge() async {
    await webviewController.runJavaScript('''
      window.addEventListener("message", function(event) {
        if (event.data) {
          if (event.data.message && event.data.message.startsWith('videoMessage:')) {
            VideoBridgeDebug.postMessage(event.data.message.replace(/^videoMessage:/, ''));
          }
        }
      });
    ''');
  }

  // 设定UA
  setDesktopUserAgent() async {
    String desktopUserAgent = Utils.getRandomUA();
    await webviewController.setUserAgent(desktopUserAgent);
  }

  // 全屏监听
  addFullscreenListener() async {
    await webviewController.runJavaScript('''
      document.addEventListener('fullscreenchange', () => {
            if (document.fullscreenElement) {
                FullscreenBridgeDebug.postMessage('enteredFullscreen');
            } else {
                FullscreenBridgeDebug.postMessage('exitedFullscreen');
            }
        });
    ''');
  }
}
