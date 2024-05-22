import 'dart:io';
import 'dart:convert';
import 'package:mobx/mobx.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/request/plugin.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';

part 'plugins_controller.g.dart';

class PluginsController = _PluginsController with _$PluginsController;

abstract class _PluginsController with Store {
  @observable
  ObservableList<Plugin> pluginList = ObservableList.of([]);

  @observable
  ObservableList<PluginHTTPItem> pluginHTTPList = ObservableList.of([]);

  Future<void> loadPlugins() async {
    pluginList.clear();

    final directory = await getApplicationSupportDirectory();
    final pluginDirectory = Directory('${directory.path}/plugins');
    debugPrint('插件目录 ${directory.path}/plugins');

    if (await pluginDirectory.exists()) {
      final jsonFiles = pluginDirectory
          .listSync()
          .where((file) => file.path.endsWith('.json') && file is File)
          .map((file) => file.path)
          .toList();

      for (var filePath in jsonFiles) {
        final jsonString = await File(filePath).readAsString();
        final data = jsonDecode(jsonString);
        pluginList.add(Plugin.fromJson(data));
      }

      debugPrint('当前插件数量 ${pluginList.length}');
    } else {
      debugPrint('插件目录不存在');
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

    debugPrint('已将 ${jsonFiles.length} 个插件文件拷贝到 ${pluginDirectory.path}');
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

    debugPrint('已创建插件文件 $fileName');
  }

  Future<void> deletePluginJsonFile(Plugin plugin) async {
    final directory = await getApplicationSupportDirectory();
    final pluginDirectory = Directory('${directory.path}/plugins');

    if (!await pluginDirectory.exists()) {
      debugPrint('插件目录不存在，无法删除文件');
      return;
    }

    final fileName = '${plugin.name}.json';
    final file = File('${pluginDirectory.path}/$fileName');

    if (await file.exists()) {
      await file.delete();
      debugPrint('已删除插件文件 $fileName');
    } else {
      debugPrint('插件文件 $fileName 不存在');
    }
  }

  Future<void> queryPluginHTTPList() async {
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
}
