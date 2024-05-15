import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:mobx/mobx.dart';

part 'info_controller.g.dart';

class InfoController = _InfoController with _$InfoController;

abstract class _InfoController with Store {
  late BangumiItem bangumiItem;

  @observable
  var pluginSearchResponseList = ObservableList<PluginSearchResponse>();

  @observable
  var pluginSearchStatus = ObservableMap<String, String>();

  querySource(String keyword) async {
    // 此异步处理可能存在内存泄漏
    final PluginsController pluginsController =
        Modular.get<PluginsController>();
    pluginSearchResponseList.clear();

    for (Plugin plugin in pluginsController.pluginList) {
      pluginSearchStatus[plugin.name] = 'pending';
    }

    var controller = StreamController();
    for (Plugin plugin in pluginsController.pluginList) {
      plugin.queryBangumi(keyword).then((result) {
        pluginSearchStatus[plugin.name] = 'success';
        controller.add(result);
      }).catchError((error) {
        pluginSearchStatus[plugin.name] = 'error';
      });
    }
    await for (var result in controller.stream) {
      pluginSearchResponseList.add(result);
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
