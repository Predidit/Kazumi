import 'package:kazumi/plugins/plugins_controller.dart';

/// Provides a way for services to refresh the in-memory plugin state.
abstract interface class IPluginReloader {
  Future<void> reload();
}

/// Adapts the plugin controller to the plugin reload boundary.
class PluginReloader implements IPluginReloader {
  PluginReloader(this._pluginsController);

  final PluginsController _pluginsController;

  @override
  Future<void> reload() => _pluginsController.init();
}
