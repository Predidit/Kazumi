import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart' show debugPrint;
import 'package:kazumi/modules/plugins/plugins_module.dart';

class PluginsController {
  List<Plugin> pluginList = [];

  loadPlugins() async {
    pluginList.clear();
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    final jsonFiles = manifestMap.keys.where((String key) =>
        key.startsWith('assets/plugins/') && key.endsWith('.json'));

    for (var filePath in jsonFiles) {
      final jsonString = await rootBundle.loadString(filePath);
      final data = jsonDecode(jsonString);
      pluginList.add(Plugin.fromJson(data));
    }

    debugPrint('当前插件数量 ${pluginList.length}');
  }
}
