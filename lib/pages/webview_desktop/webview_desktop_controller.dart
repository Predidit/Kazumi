import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:webview_windows/webview_windows.dart';

class WebviewDesktopItemController {
  bool isIframeLoaded = false;
  bool isVideoSourceLoaded = false;
  WebviewController webviewController = WebviewController();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PlayerController playerController = Modular.get<PlayerController>();

  init() async {
    await webviewController.initialize();
    // 初始化JS监听器
    await initJSBridge();
  }

  loadUrl(String url) async {
    await unloadPage();
    await webviewController.loadUrl(url);

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
        parseVideoSource();
      }
    });
  }

  initJSBridge() async {
    webviewController.webMessage.listen((event) async {
      if (event.toString().contains('iframeMessage:')) {
        String messageItem =
            event.toString().replaceFirst('iframeMessage:', '');
        debugPrint('由JS桥收到的消息为 $messageItem');
        if (messageItem.contains('https')) {
          debugPrint('成功加载 iframe');
          isIframeLoaded = true;
          debugPrint('由iframe参数获取视频源 ${Utils.decodeVideoSource(messageItem)}');
          if (Utils.decodeVideoSource(messageItem) != '') {
            isVideoSourceLoaded = true;
            if (videoPageController.currentPlugin.useNativePlayer == 'true') {
              unloadPage();
              playerController.videoUrl = Utils.decodeVideoSource(messageItem);
              playerController.init();
            }
            videoPageController.loading = false;
          }
        }
      }
      if (event.toString().contains('videoMessage:')) {
        String messageItem = event.toString().replaceFirst('videoMessage:', '');
        debugPrint('由VideoJS桥收到的消息为 $messageItem');
        if (messageItem.contains('https')) {
          debugPrint('成功获取视频源');
          isVideoSourceLoaded = true;
          if (videoPageController.currentPlugin.useNativePlayer == 'true') {
            unloadPage();
            playerController.videoUrl = messageItem;
            playerController.init();
          }
          videoPageController.loading = false;
        }
      }
    });
  }

  unloadPage() async {
    await webviewController.loadUrl('about:blank');
    await webviewController.clearCache();
    isIframeLoaded = false;
    isVideoSourceLoaded = false;
    videoPageController.loading = true;
  }

  parseIframeUrl() async {
    await webviewController.executeScript('''
      var iframes = document.getElementsByTagName('iframe');
      for (var i = 0; i < iframes.length; i++) {
          var iframe = iframes[i];
          var src = iframe.getAttribute('src');

          if (src && src.trim() !== '' && src.includes('https')) {
              window.chrome.webview.postMessage('iframeMessage:' + src);
              window.location.href = src;
              break; 
          }
      }
  ''');
  }

  // blob解码问题无法解决
  parseVideoSource() async {
    await webviewController.executeScript('''
      var videos = document.querySelectorAll('video');
      for (var i = 0; i < videos.length; i++) {
        var src = videos[i].getAttribute('src');
        if (src && src.trim() !== '' && !src.startsWith('blob:')) {
          window.chrome.webview.postMessage('videoMessage:' + src);
        } 
      }
    ''');
  }
}
