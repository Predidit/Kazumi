import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewItemController {
  int count = 0;
  bool isIframeLoaded = false;
  bool isVideoSourceLoaded = false;
  WebViewController webviewController = WebViewController();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PlayerController playerController = Modular.get<PlayerController>();

  loadUrl(String url) async {
    await unloadPage();
    count = 0;
    isIframeLoaded = false;
    isVideoSourceLoaded = false;
    videoPageController.loading = true;
    await webviewController.setNavigationDelegate(
        NavigationDelegate(onUrlChange: (_) => addFullscreenListener()));
    await webviewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await webviewController.addJavaScriptChannel('JSBridgeDebug',
        onMessageReceived: (JavaScriptMessage message) {
      debugPrint('JS桥收到的消息为 ${message.message}');
      videoPageController.logLines.add('Callback received: ${message.message}');
      videoPageController.logLines.add(
          'If there is audio but no video, please report it to the rule developer.');
      if (message.message.contains('http')) {
        isIframeLoaded = true;
        if (Utils.decodeVideoSource(message.message) !=
            Uri.encodeFull(message.message)) {
          debugPrint(
              '由iframe参数获取视频源 ${Utils.decodeVideoSource(message.message)}');
          videoPageController.logLines.add(
              'Loading video source ${Utils.decodeVideoSource(message.message)}');
          isVideoSourceLoaded = true;
          videoPageController.loading = false;
          if (videoPageController.currentPlugin.useNativePlayer) {
            unloadPage();
            playerController.videoUrl =
                Utils.decodeVideoSource(message.message);
            playerController.init();
          } else {
            addFullscreenListener();
          }
        }
      }
    });
    await webviewController.addJavaScriptChannel('VideoBridgeDebug',
        onMessageReceived: (JavaScriptMessage message) {
      debugPrint('VideoJS桥收到的消息为 ${message.message}');
      videoPageController.logLines.add('Callback received: ${message.message}');
      count++;
      if (message.message.contains('http')) {
        debugPrint('由video标签获取视频源 ${message.message}');
        videoPageController.logLines
            .add('Loading video source ${message.message}');
        isVideoSourceLoaded = true;
        videoPageController.loading = false;
        if (videoPageController.currentPlugin.useNativePlayer) {
          unloadPage();
          playerController.videoUrl = message.message;
          playerController.init();
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
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isVideoSourceLoaded) {
        timer.cancel();
      } else {
        if (count >= 15) {
          timer.cancel();
          videoPageController.logLines.clear();
          videoPageController.logLines.add('解析视频资源超时');
          videoPageController.logLines.add('请切换到其他播放列表或视频源');
        } else {
          parseVideoSource();
        }
      }
    });
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

  // loadIframe(String url) async {
  //   await webviewController.loadRequest(Uri.parse(url),
  //       headers: {'Referer': videoPageController.currentPlugin.baseUrl + '/'});
  // }

  parseIframeUrl() async {
    await webviewController.runJavaScript('''
      var iframes = document.getElementsByTagName('iframe');
      JSBridgeDebug.postMessage('The number of iframe tags is' + iframes.length);
      for (var i = 0; i < iframes.length; i++) {
          var iframe = iframes[i];
          var src = iframe.getAttribute('src');

          if (src && src.trim() !== '' && src.includes('http') && !src.includes('googleads')) {
              window.location.href = src;
              JSBridgeDebug.postMessage(src);
              break; 
          }
      }
  ''');
  }

  // blob解码问题无法解决
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
    ''');
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
