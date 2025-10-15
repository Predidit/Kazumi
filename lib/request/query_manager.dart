import 'dart:async';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

class QueryManager {
  QueryManager({
    required this.infoController,
  });

  final InfoController infoController;
  final PluginsController pluginsController = Modular.get<PluginsController>();
  late StreamController _controller;
  bool _isCancelled = false;

  Future<void> querySource(String keyword, String pluginName,
      {int page = 1, bool isAppend = false}) async {
    PluginSearchResponse? searchHistory;
    if (infoController.pluginSearchResponseList
        .any((r) => r.pluginName == pluginName)) {
      searchHistory = infoController.pluginSearchResponseList
          .firstWhere((r) => r.pluginName == pluginName);
      if (!isAppend) {
        searchHistory.data.clear();
      }
    }
    if (!isAppend &&
        infoController.pluginSearchStatus.containsKey(pluginName)) {
      infoController.pluginSearchStatus[pluginName] = 'pending';
    }
    final targetPlugin =
        pluginsController.pluginList.firstWhere((p) => p.name == pluginName);
    await targetPlugin.queryBangumi(
      keyword,
      page,
      shouldRethrow: true,
    ).then((result){
      if (_isCancelled) return;
      // 处理结果（原逻辑迁移到这里，确保状态同步）
      infoController.pluginSearchStatus[pluginName] = 'success';
      if (result.data.isNotEmpty) {
        pluginsController.validityTracker.markSearchValid(pluginName);
      }
      if (searchHistory != null) {
        searchHistory.data.addAll(result.data);
      } else {
        infoController.pluginSearchResponseList.add(result);
      }

    }).catchError((error) {
      if (_isCancelled) return;
      infoController.pluginSearchStatus[pluginName] = 'error';
    });
  }

  Future<void> queryAllSource(String keyword) async {
    _controller = StreamController();
    infoController.pluginSearchResponseList.clear();

    for (Plugin plugin in pluginsController.pluginList) {
      //todo: plugin加一个成员变量用来判断是否需要与大部队一块搜索
      infoController.pluginSearchStatus[plugin.name] = 'pending';
    }

    for (Plugin plugin in pluginsController.pluginList) {
      if (_isCancelled) return;

      plugin.queryBangumi(keyword, 1, shouldRethrow: true,).then((result) {
        if (_isCancelled) return;

        infoController.pluginSearchStatus[plugin.name] = 'success';
        if (result.data.isNotEmpty) {
          pluginsController.validityTracker.markSearchValid(plugin.name);
        }
        _controller.add(result);
      }).catchError((error) {
        if (_isCancelled) return;

        infoController.pluginSearchStatus[plugin.name] = 'error';
      });
    }

    await for (var result in _controller.stream) {
      if (_isCancelled) break;

      infoController.pluginSearchResponseList.add(result);
    }
  }

  void cancel() {
    _isCancelled = true;
    _controller.close();
  }
}
