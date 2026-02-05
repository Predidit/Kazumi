import 'dart:io';
import 'dart:async';

import 'package:kazumi/webview/webview_controller_impel/webview_android_controller_impel.dart';
import 'package:kazumi/webview/webview_controller_impel/webview_controller_impel.dart';
import 'package:kazumi/webview/webview_controller_impel/webview_windows_controller_impel.dart';
import 'package:kazumi/webview/webview_controller_impel/webview_linux_controller_impel.dart';
import 'package:kazumi/webview/webview_controller_impel/webview_apple_controller_impel.dart';
import 'package:kazumi/utils/utils.dart';

abstract class WebviewItemController<T> {
  // Webview controller
  T? webviewController;

  // Retry count
  int count = 0;
  // Last watched position
  int offset = 0;
  bool isIframeLoaded = false;
  bool isVideoSourceLoaded = false;

  /// Webview initialization method
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

  // Stream to notify video source URL when the video source is loaded
  // The first parameter is the video source URL and the second parameter is the video offset (start position)
  final StreamController<(String, int)> videoParserEventController =
      StreamController<(String, int)>.broadcast();

  Stream<(String, int)> get onVideoURLParser => videoParserEventController.stream;

  /// Webview load URL method
  Future<void> loadUrl(String url, bool useLegacyParser,
      {int offset = 0});

  /// Webview unload page method
  Future<void> unloadPage();

  /// Webview dispose method
  void dispose();
}

class WebviewItemControllerFactory {
  static WebviewItemController getController() {
    if (Platform.isWindows) {
      return WebviewWindowsItemControllerImpel();
    }
    if (Platform.isLinux) {
      return WebviewLinuxItemControllerImpel();
    }
    if (Platform.isMacOS || Platform.isIOS) {
      return WebviewAppleItemControllerImpel();
    }
    if (Platform.isAndroid && Utils.isDocumentStartScriptSupported) {
      return WebviewAndroidItemControllerImpel();
    }
    return WebviewItemControllerImpel();
  }
}
