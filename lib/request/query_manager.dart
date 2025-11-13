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
  StreamController? _controller;
  bool _isCancelled = false;

  Future<void> querySource(String keyword, String pluginName) async {
    for (PluginSearchResponse pluginSearchResponse
        in infoController.pluginSearchResponseList) {
      if (pluginSearchResponse.pluginName == pluginName) {
        infoController.pluginSearchResponseList.remove(pluginSearchResponse);
        break;
      }
    }
    if (infoController.pluginSearchStatus.containsKey(pluginName)) {
      infoController.pluginSearchStatus[pluginName] = 'pending';
    }
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == pluginName) {
        plugin.queryBangumi(keyword, shouldRethrow: true).then((result) {
          if (_isCancelled) {
            return;
          }

          infoController.pluginSearchStatus[plugin.name] = 'success';
          if (result.data.isNotEmpty) {
            pluginsController.validityTracker.markSearchValid(plugin.name);
          }
          infoController.pluginSearchResponseList.add(result);
        }).catchError((error) {
          if (_isCancelled) {
            return;
          }

          infoController.pluginSearchStatus[plugin.name] = 'error';
        });
      }
    }
  }

  Future<void> queryAllSource(String keyword) async {
    _controller = StreamController();
    infoController.pluginSearchResponseList.clear();

    for (Plugin plugin in pluginsController.pluginList) {
      infoController.pluginSearchStatus[plugin.name] = 'pending';
    }

    for (Plugin plugin in pluginsController.pluginList) {
      if (_isCancelled) return;

      plugin.queryBangumi(keyword, shouldRethrow: true).then((result) {
        if (_isCancelled) {
          return;
        }

        infoController.pluginSearchStatus[plugin.name] = 'success';
        if (result.data.isNotEmpty) {
          pluginsController.validityTracker.markSearchValid(plugin.name);
        }
        _controller?.add(result);
      }).catchError((error) {
        if (_isCancelled) {
          return;
        }

        infoController.pluginSearchStatus[plugin.name] = 'error';
      });
    }

    await for (var result in _controller!.stream) {
      if (_isCancelled) break;

      infoController.pluginSearchResponseList.add(result);
    }
  }

  void cancel() {
    _isCancelled = true;
    if (_controller != null && !_controller!.isClosed) {
      _controller!.close();
    }
  }
}
