import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kazumi/webview/video/impl/video_webview_android_impl.dart';
import 'package:kazumi/webview/video/impl/video_webview_impl.dart';
import 'package:kazumi/webview/video/impl/video_webview_windows_impl.dart';
import 'package:kazumi/webview/video/impl/video_webview_linux_impl.dart';
import 'package:kazumi/webview/video/impl/video_webview_apple_impl.dart';
import 'package:kazumi/services/platform/webview_feature_service.dart';
import 'package:kazumi/services/video_source/video_source_format.dart';

typedef VideoParserEvent = ({
  String url,
  int offset,
  VideoSourceFormat format,
});

abstract class VideoWebviewController<T> {
  // WebView controller.
  T? webviewController;

  // Retry count
  int count = 0;
  // Last watched position
  int offset = 0;
  bool isIframeLoaded = false;
  bool isVideoSourceLoaded = false;

  /// WebView initialization method.
  Future<void> init();

  final StreamController<bool> initEventController =
      StreamController<bool>.broadcast();

  // Stream to notify when the webview is initialized
  Stream<bool> get onInitialized => initEventController.stream;

  final StreamController<String> logEventController =
      StreamController<String>.broadcast();

  // Stream to subscribe to webview logs
  Stream<String> get onLog => logEventController.stream;

  final StreamController<bool> videoLoadingEventController =
      StreamController<bool>.broadcast();

  // Stream to notify when the video source is loaded
  Stream<bool> get onVideoLoading => videoLoadingEventController.stream;

  // Stream to notify when a video source URL is resolved, including its
  // playback offset and any format information confirmed by the parser.
  final StreamController<VideoParserEvent> _videoParserEventController =
      StreamController<VideoParserEvent>.broadcast();

  Stream<VideoParserEvent> get onVideoURLParser =>
      _videoParserEventController.stream;

  @protected
  void notifyVideoSourceResolved(
    String url, {
    VideoSourceFormat format = VideoSourceFormat.auto,
  }) {
    _videoParserEventController.add((
      url: url,
      offset: offset,
      format: format,
    ));
  }

  void disposeEventControllers() {
    if (!initEventController.isClosed) {
      initEventController.close();
    }
    if (!logEventController.isClosed) {
      logEventController.close();
    }
    if (!videoLoadingEventController.isClosed) {
      videoLoadingEventController.close();
    }
    if (!_videoParserEventController.isClosed) {
      _videoParserEventController.close();
    }
  }

  /// WebView load URL method.
  Future<void> loadUrl(String url, bool useLegacyParser, {int offset = 0});

  /// WebView unload page method.
  Future<void> unloadPage();

  /// WebView dispose method.
  Future<void> dispose();
}

class VideoWebviewControllerFactory {
  static VideoWebviewController getController() {
    if (Platform.isWindows) {
      return VideoWebviewWindowsImpl();
    }
    if (Platform.isLinux) {
      return VideoWebviewLinuxImpl();
    }
    if (Platform.isMacOS || Platform.isIOS) {
      return VideoWebviewAppleImpl();
    }
    if (Platform.isAndroid &&
        WebViewFeatureService.isDocumentStartScriptSupported) {
      return VideoWebviewAndroidImpl();
    }
    return VideoWebviewImpl();
  }
}
