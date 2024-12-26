import 'dart:io';
import 'dart:convert';
import 'package:mobx/mobx.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugin_validity_tracker.dart';
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

  Future<void> loadPlugins() async {
    pluginList.clear();

    final directory = await getApplicationSupportDirectory();
    final pluginDirectory = Directory('${directory.path}/plugins');
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
        // 使用文件修改时间当作安装时间
        final stat = await file.stat();
        plugin.installTime = stat.modified.millisecondsSinceEpoch;
        pluginList.add(plugin);
      }

      KazumiLogger().log(Level.info, '当前插件数量 ${pluginList.length}');
    } else {
      KazumiLogger().log(Level.warning, '插件目录不存在');
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
      // panic
      final fileName = filePath.split('/').last;
      final file = File('${pluginDirectory.path}/$fileName');
      await file.writeAsString(jsonString);
    }

    KazumiLogger().log(
        Level.info, '已将 ${jsonFiles.length} 个插件文件拷贝到 ${pluginDirectory.path}');
  }

  Future<void> savePluginToJsonFile(Plugin plugin) async {
    final directory = await getApplicationSupportDirectory();
    final pluginDirectory = Directory('${directory.path}/plugins');

    if (!await pluginDirectory.exists()) {
      await pluginDirectory.create(recursive: true);
    }

    final fileName = '${plugin.name}.json';
    final existingFile = File('${pluginDirectory.path}/$fileName');
    if (await existingFile.exists()) {
      await existingFile.delete();
    }

    final newFile = File('${pluginDirectory.path}/$fileName');
    final jsonData = jsonEncode(plugin.toJson());
    await newFile.writeAsString(jsonData);

    KazumiLogger().log(Level.info, '已创建插件文件 $fileName');
  }

  Future<void> deletePluginJsonFile(Plugin plugin) async {
    final directory = await getApplicationSupportDirectory();
    final pluginDirectory = Directory('${directory.path}/plugins');

    if (!await pluginDirectory.exists()) {
      KazumiLogger().log(Level.warning, '插件目录不存在，无法删除文件');
      return;
    }

    final fileName = '${plugin.name}.json';
    final files = pluginDirectory.listSync();

    // workaround for android/linux case insensitive
    File? targetFile;
    for (var file in files) {
      if (file is File &&
          path.basename(file.path).toLowerCase() == fileName.toLowerCase()) {
        targetFile = file;
        break;
      }
    }

    if (targetFile != null) {
      await targetFile.delete();
      KazumiLogger()
          .log(Level.info, '已删除插件文件 ${path.basename(targetFile.path)}');
    } else {
      KazumiLogger().log(Level.warning, '插件文件 $fileName 不存在');
    }
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
      await savePluginToJsonFile(pluginHTTPItem);
      await loadPlugins();
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

  Future<void> tryInstallPlugin(Plugin plugin) async {
    await savePluginToJsonFile(plugin);
    await loadPlugins();
  }
}
