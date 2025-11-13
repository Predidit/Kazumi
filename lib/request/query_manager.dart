import 'dart:async';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/repositories/video_source_repository.dart';

class QueryManager {
  QueryManager({
    required this.infoController,
  });

  final InfoController infoController;
  final PluginsController pluginsController = Modular.get<PluginsController>();
  final IVideoSourceRepository videoSourceRepository = Modular.get<IVideoSourceRepository>();
  StreamController? _controller;
  bool _isCancelled = false;

  /// 追踪本次查询预加载的所有 src（用于销毁时清理缓存）
  final Set<String> _preloadedSources = {};

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
        plugin.queryBangumi(keyword, shouldRethrow: true).then((result) async {
          if (_isCancelled) {
            return;
          }

          infoController.pluginSearchStatus[plugin.name] = 'success';
          if (result.data.isNotEmpty) {
            pluginsController.validityTracker.markSearchValid(plugin.name);
          }
          infoController.pluginSearchResponseList.add(result);

          // 预加载每个搜索结果的播放列表（通过 Repository）
          if (!_isCancelled) {
            _preloadRoadListsViaRepository(plugin, result.data);
          }
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

      plugin.queryBangumi(keyword, shouldRethrow: true).then((result) async {
        if (_isCancelled) {
          return;
        }

        infoController.pluginSearchStatus[plugin.name] = 'success';
        if (result.data.isNotEmpty) {
          pluginsController.validityTracker.markSearchValid(plugin.name);
        }
        _controller?.add(result);

        // 预加载每个搜索结果的播放列表（通过 Repository）
        if (!_isCancelled) {
          _preloadRoadListsViaRepository(plugin, result.data);
        }
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

  /// 通过 Repository 预加载搜索结果的播放列表
  void _preloadRoadListsViaRepository(Plugin plugin, List<dynamic> searchItems) {
    if (_isCancelled) return;

    // 构建预加载任务列表
    final sources = <(String, Plugin)>[];
    for (var item in searchItems) {
      if (item is SearchItem) {
        sources.add((item.src, plugin));
        // 追踪加载的 src
        _preloadedSources.add(item.src);
      }
    }

    // 批量预加载（不等待完成，后台执行）
    videoSourceRepository.batchPreloadRoadLists(sources);
  }

  void cancel() {
    _isCancelled = true;
    if (_controller != null && !_controller!.isClosed) {
      _controller!.close();
    }

    // 清理本次查询预加载的缓存
    if (_preloadedSources.isNotEmpty) {
      videoSourceRepository.clearCacheBatch(_preloadedSources.toList());
      _preloadedSources.clear();
    }
  }
}
