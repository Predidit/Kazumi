import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/logging/logger.dart';

class PluginSearchService {
  PluginSearchService({
    required this.infoController,
  });

  final InfoController infoController;
  final PluginsController pluginsController = Modular.get<PluginsController>();
  bool _isCancelled = false;

  Future<void> querySource(String keyword, String pluginName) async {
    infoController.pluginSearchResponseList.removeWhere(
      (response) => response.pluginName == pluginName,
    );
    if (infoController.pluginSearchStatus.containsKey(pluginName)) {
      infoController.pluginSearchStatus[pluginName] = 'pending';
    }
    for (final plugin in pluginsController.pluginList) {
      if (plugin.name == pluginName) {
        await _queryPlugin(plugin, keyword);
        return;
      }
    }
  }

  Future<void> queryAllSource(String keyword) async {
    infoController.pluginSearchResponseList.clear();

    final plugins = List<Plugin>.of(pluginsController.pluginList);
    for (final plugin in plugins) {
      infoController.pluginSearchStatus[plugin.name] = 'pending';
    }
    await Future.wait(
      plugins.map((plugin) => _queryPlugin(plugin, keyword)),
    );
  }

  Future<void> _queryPlugin(Plugin plugin, String keyword) async {
    if (_isCancelled) return;
    try {
      final result = await plugin.queryBangumi(
        keyword,
        shouldRethrow: true,
      );
      if (_isCancelled) return;
      infoController.pluginSearchStatus[plugin.name] = 'success';
      if (result.data.isNotEmpty) {
        pluginsController.validityTracker.markSearchValid(plugin.name);
      }
      infoController.pluginSearchResponseList.add(result);
    } catch (error) {
      if (_isCancelled) return;
      _handleSearchError(plugin, error);
    }
  }

  void _handleSearchError(Plugin plugin, Object error) {
    if (error is CaptchaRequiredException) {
      KazumiLogger().i(
        'PluginSearchService: captcha required for ${error.pluginName}',
      );
      infoController.pluginSearchStatus[error.pluginName] = 'captcha';
      return;
    }
    if (error is NoResultException) {
      KazumiLogger().i(
        'PluginSearchService: no results for ${error.pluginName}',
      );
      infoController.pluginSearchStatus[error.pluginName] = 'noResult';
      return;
    }
    final name = error is SearchErrorException ? error.pluginName : plugin.name;
    KazumiLogger().w('PluginSearchService: search error for $name');
    infoController.pluginSearchStatus[name] = 'error';
  }

  void cancel() {
    _isCancelled = true;
  }
}
