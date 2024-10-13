import 'dart:io';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/webview/webview_controller_impel/webview_controller_impel.dart';
import 'package:kazumi/pages/webview/webview_controller_impel/webview_windows_controller_impel.dart';
import 'package:kazumi/pages/webview/webview_controller_impel/webview_linux_controller_impel.dart';

abstract class WebviewItemController<T> {
  // Webview controller
  T? webviewController;

  // Retry count
  int count = 0;
  // Last watched position
  int offset = 0;
  bool isIframeLoaded = false;
  bool isVideoSourceLoaded = false;
  VideoPageController videoPageController = Modular.get<VideoPageController>();
  PlayerController playerController = Modular.get<PlayerController>();

  /// Webview initialization method
  /// This method should eventually call the changeEpisode method of videoController
  init();

  /// Webview load URL method
  loadUrl(String url, {int offset = 0});

  /// Webview unload page method
  unloadPage();

  /// Webview dispose method
  dispose();
}

class WebviewItemControllerFactory {
  static WebviewItemController getController() {
    if (Platform.isWindows) {
      return WebviewWindowsItemControllerImpel();
    }
    if (Platform.isLinux) {
      return WebviewLinuxItemControllerImpel();
    }
    return WebviewItemControllerImpel();
  }
}
