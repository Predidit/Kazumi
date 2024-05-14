import 'dart:io';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/plugins/plugins.dart';
// import 'package:kazumi/pages/webview/webview_controller.dart';
// import 'package:kazumi/pages/webview_desktop/webview_desktop_controller.dart';
import 'package:mobx/mobx.dart';

part 'video_controller.g.dart';

class VideoPageController = _VideoPageController with _$VideoPageController;

abstract class _VideoPageController with Store {
  @observable
  bool loading = true;

  @observable
  int currentEspisode = 1;

  @observable
  var roadList = ObservableList<Road>();

  late Plugin currentPlugin;

  final PluginsController pluginsController = Modular.get<PluginsController>();

  // @observable
  // bool get isIframeLoaded {
  //   if (Platform.isWindows) {
  //     final WebviewDesktopItemController webviewDesktopItemController =
  //         Modular.get<WebviewDesktopItemController>();
  //     return webviewDesktopItemController.isIframeLoaded;
  //   } else {
  //     final WebviewItemController webviewItemController = Modular.get<WebviewItemController>();
  //     return webviewItemController.isIframeLoaded;
  //   }
  // }

  Future<String> queryVideoUrl(String url) async {
    String videoUrl = '';
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == currentPlugin.name) {
        videoUrl = await plugin.queryVideoUrl(url);
      }
    }
    return videoUrl;
  }
}
