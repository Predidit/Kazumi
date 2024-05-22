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
    isIframeLoaded = false;
    isVideoSourceLoaded = false;
    videoPageController.loading = true;
    await webviewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await webviewController.addJavaScriptChannel('JSBridgeDebug',
        onMessageReceived: (JavaScriptMessage message) {
      debugPrint('JS桥收到的消息为 ${message.message}');
      videoPageController.logLines.add('Callback received: ${message.message}');
      videoPageController.logLines.add(
          'If there is audio but no video, please report it to the rule developer.');
      if (message.message.contains('http')) {
        isIframeLoaded = true;
        if (Utils.decodeVideoSource(message.message) != Uri.encodeFull(message.message)) {
          debugPrint(
              '由iframe参数获取视频源 ${Utils.decodeVideoSource(message.message)}');
          videoPageController.logLines.add('Loading video source ${Utils.decodeVideoSource(message.message)}');
          isVideoSourceLoaded = true;
          videoPageController.loading = false;
          if (videoPageController.currentPlugin.useNativePlayer) {
            unloadPage();
            playerController.videoUrl =
                Utils.decodeVideoSource(message.message);
            playerController.init();
          }
        }
      }
    });
    await webviewController.addJavaScriptChannel('VideoBridgeDebug',
        onMessageReceived: (JavaScriptMessage message) {
      debugPrint('VideoJS桥收到的消息为 ${message.message}');
      videoPageController.logLines.add('Callback received: ${message.message}');
      if (message.message.contains('http')) {
        debugPrint('由video标签获取视频源 ${message.message}');
        videoPageController.logLines.add('Loading video source ${message.message}');
        isVideoSourceLoaded = true;
        videoPageController.loading = false;
        if (videoPageController.currentPlugin.useNativePlayer) {
          unloadPage();
          playerController.videoUrl = message.message;
          playerController.init();
        }
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
  }

  // loadIframe(String url) async {
  //   await webviewController.loadRequest(Uri.parse(url),
  //       headers: {'Referer': videoPageController.currentPlugin.baseUrl + '/'});
  // }

  parseIframeUrl() async {
    await webviewController.runJavaScript('''
      var iframes = document.getElementsByTagName('iframe');
      JSBridgeDebug.postMessage('The number of iframe tags is');
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
      VideoBridgeDebug.postMessage('The number of video tags is');
      VideoBridgeDebug.postMessage(videos.length);
      for (var i = 0; i < videos.length; i++) {
        var src = videos[i].getAttribute('src');
        if (src && src.trim() !== '' && !src.startsWith('blob:')) {
          VideoBridgeDebug.postMessage(src);
          break;
        } 
      }
    ''');
  }
}
