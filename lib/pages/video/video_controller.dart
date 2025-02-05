import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:mobx/mobx.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/logger.dart';

part 'video_controller.g.dart';

class VideoPageController = _VideoPageController with _$VideoPageController;

abstract class _VideoPageController with Store {
  @observable
  bool loading = true;

  @observable
  int currentEpisode = 1;

  @observable
  int currentRoad = 0;

  /// 全屏状态
  @observable
  bool isFullscreen = false;

  /// 画中画状态
  @observable
  bool isPip = false;

  /// 播放列表显示状态
  @observable
  bool showTabBody = true;

  /// 上次观看位置
  @observable
  int historyOffset = 0;

  String title = '';

  String src = '';

  @observable
  var roadList = ObservableList<Road>();

  late Plugin currentPlugin;

  final PluginsController pluginsController = Modular.get<PluginsController>();
  final HistoryController historyController = Modular.get<HistoryController>();

  Future<void> changeEpisode(int episode,
      {int currentRoad = 0, int offset = 0}) async {
    currentEpisode = episode;
    this.currentRoad = currentRoad;
    String chapterName = roadList[currentRoad].identifier[episode - 1];
    KazumiLogger().log(Level.info, '跳转到$chapterName');
    String urlItem = roadList[currentRoad].data[episode - 1];
    if (urlItem.contains(currentPlugin.baseUrl) ||
        urlItem.contains(currentPlugin.baseUrl.replaceAll('https', 'http'))) {
      urlItem = urlItem;
    } else {
      urlItem = currentPlugin.baseUrl + urlItem;
    }
    if (urlItem.startsWith('http://')) {
      urlItem = urlItem.replaceFirst('http', 'https');
    }
    final webviewItemController = Modular.get<WebviewItemController>();
    await webviewItemController.loadUrl(
        urlItem, currentPlugin.useNativePlayer, currentPlugin.useLegacyParser,
        offset: offset);
  }

  void enterFullScreen() {
    isFullscreen = true;
    showTabBody = false;
    Utils.enterFullScreen(lockOrientation: false);
  }

  void exitFullScreen() {
    isFullscreen = false;
    Utils.exitFullScreen();
  }
}
