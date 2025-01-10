import 'dart:async';
import 'package:kazumi/plugins/plugins.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

class QueryManager {
  final InfoController infoController = Modular.get<InfoController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  late StreamController _controller;
  bool _isCancelled = false;

  Future<void> querySource(String keyword) async {
    _controller = StreamController();
    int count = pluginsController.pluginList.length;
    infoController.pluginSearchResponseList.clear();

    for (Plugin plugin in pluginsController.pluginList) {
      infoController.pluginSearchStatus[plugin.name] = 'pending';
    }

    for (Plugin plugin in pluginsController.pluginList) {
      if (_isCancelled) return;

      plugin.queryBangumi(keyword, shouldRethrow: true).then((result) {
        if (_isCancelled) return;

        infoController.pluginSearchStatus[plugin.name] = 'success';
        if (result.data.isNotEmpty) {
          pluginsController.validityTracker.markSearchValid(plugin.name);
        }
        _controller.add(result);
      }).catchError((error) {
        if (_isCancelled) return;
        
        infoController.pluginSearchStatus[plugin.name] = 'error';
        --count;
        if (count == 0) return;
      });
    }

    await for (var result in _controller.stream) {
      if (_isCancelled) break;
      infoController.pluginSearchResponseList.add(result);
      --count;
      if (count == 0) break;
    }
  }

  void cancel() {
    _isCancelled = true;
    _controller.close();
  }
}
