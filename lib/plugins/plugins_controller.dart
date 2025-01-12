import 'dart:io';
import 'dart:convert';
import 'package:mobx/mobx.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugin_validity_tracker.dart';
import 'package:kazumi/plugins/plugin_install_time_tracker.dart';
import 'package:kazumi/request/plugin.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/request/api.dart';

part 'plugins_controller.g.dart';

class PluginsController = _PluginsController with _$PluginsController;

abstract class _PluginsController with Store {
  @observable
  ObservableList<Plugin> pluginList = ObservableList.of([]);

  @observable
  ObservableList<PluginHTTPItem> pluginHTTPList = ObservableList.of([]);

  // 规则有效性追踪器
  final validityTracker = PluginValidityTracker();

  // 规则安装时间追踪器
  final installTimeTracker = PluginInstallTimeTracker();

  String pluginsFileName = "plugins.json";

  Future<void> loadAllPlugins() async {
    pluginList.clear();
    final directory = await getApplicationSupportDirectory();
    final pluginDirectory = Directory('${directory.path}/plugins');
    KazumiLogger().log(Level.info, '插件目录 ${directory.path}/plugins');
    if (await pluginDirectory.exists()) {
      final pluginsFile = File('${pluginDirectory.path}/$pluginsFileName');
      if (await pluginsFile.exists()) {
        final jsonString = await pluginsFile.readAsString();
        pluginList = ObservableList.of(getPluginListFromJson(jsonString));
        KazumiLogger().log(Level.info, '当前插件数量 ${pluginList.length}');
      } else {}
      if (pluginList.isEmpty) {
        var jsonFiles = await loadPlugins();
        for (var filePath in jsonFiles) {
          await File(filePath).delete(recursive: true);
        }
        if (pluginList.isNotEmpty) {
          savePlugins();
        }
      }
    } else {
      KazumiLogger().log(Level.warning, '插件目录不存在');
    }
  }

  Future<List<String>> loadPlugins() async {
    final directory = await getApplicationSupportDirectory();
    final pluginDirectory = Directory('${directory.path}/plugins');
    if (await pluginDirectory.exists()) {
      final pluginsFile = File('${pluginDirectory.path}/$pluginsFileName');
      if (await pluginsFile.exists()) {
        return [];
      }
    }

    pluginList.clear();
    KazumiLogger().log(Level.info, '插件目录 ${directory.path}/plugins');
    if (await pluginDirectory.exists()) {
      final jsonFiles = pluginDirectory
          .listSync()
          .where((file) => file.path.endsWith('.json') && file is File)
          .map((file) => file.path)
          .toList();

      for (var filePath in jsonFiles) {
        final file = File(filePath);
        final jsonString = await file.readAsString();
        final data = jsonDecode(jsonString);
        final plugin = Plugin.fromJson(data);
        // 使用文件修改时间作为安装时间
        final stat = await file.stat();
        installTimeTracker.setInstallTime(
            plugin.name, stat.modified.millisecondsSinceEpoch);
        pluginList.add(plugin);
      }
      KazumiLogger().log(Level.info, '当前插件数量 ${pluginList.length}');
      return jsonFiles;
    } else {
      KazumiLogger().log(Level.warning, '插件目录不存在');
      return [];
    }
  }

  Future<void> copyPluginsToExternalDirectory() async {
    final directory = await getApplicationSupportDirectory();
    final pluginDirectory = Directory('${directory.path}/plugins');

    if (!await pluginDirectory.exists()) {
      await pluginDirectory.create(recursive: true);
    }

    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    final jsonFiles = manifestMap.keys.where((String key) =>
        key.startsWith('assets/plugins/') && key.endsWith('.json'));

    for (var filePath in jsonFiles) {
      final jsonString = await rootBundle.loadString(filePath);
      final plugin = Plugin.fromJson(jsonDecode(jsonString));
      pluginList.add(plugin);
    }
    await savePlugins();
    KazumiLogger().log(
        Level.info, '已将 ${jsonFiles.length} 个插件文件拷贝到 ${pluginDirectory.path}');
  }

  List<dynamic> pluginListToJson() {
    final List<dynamic> json = [];
    for (var plugin in pluginList) {
      json.add(plugin.toJson());
    }
    return json;
  }

  List<Plugin> getPluginListFromJson(String jsonString) {
    List<dynamic> json = jsonDecode(jsonString);
    List<Plugin> plugins = [];
    for (var j in json) {
      plugins.add(Plugin.fromJson(j));
    }
    return plugins;
  }

  Future<void> removePlugin(Plugin plugin) async {
    pluginList.removeWhere((p) => p.name == plugin.name);
    await savePlugins();
  }

  // update or add plugin
  void updatePlugin(Plugin plugin) {
    bool flag = false;
    for (int i = 0; i < pluginList.length; ++i) {
      if (pluginList[i].name == plugin.name) {
        pluginList[i] = plugin;
        flag = true;
        break;
      }
    }
    if (!flag) {
      pluginList.add(plugin);
    }
    savePlugins();
  }

  void onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final plugin = pluginList.removeAt(oldIndex);
    pluginList.insert(newIndex, plugin);
    savePlugins();
  }

  Future<void> savePlugins() async {
    final jsonData = jsonEncode(pluginListToJson());
    final directory = await getApplicationSupportDirectory();
    final pluginDirectory = Directory('${directory.path}/plugins');
    final pluginsFile = File('${pluginDirectory.path}/$pluginsFileName');
    await pluginsFile.writeAsString(jsonData);
    KazumiLogger().log(Level.info, '已更新插件文件 $pluginsFileName');
    
    pluginList = ObservableList.of(pluginList); // 强制替换触发更新
  }

  Future<void> queryPluginHTTPList() async {
    pluginHTTPList.clear();
    var pluginHTTPListRes = await PluginHTTP.getPluginList();
    pluginHTTPList.addAll(pluginHTTPListRes);
  }

  Future<Plugin?> queryPluginHTTP(String name) async {
    Plugin? plugin;
    plugin = await PluginHTTP.getPlugin(name);
    return plugin;
  }

  String pluginStatus(PluginHTTPItem pluginHTTPItem) {
    String pluginStatus = 'install';
    for (Plugin plugin in pluginList) {
      if (pluginHTTPItem.name == plugin.name) {
        if (pluginHTTPItem.version == plugin.version) {
          pluginStatus = 'installed';
        } else {
          pluginStatus = 'update';
        }
        break;
      }
    }
    return pluginStatus;
  }

  String pluginUpdateStatus(Plugin plugin) {
    if (!pluginHTTPList.any((p) => p.name == plugin.name)) {
      return "nonexistent";
    }
    PluginHTTPItem p = pluginHTTPList.firstWhere(
      (p) => p.name == plugin.name,
    );
    return p.version == plugin.version ? "latest" : "updatable";
  }

  Future<int> tryUpdatePlugin(Plugin plugin) async {
    return await tryUpdatePluginByName(plugin.name);
  }

  Future<int> tryUpdatePluginByName(String name) async {
    var pluginHTTPItem = await queryPluginHTTP(name);
    if (pluginHTTPItem != null) {
      if (int.parse(pluginHTTPItem.api) > Api.apiLevel) {
        return 1;
      }
      updatePlugin(pluginHTTPItem);
      await savePlugins();
      return 0;
    }
    return 2;
  }

  Future<int> tryUpdateAllPlugin() async {
    int count = 0;
    for (Plugin plugin in pluginList) {
      if (pluginUpdateStatus(plugin) == 'updatable') {
        if (await tryUpdatePlugin(plugin) == 0) {
          count++;
        }
      }
    }
    return count;
  }

  void removePlugins(Set<String> pluginNames) {
    for (int i = pluginList.length - 1; i >= 0; --i) {
      var name = pluginList[i].name;
      if (pluginNames.contains(name)) {
        pluginList.removeAt(i);
      }
    }
  }
}
