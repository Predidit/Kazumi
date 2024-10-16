import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:mobx/mobx.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';

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

  // 播放列表显示状态
  @observable
  bool showTabBody = true;

  // 上次观看位置
  @observable
  int historyOffset = 0;

  // 显示调试日志
  @observable
  bool showDebugLog = false;

  String title = '';

  String src = '';

  @observable
  var roadList = ObservableList<Road>();

  late Plugin currentPlugin;

  final PluginsController pluginsController = Modular.get<PluginsController>();
  final HistoryController historyController = Modular.get<HistoryController>();

  changeEpisode(int episode, {int currentRoad = 0, int offset = 0}) async {
    showDebugLog = false;
    loading = true;
    currentEspisode = episode;
    this.currentRoad = currentRoad;
    logLines.clear();
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
    await webviewItemController.loadUrl(urlItem, offset: offset);
  }
}

