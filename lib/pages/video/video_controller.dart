import 'dart:io';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:kazumi/pages/webview_desktop/webview_desktop_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:window_manager/window_manager.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';

part 'video_controller.g.dart';

class VideoPageController = _VideoPageController with _$VideoPageController;

abstract class _VideoPageController with Store {
  @observable
  bool loading = true;

  @observable
  ObservableList<String> logLines = ObservableList.of([]);

  @observable
  int currentEspisode = 1;

  @observable
  int currentRoad = 0;

  // 安卓全屏状态
  @observable
  bool androidFullscreen = false;

  // 上次观看位置
  @observable
  int historyOffset = 0;

  String title = '';

  String src = '';

  @observable
  var roadList = ObservableList<Road>();

  late Plugin currentPlugin;

  final PluginsController pluginsController = Modular.get<PluginsController>();
  final HistoryController historyController = Modular.get<HistoryController>();

  changeEpisode(int episode, {int currentRoad = 0, int offset = 0}) async {
    loading = true;
    currentEspisode = episode;
    this.currentRoad = currentRoad;
    logLines.clear();
    debugPrint('跳转到第$episode话');
    String urlItem = roadList[currentRoad].data[episode - 1];
    if (urlItem.contains(currentPlugin.baseUrl) || urlItem.contains(currentPlugin.baseUrl.replaceAll('https', 'http'))) {
      urlItem = urlItem;
    } else {
      urlItem = currentPlugin.baseUrl + urlItem;
    }
    if (urlItem.startsWith('http://')) {
      urlItem = urlItem.replaceFirst('http', 'https');
    }
    if (Platform.isWindows) {
      final WebviewDesktopItemController webviewDesktopItemController =
          Modular.get<WebviewDesktopItemController>();
      await webviewDesktopItemController
          .loadUrl(urlItem, offset: offset);
    } else {
      final WebviewItemController webviewItemController =
          Modular.get<WebviewItemController>();
      await webviewItemController.loadUrl(urlItem, offset: offset);
    }
  }

  Future<void> enterFullScreen() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setFullScreen(true);
      return;
    }
    // await SystemChrome.setPreferredOrientations([
    //   DeviceOrientation.portraitUp,
    // ]);
    await landScape();
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  //退出全屏显示
  Future<void> exitFullScreen() async {
    debugPrint('退出全屏模式');
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setFullScreen(false);
    }
    dynamic document;
    late SystemUiMode mode = SystemUiMode.edgeToEdge;
    try {
      if (kIsWeb) {
        document.exitFullscreen();
      } else if (Platform.isAndroid || Platform.isIOS) {
        if (Platform.isAndroid &&
            (await DeviceInfoPlugin().androidInfo).version.sdkInt < 29) {
          mode = SystemUiMode.manual;
        }
        await SystemChrome.setEnabledSystemUIMode(
          mode,
          overlays: SystemUiOverlay.values,
        );
        // await SystemChrome.setPreferredOrientations([]);
        if (Utils.isCompact()) {
          verticalScreen();
        }
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        await const MethodChannel('com.alexmercerind/media_kit_video')
            .invokeMethod(
          'Utils.ExitNativeFullscreen',
        );
        // verticalScreen();
      }
    } catch (exception, stacktrace) {
      debugPrint(exception.toString());
      debugPrint(stacktrace.toString());
    }
  }

  //横屏
  Future<void> landScape() async {
    dynamic document;
    try {
      if (kIsWeb) {
        await document.documentElement?.requestFullscreen();
      } else if (Platform.isAndroid || Platform.isIOS) {
        // await SystemChrome.setEnabledSystemUIMode(
        //   SystemUiMode.immersiveSticky,
        //   overlays: [],
        // );
        await SystemChrome.setPreferredOrientations(
          [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
        );
        // await AutoOrientation.landscapeAutoMode(forceSensor: true);
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        await const MethodChannel('com.alexmercerind/media_kit_video')
            .invokeMethod(
          'Utils.EnterNativeFullscreen',
        );
      }
    } catch (exception, stacktrace) {
      debugPrint(exception.toString());
      debugPrint(stacktrace.toString());
    }
  }

//竖屏
  Future<void> verticalScreen() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }
}
