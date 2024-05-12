import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:kazumi/modules/bangumi/calendar_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/modules/plugins/plugins_module.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/search/search_module.dart';
import 'package:mobx/mobx.dart';

part 'info_controller.g.dart';

class InfoController = _InfoController with _$InfoController;

abstract class _InfoController with Store {
  late BangumiItem bangumiItem;

  @observable
  var searchResponseList = ObservableList<SearchResponse>();

  querySource(String keyword) async {
    // 此异步处理可能存在内存泄漏
    final PluginsController pluginsController =
        Modular.get<PluginsController>();
    searchResponseList.clear();
    var controller = StreamController();

    for (Plugin plugin in pluginsController.pluginList) {
      plugin.queryBangumi(keyword).then((result) {
        controller.add(result);
      });
    }
    await for (var result in controller.stream) {
      searchResponseList.add(result);
    }
  }

  queryRoads(String url, String pluginName) async {
    final PluginsController pluginsController =
        Modular.get<PluginsController>();
    final VideoPageController videoPageController =
        Modular.get<VideoPageController>();
    videoPageController.roadList.clear();
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == pluginName) {
        videoPageController.roadList
            .addAll(await plugin.querychapterRoads(url));
      }
    }
    debugPrint('播放列表长度 ${videoPageController.roadList.length}');
    debugPrint('第一播放列表选集数 ${videoPageController.roadList[0].data.length}');
  }
}
