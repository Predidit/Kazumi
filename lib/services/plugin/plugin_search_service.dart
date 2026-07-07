import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/logging/logger.dart';

class PluginSearchService {
  PluginSearchService({
    required this.infoController,
    required this.pluginsController,
    List<Plugin>? plugins,
  }) : _plugins = plugins == null ? null : List.unmodifiable(plugins);

  final InfoController infoController;
  final PluginsController pluginsController;
  final List<Plugin>? _plugins;
  bool _isCancelled = false;

  List<Plugin> get _queryPlugins =>
      _plugins ?? List<Plugin>.of(pluginsController.enabledPlugins);

  Future<void> querySource(String keyword, String pluginName) async {
    infoController.pluginSearchResponseList.removeWhere(
      (response) => response.pluginName == pluginName,
    );
    if (infoController.pluginSearchStatus.containsKey(pluginName)) {
      infoController.pluginSearchStatus[pluginName] = 'pending';
    }
    for (final plugin in _queryPlugins) {
      if (plugin.name == pluginName) {
        await _queryPlugin(plugin, keyword);
        return;
      }
    }
    infoController.pluginSearchStatus.remove(pluginName);
  }

  Future<void> queryAllSource(String keyword) async {
    infoController.pluginSearchResponseList.clear();
    infoController.pluginSearchStatus.clear();

    final plugins = _queryPlugins;
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
