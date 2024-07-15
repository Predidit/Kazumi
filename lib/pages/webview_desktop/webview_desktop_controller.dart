import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:webview_windows/webview_windows.dart';

class WebviewDesktopItemController {
  // 重试次数
  int count = 0;
  // 上次观看位置
  int offset = 0;
  bool isIframeLoaded = false;
  bool isVideoSourceLoaded = false;
  WebviewController webviewController = WebviewController();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PlayerController playerController = Modular.get<PlayerController>();

  /// Why is this implementation so outrageous?
  /// To take care of the quirks of webview_windows, this component must have been initialized before entering the component tree.
  /// If this component enters the component tree during initialization, it will never be initialized.
  init() async {
    await webviewController.initialize();
    await webviewController.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    await initJSBridge();
    if (videoPageController.currentPlugin.useNativePlayer) {
      await initBlobParser();
    }
    videoPageController.changeEpisode(videoPageController.currentEspisode,
        currentRoad: videoPageController.currentRoad,
        offset: videoPageController.historyOffset);
  }

  loadUrl(String url, {int offset = 0}) async {
    await unloadPage();
    count = 0;
    this.offset = offset;
    isIframeLoaded = false;
    isVideoSourceLoaded = false;
    videoPageController.loading = true;
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

  initJSBridge() async {
    webviewController.webMessage.listen((event) async {
      if (event.toString().contains('iframeMessage:')) {
        String messageItem =
            Uri.encodeFull(event.toString().replaceFirst('iframeMessage:', ''));
        debugPrint('JS Bridge: $messageItem');
        videoPageController.logLines
            .add('Callback received: ${Uri.decodeFull(messageItem)}');
        videoPageController.logLines.add(
            'If there is audio but no video, please report it to the rule developer.');
        if (messageItem.contains('http')) {
          videoPageController.logLines.add('Parsing video source $messageItem');
          isIframeLoaded = true;
          // 基于iframe参数刮削的方案由于不稳定而弃用，改用Hook关键函数的方案
          // if (Utils.decodeVideoSource(messageItem) !=
          //         Uri.encodeFull(messageItem) &&
          //     !isVideoSourceLoaded) {
          //   isVideoSourceLoaded = true;
          //   videoPageController.loading = false;
          //   videoPageController.logLines.add(
          //       'Loading video source ${Utils.decodeVideoSource(messageItem)}');
          //   debugPrint(
          //       '由iframe参数获取视频源 ${Utils.decodeVideoSource(messageItem)}');
          //   if (videoPageController.currentPlugin.useNativePlayer) {
          //     unloadPage();
          //     playerController.videoUrl = Utils.decodeVideoSource(messageItem);
          //     playerController.init(offset: offset);
          //   }
          // }
        }
      }
      if (event.toString().contains('videoMessage:')) {
        String messageItem =
            Uri.encodeFull(event.toString().replaceFirst('videoMessage:', ''));
        debugPrint('VideoJS Bridge: $messageItem');
        videoPageController.logLines
            .add('Callback received: ${Uri.decodeFull(messageItem)}');
        count++;
        if (messageItem.contains('http') && !isVideoSourceLoaded) {
          debugPrint('Loading video source ${Uri.decodeFull(messageItem)}');
          videoPageController.logLines
              .add('Loading video source ${Uri.decodeFull(messageItem)}');
          isVideoSourceLoaded = true;
          videoPageController.loading = false;
          if (videoPageController.currentPlugin.useNativePlayer) {
            unloadPage();
            playerController.videoUrl = messageItem;
            playerController.init(offset: offset);
          }
        }
      }
    });
  }

  unloadPage() async {
    await redirect2Blank();
    await webviewController.clearCache();
  }

  parseIframeUrl() async {
    await webviewController.executeScript('''
      var iframes = document.getElementsByTagName('iframe');
      window.chrome.webview.postMessage('iframeMessage:' + 'The number of iframe tags is' + iframes.length);
      for (var i = 0; i < iframes.length; i++) {
          var iframe = iframes[i];
          var src = iframe.getAttribute('src');

          if (src && src.trim() !== '' && src.includes('http') && !src.includes('googleads')) {
              window.chrome.webview.postMessage('iframeMessage:' + src);
              window.location.href = src;
              break; 
          }
      }
  ''');
  }

  // 非blob资源
  parseVideoSource() async {
    await webviewController.executeScript('''
      var videos = document.querySelectorAll('video');
      window.chrome.webview.postMessage('videoMessage:' + 'The number of video tags is' + videos.length);
      for (var i = 0; i < videos.length; i++) {
        var src = videos[i].getAttribute('src');
        if (src && src.trim() !== '' && !src.startsWith('blob:') && !src.includes('googleads')) {
          window.chrome.webview.postMessage('videoMessage:' + src);
        } 
      }
    ''');
  }

  // blob资源
  initBlobParser() async {
    await webviewController.addScriptToExecuteOnDocumentCreated('''
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
    ''');
  }

  // webview_windows本身无此方法，loadurl方法相当于打开新标签页，会造成内存泄漏
  // 而直接销毁 webview 控制器会导致更换选集时需要重新初始化，webview 重新初始化开销较大
  // 故使用此方法
  redirect2Blank() async {
    await webviewController.executeScript('''
      window.location.href = 'about:blank';
    ''');
  }
}
