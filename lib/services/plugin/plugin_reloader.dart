import 'package:kazumi/plugins/plugins_controller.dart';

/// Provides a way for services to refresh the in-memory plugin state.
abstract interface class IPluginReloader {
  Future<void> reload();

  /// Runs an operation exclusively with plugin mutations.
  ///
  /// The action must not call another operation that uses this boundary,
  /// because the underlying queue is not reentrant.
  Future<T> runExclusive<T>(Future<T> Function() action);
}

/// Adapts the plugin controller to the plugin reload boundary.
class PluginReloader implements IPluginReloader {
  PluginReloader(this._pluginsController);

  final PluginsController _pluginsController;

  @override
  Future<void> reload() => _pluginsController.init();

  @override
  Future<T> runExclusive<T>(Future<T> Function() action) {
    return _pluginsController.runSerializedPluginOperation(action);
  }
}
