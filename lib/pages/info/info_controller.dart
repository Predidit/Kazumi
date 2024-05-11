import 'package:flutter/foundation.dart';
import 'package:kazumi/modules/bangumi/calendar_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/modules/plugins/plugins_module.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/search/search_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:mobx/mobx.dart';

part 'info_controller.g.dart';

class InfoController = _InfoController with _$InfoController;

abstract class _InfoController with Store {
  late BangumiItem bangumiItem;

  @observable
  var searchResponseList = ObservableList<SearchResponse>();

  @observable
  var roadList = ObservableList<Road>();

  querySource(String keyword) async {
    final PluginsController pluginsController =
        Modular.get<PluginsController>();
    searchResponseList.clear();
    for (Plugin plugin in pluginsController.pluginList) {
      searchResponseList.add(await plugin.queryBangumi(keyword));
    }
  }

  queryRoads(String url, String pluginName) async {
    final PluginsController pluginsController =
        Modular.get<PluginsController>();
    roadList.clear();
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == pluginName) {
        roadList.addAll(await plugin.querychapterRoads(url));
      }
    }
    debugPrint('播放列表长度 ${roadList.length}');
    debugPrint('第一播放列表选集数 ${roadList[0].data.length}');
  }
}
