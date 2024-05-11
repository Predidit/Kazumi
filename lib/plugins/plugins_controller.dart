import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:kazumi/modules/plugins/plugins_module.dart';

class PluginsController {
  List<Plugin> pluginList = [];

  loadPlugins() async {
    pluginList.clear();
    String directoryPath = 'assets/plugins';
    Directory directory = Directory(directoryPath);
    List<FileSystemEntity> entities = directory.listSync(recursive: true);
    for (var entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        String jsonString =
            await rootBundle.loadString('assets/plugins/${entity.uri.pathSegments.last}');
        Map<String, dynamic> data = jsonDecode(jsonString);
        pluginList.add(Plugin.fromJson(data));
      }
    }
  }
}
