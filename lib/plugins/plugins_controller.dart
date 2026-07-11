import 'dart:io';
import 'dart:convert';
import 'package:mobx/mobx.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/services/plugin/plugin_validity_tracker.dart';
import 'package:kazumi/services/plugin/plugin_install_time_tracker.dart';
import 'package:kazumi/request/apis/plugin_catalog_api.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/async_serial_queue.dart';
import 'package:kazumi/utils/async_single_flight.dart';
import 'package:kazumi/utils/version.dart';

part 'plugins_controller.g.dart';

// 从 1.5.1 版本开始，规则文件储存在单一的 plugins.json 文件中。
// 之前的版本中，规则以分离文件形式存储，版本更新后将这些分离文件合并为单一的 plugins.json 文件。

class PluginsController = _PluginsController with _$PluginsController;

enum PluginUpdateAvailability { unknown, notInCatalog, latest, updatable }

enum PluginCatalogItemStatus { install, installed, update }

enum PluginUpdateResult { updated, requiresNewerClient, failed, notNewer }

class PluginBatchUpdateResult {
  const PluginBatchUpdateResult({
    required this.candidates,
    required this.updated,
    required this.requiresNewerClient,
    required this.failed,
    required this.notNewer,
  });

  final int candidates;
  final int updated;
  final int requiresNewerClient;
  final int failed;
  final int notNewer;

  bool get hasNoCandidates => candidates == 0;
}

typedef PluginCatalogLoader = Future<List<PluginHTTPItem>> Function();
typedef PluginLoader = Future<Plugin> Function(String name);
typedef PluginJsonWriter = Future<void> Function(String jsonData);
typedef PluginErrorReporter = void Function(
  String message,
  Object error,
  StackTrace stackTrace,
);
typedef _PluginUpdateAttempt = ({PluginUpdateResult result, Plugin? plugin});

void _defaultPluginErrorReporter(
  String message,
  Object error,
  StackTrace stackTrace,
) {
  KazumiLogger().e(message, error: error, stackTrace: stackTrace);
}

abstract class _PluginsController with Store {
  static const String disabledPluginNamesSettingKey = 'disabledPluginNames';

  _PluginsController({
    PluginCatalogLoader? catalogLoader,
    PluginLoader? pluginLoader,
    PluginJsonWriter? pluginJsonWriter,
    PluginErrorReporter? errorReporter,
  })  : _catalogLoader = catalogLoader ?? PluginCatalogApi.getPluginList,
        _pluginLoader = pluginLoader ?? PluginCatalogApi.getPlugin,
        _pluginJsonWriter = pluginJsonWriter,
        _errorReporter = errorReporter ?? _defaultPluginErrorReporter;

  final PluginCatalogLoader _catalogLoader;
  final PluginLoader _pluginLoader;
  final PluginJsonWriter? _pluginJsonWriter;
  final PluginErrorReporter _errorReporter;
  final AsyncSingleFlight<List<PluginHTTPItem>> _catalogRefreshSingleFlight =
      AsyncSingleFlight<List<PluginHTTPItem>>();
  final AsyncSerialQueue _mutations = AsyncSerialQueue();
  Map<String, PluginHTTPItem> _pluginCatalogByName = const {};
  DateTime? _pluginCatalogRefreshedAt;
  int _optimisticReorderRevision = 0;

  // Reuse a recent catalog across startup, the rule list, and the rule shop.
  // Explicit refresh actions always bypass this window.
  static const _pluginCatalogMaxAge = Duration(minutes: 5);
  static const _maxConcurrentRuleDownloads = 4;

  @observable
  ObservableList<Plugin> pluginList = ObservableList.of([]);

  @observable
  ObservableList<PluginHTTPItem> pluginHTTPList = ObservableList.of([]);

  final ObservableSet<String> disabledPluginNames =
      ObservableSet<String>.of({});

  // 规则有效性追踪器
  final validityTracker = PluginValidityTracker();

  // 规则安装时间追踪器
  final installTimeTracker = PluginInstallTimeTracker();

  String pluginsFileName = "plugins.json";

  Directory? oldPluginDirectory;

  Directory? newPluginDirectory;

  // Initializes the plugin directory and loads all plugins
  Future<void> init() async {
    final directory = await getApplicationSupportDirectory();
    oldPluginDirectory = Directory('${directory.path}/plugins');
    if (!await oldPluginDirectory!.exists()) {
      await oldPluginDirectory!.create(recursive: true);
    }
    newPluginDirectory = Directory('${directory.path}/plugins/v2');
    if (!await newPluginDirectory!.exists()) {
      await newPluginDirectory!.create(recursive: true);
    }
    await _loadAllPlugins();
    await loadPluginEnabledState();
  }

  // Loads all plugins from the directory, populates the plugin list, and saves to plugins.json if needed
  Future<void> _loadAllPlugins() async {
    pluginList.clear();
    KazumiLogger().i('Plugins Directory: ${newPluginDirectory!.path}');
    if (await newPluginDirectory!.exists()) {
      final pluginsFile = File('${newPluginDirectory!.path}/$pluginsFileName');
      if (await pluginsFile.exists()) {
        final jsonString = await pluginsFile.readAsString();
        pluginList.addAll(_getPluginListFromJson(jsonString));
        KazumiLogger().i('Plugin: Current Plugin number: ${pluginList.length}');
      } else {
        // No plugins.json
        var jsonFiles = await _getPluginFiles();
        for (var filePath in jsonFiles) {
          final file = File(filePath);
          final jsonString = await file.readAsString();
          final data = jsonDecode(jsonString);
          final plugin = Plugin.fromJson(data);
          pluginList.add(plugin);
          await file.delete(recursive: true);
        }
        await _savePlugins();
      }
    } else {
      KazumiLogger().w('Plugin: plugin directory does not exist');
    }
  }

  // Retrieves a list of JSON plugin file paths from the plugin directory
  Future<List<String>> _getPluginFiles() async {
    if (await oldPluginDirectory!.exists()) {
      final jsonFiles = oldPluginDirectory!
          .listSync()
          .where((file) => file.path.endsWith('.json') && file is File)
          .map((file) => file.path)
          .toList();
      return jsonFiles;
    } else {
      return [];
    }
  }

  // Copies plugin JSON files from the assets to the plugin directory
  Future<void> copyPluginsToExternalDirectory() async {
    final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = assetManifest.listAssets();
    final jsonFiles = assets.where((String asset) =>
        asset.startsWith('assets/plugins/') && asset.endsWith('.json'));

    for (var filePath in jsonFiles) {
      final jsonString = await rootBundle.loadString(filePath);
      final plugin = Plugin.fromJson(jsonDecode(jsonString));
      pluginList.add(plugin);
    }
    await _savePlugins();
    KazumiLogger().i(
        'Plugin: ${jsonFiles.length} plugin files copied to ${newPluginDirectory!.path}');
  }

  List<dynamic> _pluginListToJson() {
    final List<dynamic> json = [];
    for (var plugin in pluginList) {
      json.add(plugin.toJson());
    }
    return json;
  }

  Future<void> loadPluginEnabledState({
    Iterable<String>? disabledNames,
    bool persist = true,
  }) async {
    disabledPluginNames
      ..clear()
      ..addAll(disabledNames ??
          GStorage.getStringListSettingByName(disabledPluginNamesSettingKey));
    if (_pruneDisabledPluginNames() && persist) {
      await saveDisabledPluginNames();
    }
  }

  bool isPluginEnabled(String name) => !disabledPluginNames.contains(name);

  List<Plugin> get enabledPlugins => pluginList
      .where((plugin) => isPluginEnabled(plugin.name))
      .toList(growable: false);

  Future<void> setPluginEnabled(
    String name,
    bool enabled, {
    bool persist = true,
  }) async {
    if (!pluginList.any((plugin) => plugin.name == name)) {
      return;
    }
    final changed = enabled
        ? disabledPluginNames.remove(name)
        : disabledPluginNames.add(name);
    if (changed && persist) {
      await saveDisabledPluginNames();
    }
  }

  Future<void> setPluginsEnabled(
    Iterable<String> names,
    bool enabled, {
    bool persist = true,
  }) async {
    final pluginNames = pluginList.map((plugin) => plugin.name).toSet();
    var changed = false;
    for (final name in names) {
      if (!pluginNames.contains(name)) {
        continue;
      }
      if (enabled) {
        changed = disabledPluginNames.remove(name) || changed;
      } else {
        changed = disabledPluginNames.add(name) || changed;
      }
    }
    if (changed && persist) {
      await saveDisabledPluginNames();
    }
  }

  Future<void> saveDisabledPluginNames() async {
    await GStorage.putStringListSettingByName(
      disabledPluginNamesSettingKey,
      disabledPluginNames.toList(growable: false)..sort(),
    );
  }

  bool _pruneDisabledPluginNames() {
    final pluginNames = pluginList.map((plugin) => plugin.name).toSet();
    final namesToRemove = disabledPluginNames
        .where((name) => !pluginNames.contains(name))
        .toList(growable: false);
    if (namesToRemove.isEmpty) {
      return false;
    }
    disabledPluginNames.removeAll(namesToRemove);
    return true;
  }

  // Converts a JSON string into a list of Plugin objects.
  List<Plugin> _getPluginListFromJson(String jsonString) {
    List<dynamic> json = jsonDecode(jsonString);
    List<Plugin> plugins = [];
    for (var j in json) {
      plugins.add(Plugin.fromJson(j));
    }
    return plugins;
  }

  Future<void> removePlugin(Plugin plugin, {bool persist = true}) async {
    final disabledChanged = disabledPluginNames.contains(plugin.name);
    if (!persist) {
      pluginList.removeWhere(
        (candidate) => _catalogKey(candidate.name) == _catalogKey(plugin.name),
      );
      disabledPluginNames.remove(plugin.name);
      return;
    }
    await _mutateAndPersist(
      () {
        pluginList.removeWhere(
          (candidate) =>
              _catalogKey(candidate.name) == _catalogKey(plugin.name),
        );
        disabledPluginNames.remove(plugin.name);
      },
      errorMessage: 'Plugin: failed to persist rule removal',
    );
    if (disabledChanged) {
      await saveDisabledPluginNames();
    }
  }

  bool get isPluginCatalogFresh {
    final refreshedAt = _pluginCatalogRefreshedAt;
    return refreshedAt != null &&
        DateTime.now().difference(refreshedAt) < _pluginCatalogMaxAge;
  }

  void _replacePlugin(Plugin plugin) {
    bool flag = false;
    for (int i = 0; i < pluginList.length; ++i) {
      if (_catalogKey(pluginList[i].name) == _catalogKey(plugin.name)) {
        pluginList.replaceRange(i, i + 1, [plugin]);
        flag = true;
        break;
      }
    }
    if (!flag) {
      pluginList.add(plugin);
    }
  }

  Future<T> _mutateAndPersist<T>(
    T Function() mutate, {
    required String errorMessage,
  }) {
    return _mutations.run(
      () => _mutateAndPersistNow(
        mutate,
        errorMessage: errorMessage,
      ),
    );
  }

  Future<T> _mutateAndPersistNow<T>(
    T Function() mutate, {
    required String errorMessage,
  }) async {
    final previous = List<Plugin>.from(pluginList);
    try {
      final result = mutate();
      await _savePlugins();
      return result;
    } catch (error, stackTrace) {
      pluginList
        ..clear()
        ..addAll(previous);
      _errorReporter(errorMessage, error, stackTrace);
      rethrow;
    }
  }

  Future<void> updatePlugin(Plugin plugin, {bool persist = true}) {
    if (!persist) {
      _replacePlugin(plugin);
      return Future.value();
    }
    return _mutateAndPersist(
      () => _replacePlugin(plugin),
      errorMessage: 'Plugin: failed to persist rule update',
    );
  }

  Future<void> onReorder(int oldIndex, int newIndex) {
    final previous = List<Plugin>.from(pluginList);
    final plugin = pluginList.removeAt(oldIndex);
    pluginList.insert(newIndex, plugin);
    final jsonData = jsonEncode(_pluginListToJson());
    final revision = ++_optimisticReorderRevision;
    return _mutations.run(() async {
      try {
        await _writePluginsJson(jsonData);
      } catch (error, stackTrace) {
        if (revision == _optimisticReorderRevision) {
          pluginList
            ..clear()
            ..addAll(previous);
        }
        _errorReporter(
          'Plugin: failed to persist rule order',
          error,
          stackTrace,
        );
        rethrow;
      }
    });
  }

  Future<void> _savePlugins() async {
    final jsonData = jsonEncode(_pluginListToJson());
    await _writePluginsJson(jsonData);
  }

  Future<void> _writePluginsJson(String jsonData) async {
    final writer = _pluginJsonWriter;
    if (writer != null) {
      await writer(jsonData);
    } else {
      final pluginsFile = File('${newPluginDirectory!.path}/$pluginsFileName');
      await pluginsFile.writeAsString(jsonData);
      KazumiLogger().i('Plugin: updated plugin file $pluginsFileName');
    }
  }

  Future<List<PluginHTTPItem>> refreshPluginCatalog() {
    return _catalogRefreshSingleFlight.run(() async {
      try {
        final catalog = await _catalogLoader();
        _pluginCatalogByName = {
          for (final item in catalog) _catalogKey(item.name): item,
        };
        pluginHTTPList
          ..clear()
          ..addAll(catalog);
        _pluginCatalogRefreshedAt = DateTime.now();
        return List<PluginHTTPItem>.unmodifiable(catalog);
      } catch (error, stackTrace) {
        _errorReporter(
          'Plugin: failed to refresh rule catalog',
          error,
          stackTrace,
        );
        rethrow;
      }
    });
  }

  Future<List<PluginHTTPItem>> ensurePluginCatalog() {
    if (isPluginCatalogFresh) {
      return Future.value(
        List<PluginHTTPItem>.unmodifiable(pluginHTTPList),
      );
    }
    return refreshPluginCatalog();
  }

  Future<int> checkPluginUpdatesOnStartup({required bool enabled}) async {
    if (!enabled) {
      return 0;
    }
    await refreshPluginCatalog();
    return _updatablePluginNames().length;
  }

  String _catalogKey(String name) => name.toLowerCase();

  bool _remoteIsNewer(String localVersion, String remoteVersion) {
    try {
      return needUpdate(localVersion, remoteVersion);
    } catch (_) {
      return localVersion != remoteVersion;
    }
  }

  PluginCatalogItemStatus pluginStatus(PluginHTTPItem pluginHTTPItem) {
    var pluginStatus = PluginCatalogItemStatus.install;
    for (Plugin plugin in pluginList) {
      if (_catalogKey(pluginHTTPItem.name) == _catalogKey(plugin.name)) {
        if (_remoteIsNewer(plugin.version, pluginHTTPItem.version)) {
          pluginStatus = PluginCatalogItemStatus.update;
        } else {
          pluginStatus = PluginCatalogItemStatus.installed;
        }
        break;
      }
    }
    return pluginStatus;
  }

  PluginUpdateAvailability pluginUpdateStatus(Plugin plugin) {
    if (_pluginCatalogRefreshedAt == null) {
      return PluginUpdateAvailability.unknown;
    }
    final remote = _pluginCatalogByName[_catalogKey(plugin.name)];
    if (remote == null) {
      return PluginUpdateAvailability.notInCatalog;
    }
    return _remoteIsNewer(plugin.version, remote.version)
        ? PluginUpdateAvailability.updatable
        : PluginUpdateAvailability.latest;
  }

  List<String> _updatablePluginNames() {
    return [
      for (final plugin in pluginList)
        if (pluginUpdateStatus(plugin) == PluginUpdateAvailability.updatable)
          _pluginCatalogByName[_catalogKey(plugin.name)]!.name,
    ];
  }

  Future<PluginUpdateResult> tryUpdatePluginByName(String name) {
    return _mutations.run(() async {
      final catalogName = _pluginCatalogByName[_catalogKey(name)]?.name ?? name;
      final attempt = await _preparePluginUpdate(catalogName);
      if (attempt.result == PluginUpdateResult.updated) {
        await _mutateAndPersistNow(
          () => _replacePlugin(attempt.plugin!),
          errorMessage:
              'Plugin: failed to persist downloaded rule $catalogName',
        );
      }
      return attempt.result;
    });
  }

  Future<_PluginUpdateAttempt> _preparePluginUpdate(String name) async {
    late final Plugin remotePlugin;
    try {
      remotePlugin = await _pluginLoader(name);
    } catch (error, stackTrace) {
      _errorReporter(
        'Plugin: failed to download rule $name',
        error,
        stackTrace,
      );
      return (result: PluginUpdateResult.failed, plugin: null);
    }
    // Validate at the injected loader boundary so production and test/custom
    // loaders follow the same integrity rule. Preserve the catalog spelling.
    if (remotePlugin.name.isEmpty ||
        _catalogKey(remotePlugin.name) != _catalogKey(name)) {
      final error = FormatException(
        'Downloaded rule name ${remotePlugin.name} does not match $name',
      );
      _errorReporter(
        'Plugin: rejected mismatched rule payload',
        error,
        StackTrace.current,
      );
      return (result: PluginUpdateResult.failed, plugin: null);
    }
    remotePlugin.name = name;
    try {
      if (remotePlugin.requiresNewerClient) {
        return (
          result: PluginUpdateResult.requiresNewerClient,
          plugin: null,
        );
      }
    } catch (error, stackTrace) {
      _errorReporter(
        'Plugin: invalid API level in rule $name',
        error,
        stackTrace,
      );
      return (result: PluginUpdateResult.failed, plugin: null);
    }
    Plugin? local;
    for (final plugin in pluginList) {
      if (_catalogKey(plugin.name) == _catalogKey(name)) {
        local = plugin;
        break;
      }
    }
    // Never downgrade an installed plugin; mirrors may lag behind upstream.
    if (local != null && !_remoteIsNewer(local.version, remotePlugin.version)) {
      return (result: PluginUpdateResult.notNewer, plugin: null);
    }
    return (result: PluginUpdateResult.updated, plugin: remotePlugin);
  }

  Future<PluginBatchUpdateResult> tryUpdateAllPlugin({
    bool ensureCatalog = true,
  }) {
    return _mutations.run(
      () => _tryUpdateAllPlugin(ensureCatalog: ensureCatalog),
    );
  }

  Future<PluginBatchUpdateResult> _tryUpdateAllPlugin({
    required bool ensureCatalog,
  }) async {
    if (ensureCatalog) {
      await ensurePluginCatalog();
    } else if (_pluginCatalogRefreshedAt == null) {
      throw StateError('Plugin catalog has not been loaded');
    }

    final candidates = _updatablePluginNames();
    final attempts = await _preparePluginUpdates(candidates);
    var updated = 0;
    var requiresNewerClient = 0;
    var failed = 0;
    var notNewer = 0;

    final updatedPlugins = <Plugin>[];
    for (final attempt in attempts) {
      switch (attempt.result) {
        case PluginUpdateResult.updated:
          updated++;
          updatedPlugins.add(attempt.plugin!);
        case PluginUpdateResult.requiresNewerClient:
          requiresNewerClient++;
        case PluginUpdateResult.failed:
          failed++;
        case PluginUpdateResult.notNewer:
          notNewer++;
      }
    }

    if (updatedPlugins.isNotEmpty) {
      await _mutateAndPersistNow(
        () {
          for (final plugin in updatedPlugins) {
            _replacePlugin(plugin);
          }
        },
        errorMessage: 'Plugin: failed to persist batch rule update',
      );
    }
    return PluginBatchUpdateResult(
      candidates: candidates.length,
      updated: updated,
      requiresNewerClient: requiresNewerClient,
      failed: failed,
      notNewer: notNewer,
    );
  }

  Future<List<_PluginUpdateAttempt>> _preparePluginUpdates(
    List<String> names,
  ) async {
    if (names.isEmpty) {
      return const [];
    }
    final results = List<_PluginUpdateAttempt?>.filled(names.length, null);
    var nextIndex = 0;

    Future<void> worker() async {
      while (nextIndex < names.length) {
        final index = nextIndex++;
        results[index] = await _preparePluginUpdate(names[index]);
      }
    }

    final workerCount = names.length < _maxConcurrentRuleDownloads
        ? names.length
        : _maxConcurrentRuleDownloads;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results.cast<_PluginUpdateAttempt>();
  }

  Future<void> removePlugins(
    Set<String> pluginNames, {
    bool persist = true,
  }) async {
    final names = Set<String>.of(pluginNames);
    final disabledChanged = names.any(disabledPluginNames.contains);
    if (!persist) {
      for (int i = pluginList.length - 1; i >= 0; --i) {
        var name = pluginList[i].name;
        if (names.contains(name)) {
          pluginList.removeAt(i);
        }
      }
      disabledPluginNames.removeAll(names);
      return;
    }
    await _mutateAndPersist(
      () {
        for (int i = pluginList.length - 1; i >= 0; --i) {
          var name = pluginList[i].name;
          if (names.contains(name)) {
            pluginList.removeAt(i);
          }
        }
        disabledPluginNames.removeAll(names);
      },
      errorMessage: 'Plugin: failed to persist batch rule removal',
    );
    if (disabledChanged) {
      await saveDisabledPluginNames();
    }
  }
}
