import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewItemController {
  bool isIframeLoaded = false;
  bool isVideoSourceLoaded = false;
  WebViewController webviewController = WebViewController();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PlayerController playerController = Modular.get<PlayerController>();

  loadUrl(String url) async {
    await unloadPage();
    await webviewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await webviewController.addJavaScriptChannel('JSBridgeDebug',
        onMessageReceived: (JavaScriptMessage message) {
      debugPrint('JS桥收到的消息为 ${message.message}');
      if (message.message.contains('http')) {
        isIframeLoaded = true;
        if (Utils.decodeVideoSource(message.message) != message.message) {
          debugPrint(
            '由iframe参数获取视频源 ${Utils.decodeVideoSource(message.message)}');
          isVideoSourceLoaded = true;
          if (videoPageController.currentPlugin.useNativePlayer) {
            unloadPage();
            playerController.videoUrl = Utils.decodeVideoSource(message.message);
            playerController.init();
          }
          videoPageController.loading = false;
        }
      }
    });
    await webviewController.addJavaScriptChannel('VideoBridgeDebug',
        onMessageReceived: (JavaScriptMessage message) {
      debugPrint('VideoJS桥收到的消息为 ${message.message}');
      if (message.message.contains('http')) {
        debugPrint('由video标签获取视频源 ${message.message}');
        isVideoSourceLoaded = true;
        if (videoPageController.currentPlugin.useNativePlayer) {
            unloadPage();
            playerController.videoUrl = message.message;
            playerController.init();
          }
        videoPageController.loading = false;
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
        parseVideoSource();
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
    await webviewController.loadRequest(Uri.parse('about:blank'));
    await webviewController.clearCache();
    isIframeLoaded = false;
    isVideoSourceLoaded = false;
    videoPageController.loading = true;
  }

  // loadIframe(String url) async {
  //   await webviewController.loadRequest(Uri.parse(url),
  //       headers: {'Referer': videoPageController.currentPlugin.baseUrl + '/'});
  // }

  parseIframeUrl() async {
    await webviewController.runJavaScript('''
      var iframes = document.getElementsByTagName('iframe');
      JSBridgeDebug.postMessage('iframe 标签数量为');
      JSBridgeDebug.postMessage(iframes.length);
      for (var i = 0; i < iframes.length; i++) {
          var iframe = iframes[i];
          var src = iframe.getAttribute('src');

          if (src && src.trim() !== '' && src.includes('http')) {
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
      VideoBridgeDebug.postMessage('video 标签数量为');
      VideoBridgeDebug.postMessage(videos.length);
      for (var i = 0; i < videos.length; i++) {
        var src = videos[i].getAttribute('src');
        if (src && src.trim() !== '' && !src.startsWith('blob:')) {
          VideoBridgeDebug.postMessage(src);
        } 
      }
    ''');
  }
}
