import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:kazumi/modules/plugins/plugins_module.dart';
import 'package:kazumi/modules/search/search_module.dart';

class PluginsController {
  List<Plugin> pluginList = [];

  loadPlugins() async {
    String jsonString = await rootBundle.loadString('assets/plugins/girigirilove.json');
    Map<String, dynamic> data = jsonDecode(jsonString);
    pluginList.clear();
    pluginList.add(Plugin.fromJson(data));
  }
}
